import 'dart:async';
import 'package:just_audio/just_audio.dart';
import '../models/models.dart';

class AudioPlayerService {
  static final AudioPlayerService _instance = AudioPlayerService._internal();
  factory AudioPlayerService() => _instance;
  AudioPlayerService._internal();

  final AudioPlayer _player = AudioPlayer();

  List<Track> _queue = [];
  int _currentIndex = -1;
  bool _isLoading = false;
  RepeatMode _repeatMode = RepeatMode.off;
  bool _shuffleEnabled = false;

  // Streams
  Stream<PlayerState> get playerStateStream => _player.playerStateStream;
  Stream<Duration?> get durationStream => _player.durationStream;
  Stream<Duration> get positionStream => _player.positionStream;
  Stream<int?> get currentIndexStream => _player.currentIndexStream;

  // Getters
  List<Track> get queue => _queue;
  int get currentIndex => _currentIndex;
  bool get isPlaying => _player.playing;
  bool get isLoading => _isLoading;
  Duration get position => _player.position;
  Duration? get duration => _player.duration;
  RepeatMode get repeatMode => _repeatMode;
  bool get shuffleEnabled => _shuffleEnabled;

  Track? get currentTrack =>
      _currentIndex >= 0 && _currentIndex < _queue.length
          ? _queue[_currentIndex]
          : null;

  // ── Queue Management ───────────────────────────────────────────────

  void setQueue(List<Track> tracks) {
    _queue = List.from(tracks);
    _currentIndex = -1;
  }

  void addToQueue(Track track) {
    _queue.add(track);
  }

  void clearQueue() {
    _queue.clear();
    _currentIndex = -1;
  }

  // ── Playback Control ───────────────────────────────────────────────

  Future<void> playIndex(int index) async {
    if (index < 0 || index >= _queue.length) return;
    _currentIndex = index;
    final track = _queue[index];

    _isLoading = true;
    try {
      if (track.localPath != null) {
        await _player.setFilePath(track.localPath!);
      } else if (track.streamUrl != null) {
        await _player.setUrl(track.streamUrl!);
      } else {
        // Demo mode: use a silent audio or skip
        _isLoading = false;
        return;
      }
      await _player.play();
    } catch (e) {
      // handle error
    } finally {
      _isLoading = false;
    }
  }

  Future<void> play() async => await _player.play();
  Future<void> pause() async => await _player.pause();

  Future<void> togglePlayPause() async {
    if (_player.playing) {
      await _player.pause();
    } else {
      await _player.play();
    }
  }

  Future<void> stop() async {
    await _player.stop();
  }

  Future<void> seek(Duration position) async {
    await _player.seek(position);
  }

  Future<void> next() async {
    if (_queue.isEmpty) return;
    if (_repeatMode == RepeatMode.one) {
      await seek(Duration.zero);
      await play();
      return;
    }
    if (_shuffleEnabled) {
      final nextIdx = _randomIndex();
      if (nextIdx != null) await playIndex(nextIdx);
    } else {
      final nextIdx = _currentIndex + 1;
      if (nextIdx < _queue.length) {
        await playIndex(nextIdx);
      } else if (_repeatMode == RepeatMode.all) {
        await playIndex(0);
      }
    }
  }

  Future<void> previous() async {
    if (_queue.isEmpty) return;
    if (position.inSeconds > 3) {
      await seek(Duration.zero);
      return;
    }
    if (_currentIndex > 0) {
      await playIndex(_currentIndex - 1);
    } else if (_repeatMode == RepeatMode.all && _queue.isNotEmpty) {
      await playIndex(_queue.length - 1);
    }
  }

  void cycleRepeatMode() {
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
  }

  void toggleShuffle() {
    _shuffleEnabled = !_shuffleEnabled;
  }

  int? _randomIndex() {
    if (_queue.length <= 1) return null;
    int idx;
    do {
      idx = (DateTime.now().millisecondsSinceEpoch % _queue.length);
    } while (idx == _currentIndex);
    return idx;
  }

  Future<void> dispose() async {
    await _player.dispose();
  }
}

enum RepeatMode { off, all, one }
