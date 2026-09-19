import 'dart:async';
import 'package:audio_service/audio_service.dart';
import 'package:flutter/foundation.dart';
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

  void _listenStreams() {
    _playbackStateSub = _audioHandler.playbackState.listen((state) {
      final playing = state.playing;
      final buffering = state.processingState == AudioProcessingState.buffering ||
          state.processingState == AudioProcessingState.loading;

      if (_isPlaying != playing || _isBuffering != buffering) {
        _isPlaying = playing;
        _isBuffering = buffering;
        notifyListeners();
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
        notifyListeners();
      }
    });

    _positionSub = _audioHandler.player.positionStream.listen((pos) {
      _position = pos;
      notifyListeners();

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
    final audioUrl = t.isOffline && t.localAudioPath != null
        ? t.localAudioPath!
        : _musicRepository.getStreamUrl(t.id);

    final coverArtUrl = _musicRepository.getCoverArtUrl(t.coverArtId, size: 500);

    return t.toMediaItem(
      audioUri: Uri.parse(audioUrl),
      artUri: coverArtUrl.isNotEmpty ? Uri.parse(coverArtUrl) : null,
    );
  }

  Future<void> playTracks({
    required List<Track> tracks,
    int initialIndex = 0,
  }) async {
    if (tracks.isEmpty) return;

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
  }

  Future<void> playTrack(Track track) async {
    await playTracks(tracks: [track], initialIndex: 0);
  }

  // ================= Queue Manipulation =================
  Future<void> addToQueue(Track track) async {
    _queue.add(track);
    notifyListeners();
    await _audioHandler.addQueueItem(_trackToMediaItem(track));
  }

  Future<void> playNext(Track track) async {
    if (_queue.isEmpty) {
      await playTrack(track);
      return;
    }
    final insertIndex = (_currentIndex + 1).clamp(0, _queue.length);
    _queue.insert(insertIndex, track);
    notifyListeners();
    await _audioHandler.insertQueueItem(insertIndex, _trackToMediaItem(track));
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
  }

  Future<void> clearQueue() async {
    await _audioHandler.stop();
    _queue.clear();
    _currentTrack = null;
    _currentIndex = 0;
    notifyListeners();
  }

  // ================= Playback Controls =================
  Future<void> togglePlay() async {
    if (_isPlaying) {
      await _audioHandler.pause();
    } else {
      await _audioHandler.play();
    }
  }

  Future<void> seek(Duration position) async {
    await _audioHandler.seek(position);
  }

  Future<void> seekPercent(double percent) async {
    final target = Duration(
      milliseconds: (_duration.inMilliseconds * percent.clamp(0.0, 1.0)).toInt(),
    );
    await seek(target);
  }

  Future<void> skipNext() async {
    await _audioHandler.skipToNext();
  }

  Future<void> skipPrevious() async {
    await _audioHandler.skipToPrevious();
  }

  Future<void> skipToQueueItem(int index) async {
    if (index >= 0 && index < _queue.length) {
      _currentIndex = index;
      _currentTrack = _queue[index];
      notifyListeners();
      await _audioHandler.skipToQueueItem(index);
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
    _playerStateSub?.cancel();
    _positionSub?.cancel();
    _bufferedSub?.cancel();
    _durationSub?.cancel();
    _mediaItemSub?.cancel();
    _playbackStateSub?.cancel();
    super.dispose();
  }
}
