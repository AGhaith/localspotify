import 'dart:async';
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
import 'synced_lyrics_list.dart';

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
      setState(() {
        _loadLyrics();
      });
    }
  }

  void _loadLyrics() {
    _lyricsFuture = context.read<MusicProvider>().getLyrics(widget.track).timeout(
      const Duration(seconds: 5),
      onTimeout: () => null,
    ).catchError((_) => null);
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
    final backgroundColor =
        palette?.ambientTop ?? AppColors.surface;

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
                    colors: [AppColors.surface, AppColors.card],
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
                    colors: [AppColors.surface, AppColors.card],
                  ),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: palette?.lyricsBorderColor ?? AppColors.border),
            ),
            child: Row(
              children: [
                const Icon(Icons.lyrics_rounded, color: AppColors.textMuted, size: 22),
                const SizedBox(width: 12),
                Text(
                  'No lyrics for this song',
                  style: AppTypography.bodySmall.copyWith(color: AppColors.textMuted),
                ),
              ],
            ),
          );
        }

        final isSynced = lyrics.isSynced && lyrics.lines.isNotEmpty;

        return AnimatedContainer(
          duration: const Duration(milliseconds: 400),
          curve: Curves.easeOutCubic,
          height: widget.isFullScreen ? double.infinity : (isSynced ? 330 : 290),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            gradient: palette?.toLyricsCardGradient() ??
                const LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [AppColors.surface, AppColors.card],
                ),
            borderRadius: BorderRadius.circular(22),
            border: Border.all(
              color: palette?.lyricsBorderColor ?? AppColors.borderStrong,
              width: 1.5,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.25),
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
                      Text(
                        isSynced ? 'Lyrics (Synced)' : 'Lyrics',
                        style: AppTypography.titleMedium,
                      ),
                    ],
                  ),
                  _buildFullScreenButton(context, accent),
                ],
              ),
              const SizedBox(height: 10),
              Expanded(
                child: SyncedLyricsList(
                  lyrics: lyrics,
                  currentPosition: currentPosition,
                  accentColor: accent,
                  backgroundColor: backgroundColor,
                  textSize: 20.0,
                  onSeek: (timestamp) => player.seek(timestamp),
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
