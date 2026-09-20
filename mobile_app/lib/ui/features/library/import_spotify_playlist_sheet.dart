import 'dart:async';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:palette_generator/palette_generator.dart';
import 'package:provider/provider.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../../../data/models/playlist.dart';
import '../../../data/services/spotify_importer_service.dart';
import '../../../data/services/spotify_service.dart';
import '../../../state/music_provider.dart';
import '../../core_widgets/cached_cover_art.dart';
import '../../core_widgets/neo_button.dart';
import '../../core_widgets/pressable_scale.dart';
import 'playlist_detail_screen.dart';

enum _ImportStep { input, preview, downloading, success, error }

class ImportSpotifyPlaylistSheet extends StatefulWidget {
  const ImportSpotifyPlaylistSheet({super.key});

  static Future<void> show(BuildContext context) {
    return showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => const ImportSpotifyPlaylistSheet(),
    );
  }

  @override
  State<ImportSpotifyPlaylistSheet> createState() => _ImportSpotifyPlaylistSheetState();
}

class _ImportSpotifyPlaylistSheetState extends State<ImportSpotifyPlaylistSheet> {
  final _urlController = TextEditingController();
  _ImportStep _step = _ImportStep.input;

  bool _isFetching = false;
  String? _errorMessage;
  SpotifyPlaylistInfo? _playlistInfo;
  ImportProgressStatus? _importStatus;
  Playlist? _createdPlaylist;

  // Extracted color palette from album artwork
  Color _paletteDominant = const Color(0xFF181818);
  Color _paletteVibrant = const Color(0xFF1DB954);
  Color _paletteSurface = const Color(0xFF242424);

  @override
  void dispose() {
    _urlController.dispose();
    super.dispose();
  }

  Future<void> _pasteFromClipboard() async {
    final data = await Clipboard.getData(Clipboard.kTextPlain);
    if (data?.text != null && data!.text!.isNotEmpty) {
      setState(() {
        _urlController.text = data.text!.trim();
      });
      HapticFeedback.lightImpact();
    }
  }

  Future<void> _extractPalette(String coverUrl) async {
    try {
      final palette = await PaletteGenerator.fromImageProvider(
        CachedNetworkImageProvider(coverUrl),
        maximumColorCount: 16,
      );
      if (mounted) {
        setState(() {
          _paletteDominant = palette.darkVibrantColor?.color ??
              palette.darkMutedColor?.color ??
              palette.dominantColor?.color ??
              const Color(0xFF181818);
          _paletteVibrant = palette.vibrantColor?.color ??
              palette.lightVibrantColor?.color ??
              palette.dominantColor?.color ??
              const Color(0xFF1DB954);
          _paletteSurface = Color.alphaBlend(
            _paletteDominant.withValues(alpha: 0.5),
            const Color(0xFF1E1E1E),
          );
        });
      }
    } catch (_) {}
  }

  Future<void> _onFetchPlaylist() async {
    final rawUrl = _urlController.text.trim();
    if (rawUrl.isEmpty) {
      setState(() => _errorMessage = 'Please enter or paste a Spotify playlist link.');
      return;
    }

    final id = SpotifyService.parsePlaylistId(rawUrl);
    if (id == null) {
      setState(() => _errorMessage = 'Invalid link. Please provide a valid Spotify playlist URL or URI.');
      return;
    }

    setState(() {
      _isFetching = true;
      _errorMessage = null;
    });

    try {
      final music = context.read<MusicProvider>();
      final info = await music.fetchSpotifyPlaylist(rawUrl);
      if (mounted) {
        HapticFeedback.mediumImpact();
        setState(() {
          _playlistInfo = info;
          _step = _ImportStep.preview;
          _isFetching = false;
        });

        if (info.coverUrl != null && info.coverUrl!.isNotEmpty) {
          _extractPalette(info.coverUrl!);
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = e.toString().replaceAll('Exception:', '').trim();
          _isFetching = false;
        });
      }
    }
  }

  Future<void> _startImport() async {
    if (_playlistInfo == null) return;

    setState(() {
      _step = _ImportStep.downloading;
      _errorMessage = null;
    });

    try {
      final music = context.read<MusicProvider>();
      final pl = await music.importSpotifyPlaylist(
        spotifyUrl: _urlController.text.trim(),
        onProgress: (status) {
          if (mounted) {
            setState(() {
              _importStatus = status;
              if (status.playlist != null) {
                _createdPlaylist = status.playlist;
              }
            });
          }
        },
      );

      if (mounted) {
        HapticFeedback.heavyImpact();
        setState(() {
          _createdPlaylist = pl;
          _step = _ImportStep.success;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = e.toString().replaceAll('Exception:', '').trim();
          _step = _ImportStep.error;
        });
      }
    }
  }

  void _openPlaylist() {
    if (_createdPlaylist != null) {
      Navigator.pop(context);
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => PlaylistDetailScreen(playlistId: _createdPlaylist!.id),
        ),
      );
    } else {
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 350),
      curve: Curves.easeOutCubic,
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 14,
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Color.alphaBlend(_paletteDominant.withValues(alpha: 0.85), const Color(0xFF121212)),
            const Color(0xFF121212),
          ],
          stops: const [0.0, 0.5],
        ),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        border: Border(
          top: BorderSide(
            color: _paletteVibrant.withValues(alpha: 0.35),
            width: 1.5,
          ),
        ),
        boxShadow: [
          BoxShadow(
            color: _paletteDominant.withValues(alpha: 0.35),
            blurRadius: 30,
            offset: const Offset(0, -8),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Drag handle
          Center(
            child: Container(
              width: 44,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.white24,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 14),

          // Header
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      _paletteVibrant,
                      _paletteVibrant.withValues(alpha: 0.85),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  Icons.playlist_add_check_rounded,
                  color: Colors.black,
                  size: 22,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Import Spotify Playlist',
                      style: AppTypography.titleLarge.copyWith(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    Text(
                      'Sync tracks into your library vault',
                      style: AppTypography.bodySmall.copyWith(color: Colors.white70),
                    ),
                  ],
                ),
              ),
              IconButton(
                style: IconButton.styleFrom(backgroundColor: Colors.white.withValues(alpha: 0.08)),
                icon: const Icon(Icons.close_rounded, color: Colors.white70, size: 20),
                onPressed: () => Navigator.pop(context),
              ),
            ],
          ),
          const SizedBox(height: 18),

          // Content body based on current step
          if (_step == _ImportStep.input) _buildInputView(),
          if (_step == _ImportStep.preview) _buildPreviewView(),
          if (_step == _ImportStep.downloading) _buildDownloadingView(),
          if (_step == _ImportStep.success) _buildSuccessView(),
          if (_step == _ImportStep.error) _buildErrorView(),
        ],
      ),
    );
  }

  Widget _buildInputView() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Paste any Spotify playlist link below. The server will sync audio tracks, high-res artwork, and synced lyrics into your vault, and make the playlist available on your account.',
          style: AppTypography.bodySmall.copyWith(color: Colors.white70, height: 1.4),
        ),
        const SizedBox(height: 18),

        // Link Input Field
        TextField(
          controller: _urlController,
          style: AppTypography.bodyLarge,
          keyboardType: TextInputType.url,
          decoration: InputDecoration(
            hintText: 'https://open.spotify.com/playlist/...',
            prefixIcon: Icon(Icons.link_rounded, color: _paletteVibrant),
            suffixIcon: IconButton(
              icon: Icon(Icons.content_paste_rounded, color: _paletteVibrant),
              tooltip: 'Paste link',
              onPressed: _pasteFromClipboard,
            ),
          ),
          onSubmitted: (_) => _onFetchPlaylist(),
        ),

        if (_errorMessage != null) ...[
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: AppColors.error.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: AppColors.error.withValues(alpha: 0.4)),
            ),
            child: Row(
              children: [
                const Icon(Icons.error_outline_rounded, color: AppColors.error, size: 18),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    _errorMessage!,
                    style: const TextStyle(color: AppColors.error, fontSize: 13),
                  ),
                ),
              ],
            ),
          ),
        ],

        const SizedBox(height: 20),
        NeoButton(
          text: 'Fetch Playlist',
          icon: Icons.search_rounded,
          isLoading: _isFetching,
          backgroundColor: _paletteVibrant,
          textColor: Colors.black,
          onPressed: _isFetching ? null : _onFetchPlaylist,
        ),
      ],
    );
  }

  Widget _buildPreviewView() {
    final info = _playlistInfo!;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Playlist Info Card (matches cover palette)
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: _paletteSurface.withValues(alpha: 0.65),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: _paletteVibrant.withValues(alpha: 0.25),
              width: 1.2,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.25),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(10),
                  boxShadow: [
                    BoxShadow(
                      color: _paletteVibrant.withValues(alpha: 0.25),
                      blurRadius: 10,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
                child: CachedCoverArt(
                  imageUrl: info.coverUrl,
                  width: 72,
                  height: 72,
                  borderRadius: 10,
                  placeholderIcon: Icons.music_note_rounded,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      info.name,
                      style: AppTypography.titleMedium.copyWith(fontSize: 16, fontWeight: FontWeight.bold),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (info.description.isNotEmpty) ...[
                      const SizedBox(height: 3),
                      Text(
                        info.description,
                        style: AppTypography.bodySmall.copyWith(color: Colors.white60),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: _paletteVibrant.withValues(alpha: 0.18),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: _paletteVibrant.withValues(alpha: 0.4), width: 1),
                      ),
                      child: Text(
                        '${info.trackCount} Tracks Ready',
                        style: TextStyle(
                          color: _paletteVibrant,
                          fontWeight: FontWeight.bold,
                          fontSize: 11,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),

        // Track Preview List
        if (info.tracks.isNotEmpty) ...[
          Text(
            'TRACKS IN PLAYLIST',
            style: AppTypography.labelSmall.copyWith(color: Colors.white54, fontSize: 11),
          ),
          const SizedBox(height: 8),
          Container(
            constraints: const BoxConstraints(maxHeight: 150),
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.35),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
            ),
            child: ListView.separated(
              shrinkWrap: true,
              itemCount: info.tracks.length > 5 ? 5 : info.tracks.length,
              separatorBuilder: (_, __) => Divider(color: Colors.white.withValues(alpha: 0.06), height: 1),
              itemBuilder: (ctx, i) {
                final t = info.tracks[i];
                return Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  child: Row(
                    children: [
                      Text(
                        '${i + 1}.',
                        style: TextStyle(
                          color: _paletteVibrant.withValues(alpha: 0.8),
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          t.title,
                          style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        t.artist,
                        style: const TextStyle(color: Colors.white54, fontSize: 12),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
          if (info.tracks.length > 5) ...[
            const SizedBox(height: 6),
            Text(
              '+ ${info.tracks.length - 5} more songs',
              style: const TextStyle(color: Colors.white38, fontSize: 11),
              textAlign: TextAlign.center,
            ),
          ],
        ],

        const SizedBox(height: 18),

        // Action Buttons
        NeoButton(
          text: 'Import to Library',
          icon: Icons.playlist_add_check_rounded,
          backgroundColor: _paletteVibrant,
          textColor: Colors.black,
          onPressed: _startImport,
        ),
        const SizedBox(height: 10),
        TextButton(
          onPressed: () => setState(() => _step = _ImportStep.input),
          child: const Text('Choose a different link', style: TextStyle(color: Colors.white54)),
        ),
      ],
    );
  }

  Widget _buildDownloadingView() {
    final status = _importStatus;
    final progress = (status?.progress ?? 0.15).clamp(0.0, 1.0);
    final percentInt = (progress * 100).toInt();
    final info = _playlistInfo;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Album Cover Art
          Center(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: CachedCoverArt(
                imageUrl: info?.coverUrl,
                width: 88,
                height: 88,
                borderRadius: 12,
                placeholderIcon: Icons.queue_music_rounded,
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Playlist Name & Progress Count
          Text(
            info?.name ?? 'Syncing Playlist',
            textAlign: TextAlign.center,
            style: AppTypography.titleMedium.copyWith(fontSize: 16, fontWeight: FontWeight.bold),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 4),
          Text(
            status?.message ?? 'Importing tracks to library...',
            textAlign: TextAlign.center,
            style: AppTypography.bodySmall.copyWith(color: Colors.white70, fontSize: 13),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 16),

          // Progress Bar & Percentage
          Row(
            children: [
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: progress,
                    minHeight: 4,
                    backgroundColor: Colors.white12,
                    valueColor: AlwaysStoppedAnimation<Color>(_paletteVibrant),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Text(
                '$percentInt%',
                style: TextStyle(
                  color: _paletteVibrant,
                  fontWeight: FontWeight.w700,
                  fontSize: 12,
                ),
              ),
            ],
          ),
          if (status?.currentTrack != null) ...[
            const SizedBox(height: 8),
            Text(
              status!.currentTrack!,
              style: const TextStyle(color: Colors.white38, fontSize: 11),
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
          const SizedBox(height: 20),

          // Run in Background Button
          PressableScale(
            onTap: () => Navigator.pop(context),
            scaleFactor: 0.96,
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 12),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Center(
                child: Text(
                  'Continue in Background',
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSuccessView() {
    final playlistName = _createdPlaylist?.name ?? _playlistInfo?.name ?? 'Imported Playlist';
    final songCount = _playlistInfo?.trackCount ?? _createdPlaylist?.songCount ?? 0;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Center(
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: _paletteVibrant.withValues(alpha: 0.18),
                shape: BoxShape.circle,
                border: Border.all(color: _paletteVibrant, width: 2),
              ),
              child: Icon(
                Icons.check_circle_rounded,
                color: _paletteVibrant,
                size: 48,
              ),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'Playlist Imported!',
            textAlign: TextAlign.center,
            style: AppTypography.displayMedium.copyWith(fontSize: 22),
          ),
          const SizedBox(height: 8),
          Text(
            '"$playlistName" ($songCount songs)\nis now available on this app and on your account.',
            textAlign: TextAlign.center,
            style: AppTypography.bodyMedium.copyWith(color: Colors.white70, height: 1.4),
          ),
          const SizedBox(height: 24),
          NeoButton(
            text: 'Open Playlist',
            icon: Icons.play_arrow_rounded,
            backgroundColor: _paletteVibrant,
            textColor: Colors.black,
            onPressed: _openPlaylist,
          ),
          const SizedBox(height: 10),
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Done', style: TextStyle(color: Colors.white54)),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorView() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Center(
          child: Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppColors.error.withValues(alpha: 0.15),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.error_outline_rounded, color: AppColors.error, size: 40),
          ),
        ),
        const SizedBox(height: 14),
        Text(
          'Import Encountered an Issue',
          textAlign: TextAlign.center,
          style: AppTypography.titleLarge,
        ),
        const SizedBox(height: 8),
        Text(
          _errorMessage ?? 'Unable to complete sync to library vault.',
          textAlign: TextAlign.center,
          style: AppTypography.bodySmall.copyWith(color: Colors.white70),
        ),
        const SizedBox(height: 20),
        NeoButton(
          text: 'Try Again',
          icon: Icons.refresh_rounded,
          onPressed: () => setState(() => _step = _ImportStep.input),
        ),
      ],
    );
  }
}
