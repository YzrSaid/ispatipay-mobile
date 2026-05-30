Ispatipay local Telegram helper server

Usage

1. Install dependencies (preferably in a venv):

```bash
python -m pip install -r requirements.txt
```

2. Export your bot token (the server uses the Bot API for now):

```bash
export BOT_TOKEN="123456:ABCDEF..."
```

3. Run the server:

```bash
uvicorn server.app:app --reload --port 8000
```

4. From the Flutter app, set the `localTelegramServer` setting to `http://localhost:8000` and provide the `botUsername` in app settings.

Endpoints

- `POST /send_spotify` — JSON body: `{ "spotify_url": "...", "bot_username": "yourbot" }`. Returns `{'tracks': [...]}` where each track has `stream_url` like `/stream/<file>`.
- `GET /stream/{filename}` — streams the downloaded audio file with `Range` support for progressive playback.

Notes

- This implementation uses the Bot API and `getUpdates` polling (simple local dev flow). For a production-grade MTProto solution, switch to a Telethon-based client and implement proper session/login and update handling.

MTProto (Telethon) mode

1. Get your `api_id` and `api_hash` from https://my.telegram.org (API development tools).

2. Install dependencies (if you haven't already):

```bash
python -m pip install -r requirements.txt
```

3. Export your `API_ID` and `API_HASH` as environment variables and run the Telethon server:

```bash
export API_ID=123456
export API_HASH="your_api_hash_here"
uvicorn server.telethon_app:app --reload --port 8000
```

4. Authentication flow (in another terminal or via HTTP client):

Start auth (send code to your phone):

```bash
curl -X POST http://localhost:8000/mtproto/start_auth -H "Content-Type: application/json" -d '{"phone":"+1234567890"}'
```

Complete auth (submit code you receive via SMS/Telegram):

```bash
curl -X POST http://localhost:8000/mtproto/complete_auth -H "Content-Type: application/json" -d '{"phone":"+1234567890","code":"12345"}'
```

5. Use `/mtproto/send_spotify` with `session_phone` set to the phone used to sign in. The server will act as your user account, send the Spotify link to the target bot username, wait for media replies, download them, and return `stream_url` values that can be requested from `/stream/{filename}`.

Security note: session files are stored under `server/sessions/` and should be protected. Do not commit them to VCS.
