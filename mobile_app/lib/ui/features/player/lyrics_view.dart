import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../../../data/models/lyrics.dart';
import '../../../data/models/track.dart';
import '../../../state/audio_player_provider.dart';
import '../../../state/music_provider.dart';
import 'full_screen_lyrics_screen.dart';

class LyricsView extends StatefulWidget {
  final Track track;
  final bool isFullScreen;

  const LyricsView({
    super.key,
    required this.track,
    this.isFullScreen = false,
  });

  @override
  State<LyricsView> createState() => _LyricsViewState();
}

class _LyricsViewState extends State<LyricsView> {
  final ScrollController _scrollController = ScrollController();
  int _lastActiveIndex = -1;
  Future<Lyrics?>? _lyricsFuture;

  @override
  void initState() {
    super.initState();
    _loadLyrics();
  }

  @override
  void didUpdateWidget(covariant LyricsView oldWidget) {
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
      const itemHeight = 44.0;
      final targetOffset = (activeIndex * itemHeight) - 140.0;
      _scrollController.animateTo(
        targetOffset.clamp(0.0, _scrollController.position.maxScrollExtent),
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOutCubic,
      );
    }
  }

  void _openFullScreen(BuildContext context) {
    HapticFeedback.lightImpact();
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => FullScreenLyricsScreen(track: widget.track),
      ),
    );
  }

  Widget _buildFullScreenButton(BuildContext context) {
    if (widget.isFullScreen) return const SizedBox.shrink();
    return InkWell(
      onTap: () => _openFullScreen(context),
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.white24, width: 1),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.fullscreen_rounded, color: Colors.white, size: 16),
            const SizedBox(width: 4),
            Text(
              'FULL SCREEN',
              style: AppTypography.labelSmall.copyWith(
                color: Colors.white,
                fontWeight: FontWeight.w700,
                fontSize: 10,
                letterSpacing: 0.5,
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final player = context.watch<AudioPlayerProvider>();
    final currentPosition = player.position;

    return FutureBuilder<Lyrics?>(
      future: _lyricsFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: const Color(0xFF161922),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.border),
            ),
            child: const Center(
              child: SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.primary),
              ),
            ),
          );
        }

        final lyrics = snapshot.data;
        if (lyrics == null || (lyrics.lines.isEmpty && lyrics.rawText.isEmpty)) {
          return Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: const Color(0xFF161922),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.border),
            ),
            child: Row(
              children: [
                const Icon(Icons.lyrics_rounded, color: AppColors.textMuted, size: 22),
                const SizedBox(width: 12),
                Text('No lyrics found for this song', style: AppTypography.bodySmall),
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

          return Container(
            height: widget.isFullScreen ? double.infinity : 320,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Color(0xFF28114B), Color(0xFF0E0E18)],
              ),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: AppColors.borderStrong, width: 1.5),
              boxShadow: const [
                BoxShadow(
                  color: AppColors.shadow,
                  offset: Offset(4, 4),
                  blurRadius: 0,
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.lyrics_rounded, color: AppColors.primary, size: 20),
                        const SizedBox(width: 8),
                        Text('Lyrics (Synced)', style: AppTypography.titleMedium),
                      ],
                    ),
                    Row(
                      children: [
                        _buildFullScreenButton(context),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Expanded(
                  child: ListView.builder(
                    controller: _scrollController,
                    physics: const BouncingScrollPhysics(),
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
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          child: Text(
                            line.text.isEmpty ? '...' : line.text,
                            style: AppTypography.titleMedium.copyWith(
                              fontSize: isActive ? 20 : 16,
                              fontWeight: isActive ? FontWeight.w800 : FontWeight.w500,
                              color: isActive
                                  ? Colors.white
                                  : Colors.white.withValues(alpha: 0.35),
                              height: 1.3,
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          );
        }

        // 2. Plain Text Lyrics
        return Container(
          height: widget.isFullScreen ? double.infinity : 280,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: const Color(0xFF161922),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: AppColors.border),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.lyrics_rounded, color: AppColors.primary, size: 20),
                      const SizedBox(width: 8),
                      Text('Lyrics', style: AppTypography.titleMedium),
                    ],
                  ),
                  _buildFullScreenButton(context),
                ],
              ),
              const SizedBox(height: 12),
              Expanded(
                child: SingleChildScrollView(
                  physics: const BouncingScrollPhysics(),
                  child: Text(
                    lyrics.rawText,
                    style: AppTypography.bodyMedium.copyWith(color: Colors.white70, height: 1.5),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
