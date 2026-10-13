import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'package:audio_service/audio_service.dart';
import 'package:flutter/animation.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../core/config/app_config.dart';
import '../core/utils/replay_gain_volume.dart';
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
  String? _playbackError;
  int _playbackErrorVersion = 0;
  bool _hasFadedOutCurrentTrack = false;
  int _fadeOperationId = 0;
  String? _queueSource;
  int _userQueuedCount = 0;

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
  String? get playbackError => _playbackError;
  int get playbackErrorVersion => _playbackErrorVersion;
  double _playbackSpeed = 1.0;
  int _crossfadeDurationSeconds = 0;
  bool _normalizeVolume = true;
  double _targetVolume = 1.0;

  double get playbackSpeed => _playbackSpeed;
  int get crossfadeDurationSeconds => _crossfadeDurationSeconds;
  bool get normalizeVolume => _normalizeVolume;

  Future<void> setNormalizeVolume(bool enabled) async {
    _normalizeVolume = enabled;
    _updateTargetVolume();
    if (!_isFadeRunning) _restoreVolume();
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('volume_normalization', enabled);
  }

  void _updateTargetVolume() {
    _targetVolume = replayGainVolume(
      normalize: _normalizeVolume,
      gain: _currentTrack?.replayGainTrackGain,
      peak: _currentTrack?.replayGainTrackPeak,
    );
  }

  bool _isFadeRunning = false;
  int get userQueuedCount => _userQueuedCount;
  String? get queueSource => _queueSource;

  Future<void> setPlaybackSpeed(double speed) async {
    _playbackSpeed = speed;
    await _audioHandler.setSpeed(speed);
    notifyListeners();
  }

  void setCrossfadeDuration(int seconds) {
    _crossfadeDurationSeconds = seconds;
    if (seconds == 0) {
      _restoreVolume();
    }
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
    return (_position.inMilliseconds / _duration.inMilliseconds)
        .clamp(0.0, 1.0);
  }

  // ================= State Persistence & Restoration =================
  Future<void> _restorePlaybackState() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final trackJson = prefs.getString('last_played_track');
      final queueJson = prefs.getString('last_played_queue');
      final posMs = prefs.getInt('last_played_position_ms') ?? 0;
      final index = prefs.getInt('last_played_index') ?? 0;
      _crossfadeDurationSeconds =
          (prefs.getDouble('crossfade_seconds') ?? 0.0).toInt();
      _normalizeVolume = prefs.getBool('volume_normalization') ?? true;
      _queueSource = prefs.getString('last_played_queue_source');

      if (trackJson != null) {
        final track =
            Track.fromJson(jsonDecode(trackJson) as Map<String, dynamic>);
        List<Track> restoredQueue = [track];
        if (queueJson != null) {
          try {
            final list = jsonDecode(queueJson) as List<dynamic>;
            restoredQueue = list
                .map((e) => Track.fromJson(e as Map<String, dynamic>))
                .toList();
          } catch (_) {}
        }
        _currentTrack = track;
        _updateTargetVolume();
        _restoreVolume();
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
      debugPrint('[AudioPlayerProvider] Failed to restore playback state: $e');
    }
  }

  Future<void> _savePlaybackState() async {
    if (_currentTrack == null) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
          'last_played_track', jsonEncode(_currentTrack!.toJson()));
      await prefs.setInt('last_played_position_ms', _position.inMilliseconds);
      await prefs.setInt('last_played_index', _currentIndex);
      if (_queue.isNotEmpty) {
        await prefs.setString('last_played_queue',
            jsonEncode(_queue.map((t) => t.toJson()).toList()));
      }
      if (_queueSource != null) {
        await prefs.setString('last_played_queue_source', _queueSource!);
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
  void _cancelFade() {
    _fadeOperationId++;
    _isFadeRunning = false;
  }

  Future<void> _restoreVolume() async {
    _cancelFade();
    try {
      await _audioHandler.player.setVolume(_targetVolume);
    } catch (_) {}
  }

  Future<void> _runFade({
    required double from,
    required double to,
    required Duration duration,
    Curve curve = Curves.easeInOutCubic,
  }) async {
    _cancelFade();
    final opId = _fadeOperationId;
    _isFadeRunning = true;
    if (duration <= Duration.zero || (from - to).abs() < 0.001) {
      try {
        await _audioHandler.player
            .setVolume((to > 0 ? _targetVolume : 0.0).clamp(0.0, 1.0));
      } catch (_) {}
      if (_fadeOperationId == opId) _isFadeRunning = false;
      return;
    }

    final totalMs = duration.inMilliseconds;
    const tickMs = 30;
    final steps = (totalMs / tickMs).round().clamp(1, 500);
    final stepDelay =
        Duration(milliseconds: (totalMs / steps).round().clamp(15, 60));

    try {
      await _audioHandler.player.setVolume(from.clamp(0.0, 1.0));
    } catch (_) {}

    for (int i = 1; i <= steps; i++) {
      await Future.delayed(stepDelay);
      if (_fadeOperationId != opId) return; // In-flight fade cancelled
      final t = curve.transform((i / steps).clamp(0.0, 1.0));
      final endpoint = to > 0 ? _targetVolume : 0.0;
      final v = (from + (endpoint - from) * t).clamp(0.0, 1.0);
      try {
        await _audioHandler.player.setVolume(v);
      } catch (_) {}
    }
    if (_fadeOperationId == opId) _isFadeRunning = false;
  }

  void _listenStreams() {
    _playbackStateSub = _audioHandler.playbackState.listen((state) {
      final playing = state.playing;
      final buffering =
          state.processingState == AudioProcessingState.buffering ||
              state.processingState == AudioProcessingState.loading;

      if (playing && _playbackError != null) {
        _playbackError = null;
        notifyListeners();
      }

      if (_isPlaying != playing || _isBuffering != buffering) {
        _isPlaying = playing;
        _isBuffering = buffering;
        notifyListeners();
        if (!playing) {
          _restoreVolume();
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
        final isDifferentTrack = _currentTrack?.id != match.id;
        _currentTrack = match;
        _updateTargetVolume();
        _currentIndex = _queue.indexWhere((t) => t.id == item.id);
        if (_currentIndex == -1) _currentIndex = 0;
        _duration = item.duration ?? Duration.zero;
        _hasScrobbledCurrent = false;
        _hasFadedOutCurrentTrack = false;
        if (_userQueuedCount > 0) {
          _userQueuedCount--;
        }
        notifyListeners();
        _savePlaybackState();
        _ensureMinimumQueue(10);

        // When a new track starts playing, fade-in if crossfade > 0
        if (isDifferentTrack) {
          if (_crossfadeDurationSeconds > 0 && _isPlaying) {
            final fadeInSeconds = min(_crossfadeDurationSeconds, 2);
            _runFade(
              from: 0.0,
              to: _targetVolume,
              duration: Duration(seconds: fadeInSeconds),
            );
          } else {
            _restoreVolume();
          }
        } else if (!_isFadeRunning) {
          _restoreVolume();
        }
      }
    });

    _positionSub = _audioHandler.player.positionStream.listen((pos) {
      _position = pos;
      notifyListeners();
      _scheduleSavePosition();

      // Scrobble at 50% or 4 minutes
      if (!_hasScrobbledCurrent &&
          _currentTrack != null &&
          _duration.inSeconds > 0) {
        final percent = pos.inMilliseconds / _duration.inMilliseconds;
        if (percent >= 0.5 || pos.inSeconds >= 240) {
          _hasScrobbledCurrent = true;
          _musicRepository.scrobble(_currentTrack!.id);
        }
      }

      // Natural track end crossfade fade-out
      if (_crossfadeDurationSeconds > 0 &&
          _isPlaying &&
          !_hasFadedOutCurrentTrack &&
          _duration.inSeconds > _crossfadeDurationSeconds) {
        final remaining = _duration - pos;
        final fadeThreshold = Duration(seconds: _crossfadeDurationSeconds);
        if (remaining <= fadeThreshold && remaining > Duration.zero) {
          _hasFadedOutCurrentTrack = true;
          _runFade(from: _targetVolume, to: 0.0, duration: remaining);
        }
      } else if (_hasFadedOutCurrentTrack &&
          _duration - pos > Duration(seconds: _crossfadeDurationSeconds)) {
        // Same track restarted (repeat-one / loop): undo the end fade-out.
        _hasFadedOutCurrentTrack = false;
        _runFade(
          from: 0.0,
          to: _targetVolume,
          duration: Duration(seconds: min(_crossfadeDurationSeconds, 2)),
        );
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
    if (t.isOffline &&
        t.localAudioPath != null &&
        t.localAudioPath!.isNotEmpty) {
      audioUrl = t.localAudioPath!;
    } else if (t.localAudioPath != null && t.localAudioPath!.isNotEmpty) {
      audioUrl = t.localAudioPath!;
    } else if (t.id.startsWith('spotify_') || t.id.startsWith('sp_')) {
      final session = _musicRepository.session;
      final serverUrl = session?.serverUrl ?? AppConfig.serverUrl;
      final companionBase = serverUrl.replaceAll(':6767', ':6969');
      audioUrl =
          '$companionBase/api/stream?title=${Uri.encodeComponent(t.title)}&artist=${Uri.encodeComponent(t.artist)}';
    } else {
      audioUrl = _musicRepository.getStreamUrl(t.id);
    }

    final coverArtUrl =
        _musicRepository.getCoverArtUrl(t.coverArtId, size: 500);

    return t.toMediaItem(
      audioUri: Uri.parse(audioUrl),
      artUri: coverArtUrl.isNotEmpty ? Uri.parse(coverArtUrl) : null,
    );
  }

  bool _isBackfillingQueue = false;

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
        candidateRecommendations =
            await _musicRepository.getSimilarSongs(current.id, count: 20);
      } catch (_) {}

      if (candidateRecommendations.isEmpty) {
        try {
          candidateRecommendations =
              await _musicRepository.getRandomSongs(size: 20);
        } catch (_) {}
      }

      final freshTracks = candidateRecommendations
          .where((t) => !existingIds.contains(t.id))
          .toList();
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
    String? queueSource,
  }) async {
    if (tracks.isEmpty) return;

    if (_crossfadeDurationSeconds > 0 && _isPlaying) {
      final fadeOutMs =
          ((min(_crossfadeDurationSeconds.toDouble(), 0.5)).clamp(0.1, 0.5) *
                  1000)
              .round();
      await _runFade(
          from: _targetVolume,
          to: 0.0,
          duration: Duration(milliseconds: fadeOutMs));
    }

    _queueSource = queueSource ??
        (tracks.isNotEmpty && tracks.first.album.isNotEmpty
            ? tracks.first.album
            : null);
    _userQueuedCount = 0;
    _hasFadedOutCurrentTrack = false;
    _queue = List.from(tracks);
    _currentIndex = initialIndex.clamp(0, tracks.length - 1);
    _currentTrack = _queue[_currentIndex];
    _updateTargetVolume();
    _hasScrobbledCurrent = false;
    notifyListeners();

    try {
      final mediaItems = tracks.map(_trackToMediaItem).toList();
      await _audioHandler.setTrackQueue(
        items: mediaItems,
        initialIndex: _currentIndex,
        autoPlay: true,
      );
      _playbackError = null;
      notifyListeners();
    } catch (e) {
      debugPrint('[AudioPlayerProvider] Failed to play track: $e');
      _playbackError = e.toString();
      _playbackErrorVersion++;
      await _restoreVolume();
      notifyListeners();
      return;
    }

    _savePlaybackState();

    if (_crossfadeDurationSeconds > 0) {
      final fadeInSeconds = min(_crossfadeDurationSeconds, 2);
      _runFade(
          from: 0.0,
          to: _targetVolume,
          duration: Duration(seconds: fadeInSeconds));
    } else {
      await _restoreVolume();
    }

    // Auto-backfill to guarantee minimum 10 upcoming tracks
    _ensureMinimumQueue(10);
  }

  Future<void> playTrack(Track track) async {
    await playTracks(tracks: [track], initialIndex: 0);
  }

  // ================= Queue Manipulation =================
  Future<void> addToQueue(Track track) async {
    final insertIndex =
        (_currentIndex + 1 + _userQueuedCount).clamp(0, _queue.length);
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
      } else if (index > _currentIndex &&
          index <= _currentIndex + _userQueuedCount) {
        if (_userQueuedCount > 0) _userQueuedCount--;
      }
      notifyListeners();
      await _audioHandler.removeQueueItemAt(index);
      _savePlaybackState();
      _ensureMinimumQueue(10);
    }
  }

  Future<void> clearUserQueue() async {
    if (_userQueuedCount <= 0) return;
    final start = _currentIndex + 1;
    final count = _userQueuedCount;
    for (int i = 0; i < count; i++) {
      if (start < _queue.length) {
        _queue.removeAt(start);
        await _audioHandler.removeQueueItemAt(start);
      }
    }
    _userQueuedCount = 0;
    notifyListeners();
    _savePlaybackState();
    _ensureMinimumQueue(10);
  }

  Future<void> reorderQueue(int oldIndex, int newIndex) async {
    if (oldIndex < 0 ||
        oldIndex >= _queue.length ||
        newIndex < 0 ||
        newIndex >= _queue.length) {
      return;
    }
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
    await _restoreVolume();
    await _audioHandler.stop();
    _queue.clear();
    _currentTrack = null;
    _currentIndex = 0;
    _userQueuedCount = 0;
    _hasFadedOutCurrentTrack = false;
    notifyListeners();
    _savePlaybackState();
  }

  // ================= Playback Controls =================
  Future<void> togglePlay() async {
    if (_isPlaying) {
      await _restoreVolume();
      await _audioHandler.pause();
      _savePlaybackState();
    } else {
      await _audioHandler.play();
    }
  }

  Future<void> seek(Duration position) async {
    await _restoreVolume();
    if (_duration > Duration.zero &&
        position < _duration - Duration(seconds: _crossfadeDurationSeconds)) {
      _hasFadedOutCurrentTrack = false;
    }
    await _audioHandler.seek(position);
    _savePlaybackState();
  }

  Future<void> seekPercent(double percent) async {
    final target = Duration(
      milliseconds:
          (_duration.inMilliseconds * percent.clamp(0.0, 1.0)).toInt(),
    );
    await seek(target);
  }

  Future<void> skipNext() async {
    if (_crossfadeDurationSeconds > 0 && _isPlaying) {
      final fadeOutMs =
          ((min(_crossfadeDurationSeconds.toDouble(), 0.5)).clamp(0.1, 0.5) *
                  1000)
              .round();
      await _runFade(
          from: _targetVolume,
          to: 0.0,
          duration: Duration(milliseconds: fadeOutMs));
      await _audioHandler.skipToNext();
      final fadeInSeconds = min(_crossfadeDurationSeconds, 2);
      _runFade(
          from: 0.0,
          to: _targetVolume,
          duration: Duration(seconds: fadeInSeconds));
    } else {
      await _audioHandler.skipToNext();
    }
  }

  Future<void> skipPrevious() async {
    if (_crossfadeDurationSeconds > 0 && _isPlaying) {
      final fadeOutMs =
          ((min(_crossfadeDurationSeconds.toDouble(), 0.5)).clamp(0.1, 0.5) *
                  1000)
              .round();
      await _runFade(
          from: _targetVolume,
          to: 0.0,
          duration: Duration(milliseconds: fadeOutMs));
      await _audioHandler.skipToPrevious();
      final fadeInSeconds = min(_crossfadeDurationSeconds, 2);
      _runFade(
          from: 0.0,
          to: _targetVolume,
          duration: Duration(seconds: fadeInSeconds));
    } else {
      await _audioHandler.skipToPrevious();
    }
  }

  Future<void> skipToQueueItem(int index) async {
    if (index >= 0 && index < _queue.length) {
      if (_crossfadeDurationSeconds > 0 && _isPlaying) {
        final fadeOutMs =
            ((min(_crossfadeDurationSeconds.toDouble(), 0.5)).clamp(0.1, 0.5) *
                    1000)
                .round();
        await _runFade(
            from: _targetVolume,
            to: 0.0,
            duration: Duration(milliseconds: fadeOutMs));
      }
      _currentIndex = index;
      _currentTrack = _queue[index];
      _updateTargetVolume();
      _hasFadedOutCurrentTrack = false;
      notifyListeners();
      await _audioHandler.skipToQueueItem(index);
      _savePlaybackState();
      if (_crossfadeDurationSeconds > 0) {
        final fadeInSeconds = min(_crossfadeDurationSeconds, 2);
        _runFade(
            from: 0.0,
            to: _targetVolume,
            duration: Duration(seconds: fadeInSeconds));
      } else {
        await _restoreVolume();
      }
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
    _cancelFade();
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
