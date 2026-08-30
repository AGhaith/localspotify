import 'dart:async';
import 'package:audio_service/audio_service.dart';
import 'package:flutter/foundation.dart';
import 'package:just_audio/just_audio.dart';
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

    final mediaItems = tracks.map((t) {
      final audioUrl = t.isOffline && t.localAudioPath != null
          ? t.localAudioPath!
          : _musicRepository.getStreamUrl(t.id);

      final coverArtUrl = _musicRepository.getCoverArtUrl(t.coverArtId, size: 500);

      return t.toMediaItem(
        audioUri: Uri.parse(audioUrl),
        artUri: coverArtUrl.isNotEmpty ? Uri.parse(coverArtUrl) : null,
      );
    }).toList();

    await _audioHandler.setTrackQueue(
      items: mediaItems,
      initialIndex: _currentIndex,
      autoPlay: true,
    );
  }

  Future<void> playTrack(Track track) async {
    await playTracks(tracks: [track], initialIndex: 0);
  }

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

  @override
  void dispose() {
    _playerStateSub?.cancel();
    _positionSub?.cancel();
    _bufferedSub?.cancel();
    _durationSub?.cancel();
    _mediaItemSub?.cancel();
    _playbackStateSub?.cancel();
    super.dispose();
  }
}
