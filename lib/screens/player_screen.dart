import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart' hide RepeatMode;
import 'package:flutter/services.dart';
import '../main.dart';
import '../models/models.dart';
import '../services/telegram_service.dart';
import '../services/audio_player_service.dart';
import '../services/settings_service.dart';

class PlayerScreen extends StatefulWidget {
  const PlayerScreen({super.key});

  @override
  State<PlayerScreen> createState() => _PlayerScreenState();
}

class _PlayerScreenState extends State<PlayerScreen>
    with TickerProviderStateMixin {
  final TextEditingController _urlController = TextEditingController();

  final List<Track> _queue = [];
  int _currentIndex = -1;
  bool _isLoading = false;
  bool _isPlaying = false;
  bool _isPaused = false;
  bool _showPlaylist = false;
  bool _shuffleEnabled = false;
  RepeatMode _repeatMode = RepeatMode.off;

  // Position tracking
  Duration _position = Duration.zero;
  Duration _duration = Duration.zero;
  Timer? _positionTimer;

  // Equalizer animation
  late AnimationController _eqController;
  final List<double> _eqBars = List.generate(20, (_) => 0.2);

  // Messages
  final List<String> _messages = [];

  @override
  void initState() {
    super.initState();
    _eqController = AnimationController(
      duration: const Duration(milliseconds: 150),
      vsync: this,
    )..addListener(_updateEqualizer);
    _startEqTimer();
  }

  @override
  void dispose() {
    _urlController.dispose();
    _positionTimer?.cancel();
    _eqController.dispose();
    super.dispose();
  }

  void _startEqTimer() {
    Timer.periodic(const Duration(milliseconds: 120), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      if (_isPlaying && !_isPaused) {
        setState(() {
          for (int i = 0; i < _eqBars.length; i++) {
            final delta = (Random().nextDouble() - 0.4) * 0.3;
            _eqBars[i] = (_eqBars[i] + delta).clamp(0.05, 1.0);
          }
        });
      } else {
        setState(() {
          for (int i = 0; i < _eqBars.length; i++) {
            _eqBars[i] = max(0.05, _eqBars[i] - 0.05);
          }
        });
      }
    });
  }

  void _updateEqualizer() {}

  Future<void> _loadSpotifyLink() async {
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
      _isLoading = true;
      _queue.clear();
      _currentIndex = -1;
      _messages.clear();
      _isPlaying = false;
      _isPaused = false;
      _position = Duration.zero;
    });

    await TelegramService.sendSpotifyLink(
      spotifyUrl: url,
      onTrackReady: (track) {
        if (!mounted) return;
        setState(() {
          _queue.add(track);
          // Auto-play first track
          if (_currentIndex == -1) {
            _currentIndex = 0;
            _simulatePlay(_queue[0]);
          }
        });
      },
      onMessage: (msg) {
        if (mounted) setState(() => _messages.add(msg));
      },
      onDone: () {
        if (mounted) setState(() => _isLoading = false);
      },
      onError: () {
        if (mounted) setState(() => _isLoading = false);
      },
    );
  }

  void _simulatePlay(Track track) {
    setState(() {
      _isPlaying = true;
      _isPaused = false;
      _position = Duration.zero;
      _duration = track.duration;
    });

    _positionTimer?.cancel();
    _positionTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      if (!_isPaused) {
        setState(() {
          if (_position < _duration) {
            _position += const Duration(seconds: 1);
          } else {
            timer.cancel();
            _onTrackEnd();
          }
        });
      }
    });
  }

  void _onTrackEnd() {
    if (_repeatMode == RepeatMode.one) {
      _simulatePlay(_queue[_currentIndex]);
    } else if (_repeatMode == RepeatMode.all ||
        _currentIndex < _queue.length - 1) {
      _nextTrack();
    } else {
      setState(() {
        _isPlaying = false;
        _isPaused = false;
      });
    }
  }

  void _togglePlayPause() {
    setState(() => _isPaused = !_isPaused);
  }

  void _nextTrack() {
    if (_queue.isEmpty) return;
    int next;
    if (_shuffleEnabled) {
      next = Random().nextInt(_queue.length);
    } else if (_repeatMode == RepeatMode.one) {
      next = _currentIndex;
    } else {
      next = (_currentIndex + 1) % _queue.length;
    }
    setState(() => _currentIndex = next);
    _simulatePlay(_queue[next]);
  }

  void _prevTrack() {
    if (_queue.isEmpty) return;
    if (_position.inSeconds > 3) {
      setState(() => _position = Duration.zero);
      return;
    }
    final prev = _currentIndex > 0 ? _currentIndex - 1 : _queue.length - 1;
    setState(() => _currentIndex = prev);
    _simulatePlay(_queue[prev]);
  }

  void _jumpToTrack(int index) {
    if (index < 0 || index >= _queue.length) return;
    setState(() => _currentIndex = index);
    _simulatePlay(_queue[index]);
  }

  void _cycleRepeat() {
    setState(() {
      switch (_repeatMode) {
        case RepeatMode.off:
          _repeatMode = RepeatMode.all;
          break;
        case RepeatMode.all:
          _repeatMode = RepeatMode.one;
          break;
        case RepeatMode.one:
          _repeatMode = RepeatMode.off;
          break;
      }
    });
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
          'Please configure your Telegram API credentials in Settings.',
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

  String _fmt(Duration d) {
    final m = d.inMinutes;
    final s = d.inSeconds % 60;
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.bgColor,
      body: SafeArea(
        child: _showPlaylist ? _buildPlaylistView() : _buildPlayerView(),
      ),
    );
  }

  Widget _buildPlayerView() {
    final track = _currentIndex >= 0 && _currentIndex < _queue.length
        ? _queue[_currentIndex]
        : null;

    return Column(
      children: [
        _buildHeader(track),
        if (_isLoading || _messages.isNotEmpty) _buildStatusBanner(),
        const SizedBox(height: 8),
        _buildInputRow(),
        const SizedBox(height: 16),
        _buildAlbumArt(track),
        const SizedBox(height: 20),
        _buildTrackInfo(track),
        const SizedBox(height: 12),
        _buildEqualizer(),
        const SizedBox(height: 16),
        _buildProgressBar(),
        const SizedBox(height: 20),
        _buildControls(),
        const SizedBox(height: 20),
        _buildModeButtons(),
      ],
    );
  }

  Widget _buildHeader(Track? track) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [AppTheme.accentPurple, AppTheme.accentCyan],
              ),
              borderRadius: BorderRadius.circular(14),
            ),
            child: const Icon(Icons.headphones_rounded,
                color: Colors.black, size: 24),
          ),
          const SizedBox(width: 14),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Music Player',
                    style: TextStyle(
                      color: AppTheme.textPrimary,
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                    )),
                Text('Stream via Telegram bot',
                    style:
                        TextStyle(color: AppTheme.textSecondary, fontSize: 12)),
              ],
            ),
          ),
          if (_queue.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.queue_music_rounded,
                  color: AppTheme.textSecondary),
              onPressed: () => setState(() => _showPlaylist = true),
            ),
        ],
      ),
    );
  }

  Widget _buildStatusBanner() {
    final lastMsg = _messages.isNotEmpty ? _messages.last : '';
    return Container(
      margin: const EdgeInsets.fromLTRB(20, 12, 20, 0),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFF0D1117),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFF30363D)),
      ),
      child: Row(
        children: [
          if (_isLoading)
            const SizedBox(
              width: 12,
              height: 12,
              child: CircularProgressIndicator(
                color: AppTheme.accentCyan,
                strokeWidth: 1.5,
              ),
            ),
          if (_isLoading) const SizedBox(width: 8),
          Expanded(
            child: Text(
              lastMsg,
              style: const TextStyle(
                color: Color(0xFF58A6FF),
                fontSize: 11,
                fontFamily: 'monospace',
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInputRow() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Row(
        children: [
          Expanded(
            child: Container(
              height: 44,
              decoration: BoxDecoration(
                color: AppTheme.cardColor,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppTheme.borderColor),
              ),
              child: TextField(
                controller: _urlController,
                style:
                    const TextStyle(color: AppTheme.textPrimary, fontSize: 13),
                decoration: InputDecoration(
                  hintText: 'Paste Spotify link to stream...',
                  hintStyle: const TextStyle(
                      color: AppTheme.textSecondary, fontSize: 12),
                  prefixIcon: const Icon(Icons.link_rounded,
                      color: AppTheme.textSecondary, size: 18),
                  suffixIcon: IconButton(
                    icon: const Icon(Icons.content_paste_rounded,
                        color: AppTheme.textSecondary, size: 16),
                    onPressed: _pasteFromClipboard,
                  ),
                  border: InputBorder.none,
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                ),
              ),
            ),
          ),
          const SizedBox(width: 10),
          GestureDetector(
            onTap: _isLoading ? null : _loadSpotifyLink,
            child: Container(
              height: 44,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              decoration: BoxDecoration(
                gradient: _isLoading
                    ? null
                    : const LinearGradient(
                        colors: [AppTheme.accentGreen, Color(0xFF00BFA5)],
                      ),
                color: _isLoading ? AppTheme.borderColor : null,
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Center(
                child: Text('PLAY',
                    style: TextStyle(
                      color: Colors.black,
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                    )),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAlbumArt(Track? track) {
    return Container(
      width: 180,
      height: 180,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: track != null
              ? [const Color(0xFF6B2FBF), const Color(0xFF1DB954)]
              : [const Color(0xFF1A1A2E), const Color(0xFF16213E)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: (track != null ? AppTheme.accentGreen : Colors.black)
                .withValues(alpha: 0.3),
            blurRadius: 30,
            spreadRadius: 5,
          ),
        ],
      ),
      child: Icon(
        track != null ? Icons.music_note_rounded : Icons.library_music_rounded,
        color: Colors.white.withValues(alpha: 0.9),
        size: 72,
      ),
    );
  }

  Widget _buildTrackInfo(Track? track) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32),
      child: Column(
        children: [
          Text(
            track?.title ?? 'No Track Loaded',
            style: const TextStyle(
              color: AppTheme.textPrimary,
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 4),
          Text(
            track?.artist ?? 'Paste a Spotify link above',
            style: const TextStyle(color: AppTheme.textSecondary, fontSize: 14),
            textAlign: TextAlign.center,
          ),
          if (_queue.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                '${_currentIndex + 1} / ${_queue.length}',
                style:
                    const TextStyle(color: AppTheme.accentGreen, fontSize: 12),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildEqualizer() {
    return SizedBox(
      height: 40,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: _eqBars.map((h) {
          Color barColor;
          if (h > 0.7) {
            barColor = AppTheme.accentGreen;
          } else if (h > 0.4)
            barColor = AppTheme.accentCyan;
          else
            barColor = const Color(0xFF1565C0);

          return AnimatedContainer(
            duration: const Duration(milliseconds: 100),
            width: 6,
            height: max(3.0, h * 40),
            margin: const EdgeInsets.symmetric(horizontal: 1),
            decoration: BoxDecoration(
              color: barColor,
              borderRadius: BorderRadius.circular(3),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildProgressBar() {
    final progress = _duration.inMilliseconds > 0
        ? _position.inMilliseconds / _duration.inMilliseconds
        : 0.0;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        children: [
          SliderTheme(
            data: SliderThemeData(
              trackHeight: 3,
              thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
              overlayShape: const RoundSliderOverlayShape(overlayRadius: 14),
              activeTrackColor: AppTheme.accentGreen,
              inactiveTrackColor: AppTheme.borderColor,
              thumbColor: AppTheme.accentGreen,
              overlayColor: AppTheme.accentGreen.withValues(alpha: 0.2),
            ),
            child: Slider(
              value: progress.clamp(0.0, 1.0),
              onChanged: _isPlaying
                  ? (val) {
                      setState(() {
                        _position = Duration(
                          milliseconds:
                              (val * _duration.inMilliseconds).round(),
                        );
                      });
                    }
                  : null,
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(_fmt(_position),
                    style: const TextStyle(
                        color: AppTheme.accentGreen, fontSize: 12)),
                Text(_fmt(_duration),
                    style: const TextStyle(
                        color: AppTheme.textSecondary, fontSize: 12)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildControls() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        _ControlButton(
          icon: Icons.skip_previous_rounded,
          size: 36,
          onTap: _queue.isNotEmpty ? _prevTrack : null,
        ),
        const SizedBox(width: 24),
        GestureDetector(
          onTap: _isPlaying ? _togglePlayPause : null,
          child: Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [AppTheme.accentGreen, Color(0xFF00BFA5)],
              ),
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: AppTheme.accentGreen.withValues(alpha: 0.4),
                  blurRadius: 20,
                  spreadRadius: 2,
                ),
              ],
            ),
            child: Icon(
              _isPaused || !_isPlaying
                  ? Icons.play_arrow_rounded
                  : Icons.pause_rounded,
              color: Colors.black,
              size: 40,
            ),
          ),
        ),
        const SizedBox(width: 24),
        _ControlButton(
          icon: Icons.skip_next_rounded,
          size: 36,
          onTap: _queue.isNotEmpty ? _nextTrack : null,
        ),
      ],
    );
  }

  Widget _buildModeButtons() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          _ModeButton(
            icon: _shuffleEnabled
                ? Icons.shuffle_on_rounded
                : Icons.shuffle_rounded,
            label: 'Shuffle',
            isActive: _shuffleEnabled,
            onTap: () => setState(() => _shuffleEnabled = !_shuffleEnabled),
          ),
          _ModeButton(
            icon: _repeatMode == RepeatMode.one
                ? Icons.repeat_one_rounded
                : Icons.repeat_rounded,
            label: _repeatMode == RepeatMode.off
                ? 'Repeat'
                : _repeatMode == RepeatMode.all
                    ? 'All'
                    : 'One',
            isActive: _repeatMode != RepeatMode.off,
            onTap: _cycleRepeat,
          ),
          if (_queue.isNotEmpty)
            _ModeButton(
              icon: Icons.queue_music_rounded,
              label: '${_queue.length} tracks',
              isActive: false,
              onTap: () => setState(() => _showPlaylist = true),
            ),
        ],
      ),
    );
  }

  Widget _buildPlaylistView() {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
          child: Row(
            children: [
              IconButton(
                icon: const Icon(Icons.arrow_back_rounded,
                    color: AppTheme.textPrimary),
                onPressed: () => setState(() => _showPlaylist = false),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Playlist',
                        style: TextStyle(
                            color: AppTheme.textPrimary,
                            fontSize: 20,
                            fontWeight: FontWeight.bold)),
                    Text('${_queue.length} tracks',
                        style: const TextStyle(
                            color: AppTheme.textSecondary, fontSize: 12)),
                  ],
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: _queue.length,
            itemBuilder: (_, i) {
              final track = _queue[i];
              final isCurrent = i == _currentIndex;
              return GestureDetector(
                onTap: () {
                  _jumpToTrack(i);
                  setState(() => _showPlaylist = false);
                },
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  margin: const EdgeInsets.only(bottom: 8),
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: isCurrent
                        ? AppTheme.accentGreen.withValues(alpha: 0.12)
                        : AppTheme.cardColor,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: isCurrent
                          ? AppTheme.accentGreen.withValues(alpha: 0.4)
                          : AppTheme.borderColor,
                    ),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                          color: isCurrent
                              ? AppTheme.accentGreen
                              : AppTheme.borderColor,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Center(
                          child: isCurrent && _isPlaying && !_isPaused
                              ? const Icon(Icons.graphic_eq_rounded,
                                  color: Colors.black, size: 18)
                              : Text(
                                  '${i + 1}',
                                  style: TextStyle(
                                    color: isCurrent
                                        ? Colors.black
                                        : AppTheme.textSecondary,
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              track.title,
                              style: TextStyle(
                                color: isCurrent
                                    ? AppTheme.accentGreen
                                    : AppTheme.textPrimary,
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            Text(
                              track.artist,
                              style: const TextStyle(
                                color: AppTheme.textSecondary,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Text(
                        track.formattedDuration,
                        style: const TextStyle(
                            color: AppTheme.textSecondary, fontSize: 12),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

class _ControlButton extends StatelessWidget {
  final IconData icon;
  final double size;
  final VoidCallback? onTap;

  const _ControlButton({
    required this.icon,
    required this.size,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Icon(
        icon,
        color: onTap != null ? AppTheme.textPrimary : AppTheme.textSecondary,
        size: size,
      ),
    );
  }
}

class _ModeButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool isActive;
  final VoidCallback onTap;

  const _ModeButton({
    required this.icon,
    required this.label,
    required this.isActive,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        children: [
          Icon(
            icon,
            color: isActive ? AppTheme.accentGreen : AppTheme.textSecondary,
            size: 24,
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(
              color: isActive ? AppTheme.accentGreen : AppTheme.textSecondary,
              fontSize: 10,
            ),
          ),
        ],
      ),
    );
  }
}
