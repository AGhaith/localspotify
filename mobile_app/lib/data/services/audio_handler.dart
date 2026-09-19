import 'dart:async';
import 'package:audio_service/audio_service.dart';
import 'package:just_audio/just_audio.dart';

class LocalSpotifyAudioHandler extends BaseAudioHandler
    with QueueHandler, SeekHandler {
  final AudioPlayer _player = AudioPlayer();
  final _playlist = ConcatenatingAudioSource(children: []);

  AudioPlayer get player => _player;

  LocalSpotifyAudioHandler() {
    _init();
  }

  Future<void> _init() async {
    // 1. Broadcast playback state changes to Android MediaSession
    _player.playbackEventStream.listen(_broadcastState);

    // 2. Broadcast current media item index changes
    _player.currentIndexStream.listen((index) {
      if (index != null && queue.value.isNotEmpty && index < queue.value.length) {
        mediaItem.add(queue.value[index]);
      }
    });

    // 3. Handle playback completion
    _player.playerStateStream.listen((state) {
      if (state.processingState == ProcessingState.completed) {
        if (_player.hasNext) {
          skipToNext();
        } else {
          pause();
          seek(Duration.zero);
        }
      }
    });
  }

  void _broadcastState(PlaybackEvent event) {
    final playing = _player.playing;
    final queueIndex = _player.currentIndex;

    playbackState.add(
      playbackState.value.copyWith(
        controls: [
          MediaControl.skipToPrevious,
          if (playing) MediaControl.pause else MediaControl.play,
          MediaControl.skipToNext,
          MediaControl.stop,
        ],
        systemActions: const {
          MediaAction.seek,
          MediaAction.seekForward,
          MediaAction.seekBackward,
          MediaAction.setShuffleMode,
          MediaAction.setRepeatMode,
        },
        androidCompactActionIndices: const [0, 1, 2],
        processingState: const {
          ProcessingState.idle: AudioProcessingState.idle,
          ProcessingState.loading: AudioProcessingState.loading,
          ProcessingState.buffering: AudioProcessingState.buffering,
          ProcessingState.ready: AudioProcessingState.ready,
          ProcessingState.completed: AudioProcessingState.completed,
        }[_player.processingState]!,
        playing: playing,
        updatePosition: _player.position,
        bufferedPosition: _player.bufferedPosition,
        speed: _player.speed,
        queueIndex: queueIndex,
      ),
    );
  }

  AudioSource _createAudioSource(MediaItem item) {
    final url = item.extras?['url'] as String? ?? '';
    final isOffline = item.extras?['isOffline'] as bool? ?? false;
    final localPath = item.extras?['localAudioPath'] as String?;

    if (isOffline && localPath != null && localPath.isNotEmpty) {
      return AudioSource.uri(Uri.file(localPath), tag: item);
    }
    return AudioSource.uri(Uri.parse(url), tag: item);
  }

  Future<void> setTrackQueue({
    required List<MediaItem> items,
    int initialIndex = 0,
    bool autoPlay = true,
  }) async {
    if (items.isEmpty) return;

    queue.add(items);
    final audioSources = items.map(_createAudioSource).toList();

    await _playlist.clear();
    await _playlist.addAll(audioSources);

    try {
      await _player.setAudioSource(
        _playlist,
        initialIndex: initialIndex,
        initialPosition: Duration.zero,
      );
      mediaItem.add(items[initialIndex]);
      if (autoPlay) {
        await play();
      }
    } catch (e) {
      print('[AudioHandler] Error loading audio source: $e');
    }
  }

  @override
  Future<void> addQueueItem(MediaItem mediaItem) async {
    final newQueue = List<MediaItem>.from(queue.value)..add(mediaItem);
    queue.add(newQueue);
    await _playlist.add(_createAudioSource(mediaItem));
  }

  @override
  Future<void> insertQueueItem(int index, MediaItem mediaItem) async {
    final newQueue = List<MediaItem>.from(queue.value)..insert(index, mediaItem);
    queue.add(newQueue);
    await _playlist.insert(index, _createAudioSource(mediaItem));
  }

  @override
  Future<void> removeQueueItemAt(int index) async {
    if (index >= 0 && index < queue.value.length) {
      final newQueue = List<MediaItem>.from(queue.value)..removeAt(index);
      queue.add(newQueue);
      await _playlist.removeAt(index);
    }
  }

  Future<void> moveQueueItem(int oldIndex, int newIndex) async {
    if (oldIndex >= 0 &&
        oldIndex < queue.value.length &&
        newIndex >= 0 &&
        newIndex < queue.value.length) {
      final item = queue.value[oldIndex];
      final newQueue = List<MediaItem>.from(queue.value);
      newQueue.removeAt(oldIndex);
      newQueue.insert(newIndex, item);
      queue.add(newQueue);
      await _playlist.move(oldIndex, newIndex);
    }
  }

  @override
  Future<void> play() => _player.play();

  @override
  Future<void> pause() => _player.pause();

  @override
  Future<void> stop() async {
    await _player.stop();
    return super.stop();
  }

  @override
  Future<void> seek(Duration position) => _player.seek(position);

  @override
  Future<void> skipToNext() async {
    if (_player.hasNext) {
      await _player.seekToNext();
    }
  }

  @override
  Future<void> skipToPrevious() async {
    if (_player.position.inSeconds > 4) {
      await _player.seek(Duration.zero);
    } else if (_player.hasPrevious) {
      await _player.seekToPrevious();
    }
  }

  @override
  Future<void> skipToQueueItem(int index) async {
    if (index >= 0 && index < queue.value.length) {
      await _player.seek(Duration.zero, index: index);
    }
  }

  @override
  Future<void> setRepeatMode(AudioServiceRepeatMode repeatMode) async {
    switch (repeatMode) {
      case AudioServiceRepeatMode.none:
        await _player.setLoopMode(LoopMode.off);
        break;
      case AudioServiceRepeatMode.one:
        await _player.setLoopMode(LoopMode.one);
        break;
      case AudioServiceRepeatMode.all:
      case AudioServiceRepeatMode.group:
        await _player.setLoopMode(LoopMode.all);
        break;
    }
  }

  @override
  Future<void> setShuffleMode(AudioServiceShuffleMode shuffleMode) async {
    final enabled = shuffleMode == AudioServiceShuffleMode.all ||
        shuffleMode == AudioServiceShuffleMode.group;
    await _player.setShuffleModeEnabled(enabled);
  }

  @override
  Future<void> setSpeed(double speed) => _player.setSpeed(speed);
}
