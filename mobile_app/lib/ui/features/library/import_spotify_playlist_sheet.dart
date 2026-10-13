import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_radius.dart';
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
    return Container(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 14,
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        border: const Border(
          top: BorderSide(
            color: AppColors.border,
            width: 1.5,
          ),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.5),
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
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: AppColors.border),
                ),
                child: const Icon(
                  Icons.playlist_add_check_rounded,
                  color: AppColors.textPrimary,
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
                      'Sync tracks into your Library',
                      style: AppTypography.bodySmall.copyWith(color: AppColors.textSecondary),
                    ),
                  ],
                ),
              ),
              IconButton(
                style: IconButton.styleFrom(backgroundColor: AppColors.surface),
                icon: const Icon(Icons.close_rounded, color: AppColors.textSecondary, size: 20),
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
          'Paste any Spotify playlist link below to sync audio tracks, high-res artwork, and synced lyrics into your Library, and make the playlist available on your account.',
          style: AppTypography.bodySmall.copyWith(color: AppColors.textSecondary, height: 1.4),
        ),
        const SizedBox(height: 18),

        // Link Input Field
        TextField(
          controller: _urlController,
          style: AppTypography.bodyLarge,
          keyboardType: TextInputType.url,
          decoration: InputDecoration(
            hintText: 'https://open.spotify.com/playlist/...',
            prefixIcon: const Icon(Icons.link_rounded, color: AppColors.textSecondary),
            suffixIcon: IconButton(
              icon: const Icon(Icons.content_paste_rounded, color: AppColors.textPrimary),
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
                    style: AppTypography.bodySmall.copyWith(color: AppColors.error, fontSize: 13),
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
        // Playlist Info Card
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: AppColors.card,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: AppColors.border,
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
                  borderRadius: BorderRadius.circular(AppRadius.card),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.3),
                      blurRadius: 10,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
                child: CachedCoverArt(
                  imageUrl: info.coverUrl,
                  width: 72,
                  height: 72,
                  borderRadius: AppRadius.card,
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
                        style: AppTypography.bodySmall.copyWith(color: AppColors.textSecondary),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: AppColors.surface,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: AppColors.border, width: 1),
                      ),
                      child: Text(
                        '${info.trackCount} Tracks Ready',
                        style: AppTypography.labelSmall.copyWith(
                          color: AppColors.textPrimary,
                          fontWeight: FontWeight.bold,
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
            style: AppTypography.labelSmall.copyWith(color: AppColors.textMuted, fontSize: 11),
          ),
          const SizedBox(height: 8),
          Container(
            constraints: const BoxConstraints(maxHeight: 150),
            decoration: BoxDecoration(
              color: AppColors.card,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.border),
            ),
            child: ListView.separated(
              shrinkWrap: true,
              itemCount: info.tracks.length > 5 ? 5 : info.tracks.length,
              separatorBuilder: (_, __) => const Divider(color: AppColors.border, height: 1),
              itemBuilder: (ctx, i) {
                final t = info.tracks[i];
                return Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  child: Row(
                    children: [
                      Text(
                        '${i + 1}.',
                        style: AppTypography.labelSmall.copyWith(
                          color: AppColors.textSecondary,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          t.title,
                          style: AppTypography.bodyMedium.copyWith(
                            color: AppColors.textPrimary,
                            fontWeight: FontWeight.w600,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        t.artist,
                        style: AppTypography.bodySmall.copyWith(
                          color: AppColors.textSecondary,
                        ),
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
              style: AppTypography.bodySmall.copyWith(color: AppColors.textMuted, fontSize: 11),
              textAlign: TextAlign.center,
            ),
          ],
        ],

        const SizedBox(height: 18),

        // Action Buttons
        NeoButton(
          text: 'Import to Library',
          icon: Icons.playlist_add_check_rounded,
          onPressed: _startImport,
        ),
        const SizedBox(height: 10),
        TextButton(
          onPressed: () => setState(() => _step = _ImportStep.input),
          child: Text('Choose a different link', style: AppTypography.bodySmall.copyWith(color: AppColors.textSecondary)),
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
              borderRadius: BorderRadius.circular(AppRadius.header),
              child: CachedCoverArt(
                imageUrl: info?.coverUrl,
                width: 88,
                height: 88,
                borderRadius: AppRadius.header,
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
            style: AppTypography.bodySmall.copyWith(color: AppColors.textSecondary, fontSize: 13),
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
                    backgroundColor: AppColors.surface,
                    valueColor: const AlwaysStoppedAnimation<Color>(AppColors.primary),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Text(
                '$percentInt%',
                style: AppTypography.labelSmall.copyWith(
                  color: AppColors.textPrimary,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          if (status?.currentTrack != null) ...[
            const SizedBox(height: 8),
            Text(
              status!.currentTrack!,
              style: AppTypography.bodySmall.copyWith(color: AppColors.textMuted, fontSize: 11),
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
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: AppColors.border),
              ),
              child: Center(
                child: Text(
                  'Continue in Background',
                  style: AppTypography.labelMedium.copyWith(
                    color: AppColors.textPrimary,
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
                color: AppColors.surface,
                shape: BoxShape.circle,
                border: Border.all(color: AppColors.border, width: 2),
              ),
              child: const Icon(
                Icons.check_circle_rounded,
                color: AppColors.primary,
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
            '"$playlistName" ($songCount ${songCount == 1 ? "song" : "songs"})\nis now available on this app and on your account.',
            textAlign: TextAlign.center,
            style: AppTypography.bodyMedium.copyWith(color: AppColors.textSecondary, height: 1.4),
          ),
          const SizedBox(height: 24),
          NeoButton(
            text: 'Open Playlist',
            icon: Icons.play_arrow_rounded,
            onPressed: _openPlaylist,
          ),
          const SizedBox(height: 10),
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Done', style: AppTypography.bodySmall.copyWith(color: AppColors.textSecondary)),
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
          _errorMessage ?? 'Unable to complete sync to Library.',
          textAlign: TextAlign.center,
          style: AppTypography.bodySmall.copyWith(color: AppColors.textSecondary),
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
