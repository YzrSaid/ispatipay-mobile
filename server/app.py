import os
import time
import tempfile
import shutil
from pathlib import Path
from typing import List

import requests
from fastapi import FastAPI, HTTPException, Request, Response
from fastapi.responses import StreamingResponse, JSONResponse

app = FastAPI(title="Ispatipay Telegram Helper")

BOT_TOKEN = os.environ.get("BOT_TOKEN", "")
DOWNLOAD_DIR = Path(__file__).parent / "downloads"
DOWNLOAD_DIR.mkdir(exist_ok=True)

if not BOT_TOKEN:
    print("Warning: BOT_TOKEN not set. Set BOT_TOKEN env var before running the server.")

TELEGRAM_API = lambda token: f"https://api.telegram.org/bot{token}"
FILE_API = lambda token, path: f"https://api.telegram.org/file/bot{token}/{path}"


@app.post('/send_spotify')
def send_spotify(payload: dict):
    """Send a Spotify URL to the configured bot and wait for audio/document replies.
    Returns a JSON payload with 'tracks': list of {id, title, artist, duration, stream_url}
    """
    if not BOT_TOKEN:
        raise HTTPException(status_code=500, detail="BOT_TOKEN not configured on server")

    spotify_url = payload.get('spotify_url')
    if not spotify_url:
        raise HTTPException(status_code=400, detail="spotify_url required")

    bot_username = payload.get('bot_username')
    if not bot_username:
        raise HTTPException(status_code=400, detail="bot_username required")

    # Send message to bot
    send_resp = requests.post(
        f"{TELEGRAM_API(BOT_TOKEN)}/sendMessage",
        json={'chat_id': f'@{bot_username.replace("@","")}', 'text': spotify_url},
        timeout=15,
    )
    if send_resp.status_code != 200:
        raise HTTPException(status_code=500, detail=f"sendMessage failed: {send_resp.text}")

    # Poll getUpdates for replies (simple polling, for local dev)
    timeout = int(payload.get('timeout', 12))
    deadline = time.time() + timeout
    found: List[dict] = []

    last_update_id = None
    while time.time() < deadline:
        try:
            r = requests.get(f"{TELEGRAM_API(BOT_TOKEN)}/getUpdates", timeout=10)
            if r.status_code != 200:
                time.sleep(1)
                continue
            data = r.json()
            results = data.get('result', [])
            for upd in results:
                update_id = upd.get('update_id')
                if last_update_id is None or update_id > last_update_id:
                    last_update_id = update_id
                message = upd.get('message')
                if not message:
                    continue
                # Accept audio or document
                media = message.get('audio') or message.get('document')
                if media:
                    file_id = media.get('file_id')
                    if not file_id:
                        continue
                    # getFile to obtain file_path
                    gf = requests.get(f"{TELEGRAM_API(BOT_TOKEN)}/getFile", params={'file_id': file_id}, timeout=15)
                    if gf.status_code != 200:
                        continue
                    file_info = gf.json().get('result') or {}
                    file_path = file_info.get('file_path')
                    if not file_path:
                        continue
                    # download file into downloads dir
                    fname = Path(file_path).name
                    # avoid name collisions
                    dest = DOWNLOAD_DIR / f"{int(time.time())}_{fname}"
                    try:
                        with requests.get(FILE_API(BOT_TOKEN, file_path), stream=True, timeout=30) as rr:
                            rr.raise_for_status()
                            with open(dest, 'wb') as f:
                                shutil.copyfileobj(rr.raw, f)
                    except Exception:
                        continue

                    track = {
                        'id': file_id,
                        'title': media.get('file_name') or fname,
                        'artist': message.get('from') or 'bot',
                        'duration': media.get('duration') or 0,
                        'stream_url': f"/stream/{dest.name}",
                    }
                    found.append(track)
        except Exception:
            pass
        if found:
            break
        time.sleep(1)

    return JSONResponse({'tracks': found})


@app.get('/stream/{filename}')
def stream_file(request: Request, filename: str):
    file_path = DOWNLOAD_DIR / filename
    if not file_path.exists():
        raise HTTPException(status_code=404, detail='file not found')

    file_size = file_path.stat().st_size
    range_header = request.headers.get('range')
    if range_header is None:
        return StreamingResponse(open(file_path, 'rb'), media_type='audio/mpeg')

    # Parse Range header: bytes=start-end
    bytes_unit, bytes_range = range_header.split('=')
    if bytes_unit != 'bytes':
        return Response(status_code=416)
    start_end = bytes_range.split('-')
    try:
        start = int(start_end[0]) if start_end[0] else 0
        end = int(start_end[1]) if len(start_end) > 1 and start_end[1] else file_size - 1
    except ValueError:
        return Response(status_code=416)
    if start >= file_size:
        return Response(status_code=416)

    chunk_size = (end - start) + 1
    def iterfile(path, start, chunk_size):
        with open(path, 'rb') as f:
            f.seek(start)
            remaining = chunk_size
            while remaining > 0:
                read_size = min(4096, remaining)
                data = f.read(read_size)
                if not data:
                    break
                remaining -= len(data)
                yield data

    headers = {
        'Content-Range': f'bytes {start}-{end}/{file_size}',
        'Accept-Ranges': 'bytes',
        'Content-Length': str(chunk_size),
    }
    return StreamingResponse(iterfile(file_path, start, chunk_size), status_code=206, headers=headers, media_type='audio/mpeg')
