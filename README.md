# Ispatipay — Flutter Mobile App

A beautiful Flutter mobile app that lets you download and stream Spotify music via a Telegram bot. This is the mobile reimagining of the original Python CLI tool.

## 📱 Screenshots & Features

### Screens
- **Splash Screen** — Animated logo intro
- **Downloader** — Paste Spotify links, watch downloads progress in real-time
- **Player** — Full music player with equalizer animation, playlist view, controls
- **Settings** — Configure your Telegram API credentials
- **About** — App info and usage guide

### Features
- 🎵 Download individual tracks, albums, and playlists
- ▶️ Stream music instantly via Telegram bot
- 🎮 Full playback controls (play/pause, skip, seek)
- 🔀 Shuffle and repeat modes (off / all / one)
- 📊 Animated equalizer display
- 📋 Playlist/queue management with track jumping
- 📥 Real-time download progress with speed/size info
- 🌙 Dark theme with Spotify-inspired green accents
- 🔧 Easy Telegram credential setup

## 🚀 Getting Started

### Prerequisites
- Flutter SDK 3.x
- Android Studio / VS Code
- Android device or emulator (Android 6.0+)

### Installation

```bash
# Clone or download the project
cd ispatipay_flutter

# Get dependencies
flutter pub get

# Run on device/emulator
flutter run

# Build APK
flutter build apk --release
```

### Configuration
1. Go to [my.telegram.org/apps](https://my.telegram.org/apps)
2. Create a new application and copy your **API ID** and **API Hash**
3. Find a Telegram bot that accepts Spotify links (e.g. @spotifydownloaderbot)
4. Open the app → Settings → Enter your credentials → Save

## 🏗️ Architecture

```
lib/
├── main.dart                    # App entry, theme
├── models/
│   └── models.dart              # Track, DownloadItem, AppSettings
├── services/
│   ├── telegram_service.dart    # Telegram bot communication
│   ├── audio_player_service.dart # Music playback
│   └── settings_service.dart    # Persistent settings
├── screens/
│   ├── splash_screen.dart       # Animated launch screen
│   ├── home_screen.dart         # Bottom nav shell
│   ├── downloader_screen.dart   # Download UI
│   ├── player_screen.dart       # Music player UI
│   ├── settings_screen.dart     # Configuration
│   └── about_screen.dart        # Info & help
└── widgets/
    └── track_download_card.dart # Download progress card
```

## 📦 Key Dependencies

| Package | Purpose |
|---------|---------|
| `just_audio` | Audio playback engine |
| `audio_service` | Background audio & media controls |
| `shared_preferences` | Settings persistence |
| `dio` | HTTP client for downloads |
| `path_provider` | File system paths |
| `permission_handler` | Storage permissions |
| `url_launcher` | Open GitHub/external links |

## ⚠️ Important Notes

- The app communicates with Telegram bots via the Bot HTTP API
- For full user-account access (like the Python CLI's Telethon), a backend server running the Python code would be needed
- All Telegram credentials are stored locally on the device
- The `.env` equivalent is the Settings screen — nothing is hardcoded

## 🔄 Differences from Python CLI

| Feature | Python CLI | Flutter App |
|---------|-----------|-------------|
| UI | Terminal (rich/figlet) | Native mobile UI |
| Audio | MPV subprocess | just_audio package |
| Telegram | Telethon (user account) | Bot API / simulated |
| Platform | Desktop | Android/iOS |
| Config | `.env` file | Settings screen |
| Download path | `~/Downloads/` | Device storage |

## 👨‍💻 Author

**Mohammad Aldrin Said** — [github.com/YzrSaid](https://github.com/YzrSaid)

Original Python project: [github.com/YzrSaid/ispatipay](https://github.com/YzrSaid/ispatipay)
