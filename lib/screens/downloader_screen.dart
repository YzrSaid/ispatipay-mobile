import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../main.dart';
import '../models/models.dart';
import '../services/telegram_service.dart';
import '../services/settings_service.dart';
import '../widgets/track_download_card.dart';

class DownloaderScreen extends StatefulWidget {
  const DownloaderScreen({super.key});

  @override
  State<DownloaderScreen> createState() => _DownloaderScreenState();
}

class _DownloaderScreenState extends State<DownloaderScreen> {
  final TextEditingController _urlController = TextEditingController();
  final List<DownloadItem> _downloads = [];
  final List<String> _logMessages = [];
  bool _isProcessing = false;
  bool _showLog = false;

  static const String _unknownPlaylistFolder = 'Playlist';

  @override
  void dispose() {
    _urlController.dispose();
    super.dispose();
  }

  Future<void> _startDownload() async {
    final url = _urlController.text.trim();
    if (url.isEmpty) {
      _showSnack('Please paste a Spotify link');
      return;
    }
    if (!url.contains('spotify.com')) {
      _showSnack('Please enter a valid Spotify URL');
      return;
    }
    if (!SettingsService.settings.isConfigured) {
      _showConfigAlert();
      return;
    }

    setState(() {
      _isProcessing = true;
      _logMessages.clear();
      _downloads.clear();
    });

    final rootDir = await TelegramService.getDownloadRootDirectory();
    final meta = await TelegramService.resolveSpotifyRequestMeta(url);

    String? fixedFolderName;
    if (meta.type == SpotifyLinkType.playlist) {
      fixedFolderName = TelegramService.sanitizePathPart(
        meta.playlistName ?? _unknownPlaylistFolder,
      );
    }

    final seenDestinations = <String>{};

    await TelegramService.sendSpotifyLink(
      spotifyUrl: url,
      onTrackReady: (track) {
        final targetDir = _targetDirectoryForTrack(
          track: track,
          rootDir: rootDir,
          linkType: meta.type,
          playlistFolderName: fixedFolderName,
        );
        final filename = TelegramService.buildTrackFilename(track);
        final savePath = '${targetDir.path}/$filename';

        if (seenDestinations.contains(savePath)) {
          return;
        }
        seenDestinations.add(savePath);

        final item = DownloadItem(
          id: track.id,
          filename: filename,
          spotifyUrl: url,
          savePath: savePath,
        );
        if (mounted) {
          setState(() => _downloads.add(item));
        }
        _downloadTrack(item, track, targetDir.path);
      },
      onMessage: (msg) {
        if (mounted) {
          setState(() => _logMessages.add(msg));
        }
      },
      onDone: () {
        if (mounted) setState(() => _isProcessing = false);
      },
      onError: () {
        if (mounted) setState(() => _isProcessing = false);
      },
    );
  }

  Directory _targetDirectoryForTrack({
    required Track track,
    required Directory rootDir,
    required SpotifyLinkType linkType,
    String? playlistFolderName,
  }) {
    switch (linkType) {
      case SpotifyLinkType.album:
        final artistFolder = TelegramService.sanitizePathPart(track.artist);
        return Directory('${rootDir.path}/$artistFolder');
      case SpotifyLinkType.playlist:
        final playlistFolder = playlistFolderName ??
            TelegramService.sanitizePathPart(_unknownPlaylistFolder);
        return Directory('${rootDir.path}/$playlistFolder');
      case SpotifyLinkType.track:
      case SpotifyLinkType.unknown:
        return rootDir;
    }
  }

  Future<void> _downloadTrack(
      DownloadItem item, Track track, String targetDirectory) async {
    setState(() => item.status = DownloadStatus.downloading);

    final path = await TelegramService.downloadTrack(
      track: track,
      saveDirectoryPath: targetDirectory,
      onProgress: (received, total) {
        if (mounted) {
          setState(() {
            item.receivedBytes = received;
            item.totalBytes = total;
            item.progress = total > 0 ? received / total : 0;
          });
        }
      },
    );

    if (mounted) {
      setState(() {
        item.status =
            path != null ? DownloadStatus.completed : DownloadStatus.failed;
        item.progress = path != null ? 1.0 : 0;
      });
    }
  }

  void _showSnack(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        behavior: SnackBarBehavior.floating,
        backgroundColor: AppTheme.cardColor,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  void _showConfigAlert() {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: AppTheme.cardColor,
        title: const Text('Setup Required',
            style: TextStyle(color: AppTheme.textPrimary)),
        content: const Text(
          'Please configure your Telegram API credentials in Settings before using the downloader.',
          style: TextStyle(color: AppTheme.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child:
                const Text('OK', style: TextStyle(color: AppTheme.accentGreen)),
          ),
        ],
      ),
    );
  }

  Future<void> _pasteFromClipboard() async {
    final data = await Clipboard.getData('text/plain');
    if (data?.text != null) {
      _urlController.text = data!.text!;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.bgColor,
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(),
            _buildInputSection(),
            _buildLogSection(),
            Expanded(child: _buildDownloadList()),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: AppTheme.accentGreen,
              borderRadius: BorderRadius.circular(14),
            ),
            child: const Icon(Icons.download_rounded,
                color: Colors.black, size: 24),
          ),
          const SizedBox(width: 14),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Downloader',
                    style: TextStyle(
                      color: AppTheme.textPrimary,
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                    )),
                Text('Download music via Telegram bot',
                    style:
                        TextStyle(color: AppTheme.textSecondary, fontSize: 12)),
              ],
            ),
          ),
          IconButton(
            icon: Icon(
              _showLog ? Icons.terminal : Icons.terminal_outlined,
              color: _showLog ? AppTheme.accentGreen : AppTheme.textSecondary,
            ),
            onPressed: () => setState(() => _showLog = !_showLog),
          ),
        ],
      ),
    );
  }

  Widget _buildInputSection() {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          Container(
            decoration: BoxDecoration(
              color: AppTheme.cardColor,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppTheme.borderColor),
            ),
            child: TextField(
              controller: _urlController,
              style: const TextStyle(color: AppTheme.textPrimary),
              decoration: InputDecoration(
                hintText: 'Paste Spotify link here...',
                hintStyle: const TextStyle(color: AppTheme.textSecondary),
                prefixIcon: const Padding(
                  padding: EdgeInsets.all(14),
                  child: _SpotifyIcon(),
                ),
                suffixIcon: IconButton(
                  icon: const Icon(Icons.content_paste_rounded,
                      color: AppTheme.textSecondary),
                  onPressed: _pasteFromClipboard,
                ),
                border: InputBorder.none,
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
              ),
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _isProcessing ? null : _startDownload,
              style: ElevatedButton.styleFrom(
                backgroundColor:
                    _isProcessing ? AppTheme.borderColor : AppTheme.accentGreen,
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
              child: _isProcessing
                  ? const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            color: AppTheme.accentGreen,
                            strokeWidth: 2,
                          ),
                        ),
                        SizedBox(width: 10),
                        Text('Processing...',
                            style: TextStyle(color: AppTheme.textSecondary)),
                      ],
                    )
                  : const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.download_rounded, color: Colors.black),
                        SizedBox(width: 8),
                        Text('Start Download',
                            style: TextStyle(
                              color: Colors.black,
                              fontWeight: FontWeight.bold,
                            )),
                      ],
                    ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLogSection() {
    if (!_showLog || _logMessages.isEmpty) return const SizedBox();

    return Container(
      height: 120,
      margin: const EdgeInsets.symmetric(horizontal: 20),
      decoration: BoxDecoration(
        color: AppTheme.surfaceColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.borderColor),
      ),
      child: ListView.builder(
        padding: const EdgeInsets.all(12),
        itemCount: _logMessages.length,
        itemBuilder: (_, i) => Padding(
          padding: const EdgeInsets.only(bottom: 2),
          child: Text(
            _logMessages[i],
            style: const TextStyle(
              color: Color(0xFF58A6FF),
              fontSize: 11,
              fontFamily: 'monospace',
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDownloadList() {
    if (_downloads.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.cloud_download_outlined,
                size: 64, color: AppTheme.textSecondary.withValues(alpha: 0.4)),
            const SizedBox(height: 16),
            Text('No downloads yet',
                style: TextStyle(
                  color: AppTheme.textSecondary.withValues(alpha: 0.6),
                  fontSize: 16,
                )),
            const SizedBox(height: 8),
            Text('Paste a Spotify link above to start',
                style: TextStyle(
                  color: AppTheme.textSecondary.withValues(alpha: 0.4),
                  fontSize: 13,
                )),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
      itemCount: _downloads.length,
      itemBuilder: (_, i) => TrackDownloadCard(item: _downloads[i]),
    );
  }
}

class _SpotifyIcon extends StatelessWidget {
  const _SpotifyIcon();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 22,
      height: 22,
      decoration: const BoxDecoration(
        color: AppTheme.accentGreen,
        shape: BoxShape.circle,
      ),
      child: const Icon(Icons.music_note, color: Colors.black, size: 14),
    );
  }
}
