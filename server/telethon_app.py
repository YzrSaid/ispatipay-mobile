import os
import time
import asyncio
from pathlib import Path
from typing import List, Dict, Optional
from urllib.parse import quote, urlparse

from fastapi import FastAPI, HTTPException, Request
from fastapi.responses import JSONResponse, StreamingResponse
from telethon import TelegramClient, events, errors

API_ID = int(os.environ.get('API_ID') or 0)
API_HASH = os.environ.get('API_HASH') or ''

if not API_ID or not API_HASH:
    print('Warning: API_ID/API_HASH not set. Set these env vars for MTProto Telethon flow.')

app = FastAPI(title='Ispatipay Telethon Helper')
BASE_DIR = Path(__file__).parent
DOWNLOAD_DIR = BASE_DIR / 'downloads'
SESSIONS_DIR = BASE_DIR / 'sessions'
DOWNLOAD_DIR.mkdir(exist_ok=True)
SESSIONS_DIR.mkdir(exist_ok=True)

# In-memory clients cache
_clients: Dict[str, TelegramClient] = {}
_album_art_cache: Dict[str, str] = {}


def session_path_for(phone: str) -> str:
    safe = phone.replace('+', '').replace(' ', '').replace('/', '_')
    return str(SESSIONS_DIR / f'session_{safe}')


async def get_client(phone: str) -> TelegramClient:
    key = phone
    if key in _clients:
        client = _clients[key]
        if not client.is_connected():
            await client.connect()
        return client

    session = session_path_for(phone)
    client = TelegramClient(session, API_ID, API_HASH)
    await client.connect()
    _clients[key] = client
    return client


async def reset_client(phone: str) -> TelegramClient:
    """Disconnect and remove cached client so next call starts completely fresh."""
    key = phone
    if key in _clients:
        try:
            await _clients[key].disconnect()
        except Exception:
            pass
        del _clients[key]

    session_base = session_path_for(phone)
    for ext in ['.session', '.session-journal']:
        p = Path(session_base + ext)
        try:
            if p.exists():
                p.unlink()
        except Exception as e:
            print(f"Warning: could not delete {p}: {e}")

    return await get_client(phone)


@app.post('/mtproto/start_auth')
async def mt_start_auth(payload: dict):
    phone = payload.get('phone')
    if not phone:
        raise HTTPException(status_code=400, detail='phone required')
    if not API_ID or not API_HASH:
        raise HTTPException(status_code=500, detail='API_ID/API_HASH not configured on server')

    client = await reset_client(phone)
    try:
        sent = await client.send_code_request(phone)
        sent_type = None
        try:
            sent_type = sent.type.__class__.__name__ if getattr(sent, 'type', None) is not None else None
        except Exception:
            sent_type = str(getattr(sent, 'type', None))
        info = {
            'sent': True,
            'phone_code_hash': getattr(sent, 'phone_code_hash', None),
            'sent_type': sent_type,
            'repr': str(sent),
        }
        print(f"start_auth: phone={phone} -> {info}")
        return JSONResponse(info)
    except errors.PhoneNumberInvalidError:
        raise HTTPException(status_code=400, detail='Invalid phone number')
    except errors.rpcerrorlist.SendCodeUnavailableError as e:
        print(f"start_auth SendCodeUnavailable for {phone}: {e}")
        raise HTTPException(
            status_code=429,
            detail='Telegram exhausted all code delivery methods. Wait 5-10 minutes and try again.',
        )
    except Exception as e:
        print(f"start_auth error for {phone}: {e}")
        raise HTTPException(status_code=500, detail=str(e))


@app.post('/mtproto/complete_auth')
async def mt_complete_auth(payload: dict):
    phone = payload.get('phone')
    code = payload.get('code')
    if not phone or not code:
        raise HTTPException(status_code=400, detail='phone and code required')
    client = await get_client(phone)
    try:
        try:
            await client.sign_in(phone=phone, code=code)
        except errors.SessionPasswordNeededError:
            return JSONResponse({'password_required': True})
        return JSONResponse({'signed_in': True})
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))


@app.post('/mtproto/send_spotify')
async def mt_send_spotify(payload: dict):
    phone = payload.get('session_phone')
    bot_username = payload.get('bot_username')
    spotify_url = payload.get('spotify_url')
    timeout = int(payload.get('timeout', 60))

    if not phone or not bot_username or not spotify_url:
        raise HTTPException(status_code=400, detail='session_phone, bot_username and spotify_url required')
    if not API_ID or not API_HASH:
        raise HTTPException(status_code=500, detail='API_ID/API_HASH not configured')

    client = await get_client(phone)

    found: List[Dict] = []
    seen_track_keys = set()
    clicked_get_all = False
    parsed_url = urlparse(spotify_url.strip())
    segments = [s for s in parsed_url.path.split('/') if s]
    stable_path = '/'.join(segments[:2]).lower() if len(segments) >= 2 else parsed_url.path.lower()
    cache_key = f"{bot_username.lower()}::{stable_path}"
    cached_album_art = _album_art_cache.get(cache_key)
    if cached_album_art and not Path(cached_album_art).exists():
        cached_album_art = None
        _album_art_cache.pop(cache_key, None)
    last_image_path: Optional[str] = cached_album_art

    @client.on(events.NewMessage(chats=bot_username))
    async def handler(event):
        nonlocal clicked_get_all, last_image_path, cached_album_art

        if event.out:
            return

        # Click "GET ALL" button if present and not yet clicked
        if event.buttons and not clicked_get_all:
            for row in event.buttons:
                for btn in row:
                    if 'GET ALL' in btn.text.upper():
                        clicked_get_all = True
                        await event.click(text=btn.text)
                        return

        if not event.file:
            return

        filename = Path(event.file.name or '').name
        ext = Path(filename).suffix.lower()
        mime_type = (getattr(event.file, 'mime_type', '') or '').lower()
        AUDIO_EXTENSIONS = ('.mp3', '.m4a', '.wav', '.flac', '.ogg', '.aac')
        IMAGE_EXTENSIONS = ('.jpg', '.jpeg', '.png', '.webp')
        is_audio = (
            event.audio is not None
            or ext in AUDIO_EXTENSIONS
            or mime_type.startswith('audio/')
        )
        is_image = (
            event.photo is not None
            or ext in IMAGE_EXTENSIONS
            or mime_type.startswith('image/')
        )

        # For repeated requests of the same Spotify URL, reuse cached art and skip downloading it again.
        if is_image and cached_album_art and Path(cached_album_art).exists():
            last_image_path = cached_album_art
            print(f"[handler] reusing cached album art: {Path(cached_album_art).name}")
            return

        # Reuse existing files by filename to avoid duplicates across repeated playlist requests.
        media_path: Optional[Path] = None
        if filename:
            candidate = DOWNLOAD_DIR / filename
            if candidate.exists():
                media_path = candidate
                print(f"[handler] reusing existing file: {candidate.name}")

        if media_path is None:
            downloaded = await event.download_media(file=DOWNLOAD_DIR)
            if not downloaded:
                return
            media_path = Path(downloaded)

        fname = media_path.name
        print(
            f"[handler] downloaded: {fname}, is_audio: {is_audio}, "
            f"is_image: {is_image}, mime: {mime_type or 'n/a'}"
        )

        # Save image path to attach to next audio track
        if is_image:
            last_image_path = str(media_path)
            cached_album_art = last_image_path
            _album_art_cache[cache_key] = last_image_path
            for track in found:
                if not track.get('album_art'):
                    track['album_art'] = last_image_path
            print(f"[handler] saved album art: {fname}")
            return

        # Skip non-audio, non-image files
        if not is_audio:
            print(f"[handler] skipping non-audio file: {fname}")
            return

        # Parse artist and title from filename — bot usually names "Artist - Title.mp3"
        stem_source = filename or fname
        stem = Path(stem_source).stem if stem_source else f'track_{len(found) + 1}'
        title = stem
        artist = bot_username.replace('@', '')
        if ' - ' in stem:
            parts = stem.split(' - ', 1)
            artist = parts[0].strip()
            title = parts[1].strip()

        track_key = f"{artist.lower()}::{title.lower()}"
        if track_key in seen_track_keys:
            print(f"[handler] duplicate track skipped: {title} by {artist}")
            return
        seen_track_keys.add(track_key)

        track = {
            'id': str(event.id),
            'title': title,
            'artist': artist,
            'album_art': last_image_path or cached_album_art,
            'duration': int(getattr(event.file, 'duration', 0) or 0),
            'stream_url': f"/stream/{quote(fname, safe='')}",
            'local_path': str(media_path),
        }
        print(f"[handler] track ready: {track['title']} by {track['artist']}")
        found.append(track)

    # Send the Spotify URL to the bot AFTER registering the handler
    await client.send_message(bot_username, spotify_url)
    print(f"[send_spotify] message sent to {bot_username}, waiting for tracks...")

    ## First wait up to 60 seconds for the FIRST track to arrive
    first_track_deadline = time.time() + 60
    while time.time() < first_track_deadline:
        await asyncio.sleep(1)
        if len(found) > 0:
            print(f"[send_spotify] first track arrived, switching to idle timer")
            break
    else:
        print(f"[send_spotify] timed out waiting for first track")
        client.remove_event_handler(handler)
        return JSONResponse({'tracks': found})

    # Then wait up to 120 more seconds, stopping if no new tracks for 10 seconds
    deadline = time.time() + 120
    last_count = len(found)
    last_new = time.time()

    while time.time() < deadline:
        await asyncio.sleep(1)
        if len(found) > last_count:
            last_new = time.time()
            last_count = len(found)
            print(f"[send_spotify] got {last_count} track(s) so far")
        elif (time.time() - last_new) > 10:
            print(f"[send_spotify] no new tracks for 10s, done")
            break

    client.remove_event_handler(handler)

    if cached_album_art:
        for track in found:
            if not track.get('album_art'):
                track['album_art'] = cached_album_art

    print(f"[send_spotify] returning {len(found)} tracks")
    return JSONResponse({'tracks': found})


@app.get('/stream/{filename}')
async def stream_file(request: Request, filename: str):
    file_path = DOWNLOAD_DIR / filename
    if not file_path.exists():
        raise HTTPException(status_code=404, detail='file not found')

    file_size = file_path.stat().st_size
    range_header = request.headers.get('range')

    if range_header is None:
        return StreamingResponse(
            open(file_path, 'rb'),
            media_type='audio/mpeg',
            headers={
                'Content-Length': str(file_size),
                'Accept-Ranges': 'bytes',
            }
        )

    try:
        bytes_range = range_header.replace('bytes=', '')
        start_str, end_str = bytes_range.split('-')
        start = int(start_str) if start_str else 0
        end = int(end_str) if end_str else file_size - 1
    except Exception:
        raise HTTPException(status_code=416, detail='Invalid range')

    if start >= file_size or start < 0:
        raise HTTPException(status_code=416, detail='Range out of bounds')

    end = min(end, file_size - 1)
    chunk_size = end - start + 1

    def iterfile(path, start, length):
        with open(path, 'rb') as f:
            f.seek(start)
            remaining = length
            while remaining > 0:
                data = f.read(min(65536, remaining))
                if not data:
                    break
                remaining -= len(data)
                yield data

    return StreamingResponse(
        iterfile(file_path, start, chunk_size),
        status_code=206,
        media_type='audio/mpeg',
        headers={
            'Content-Range': f'bytes {start}-{end}/{file_size}',
            'Accept-Ranges': 'bytes',
            'Content-Length': str(chunk_size),
        }
    )