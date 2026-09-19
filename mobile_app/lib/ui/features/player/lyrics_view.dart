import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/theme/dynamic_palette_service.dart';
import '../../../data/models/lyrics.dart';
import '../../../data/models/track.dart';
import '../../../state/audio_player_provider.dart';
import '../../../state/music_provider.dart';
import '../../core_widgets/pressable_scale.dart';
import 'full_screen_lyrics_screen.dart';

class LyricsView extends StatefulWidget {
  final Track track;
  final bool isFullScreen;
  final PaletteColors? paletteColors;

  const LyricsView({
    super.key,
    required this.track,
    this.isFullScreen = false,
    this.paletteColors,
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
      const itemHeight = 48.0;
      final targetOffset = (activeIndex * itemHeight) - 130.0;
      _scrollController.animateTo(
        targetOffset.clamp(0.0, _scrollController.position.maxScrollExtent),
        duration: const Duration(milliseconds: 380),
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

  Widget _buildFullScreenButton(BuildContext context, Color accentColor) {
    if (widget.isFullScreen) return const SizedBox.shrink();
    return PressableScale(
      onTap: () => _openFullScreen(context),
      scaleFactor: 0.92,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: accentColor.withValues(alpha: 0.35), width: 1),
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
                fontWeight: FontWeight.w800,
                fontSize: 10,
                letterSpacing: 0.6,
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
    final palette = widget.paletteColors;
    final accent = palette?.primaryAccent ?? AppColors.primary;

    return FutureBuilder<Lyrics?>(
      future: _lyricsFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return AnimatedContainer(
            duration: const Duration(milliseconds: 350),
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              gradient: palette?.toLyricsCardGradient() ??
                  const LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [Color(0xFF222226), Color(0xFF141418)],
                  ),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: palette?.lyricsBorderColor ?? AppColors.border),
            ),
            child: Center(
              child: SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(strokeWidth: 2, color: accent),
              ),
            ),
          );
        }

        final lyrics = snapshot.data;
        if (lyrics == null || (lyrics.lines.isEmpty && lyrics.rawText.isEmpty)) {
          return AnimatedContainer(
            duration: const Duration(milliseconds: 350),
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: palette?.toLyricsCardGradient() ??
                  const LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [Color(0xFF222226), Color(0xFF141418)],
                  ),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: palette?.lyricsBorderColor ?? AppColors.border),
            ),
            child: Row(
              children: [
                Icon(Icons.lyrics_rounded, color: accent.withValues(alpha: 0.7), size: 22),
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

          return AnimatedContainer(
            duration: const Duration(milliseconds: 400),
            curve: Curves.easeOutCubic,
            height: widget.isFullScreen ? double.infinity : 330,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: palette?.toLyricsCardGradient() ??
                  const LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [Color(0xFF222228), Color(0xFF111115)],
                  ),
              borderRadius: BorderRadius.circular(22),
              border: Border.all(
                color: palette?.lyricsBorderColor ?? AppColors.borderStrong,
                width: 1.5,
              ),
              boxShadow: [
                BoxShadow(
                  color: (palette?.primaryAccent ?? Colors.black).withValues(alpha: 0.18),
                  offset: const Offset(0, 6),
                  blurRadius: 16,
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
                        Icon(Icons.lyrics_rounded, color: accent, size: 20),
                        const SizedBox(width: 8),
                        Text('Lyrics (Synced)', style: AppTypography.titleMedium),
                      ],
                    ),
                    _buildFullScreenButton(context, accent),
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
                      final isArabic = AppTypography.isArabicText(line.text);

                      final lineStyle = AppTypography.lyricsLineStyle(
                        text: line.text,
                        isActive: isActive,
                        fontSize: isActive ? 21 : 16.5,
                        activeColor: Colors.white,
                        inactiveColor: Colors.white.withValues(alpha: 0.35),
                      );

                      return PressableScale(
                        onTap: () {
                          HapticFeedback.selectionClick();
                          player.seek(line.timestamp);
                        },
                        scaleFactor: 0.98,
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 250),
                          curve: Curves.easeOutCubic,
                          padding: EdgeInsets.symmetric(
                            vertical: isActive ? 10 : 6,
                            horizontal: isActive ? 8 : 4,
                          ),
                          margin: const EdgeInsets.symmetric(vertical: 2),
                          decoration: BoxDecoration(
                            color: isActive
                                ? Colors.white.withValues(alpha: 0.08)
                                : Colors.transparent,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Align(
                            alignment: isArabic ? Alignment.centerRight : Alignment.centerLeft,
                            child: AnimatedDefaultTextStyle(
                              duration: const Duration(milliseconds: 280),
                              curve: Curves.easeOutCubic,
                              style: lineStyle,
                              child: Text(
                                line.text.isEmpty ? '...' : line.text,
                                textDirection: isArabic ? TextDirection.rtl : TextDirection.ltr,
                                textAlign: isArabic ? TextAlign.right : TextAlign.left,
                              ),
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
        final isArabic = AppTypography.isArabicText(lyrics.rawText);
        return AnimatedContainer(
          duration: const Duration(milliseconds: 400),
          height: widget.isFullScreen ? double.infinity : 290,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            gradient: palette?.toLyricsCardGradient() ??
                const LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Color(0xFF222228), Color(0xFF111115)],
                ),
            borderRadius: BorderRadius.circular(22),
            border: Border.all(
              color: palette?.lyricsBorderColor ?? AppColors.border,
              width: 1.5,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Icon(Icons.lyrics_rounded, color: accent, size: 20),
                      const SizedBox(width: 8),
                      Text('Lyrics', style: AppTypography.titleMedium),
                    ],
                  ),
                  _buildFullScreenButton(context, accent),
                ],
              ),
              const SizedBox(height: 12),
              Expanded(
                child: SingleChildScrollView(
                  physics: const BouncingScrollPhysics(),
                  child: Text(
                    lyrics.rawText,
                    textDirection: isArabic ? TextDirection.rtl : TextDirection.ltr,
                    textAlign: isArabic ? TextAlign.right : TextAlign.left,
                    style: AppTypography.lyricsLineStyle(
                      text: lyrics.rawText,
                      isActive: true,
                      fontSize: 16,
                      activeColor: Colors.white.withValues(alpha: 0.88),
                    ),
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
