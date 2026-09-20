import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/theme/dynamic_palette_service.dart';
import '../../../core/utils/duration_formatter.dart';
import '../../../data/models/lyrics.dart';
import '../../../data/models/track.dart';
import '../../../state/audio_player_provider.dart';
import '../../../state/music_provider.dart';
import '../../core_widgets/cached_cover_art.dart';
import '../../core_widgets/pressable_scale.dart';

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
  List<GlobalKey> _itemKeys = [];
  bool _isUserScrolling = false;
  Timer? _userScrollTimer;
  double? _dragValue;
  PaletteColors? _paletteColors;
  String? _lastTrackId;

  Lyrics? _cachedLyrics;

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
      _itemKeys = [];
      _isUserScrolling = false;
      _userScrollTimer?.cancel();
      _cachedLyrics = null;
      _lastTrackId = null;
      _loadLyrics();
    }
  }

  void _loadLyrics() {
    _lyricsFuture = context.read<MusicProvider>().getLyrics(widget.track).then((l) {
      if (mounted) setState(() => _cachedLyrics = l);
      return l;
    });
  }

  void _loadPalette(Track track, MusicProvider music) {
    if (_lastTrackId == track.id) return;
    _lastTrackId = track.id;
    final coverArtUrl = music.getCoverArtUrl(track.coverArtId, size: 250);
    DynamicPaletteService().extractColors(
      key: (track.coverArtId != null && track.coverArtId!.isNotEmpty) ? track.coverArtId! : track.id,
      imageUrl: coverArtUrl,
      localImagePath: track.localCoverArtPath,
    ).then((palette) {
      if (mounted) setState(() => _paletteColors = palette);
    });
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _userScrollTimer?.cancel();
    super.dispose();
  }

  void _onUserScrolled() {
    _isUserScrolling = true;
    _userScrollTimer?.cancel();
    _userScrollTimer = Timer(const Duration(milliseconds: 3500), () {
      if (mounted) {
        setState(() => _isUserScrolling = false);
      }
    });
  }

  void _scrollToActive(int activeIndex) {
    if (_isUserScrolling) return;
    if (activeIndex < 0 || activeIndex >= _itemKeys.length) return;
    if (activeIndex == _lastActiveIndex) return;
    _lastActiveIndex = activeIndex;

    final keyContext = _itemKeys[activeIndex].currentContext;
    if (keyContext != null) {
      Scrollable.ensureVisible(
        keyContext,
        duration: const Duration(milliseconds: 380),
        curve: Curves.easeOutCubic,
        alignment: 0.35,
        alignmentPolicy: ScrollPositionAlignmentPolicy.explicit,
      );
    }
  }

  void _showShareLyricsCard(BuildContext context, Track track, Lyrics? lyrics, int activeIndex) {
    String quoteText = '';
    if (lyrics != null && lyrics.isSynced && lyrics.lines.isNotEmpty) {
      final startIndex = (activeIndex - 1).clamp(0, lyrics.lines.length - 1);
      final endIndex = (activeIndex + 2).clamp(0, lyrics.lines.length);
      quoteText = lyrics.lines
          .sublist(startIndex, endIndex)
          .map((l) => l.text)
          .where((t) => t.isNotEmpty)
          .join('\n');
    } else if (lyrics != null && lyrics.rawText.isNotEmpty) {
      quoteText = lyrics.rawText.split('\n').take(4).join('\n');
    } else {
      quoteText = track.title;
    }

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) {
        return Container(
          padding: const EdgeInsets.all(24),
          decoration: const BoxDecoration(
            color: Color(0xFF141622),
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Share Lyrics Card', style: AppTypography.titleLarge),
              const SizedBox(height: 16),
              // Spotify-style Card preview
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  gradient: _paletteColors?.toAmbientGradient() ??
                      const LinearGradient(
                        colors: [Color(0xFF32125A), Color(0xFF120824)],
                      ),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: Colors.white.withValues(alpha: 0.12), width: 1.0),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.35),
                      offset: const Offset(0, 6),
                      blurRadius: 18,
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        CachedCoverArt(
                          imageUrl: context.read<MusicProvider>().getCoverArtUrl(track.coverArtId, size: 120),
                          localImagePath: track.localCoverArtPath,
                          width: 40,
                          height: 40,
                          borderRadius: 8,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(track.title, style: AppTypography.titleMedium.copyWith(fontSize: 14), maxLines: 1),
                              Text(track.artist, style: AppTypography.bodySmall.copyWith(color: Colors.white70), maxLines: 1),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 18),
                    Text(
                      quoteText,
                      style: const TextStyle(
                        fontFamily: 'Montserrat',
                        fontSize: 19,
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                        height: 1.45,
                      ),
                    ),
                    const SizedBox(height: 18),
                    Row(
                      children: [
                        const Icon(Icons.music_note_rounded, color: AppColors.primary, size: 16),
                        const SizedBox(width: 4),
                        Text('LocalSpotify', style: AppTypography.labelSmall.copyWith(color: AppColors.primary, fontWeight: FontWeight.bold)),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.black,
                  minimumSize: const Size(double.infinity, 50),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
                icon: const Icon(Icons.copy_rounded, size: 20),
                label: const Text('Copy Lyrics Quote', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                onPressed: () {
                  HapticFeedback.mediumImpact();
                  Clipboard.setData(ClipboardData(text: '"$quoteText"\n— ${track.title} by ${track.artist}'));
                  Navigator.pop(ctx);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Lyrics quote copied to clipboard!'), duration: Duration(seconds: 2)),
                  );
                },
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final player = context.watch<AudioPlayerProvider>();
    final music = context.watch<MusicProvider>();
    final currentTrack = player.currentTrack ?? widget.track;
    final currentPosition = player.position;

    _loadPalette(currentTrack, music);

    final currentSeconds = _dragValue != null
        ? (_dragValue! * player.duration.inSeconds).toInt()
        : player.position.inSeconds;

    return Scaffold(
      backgroundColor: const Color(0xFF0C0817),
      body: AnimatedContainer(
        duration: const Duration(milliseconds: 400),
        curve: Curves.easeOutCubic,
        decoration: BoxDecoration(
          gradient: _paletteColors?.toAmbientGradient() ??
              const LinearGradient(
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
                    IconButton(
                      icon: const Icon(Icons.share_rounded, color: Colors.white70, size: 22),
                      tooltip: 'Share Lyrics Card',
                      onPressed: () {
                        _showShareLyricsCard(context, currentTrack, _cachedLyrics, _lastActiveIndex);
                      },
                    ),
                    const SizedBox(width: 4),
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
                      if (_itemKeys.length != lyrics.lines.length) {
                        _itemKeys = List.generate(lyrics.lines.length, (_) => GlobalKey());
                      }

                      int activeIndex = -1;
                      for (int i = 0; i < lyrics.lines.length; i++) {
                        if (lyrics.lines[i].timestamp <= currentPosition) {
                          activeIndex = i;
                        } else {
                          break;
                        }
                      }

                      WidgetsBinding.instance.addPostFrameCallback((_) {
                        _scrollToActive(activeIndex);
                      });

                      return Stack(
                        children: [
                          NotificationListener<UserScrollNotification>(
                            onNotification: (notification) {
                              if (notification.direction != ScrollDirection.idle) {
                                _onUserScrolled();
                              }
                              return false;
                            },
                            child: ListView.builder(
                              controller: _scrollController,
                              physics: const BouncingScrollPhysics(),
                              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
                              itemCount: lyrics.lines.length,
                              itemBuilder: (ctx, i) {
                                final line = lyrics.lines[i];
                                final isActive = i == activeIndex;
                                final isArabic = AppTypography.isArabicText(line.text);

                                final lineStyle = AppTypography.lyricsLineStyle(
                                  text: line.text,
                                  isActive: isActive,
                                  fontSize: 22.5,
                                  activeColor: Colors.white,
                                  inactiveColor: Colors.white.withValues(alpha: 0.32),
                                );

                                return PressableScale(
                                  key: _itemKeys[i],
                                  onTap: () {
                                    HapticFeedback.selectionClick();
                                    player.seek(line.timestamp);
                                    _isUserScrolling = false;
                                    _scrollToActive(i);
                                  },
                                  scaleFactor: 0.98,
                                  child: AnimatedContainer(
                                    duration: const Duration(milliseconds: 240),
                                    curve: Curves.easeOutCubic,
                                    padding: const EdgeInsets.symmetric(
                                      vertical: 10,
                                      horizontal: 12,
                                    ),
                                    margin: const EdgeInsets.symmetric(vertical: 3),
                                    decoration: BoxDecoration(
                                      color: isActive
                                          ? Colors.white.withValues(alpha: 0.08)
                                          : Colors.transparent,
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: Align(
                                      alignment: isArabic ? Alignment.centerRight : Alignment.centerLeft,
                                      child: AnimatedDefaultTextStyle(
                                        duration: const Duration(milliseconds: 240),
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

                          // Floating Sync Re-alignment button if user scrolled away
                          if (_isUserScrolling && activeIndex >= 0)
                            Positioned(
                              bottom: 16,
                              right: 24,
                              child: PressableScale(
                                onTap: () {
                                  HapticFeedback.mediumImpact();
                                  setState(() => _isUserScrolling = false);
                                  _lastActiveIndex = -1;
                                  _scrollToActive(activeIndex);
                                },
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                                  decoration: BoxDecoration(
                                    color: AppColors.primary,
                                    borderRadius: BorderRadius.circular(20),
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.black.withValues(alpha: 0.4),
                                        blurRadius: 10,
                                        offset: const Offset(0, 4),
                                      ),
                                    ],
                                  ),
                                  child: const Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(Icons.sync_rounded, color: Colors.black, size: 16),
                                      SizedBox(width: 6),
                                      Text(
                                        'Sync to song',
                                        style: TextStyle(
                                          color: Colors.black,
                                          fontWeight: FontWeight.bold,
                                          fontSize: 12,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                        ],
                      );
                    }

                    // 2. Plain Text Lyrics
                    final isArabic = AppTypography.isArabicText(lyrics.rawText);
                    return SingleChildScrollView(
                      physics: const BouncingScrollPhysics(),
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
                      child: Text(
                        lyrics.rawText,
                        textDirection: isArabic ? TextDirection.rtl : TextDirection.ltr,
                        textAlign: isArabic ? TextAlign.right : TextAlign.left,
                        style: AppTypography.lyricsLineStyle(
                          text: lyrics.rawText,
                          isActive: true,
                          fontSize: 19,
                          activeColor: Colors.white.withValues(alpha: 0.88),
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
                        Builder(
                          builder: (context) {
                            final isStarred = music.isTrackStarred(currentTrack.id);
                            return PressableScale(
                              onTap: () {
                                HapticFeedback.lightImpact();
                                music.toggleStar(currentTrack);
                              },
                              scaleFactor: 0.88,
                              child: Padding(
                                padding: const EdgeInsets.all(8.0),
                                child: Icon(
                                  isStarred ? Icons.favorite_rounded : Icons.favorite_border_rounded,
                                  color: isStarred ? AppColors.primary : Colors.white70,
                                  size: 24,
                                ),
                              ),
                            );
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
