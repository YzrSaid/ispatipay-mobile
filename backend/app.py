import asyncio
import os
import re
import time
from pathlib import Path
from typing import Any

from fastapi import FastAPI, HTTPException
from fastapi.middleware.cors import CORSMiddleware
from fastapi.staticfiles import StaticFiles
from pydantic import BaseModel, Field
from telethon import TelegramClient

BASE_DIR = Path(__file__).resolve().parent
SESSIONS_DIR = BASE_DIR / 'sessions'
DOWNLOADS_DIR = BASE_DIR / 'downloads'
SESSION_NAME = 'telegram'
DEFAULT_BASE_URL = 'http://127.0.0.1:8000'

SESSIONS_DIR.mkdir(parents=True, exist_ok=True)
DOWNLOADS_DIR.mkdir(parents=True, exist_ok=True)

app = FastAPI(title='Ispatipay Telegram Backend')
app.add_middleware(
    CORSMiddleware,
    allow_origins=['*'],
    allow_credentials=True,
    allow_methods=['*'],
    allow_headers=['*'],
)
app.mount('/media', StaticFiles(directory=str(DOWNLOADS_DIR)), name='media')

_client: TelegramClient | None = None
_client_key: tuple[int, str] | None = None


class ProcessRequest(BaseModel):
    spotify_url: str = Field(..., min_length=1)
    api_id: str = Field(..., min_length=1)
    api_hash: str = Field(..., min_length=1)
    bot_username: str = Field(..., min_length=1)
    backend_url: str = Field(default=DEFAULT_BASE_URL)


class TrackPayload(BaseModel):
    id: str
    title: str
    artist: str
    duration_seconds: int
    local_path: str | None = None
    stream_url: str | None = None
    album_art: str | None = None


class ProcessResponse(BaseModel):
    messages: list[str]
    tracks: list[TrackPayload]


async def _ensure_client(api_id: int, api_hash: str) -> TelegramClient:
    global _client, _client_key

    current_key = (api_id, api_hash)
    if _client is None or _client_key != current_key:
        if _client is not None:
            await _client.disconnect()
        session_path = SESSIONS_DIR / SESSION_NAME
        _client = TelegramClient(str(session_path), api_id, api_hash)
        await _client.connect()
        _client_key = current_key

    if not await _client.is_user_authorized():
        print('\nTelegram login required for the backend session.')
        print('Enter your phone number, then the login code when prompted.')
        await _client.start(phone=lambda: input('Telegram phone number: ').strip())

    return _client


def _clean_text(value: str | None) -> str:
    return re.sub(r'\s+', ' ', (value or '').strip())


def _split_artist_title(value: str) -> tuple[str, str]:
    for separator in [' - ', ' — ', ' | ']:
        if separator in value:
            left, right = value.split(separator, 1)
            return _clean_text(left), _clean_text(right)
    return 'Telegram', _clean_text(value) or 'Unknown Track'


async def _collect_messages_and_media(
    client: TelegramClient,
    bot_username: str,
    spotify_url: str,
    base_url: str,
) -> ProcessResponse:
    history = await client.get_messages(bot_username, limit=1)
    last_seen_id = history[0].id if history else 0

    await client.send_message(bot_username, spotify_url)

    messages: list[str] = []
    tracks: list[TrackPayload] = []
    stable_rounds = 0
    deadline = time.monotonic() + 180

    while time.monotonic() < deadline and stable_rounds < 3:
        new_messages: list[Any] = []
        async for message in client.iter_messages(bot_username, min_id=last_seen_id, reverse=True):
            new_messages.append(message)

        if not new_messages:
            stable_rounds += 1
            await asyncio.sleep(2)
            continue

        stable_rounds = 0
        last_seen_id = max(message.id for message in new_messages)

        for message in new_messages:
            text = _clean_text(getattr(message, 'message', None) or getattr(message, 'raw_text', None))
            if text:
                messages.append(text)

            if not getattr(message, 'media', None):
                continue

            downloaded_path = await client.download_media(message, file=str(DOWNLOADS_DIR))
            if not downloaded_path:
                continue

            path = Path(downloaded_path)
            caption = _clean_text(text or path.stem)
            artist, title = _split_artist_title(caption)
            duration_seconds = 180

            audio = getattr(message, 'audio', None)
            if audio and getattr(audio, 'duration', None):
                duration_seconds = int(audio.duration)
            elif getattr(message, 'document', None):
                attrs = getattr(message.document, 'attributes', []) or []
                for attr in attrs:
                    duration = getattr(attr, 'duration', None)
                    if duration:
                        duration_seconds = int(duration)
                        break

            tracks.append(
                TrackPayload(
                    id=str(message.id),
                    title=title,
                    artist=artist,
                    duration_seconds=duration_seconds,
                    local_path=str(path),
                    stream_url=f'{base_url.rstrip("/")}/media/{path.name}',
                    album_art=None,
                )
            )

    if not tracks:
        raise HTTPException(
            status_code=502,
            detail='No audio files were returned by the Telegram bot.',
        )

    return ProcessResponse(messages=messages, tracks=tracks)


@app.get('/health')
async def health() -> dict[str, str]:
    return {'status': 'ok'}


@app.post('/process', response_model=ProcessResponse)
async def process_spotify_url(request: ProcessRequest) -> ProcessResponse:
    try:
        api_id = int(request.api_id)
    except ValueError as exc:
        raise HTTPException(status_code=400, detail='API ID must be numeric.') from exc

    if not request.api_hash.strip():
        raise HTTPException(status_code=400, detail='API hash is required.')
    if not request.bot_username.strip():
        raise HTTPException(status_code=400, detail='Bot username is required.')

    client = await _ensure_client(api_id, request.api_hash.strip())
    return await _collect_messages_and_media(
        client=client,
        bot_username=request.bot_username.strip(),
        spotify_url=request.spotify_url.strip(),
        base_url=request.backend_url.strip() or DEFAULT_BASE_URL,
    )


if __name__ == '__main__':
    import uvicorn

    uvicorn.run('app:app', host='0.0.0.0', port=8000, reload=False)
