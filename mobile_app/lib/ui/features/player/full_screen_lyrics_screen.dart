import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/utils/duration_formatter.dart';
import '../../../data/models/lyrics.dart';
import '../../../data/models/track.dart';
import '../../../state/audio_player_provider.dart';
import '../../../state/music_provider.dart';
import '../../core_widgets/cached_cover_art.dart';

class FullScreenLyricsScreen extends StatefulWidget {
  final Track track;

  const FullScreenLyricsScreen({super.key, required this.track});

  @override
  State<FullScreenLyricsScreen> createState() => _FullScreenLyricsScreenState();
}

class _FullScreenLyricsScreenState extends State<FullScreenLyricsScreen> {
  final ScrollController _scrollController = ScrollController();
  int _lastActiveIndex = -1;
  Future<Lyrics?>? _lyricsFuture;
  double? _dragValue;

  @override
  void initState() {
    super.initState();
    _loadLyrics();
  }

  @override
  void didUpdateWidget(covariant FullScreenLyricsScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.track.id != widget.track.id) {
      _lastActiveIndex = -1;
      _loadLyrics();
    }
  }

  void _loadLyrics() {
    _lyricsFuture = context.read<MusicProvider>().getLyrics(widget.track);
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _scrollToActive(int activeIndex, int totalLines) {
    if (activeIndex != _lastActiveIndex && _scrollController.hasClients) {
      _lastActiveIndex = activeIndex;
      const itemHeight = 64.0;
      final targetOffset = (activeIndex * itemHeight) - 220.0;
      _scrollController.animateTo(
        targetOffset.clamp(0.0, _scrollController.position.maxScrollExtent),
        duration: const Duration(milliseconds: 350),
        curve: Curves.easeOutCubic,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final player = context.watch<AudioPlayerProvider>();
    final music = context.watch<MusicProvider>();
    final currentTrack = player.currentTrack ?? widget.track;
    final currentPosition = player.position;

    final currentSeconds = _dragValue != null
        ? (_dragValue! * player.duration.inSeconds).toInt()
        : player.position.inSeconds;

    return Scaffold(
      backgroundColor: const Color(0xFF0C0817),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Color(0xFF220C40),
              Color(0xFF0F0B1A),
              Color(0xFF08060E),
            ],
            stops: [0.0, 0.45, 1.0],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              // Top Header
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.keyboard_arrow_down_rounded, color: Colors.white, size: 32),
                      onPressed: () => Navigator.maybePop(context),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            currentTrack.title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: AppTypography.titleMedium.copyWith(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            currentTrack.artist,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: AppTypography.bodySmall.copyWith(
                              color: Colors.white.withValues(alpha: 0.7),
                            ),
                          ),
                        ],
                      ),
                    ),
                    CachedCoverArt(
                      imageUrl: music.getCoverArtUrl(currentTrack.coverArtId, size: 100),
                      localImagePath: currentTrack.localCoverArtPath,
                      width: 42,
                      height: 42,
                      borderRadius: 6,
                    ),
                  ],
                ),
              ),

              const Divider(color: Colors.white12, height: 1),

              // Lyrics Content
              Expanded(
                child: FutureBuilder<Lyrics?>(
                  future: _lyricsFuture,
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Center(
                        child: CircularProgressIndicator(color: AppColors.primary),
                      );
                    }

                    final lyrics = snapshot.data;
                    if (lyrics == null || (lyrics.lines.isEmpty && lyrics.rawText.isEmpty)) {
                      return Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.lyrics_rounded, color: AppColors.textMuted, size: 48),
                            const SizedBox(height: 12),
                            Text('No lyrics found for this song', style: AppTypography.titleMedium),
                          ],
                        ),
                      );
                    }

                    // 1. Synced Lyrics
                    if (lyrics.isSynced && lyrics.lines.isNotEmpty) {
                      int activeIndex = 0;
                      for (int i = 0; i < lyrics.lines.length; i++) {
                        if (lyrics.lines[i].timestamp <= currentPosition) {
                          activeIndex = i;
                        } else {
                          break;
                        }
                      }

                      WidgetsBinding.instance.addPostFrameCallback((_) {
                        _scrollToActive(activeIndex, lyrics.lines.length);
                      });

                      return ListView.builder(
                        controller: _scrollController,
                        physics: const BouncingScrollPhysics(),
                        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
                        itemCount: lyrics.lines.length,
                        itemBuilder: (ctx, i) {
                          final line = lyrics.lines[i];
                          final isActive = i == activeIndex;

                          return GestureDetector(
                            onTap: () {
                              HapticFeedback.selectionClick();
                              player.seek(line.timestamp);
                            },
                            child: Padding(
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              child: Text(
                                line.text.isEmpty ? '♪' : line.text,
                                style: TextStyle(
                                  fontFamily: 'Montserrat',
                                  fontSize: isActive ? 26 : 21,
                                  fontWeight: isActive ? FontWeight.w900 : FontWeight.w600,
                                  color: isActive
                                      ? Colors.white
                                      : Colors.white.withValues(alpha: 0.3),
                                  height: 1.35,
                                  letterSpacing: -0.3,
                                ),
                              ),
                            ),
                          );
                        },
                      );
                    }

                    // 2. Plain Text Lyrics
                    return SingleChildScrollView(
                      physics: const BouncingScrollPhysics(),
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
                      child: Text(
                        lyrics.rawText,
                        style: AppTypography.bodyLarge.copyWith(
                          color: Colors.white.withValues(alpha: 0.85),
                          height: 1.8,
                          fontSize: 18,
                        ),
                      ),
                    );
                  },
                ),
              ),

              // Bottom Player Controls Dock
              Container(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.75),
                  border: const Border(top: BorderSide(color: Colors.white10, width: 1)),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Scrubber Slider
                    SliderTheme(
                      data: SliderTheme.of(context).copyWith(
                        trackHeight: 3.5,
                        thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
                        overlayShape: const RoundSliderOverlayShape(overlayRadius: 14),
                        activeTrackColor: AppColors.primary,
                        inactiveTrackColor: Colors.white12,
                        thumbColor: Colors.white,
                      ),
                      child: Slider(
                        value: _dragValue ?? player.progress,
                        onChanged: (val) {
                          setState(() => _dragValue = val);
                        },
                        onChangeEnd: (val) {
                          player.seekPercent(val);
                          setState(() => _dragValue = null);
                        },
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 6),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            DurationFormatter.format(currentSeconds),
                            style: AppTypography.labelSmall.copyWith(color: Colors.white70),
                          ),
                          Text(
                            DurationFormatter.format(player.duration.inSeconds),
                            style: AppTypography.labelSmall.copyWith(color: Colors.white70),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 8),

                    // Controls Row
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        IconButton(
                          icon: Icon(
                            player.isShuffle ? Icons.shuffle_on_rounded : Icons.shuffle_rounded,
                            color: player.isShuffle ? AppColors.primary : Colors.white70,
                            size: 22,
                          ),
                          onPressed: () {
                            HapticFeedback.lightImpact();
                            player.toggleShuffle();
                          },
                        ),
                        IconButton(
                          icon: const Icon(Icons.skip_previous_rounded, color: Colors.white, size: 34),
                          onPressed: () {
                            HapticFeedback.lightImpact();
                            player.skipPrevious();
                          },
                        ),
                        GestureDetector(
                          onTap: () {
                            HapticFeedback.heavyImpact();
                            player.togglePlay();
                          },
                          child: Container(
                            width: 56,
                            height: 56,
                            decoration: const BoxDecoration(
                              color: AppColors.primary,
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              player.isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
                              color: Colors.black,
                              size: 32,
                            ),
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.skip_next_rounded, color: Colors.white, size: 34),
                          onPressed: () {
                            HapticFeedback.lightImpact();
                            player.skipNext();
                          },
                        ),
                        IconButton(
                          icon: Icon(
                            currentTrack.isStarred ? Icons.favorite_rounded : Icons.favorite_border_rounded,
                            color: currentTrack.isStarred ? AppColors.primary : Colors.white70,
                            size: 24,
                          ),
                          onPressed: () {
                            HapticFeedback.lightImpact();
                            music.toggleStar(currentTrack);
                          },
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
