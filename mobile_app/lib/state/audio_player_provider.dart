import 'dart:async';
import 'dart:convert';
import 'package:audio_service/audio_service.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../core/config/app_config.dart';
import '../data/models/track.dart';
import '../data/repositories/music_repository.dart';
import '../data/services/audio_handler.dart';

enum AppRepeatMode { off, all, one }

class AudioPlayerProvider extends ChangeNotifier {
  final LocalSpotifyAudioHandler _audioHandler;
  final MusicRepository _musicRepository;

  Track? _currentTrack;
  List<Track> _queue = [];
  int _currentIndex = 0;
  bool _isPlaying = false;
  bool _isBuffering = false;
  Duration _position = Duration.zero;
  Duration _duration = Duration.zero;
  Duration _bufferedPosition = Duration.zero;
  bool _isShuffle = false;
  AppRepeatMode _repeatMode = AppRepeatMode.off;
  bool _hasScrobbledCurrent = false;

  // Sleep Timer
  Timer? _sleepTimer;
  DateTime? _sleepTimerTarget;

  // Position Save Debounce Timer
  Timer? _savePositionTimer;

  // Stream Subscriptions
  StreamSubscription? _playerStateSub;
  StreamSubscription? _positionSub;
  StreamSubscription? _bufferedSub;
  StreamSubscription? _durationSub;
  StreamSubscription? _mediaItemSub;
  StreamSubscription? _playbackStateSub;

  AudioPlayerProvider({
    required LocalSpotifyAudioHandler audioHandler,
    required MusicRepository musicRepository,
  })  : _audioHandler = audioHandler,
        _musicRepository = musicRepository {
    _listenStreams();
    _restorePlaybackState();
  }

  Track? get currentTrack => _currentTrack;
  List<Track> get queue => _queue;
  int get currentIndex => _currentIndex;
  bool get isPlaying => _isPlaying;
  bool get isBuffering => _isBuffering;
  Duration get position => _position;
  Duration get duration => _duration;
  Duration get bufferedPosition => _bufferedPosition;
  bool get isShuffle => _isShuffle;
  AppRepeatMode get repeatMode => _repeatMode;
  bool get hasTrack => _currentTrack != null;
  double _playbackSpeed = 1.0;
  int _crossfadeDurationSeconds = 0;

  double get playbackSpeed => _playbackSpeed;
  int get crossfadeDurationSeconds => _crossfadeDurationSeconds;

  Future<void> setPlaybackSpeed(double speed) async {
    _playbackSpeed = speed;
    await _audioHandler.setSpeed(speed);
    notifyListeners();
  }

  void setCrossfadeDuration(int seconds) {
    _crossfadeDurationSeconds = seconds;
    notifyListeners();
  }

  bool get hasActiveSleepTimer =>
      _sleepTimer != null && _sleepTimer!.isActive && _sleepTimerTarget != null;

  Duration? get sleepTimerRemaining {
    if (!hasActiveSleepTimer) return null;
    final diff = _sleepTimerTarget!.difference(DateTime.now());
    return diff.isNegative ? Duration.zero : diff;
  }

  double get progress {
    if (_duration.inMilliseconds == 0) return 0.0;
    return (_position.inMilliseconds / _duration.inMilliseconds).clamp(0.0, 1.0);
  }

  // ================= State Persistence & Restoration =================
  Future<void> _restorePlaybackState() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final trackJson = prefs.getString('last_played_track');
      final queueJson = prefs.getString('last_played_queue');
      final posMs = prefs.getInt('last_played_position_ms') ?? 0;
      final index = prefs.getInt('last_played_index') ?? 0;
      _crossfadeDurationSeconds = (prefs.getDouble('crossfade_seconds') ?? 0.0).toInt();

      if (trackJson != null) {
        final track = Track.fromJson(jsonDecode(trackJson) as Map<String, dynamic>);
        List<Track> restoredQueue = [track];
        if (queueJson != null) {
          try {
            final list = jsonDecode(queueJson) as List<dynamic>;
            restoredQueue = list.map((e) => Track.fromJson(e as Map<String, dynamic>)).toList();
          } catch (_) {}
        }
        _currentTrack = track;
        _queue = restoredQueue;
        _currentIndex = index.clamp(0, restoredQueue.length - 1);
        _position = Duration(milliseconds: posMs);
        _duration = Duration(seconds: track.duration);
        notifyListeners();

        // Queue in audio handler without auto-playing so user can immediately press play
        final mediaItems = restoredQueue.map(_trackToMediaItem).toList();
        await _audioHandler.setTrackQueue(
          items: mediaItems,
          initialIndex: _currentIndex,
          autoPlay: false,
        );
        if (posMs > 0) {
          await _audioHandler.seek(Duration(milliseconds: posMs));
        }
      }
    } catch (e) {
      if (kDebugMode) {
        print('[AudioPlayerProvider] Failed to restore playback state: $e');
      }
    }
  }

  Future<void> _savePlaybackState() async {
    if (_currentTrack == null) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('last_played_track', jsonEncode(_currentTrack!.toJson()));
      await prefs.setInt('last_played_position_ms', _position.inMilliseconds);
      await prefs.setInt('last_played_index', _currentIndex);
      if (_queue.isNotEmpty) {
        await prefs.setString('last_played_queue', jsonEncode(_queue.map((t) => t.toJson()).toList()));
      }
    } catch (_) {}
  }

  void _scheduleSavePosition() {
    _savePositionTimer?.cancel();
    _savePositionTimer = Timer(const Duration(seconds: 3), () {
      _savePlaybackState();
    });
  }

  // ================= Crossfade Engine =================
  Future<void> _fadeVolume({required double from, required double to, required Duration duration}) async {
    const steps = 8;
    final stepDuration = Duration(milliseconds: (duration.inMilliseconds / steps).round());
    for (int i = 1; i <= steps; i++) {
      final v = from + (to - from) * (i / steps);
      await _audioHandler.player.setVolume(v.clamp(0.0, 1.0));
      await Future.delayed(stepDuration);
    }
  }

  void _listenStreams() {
    _playbackStateSub = _audioHandler.playbackState.listen((state) {
      final playing = state.playing;
      final buffering = state.processingState == AudioProcessingState.buffering ||
          state.processingState == AudioProcessingState.loading;

      if (_isPlaying != playing || _isBuffering != buffering) {
        _isPlaying = playing;
        _isBuffering = buffering;
        notifyListeners();
        if (!playing) {
          _savePlaybackState();
        }
      }
    });

    _mediaItemSub = _audioHandler.mediaItem.listen((item) {
      if (item != null) {
        final match = _queue.firstWhere(
          (t) => t.id == item.id,
          orElse: () => Track(
            id: item.id,
            title: item.title,
            artist: item.artist ?? '',
            album: item.album ?? '',
            duration: item.duration?.inSeconds ?? 0,
          ),
        );
        _currentTrack = match;
        _currentIndex = _queue.indexWhere((t) => t.id == item.id);
        if (_currentIndex == -1) _currentIndex = 0;
        _duration = item.duration ?? Duration.zero;
        _hasScrobbledCurrent = false;
        if (_userQueuedCount > 0) {
          _userQueuedCount--;
        }
        notifyListeners();
        _savePlaybackState();
        _ensureMinimumQueue(10);
      }
    });

    _positionSub = _audioHandler.player.positionStream.listen((pos) {
      _position = pos;
      notifyListeners();
      _scheduleSavePosition();

      // Scrobble at 50% or 4 minutes
      if (!_hasScrobbledCurrent && _currentTrack != null && _duration.inSeconds > 0) {
        final percent = pos.inMilliseconds / _duration.inMilliseconds;
        if (percent >= 0.5 || pos.inSeconds >= 240) {
          _hasScrobbledCurrent = true;
          _musicRepository.scrobble(_currentTrack!.id);
        }
      }
    });

    _bufferedSub = _audioHandler.player.bufferedPositionStream.listen((buf) {
      _bufferedPosition = buf;
      notifyListeners();
    });

    _durationSub = _audioHandler.player.durationStream.listen((dur) {
      if (dur != null) {
        _duration = dur;
        notifyListeners();
      }
    });
  }

  MediaItem _trackToMediaItem(Track t) {
    String audioUrl;
    if (t.isOffline && t.localAudioPath != null && t.localAudioPath!.isNotEmpty) {
      audioUrl = t.localAudioPath!;
    } else if (t.localAudioPath != null && t.localAudioPath!.isNotEmpty) {
      audioUrl = t.localAudioPath!;
    } else if (t.id.startsWith('spotify_') || t.id.startsWith('sp_')) {
      final session = _musicRepository.session;
      final serverUrl = session?.serverUrl ?? AppConfig.serverUrl;
      final companionBase = serverUrl.replaceAll(':6767', ':6969');
      audioUrl = '$companionBase/api/stream?title=${Uri.encodeComponent(t.title)}&artist=${Uri.encodeComponent(t.artist)}';
    } else {
      audioUrl = _musicRepository.getStreamUrl(t.id);
    }

    final coverArtUrl = _musicRepository.getCoverArtUrl(t.coverArtId, size: 500);

    return t.toMediaItem(
      audioUri: Uri.parse(audioUrl),
      artUri: coverArtUrl.isNotEmpty ? Uri.parse(coverArtUrl) : null,
    );
  }

  bool _isBackfillingQueue = false;
  int _userQueuedCount = 0;

  /// Ensures that there are always at least [minRemaining] songs upcoming in the queue
  Future<void> _ensureMinimumQueue([int minRemaining = 10]) async {
    if (_isBackfillingQueue || _currentTrack == null) return;
    final remaining = _queue.length - (_currentIndex + 1);
    if (remaining >= minRemaining) return;

    _isBackfillingQueue = true;
    try {
      final current = _currentTrack!;
      final existingIds = _queue.map((t) => t.id).toSet();

      List<Track> candidateRecommendations = [];
      try {
        candidateRecommendations = await _musicRepository.getSimilarSongs(current.id, count: 20);
      } catch (_) {}

      if (candidateRecommendations.isEmpty) {
        try {
          candidateRecommendations = await _musicRepository.getRandomSongs(size: 20);
        } catch (_) {}
      }

      final freshTracks = candidateRecommendations.where((t) => !existingIds.contains(t.id)).toList();
      final needed = (minRemaining - remaining + 5).clamp(1, 20);
      final toAdd = freshTracks.take(needed).toList();

      if (toAdd.isNotEmpty) {
        _queue.addAll(toAdd);
        notifyListeners();
        final mediaItems = toAdd.map(_trackToMediaItem).toList();
        await _audioHandler.addQueueItems(mediaItems);
      }
    } catch (_) {
    } finally {
      _isBackfillingQueue = false;
    }
  }

  // ================= Playback Start & Set =================
  Future<void> playTracks({
    required List<Track> tracks,
    int initialIndex = 0,
  }) async {
    if (tracks.isEmpty) return;

    if (_crossfadeDurationSeconds > 0 && _isPlaying) {
      await _fadeVolume(from: 1.0, to: 0.1, duration: const Duration(milliseconds: 300));
    }

    _userQueuedCount = 0;
    _queue = List.from(tracks);
    _currentIndex = initialIndex.clamp(0, tracks.length - 1);
    _currentTrack = _queue[_currentIndex];
    _hasScrobbledCurrent = false;
    notifyListeners();

    final mediaItems = tracks.map(_trackToMediaItem).toList();

    await _audioHandler.setTrackQueue(
      items: mediaItems,
      initialIndex: _currentIndex,
      autoPlay: true,
    );

    _savePlaybackState();

    if (_crossfadeDurationSeconds > 0) {
      await _fadeVolume(from: 0.1, to: 1.0, duration: const Duration(milliseconds: 400));
    }

    // Auto-backfill to guarantee minimum 10 upcoming tracks
    _ensureMinimumQueue(10);
  }

  Future<void> playTrack(Track track) async {
    await playTracks(tracks: [track], initialIndex: 0);
  }

  // ================= Queue Manipulation =================
  Future<void> addToQueue(Track track) async {
    final insertIndex = (_currentIndex + 1 + _userQueuedCount).clamp(0, _queue.length);
    _queue.insert(insertIndex, track);
    _userQueuedCount++;
    notifyListeners();
    await _audioHandler.insertQueueItem(insertIndex, _trackToMediaItem(track));
    _savePlaybackState();
    _ensureMinimumQueue(10);
  }

  Future<void> playNext(Track track) async {
    if (_queue.isEmpty) {
      await playTrack(track);
      return;
    }
    final insertIndex = (_currentIndex + 1).clamp(0, _queue.length);
    _queue.insert(insertIndex, track);
    _userQueuedCount++;
    notifyListeners();
    await _audioHandler.insertQueueItem(insertIndex, _trackToMediaItem(track));
    _savePlaybackState();
    _ensureMinimumQueue(10);
  }

  Future<void> removeFromQueue(int index) async {
    if (index >= 0 && index < _queue.length) {
      if (index == _currentIndex) {
        await skipNext();
      }
      _queue.removeAt(index);
      if (index < _currentIndex) {
        _currentIndex--;
      }
      notifyListeners();
      await _audioHandler.removeQueueItemAt(index);
      _savePlaybackState();
      _ensureMinimumQueue(10);
    }
  }

  Future<void> reorderQueue(int oldIndex, int newIndex) async {
    if (oldIndex < 0 || oldIndex >= _queue.length || newIndex < 0 || newIndex >= _queue.length) return;
    final item = _queue.removeAt(oldIndex);
    _queue.insert(newIndex, item);

    if (_currentIndex == oldIndex) {
      _currentIndex = newIndex;
    } else if (oldIndex < _currentIndex && newIndex >= _currentIndex) {
      _currentIndex--;
    } else if (oldIndex > _currentIndex && newIndex <= _currentIndex) {
      _currentIndex++;
    }
    notifyListeners();
    await _audioHandler.moveQueueItem(oldIndex, newIndex);
    _savePlaybackState();
  }

  Future<void> clearQueue() async {
    await _audioHandler.stop();
    _queue.clear();
    _currentTrack = null;
    _currentIndex = 0;
    _userQueuedCount = 0;
    notifyListeners();
    _savePlaybackState();
  }

  // ================= Playback Controls =================
  Future<void> togglePlay() async {
    if (_isPlaying) {
      await _audioHandler.pause();
      _savePlaybackState();
    } else {
      await _audioHandler.play();
    }
  }

  Future<void> seek(Duration position) async {
    await _audioHandler.seek(position);
    _savePlaybackState();
  }

  Future<void> seekPercent(double percent) async {
    final target = Duration(
      milliseconds: (_duration.inMilliseconds * percent.clamp(0.0, 1.0)).toInt(),
    );
    await seek(target);
  }

  Future<void> skipNext() async {
    if (_crossfadeDurationSeconds > 0 && _isPlaying) {
      await _fadeVolume(from: 1.0, to: 0.15, duration: const Duration(milliseconds: 250));
      await _audioHandler.skipToNext();
      await _fadeVolume(from: 0.15, to: 1.0, duration: const Duration(milliseconds: 350));
    } else {
      await _audioHandler.skipToNext();
    }
  }

  Future<void> skipPrevious() async {
    if (_crossfadeDurationSeconds > 0 && _isPlaying) {
      await _fadeVolume(from: 1.0, to: 0.15, duration: const Duration(milliseconds: 250));
      await _audioHandler.skipToPrevious();
      await _fadeVolume(from: 0.15, to: 1.0, duration: const Duration(milliseconds: 350));
    } else {
      await _audioHandler.skipToPrevious();
    }
  }

  Future<void> skipToQueueItem(int index) async {
    if (index >= 0 && index < _queue.length) {
      _currentIndex = index;
      _currentTrack = _queue[index];
      notifyListeners();
      await _audioHandler.skipToQueueItem(index);
      _savePlaybackState();
    }
  }

  Future<void> toggleShuffle() async {
    _isShuffle = !_isShuffle;
    await _audioHandler.setShuffleMode(
      _isShuffle ? AudioServiceShuffleMode.all : AudioServiceShuffleMode.none,
    );
    notifyListeners();
  }

  Future<void> toggleRepeat() async {
    switch (_repeatMode) {
      case AppRepeatMode.off:
        _repeatMode = AppRepeatMode.all;
        await _audioHandler.setRepeatMode(AudioServiceRepeatMode.all);
        break;
      case AppRepeatMode.all:
        _repeatMode = AppRepeatMode.one;
        await _audioHandler.setRepeatMode(AudioServiceRepeatMode.one);
        break;
      case AppRepeatMode.one:
        _repeatMode = AppRepeatMode.off;
        await _audioHandler.setRepeatMode(AudioServiceRepeatMode.none);
        break;
    }
    notifyListeners();
  }

  // ================= Sleep Timer =================
  void setSleepTimer(Duration duration) {
    _sleepTimer?.cancel();
    _sleepTimerTarget = DateTime.now().add(duration);
    notifyListeners();

    _sleepTimer = Timer(duration, () async {
      await _audioHandler.pause();
      cancelSleepTimer();
    });
  }

  void cancelSleepTimer() {
    _sleepTimer?.cancel();
    _sleepTimer = null;
    _sleepTimerTarget = null;
    notifyListeners();
  }

  @override
  void dispose() {
    _sleepTimer?.cancel();
    _savePositionTimer?.cancel();
    _playerStateSub?.cancel();
    _positionSub?.cancel();
    _bufferedSub?.cancel();
    _durationSub?.cancel();
    _mediaItemSub?.cancel();
    _playbackStateSub?.cancel();
    super.dispose();
  }
}
