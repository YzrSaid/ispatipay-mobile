// lib/models/track.dart

class Track {
  final String id;
  final String title;
  final String artist;
  final String? albumArt;
  final Duration duration;
  final String? localPath;
  final String? streamUrl;
  final TrackStatus status;

  const Track({
    required this.id,
    required this.title,
    required this.artist,
    this.albumArt,
    required this.duration,
    this.localPath,
    this.streamUrl,
    this.status = TrackStatus.pending,
  });

  Track copyWith({
    String? id,
    String? title,
    String? artist,
    String? albumArt,
    Duration? duration,
    String? localPath,
    String? streamUrl,
    TrackStatus? status,
  }) {
    return Track(
      id: id ?? this.id,
      title: title ?? this.title,
      artist: artist ?? this.artist,
      albumArt: albumArt ?? this.albumArt,
      duration: duration ?? this.duration,
      localPath: localPath ?? this.localPath,
      streamUrl: streamUrl ?? this.streamUrl,
      status: status ?? this.status,
    );
  }

  String get formattedDuration {
    final minutes = duration.inMinutes;
    final seconds = duration.inSeconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }
}

enum TrackStatus {
  pending,
  downloading,
  downloaded,
  streaming,
  failed,
}

// lib/models/download_item.dart
class DownloadItem {
  final String id;
  final String filename;
  final String spotifyUrl;
  final String savePath;
  double progress;
  DownloadStatus status;
  String? errorMessage;
  int? totalBytes;
  int? receivedBytes;

  DownloadItem({
    required this.id,
    required this.filename,
    required this.spotifyUrl,
    required this.savePath,
    this.progress = 0.0,
    this.status = DownloadStatus.pending,
    this.errorMessage,
    this.totalBytes,
    this.receivedBytes,
  });

  String get speedFormatted {
    return '-- KB/s';
  }

  String get sizeFormatted {
    if (totalBytes == null) return '-- MB';
    final mb = totalBytes! / (1024 * 1024);
    return '${mb.toStringAsFixed(1)} MB';
  }
}

enum DownloadStatus {
  pending,
  downloading,
  completed,
  failed,
  cancelled,
}

// lib/models/settings.dart
class AppSettings {
  final String telegramApiId;
  final String telegramApiHash;
  final String botUsername;
  final String downloadPath;
  final bool streamingQuality;
  final bool autoPlay;

  const AppSettings({
    this.telegramApiId = '',
    this.telegramApiHash = '',
    this.botUsername = '',
    this.downloadPath = '',
    this.streamingQuality = true,
    this.autoPlay = true,
  });

  AppSettings copyWith({
    String? telegramApiId,
    String? telegramApiHash,
    String? botUsername,
    String? downloadPath,
    bool? streamingQuality,
    bool? autoPlay,
  }) {
    return AppSettings(
      telegramApiId: telegramApiId ?? this.telegramApiId,
      telegramApiHash: telegramApiHash ?? this.telegramApiHash,
      botUsername: botUsername ?? this.botUsername,
      downloadPath: downloadPath ?? this.downloadPath,
      streamingQuality: streamingQuality ?? this.streamingQuality,
      autoPlay: autoPlay ?? this.autoPlay,
    );
  }

  bool get isConfigured =>
      telegramApiId.isNotEmpty &&
      telegramApiHash.isNotEmpty &&
      botUsername.isNotEmpty;

  Map<String, dynamic> toJson() => {
        'telegramApiId': telegramApiId,
        'telegramApiHash': telegramApiHash,
        'botUsername': botUsername,
        'downloadPath': downloadPath,
        'streamingQuality': streamingQuality,
        'autoPlay': autoPlay,
      };

  factory AppSettings.fromJson(Map<String, dynamic> json) => AppSettings(
        telegramApiId: json['telegramApiId'] ?? '',
        telegramApiHash: json['telegramApiHash'] ?? '',
        botUsername: json['botUsername'] ?? '',
        downloadPath: json['downloadPath'] ?? '',
        streamingQuality: json['streamingQuality'] ?? true,
        autoPlay: json['autoPlay'] ?? true,
      );
}
