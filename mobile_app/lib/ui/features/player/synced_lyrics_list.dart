import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../../../data/models/lyrics.dart';
import '../../core_widgets/pressable_scale.dart';

/// Spotify-style shared synced & unsynced lyrics list.
///
/// Features:
/// - One-time GlobalKey generation per lyrics instance (recreated only on track/lyrics change).
/// - Fast binary search for active line lookup.
/// - SingleChildScrollView + Column ensuring all lines are mounted and laid out.
/// - Scroll targeting ~35% viewport offset with Curves.easeOutCubic (450ms) on index change.
/// - User drag pauses auto-scroll with smooth 3-second resume.
/// - Spotify typography: bold w800 lines, 14px vertical spacing, AnimatedDefaultTextStyle (250ms).
/// - Edge fade via top/bottom ShaderMask.
class SyncedLyricsList extends StatefulWidget {
  final Lyrics lyrics;
  final Duration currentPosition;
  final Stream<Duration>? positionStream;
  final Color? accentColor;
  final Color? backgroundColor;
  final double textSize;
  final ValueChanged<Duration>? onSeek;
  final EdgeInsetsGeometry padding;
  final bool showSyncButton;
  final ValueChanged<int>? onActiveIndexChanged;

  const SyncedLyricsList({
    super.key,
    required this.lyrics,
    this.currentPosition = Duration.zero,
    this.positionStream,
    this.accentColor,
    this.backgroundColor,
    this.textSize = 24.0,
    this.onSeek,
    this.padding = const EdgeInsets.symmetric(horizontal: 20),
    this.showSyncButton = false,
    this.onActiveIndexChanged,
  });

  @override
  State<SyncedLyricsList> createState() => _SyncedLyricsListState();
}

class _SyncedLyricsListState extends State<SyncedLyricsList> {
  final ScrollController _scrollController = ScrollController();
  final GlobalKey _viewportKey = GlobalKey();
  final GlobalKey _contentKey = GlobalKey();

  late List<GlobalKey> _itemKeys;
  int _activeIndex = -1;
  int _lastScrolledIndex = -1;

  bool _isUserScrolling = false;
  Timer? _userScrollTimer;
  StreamSubscription<Duration>? _positionSub;

  @override
  void initState() {
    super.initState();
    _initKeys();
    _activeIndex = _computeActiveIndex(widget.currentPosition);
    _lastScrolledIndex = _activeIndex;
    widget.onActiveIndexChanged?.call(_activeIndex);

    if (widget.positionStream != null) {
      _positionSub = widget.positionStream!.listen(_handlePosition);
    }

    if (widget.lyrics.isSynced && _activeIndex >= 0) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _scrollToLine(_activeIndex);
      });
    }
  }

  void _initKeys() {
    _itemKeys = List.generate(
      widget.lyrics.lines.length,
      (_) => GlobalKey(),
    );
  }

  @override
  void didUpdateWidget(covariant SyncedLyricsList oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (widget.positionStream != oldWidget.positionStream) {
      _positionSub?.cancel();
      if (widget.positionStream != null) {
        _positionSub = widget.positionStream!.listen(_handlePosition);
      }
    }

    final lyricsChanged = !identical(oldWidget.lyrics, widget.lyrics) ||
        oldWidget.lyrics.lines.length != widget.lyrics.lines.length;

    if (lyricsChanged) {
      _initKeys();
      _userScrollTimer?.cancel();
      _isUserScrolling = false;
      _lastScrolledIndex = -1;
      _activeIndex = _computeActiveIndex(widget.currentPosition);
      widget.onActiveIndexChanged?.call(_activeIndex);

      if (widget.lyrics.isSynced && _activeIndex >= 0) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          _lastScrolledIndex = _activeIndex;
          _scrollToLine(_activeIndex);
        });
      }
    } else if (widget.positionStream == null &&
        oldWidget.currentPosition != widget.currentPosition) {
      _handlePosition(widget.currentPosition);
    }
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _userScrollTimer?.cancel();
    _positionSub?.cancel();
    super.dispose();
  }

  /// Binary search on line timestamps. Returns -1 if position is before first line.
  int _computeActiveIndex(Duration position) {
    final lines = widget.lyrics.lines;
    if (lines.isEmpty || position < lines.first.timestamp) {
      return -1;
    }
    int low = 0;
    int high = lines.length - 1;
    int result = 0;
    while (low <= high) {
      final mid = (low + high) >> 1;
      if (lines[mid].timestamp <= position) {
        result = mid;
        low = mid + 1;
      } else {
        high = mid - 1;
      }
    }
    return result;
  }

  void _handlePosition(Duration position) {
    if (!widget.lyrics.isSynced) return;
    final newIndex = _computeActiveIndex(position);
    if (newIndex != _activeIndex) {
      setState(() {
        _activeIndex = newIndex;
      });
      widget.onActiveIndexChanged?.call(newIndex);

      if (!_isUserScrolling && newIndex != _lastScrolledIndex) {
        _lastScrolledIndex = newIndex;
        if (newIndex >= 0) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            _scrollToLine(newIndex);
          });
        }
      }
    }
  }

  void _scrollToLine(int index) {
    if (!mounted || !_scrollController.hasClients) return;
    if (index < 0 || index >= _itemKeys.length) return;

    final contentContext = _contentKey.currentContext;
    final itemContext = _itemKeys[index].currentContext;
    final viewportContext = _viewportKey.currentContext;
    if (contentContext == null || itemContext == null || viewportContext == null) return;

    final contentBox = contentContext.findRenderObject() as RenderBox?;
    final itemBox = itemContext.findRenderObject() as RenderBox?;
    final viewportBox = viewportContext.findRenderObject() as RenderBox?;
    if (contentBox == null || !contentBox.hasSize ||
        itemBox == null || !itemBox.hasSize ||
        viewportBox == null || !viewportBox.hasSize) {
      return;
    }

    final lineOffsetInContent = itemBox.localToGlobal(Offset.zero, ancestor: contentBox);
    final viewportHeight = viewportBox.size.height;
    final targetPositionInViewport = viewportHeight * 0.35;

    final targetOffset = (lineOffsetInContent.dy - targetPositionInViewport).clamp(
      _scrollController.position.minScrollExtent,
      _scrollController.position.maxScrollExtent,
    );

    if ((targetOffset - _scrollController.offset).abs() < 1.0) return;

    _scrollController.animateTo(
      targetOffset,
      duration: const Duration(milliseconds: 450),
      curve: Curves.easeOutCubic,
    );
  }

  void _onUserDragStarted() {
    _userScrollTimer?.cancel();
    if (!_isUserScrolling) {
      setState(() {
        _isUserScrolling = true;
      });
    }
  }

  void _onUserDragEnded() {
    _userScrollTimer?.cancel();
    _userScrollTimer = Timer(const Duration(seconds: 3), () {
      if (!mounted) return;
      setState(() {
        _isUserScrolling = false;
      });
      if (_activeIndex >= 0) {
        _lastScrolledIndex = _activeIndex;
        _scrollToLine(_activeIndex);
      }
    });
  }

  Color get _upcomingColor {
    final bg = widget.backgroundColor;
    if (bg != null) {
      final lum = bg.computeLuminance();
      if (lum > 0.08) {
        return Colors.black.withValues(alpha: 0.45);
      }
    }
    return Colors.white.withValues(alpha: 0.35);
  }

  Color _getLineColor(int index) {
    if (_activeIndex == -1) {
      return _upcomingColor;
    }
    if (index == _activeIndex) {
      return Colors.white;
    }
    if (index < _activeIndex) {
      return Colors.white.withValues(alpha: 0.55);
    }
    return _upcomingColor;
  }

  TextStyle _getLineStyle({
    required String text,
    required Color color,
    required double fontSize,
  }) {
    final isArabic = AppTypography.isArabicText(text);
    if (isArabic) {
      return GoogleFonts.cairo(
        fontSize: fontSize,
        fontWeight: FontWeight.w800,
        color: color,
        height: 1.4,
      );
    }
    return GoogleFonts.rubik(
      fontSize: fontSize,
      fontWeight: FontWeight.w800,
      color: color,
      height: 1.25,
      letterSpacing: -0.3,
    );
  }

  Widget _buildShaderMask({required Widget child}) {
    return ShaderMask(
      shaderCallback: (Rect bounds) {
        return const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Colors.transparent,
            Colors.black,
            Colors.black,
            Colors.transparent,
          ],
          stops: [0.0, 0.08, 0.92, 1.0],
        ).createShader(bounds);
      },
      blendMode: BlendMode.dstIn,
      child: child,
    );
  }

  Widget _buildSyncedLine(int index, LyricsLine line) {
    final isArabic = AppTypography.isArabicText(line.text);
    final color = _getLineColor(index);
    final lineStyle = _getLineStyle(
      text: line.text,
      color: color,
      fontSize: widget.textSize,
    );

    return GestureDetector(
      key: _itemKeys[index],
      behavior: HitTestBehavior.opaque,
      onTap: () {
        HapticFeedback.selectionClick();
        widget.onSeek?.call(line.timestamp);
        _userScrollTimer?.cancel();
        if (_isUserScrolling) {
          setState(() => _isUserScrolling = false);
        }
        _lastScrolledIndex = index;
        _scrollToLine(index);
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 7.0),
        child: Align(
          alignment: isArabic ? Alignment.centerRight : Alignment.centerLeft,
          child: AnimatedDefaultTextStyle(
            duration: const Duration(milliseconds: 250),
            curve: Curves.easeOut,
            style: lineStyle,
            child: Text(
              line.text.isEmpty ? '...' : line.text,
              textAlign: isArabic ? TextAlign.right : TextAlign.left,
              textDirection: isArabic ? TextDirection.rtl : TextDirection.ltr,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPlainLyrics() {
    final rawLines = widget.lyrics.rawText.split('\n');
    return _buildShaderMask(
      child: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        padding: widget.padding,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: rawLines.map((raw) {
            final text = raw.trim();
            if (text.isEmpty) {
              return const SizedBox(height: 14);
            }
            final isArabic = AppTypography.isArabicText(text);
            final lineStyle = _getLineStyle(
              text: text,
              color: Colors.white.withValues(alpha: 0.85),
              fontSize: widget.textSize,
            );
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 7.0),
              child: Align(
                alignment: isArabic ? Alignment.centerRight : Alignment.centerLeft,
                child: Text(
                  text,
                  style: lineStyle,
                  textAlign: isArabic ? TextAlign.right : TextAlign.left,
                  textDirection: isArabic ? TextDirection.rtl : TextDirection.ltr,
                ),
              ),
            );
          }).toList(),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.lyrics.isSynced || widget.lyrics.lines.isEmpty) {
      return _buildPlainLyrics();
    }

    return NotificationListener<ScrollNotification>(
      onNotification: (notification) {
        if (notification is UserScrollNotification) {
          if (notification.direction != ScrollDirection.idle) {
            _onUserDragStarted();
          } else if (_isUserScrolling) {
            _onUserDragEnded();
          }
        } else if (notification is ScrollEndNotification) {
          if (_isUserScrolling &&
              (_userScrollTimer == null || !_userScrollTimer!.isActive)) {
            _onUserDragEnded();
          }
        }
        return false;
      },
      child: LayoutBuilder(
        builder: (context, constraints) {
          final viewportHeight =
              constraints.hasBoundedHeight ? constraints.maxHeight : 400.0;
          final topSpacing = (viewportHeight * 0.35).clamp(24.0, 240.0);
          final bottomSpacing = (viewportHeight * 0.65).clamp(60.0, 360.0);

          return Stack(
            children: [
              KeyedSubtree(
                key: _viewportKey,
                child: _buildShaderMask(
                  child: SingleChildScrollView(
                    controller: _scrollController,
                    physics: const BouncingScrollPhysics(),
                    padding: widget.padding,
                    child: KeyedSubtree(
                      key: _contentKey,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          SizedBox(height: topSpacing),
                          ...List.generate(
                            widget.lyrics.lines.length,
                            (i) => _buildSyncedLine(i, widget.lyrics.lines[i]),
                          ),
                          SizedBox(height: bottomSpacing),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              if (widget.showSyncButton && _isUserScrolling && _activeIndex >= 0)
                Positioned(
                  bottom: 24,
                  right: 24,
                  child: PressableScale(
                    onTap: () {
                      HapticFeedback.mediumImpact();
                      _userScrollTimer?.cancel();
                      setState(() => _isUserScrolling = false);
                      _lastScrolledIndex = _activeIndex;
                      _scrollToLine(_activeIndex);
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: widget.accentColor ?? AppColors.primary,
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
        },
      ),
    );
  }
}
