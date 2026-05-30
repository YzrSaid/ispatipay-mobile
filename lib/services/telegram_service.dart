import 'dart:async';
import 'dart:io';
import 'package:dio/dio.dart';
import 'package:path_provider/path_provider.dart';
import '../models/models.dart';
import 'settings_service.dart';

/// TelegramService
///
/// This service uses the official Telegram Bot API directly from Flutter.
///
/// The flow mirrors the Python CLI:
///   1. User pastes a Spotify URL
///   2. The app sends it to the configured bot with sendMessage
///   3. The app polls getUpdates for replies and extracts audio file IDs
///   4. The app downloads the audio with getFile and stores it locally

typedef ProgressCallback = void Function(int received, int total);
typedef MessageCallback = void Function(String message);
typedef TrackReadyCallback = void Function(Track track);

enum SpotifyLinkType {
  track,
  album,
  playlist,
  unknown,
}

class SpotifyRequestMeta {
  final SpotifyLinkType type;
  final String? playlistName;

  const SpotifyRequestMeta({
    required this.type,
    this.playlistName,
  });
}

class TelegramService {
  static final Dio _dio = Dio(BaseOptions(
    connectTimeout: const Duration(seconds: 30),
    receiveTimeout: const Duration(minutes: 5),
    sendTimeout: const Duration(seconds: 30),
    responseType: ResponseType.json,
  ));

  static String get _botToken => SettingsService.settings.botToken.trim();
  static String get _botUsername => SettingsService.settings.botUsername;
  static String get _botApiBase => 'https://api.telegram.org/bot$_botToken';

  static bool get isConfigured {
    return SettingsService.settings.telegramApiId.isNotEmpty &&
        SettingsService.settings.telegramApiHash.isNotEmpty &&
        _botUsername.isNotEmpty &&
        _botToken.isNotEmpty;
  }

  static String? get _localServerUrl {
    final url = SettingsService.settings.localTelegramServer.trim();
    print('DEBUG _localServerUrl raw value: "$url"');
    if (url.isEmpty) return null;
    return url.endsWith('/') ? url.substring(0, url.length - 1) : url;
  }

  // MTProto auth helpers (via local server)
  static Future<Map<String, dynamic>?> startAuth(
      {required String serverUrl, required String phone}) async {
    try {
      final resp = await _dio.post<Map<String, dynamic>>(
        '$serverUrl/mtproto/start_auth',
        data: {'phone': phone},
      );
      return resp.data;
    } catch (_) {
      return {'error': 'start_auth request failed'};
    }
  }

  static Future<Map<String, dynamic>?> completeAuth(
      {required String serverUrl,
      required String phone,
      required String code}) async {
    try {
      final resp = await _dio.post<Map<String, dynamic>>(
        '$serverUrl/mtproto/complete_auth',
        data: {'phone': phone, 'code': code},
      );
      return resp.data;
    } catch (e) {
      return {'error': e.toString()};
    }
  }

  // ── Send a Spotify link to the configured bot ──────────────────────

  static Future<void> sendSpotifyLink({
    required String spotifyUrl,
    required TrackReadyCallback onTrackReady,
    required MessageCallback onMessage,
    required VoidCallback onDone,
    required VoidCallback onError,
  }) async {
    // If a local helper server is configured, use it (supports ranged streaming).
    final local = _localServerUrl;
    if (local != null) {
      await _sendSpotifyViaLocalServer(
          local, spotifyUrl, onTrackReady, onMessage, onDone, onError);
      return;
    }

    if (!isConfigured) {
      onMessage(
          '⚠️ Please configure your Telegram API credentials, bot username, and bot token in Settings first.');
      onError();
      return;
    }

    onMessage('📡 Connecting to Telegram bot...');

    try {
      final cleanBotUsername = _botUsername.replaceAll('@', '');
      final sendResponse = await _dio.post<Map<String, dynamic>>(
        '$_botApiBase/sendMessage',
        data: {
          'chat_id': cleanBotUsername,
          'text': spotifyUrl,
        },
      );

      if (sendResponse.data == null || sendResponse.data!['ok'] != true) {
        throw const FormatException('Telegram sendMessage failed');
      }

      onMessage('📨 Sent Spotify link to @$cleanBotUsername');

      final updatesResponse = await _dio.get<Map<String, dynamic>>(
        '$_botApiBase/getUpdates',
      );

      final data = updatesResponse.data;
      if (data == null) {
        throw const FormatException('Telegram returned an empty response');
      }

      final updates = (data['result'] as List<dynamic>?) ?? const [];
      var foundTracks = 0;
      for (final update in updates) {
        if (update is! Map<String, dynamic>) continue;
        final message = update['message'];
        if (message is! Map<String, dynamic>) continue;

        final text = message['text']?.toString();
        if (text != null && text.isNotEmpty) {
          onMessage(text);
        }

        final audio = message['audio'];
        final document = message['document'];
        final media = audio is Map<String, dynamic>
            ? audio
            : document is Map<String, dynamic>
                ? document
                : null;
        if (media == null) continue;

        final fileId = media['file_id']?.toString();
        if (fileId == null || fileId.isEmpty) continue;

        final fileName =
            media['file_name']?.toString() ?? 'track_$foundTracks.mp3';
        final durationSeconds =
            int.tryParse(media['duration']?.toString() ?? '') ?? 180;
        final filePath = await _downloadTelegramFile(fileId, fileName);

        final track = Track(
          id: fileId,
          title: fileName.replaceAll(
              RegExp(r'\.mp3$|\.m4a$|\.ogg$', caseSensitive: false), ''),
          artist: _botUsername.replaceAll('@', ''),
          duration:
              Duration(seconds: durationSeconds > 0 ? durationSeconds : 180),
          localPath: filePath,
          streamUrl: filePath,
          status: TrackStatus.downloaded,
        );
        foundTracks += 1;
        onTrackReady(track);
      }

      if (foundTracks == 0) {
        throw const FormatException('No audio files were returned by the bot');
      }

      onMessage('✅ Telegram bot finished processing.');
      onDone();
    } on DioException catch (e) {
      onMessage('❌ Telegram request failed: ${e.message ?? e.type.name}');
      onError();
    } catch (e) {
      onMessage('❌ Telegram request failed: $e');
      onError();
    }
  }

  static Future<void> _sendSpotifyViaLocalServer(
    String serverUrl,
    String spotifyUrl,
    TrackReadyCallback onTrackReady,
    MessageCallback onMessage,
    VoidCallback onDone,
    VoidCallback onError,
  ) async {
    try {
      onMessage('📡 Sending to local server...');
      final fullUrl = '$serverUrl/mtproto/send_spotify';
      print('DEBUG sending to: $fullUrl');
      print('DEBUG phone: ${SettingsService.settings.phone}');
      print('DEBUG bot: ${SettingsService.settings.botUsername}');
      final resp = await _dio.post<Map<String, dynamic>>(
        fullUrl,
        data: {
          'spotify_url': spotifyUrl,
          'session_phone': SettingsService.settings.phone,
          'bot_username': SettingsService.settings.botUsername,
        },
      );

      final data = resp.data;
      if (data == null || data['tracks'] == null) {
        throw const FormatException('Local server returned no tracks');
      }

      final tracks = data['tracks'] as List<dynamic>;
      for (final t in tracks) {
        if (t is! Map<String, dynamic>) continue;
        final id = t['id']?.toString() ??
            DateTime.now().millisecondsSinceEpoch.toString();
        final title = t['title']?.toString() ?? 'Track';
        final artist = t['artist']?.toString() ?? 'bot';
        final durationSec =
            int.tryParse(t['duration']?.toString() ?? '') ?? 180;
        final localPath = t['local_path']?.toString();
        final albumArt = t['album_art']?.toString();
        final streamUrl =
            t['stream_url'] != null ? '$serverUrl${t['stream_url']}' : null;

        final track = Track(
          id: id,
          title: title,
          artist: artist,
          albumArt: albumArt,
          duration: Duration(seconds: durationSec),
          localPath: localPath,
          streamUrl: streamUrl,
          status: TrackStatus.downloaded,
        );
        onTrackReady(track);
      }

      onMessage('✅ Local server finished processing.');
      onDone();
    } catch (e) {
      onMessage('❌ Local server request failed: $e');
      onError();
    }
  }

  // ── Download a track ───────────────────────────────────────────────

  static Future<SpotifyRequestMeta> resolveSpotifyRequestMeta(
      String spotifyUrl) async {
    final type = _detectSpotifyLinkType(spotifyUrl);
    if (type != SpotifyLinkType.playlist) {
      return SpotifyRequestMeta(type: type);
    }

    final playlistName = await _fetchSpotifyOEmbedTitle(spotifyUrl);
    return SpotifyRequestMeta(type: type, playlistName: playlistName);
  }

  static SpotifyLinkType _detectSpotifyLinkType(String spotifyUrl) {
    final uri = Uri.tryParse(spotifyUrl);
    if (uri == null) return SpotifyLinkType.unknown;

    final segments = uri.pathSegments.map((s) => s.toLowerCase()).toList();
    if (segments.contains('track')) return SpotifyLinkType.track;
    if (segments.contains('album')) return SpotifyLinkType.album;
    if (segments.contains('playlist')) return SpotifyLinkType.playlist;
    return SpotifyLinkType.unknown;
  }

  static Future<String?> _fetchSpotifyOEmbedTitle(String spotifyUrl) async {
    try {
      final resp = await _dio.get<Map<String, dynamic>>(
        'https://open.spotify.com/oembed',
        queryParameters: {'url': spotifyUrl},
      );
      final title = resp.data?['title']?.toString().trim();
      if (title == null || title.isEmpty) return null;
      return title;
    } catch (_) {
      return null;
    }
  }

  static String buildTrackFilename(Track track) {
    return '${_sanitizeFilename(track.title)} - ${_sanitizeFilename(track.artist)}.mp3';
  }

  static String sanitizePathPart(String value) {
    final cleaned = _sanitizeFilename(value).trim();
    return cleaned.isEmpty ? 'Unknown' : cleaned;
  }

  static Future<Directory> getDownloadRootDirectory() async {
    return _getDownloadDirectory();
  }

  static Future<String?> downloadTrack({
    required Track track,
    required ProgressCallback onProgress,
    String? saveDirectoryPath,
    CancelToken? cancelToken,
  }) async {
    try {
      final dir = saveDirectoryPath != null
          ? Directory(saveDirectoryPath)
          : await _getDownloadDirectory();
      await dir.create(recursive: true);

      final filename = buildTrackFilename(track);
      final savePath = '${dir.path}/$filename';
      final destination = File(savePath);

      if (await destination.exists()) {
        onProgress(1, 1);
        return savePath;
      }

      if (track.localPath != null && track.localPath!.isNotEmpty) {
        final sourceFile = File(track.localPath!);
        if (await sourceFile.exists()) {
          if (sourceFile.path == destination.path) {
            onProgress(1, 1);
            return savePath;
          }
          await sourceFile.copy(savePath);
          onProgress(1, 1);
          return savePath;
        }
      }

      final sourceUrl = track.streamUrl;
      if (sourceUrl == null || sourceUrl.isEmpty) {
        throw const FormatException('Track has no downloadable source');
      }

      await _dio.download(
        sourceUrl,
        savePath,
        cancelToken: cancelToken,
        onReceiveProgress: onProgress,
      );

      return savePath;
    } catch (e) {
      return null;
    }
  }

  // ── Helpers ────────────────────────────────────────────────────────

  static Future<Directory> _getDownloadDirectory() async {
    Directory? base;

    try {
      base = await getExternalStorageDirectory();
    } on UnimplementedError {
      base = null;
    }

    if (base == null) {
      try {
        base = await getDownloadsDirectory();
      } on UnimplementedError {
        base = null;
      }
    }

    base ??= await getApplicationDocumentsDirectory();

    final dir = Directory('${base.path}/Ispatipay');
    await dir.create(recursive: true);
    return dir;
  }

  static String _sanitizeFilename(String name) {
    return name.replaceAll(RegExp(r'[<>:"/\\|?*]'), '_');
  }

  static Future<String> _downloadTelegramFile(
    String fileId,
    String fileName,
  ) async {
    final fileResponse = await _dio.get<Map<String, dynamic>>(
      '$_botApiBase/getFile',
      queryParameters: {'file_id': fileId},
    );

    final fileData = fileResponse.data;
    if (fileData == null || fileData['ok'] != true) {
      throw const FormatException('Telegram getFile failed');
    }

    final filePath = fileData['result']?['file_path']?.toString();
    if (filePath == null || filePath.isEmpty) {
      throw const FormatException('Telegram file path missing');
    }

    final dir = await _getDownloadDirectory();
    final savePath = '${dir.path}/${_sanitizeFilename(fileName)}';
    await _dio.download(
        'https://api.telegram.org/file/bot$_botToken/$filePath', savePath);
    return savePath;
  }
}

// Alias for usage
typedef VoidCallback = void Function();
