import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_typography.dart';
import '../../data/services/spotify_service.dart';
import '../../state/audio_player_provider.dart';
import '../../state/music_provider.dart';

class CatalogTrackRow extends StatelessWidget {
  final SpotifyTrackItem item;
  final int? index;
  final bool showCover;
  final EdgeInsetsGeometry contentPadding;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;

  const CatalogTrackRow({
    super.key,
    required this.item,
    this.index,
    this.showCover = true,
    this.contentPadding = const EdgeInsets.symmetric(vertical: 2),
    this.onTap,
    this.onLongPress,
  });

  @override
  Widget build(BuildContext context) {
    final music = context.watch<MusicProvider>();
    final player = context.watch<AudioPlayerProvider>();

    final syncState = music.getSpotifySyncState(item.id);
    final syncProgress = music.getSpotifySyncProgress(item.id);
    final isPlaying = isSpotifyItemPlaying(item, player);

    Widget? leadingWidget;
    if (showCover) {
      leadingWidget = ClipRRect(
        borderRadius: BorderRadius.circular(6),
        child: item.coverUrl != null && item.coverUrl!.isNotEmpty
            ? Image.network(
                item.coverUrl!,
                width: 48,
                height: 48,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => Container(
                  width: 48,
                  height: 48,
                  color: AppColors.card,
                  child: const Icon(Icons.music_note_rounded, color: AppColors.primary),
                ),
              )
            : Container(
                width: 48,
                height: 48,
                color: AppColors.card,
                child: const Icon(Icons.music_note_rounded, color: AppColors.primary),
              ),
      );
    } else if (index != null) {
      leadingWidget = SizedBox(
        width: 28,
        child: Center(
          child: Text(
            '$index',
            style: AppTypography.bodyMedium.copyWith(
              color: AppColors.textMuted,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      );
    }

    return ListTile(
      contentPadding: contentPadding,
      leading: leadingWidget,
      title: Text(
        item.title,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: AppTypography.titleMedium.copyWith(fontSize: 15),
      ),
      subtitle: Text(
        '${item.artist} • ${item.durationFormatted}',
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: AppTypography.bodySmall.copyWith(color: AppColors.textMuted),
      ),
      trailing: _buildTrailing(syncState, syncProgress, isPlaying),
      onLongPress: onLongPress ??
          () {
            HapticFeedback.selectionClick();
            if (item.individualArtists.length > 1) {
              showSpotifyArtistsSheet(context, item, music);
            } else {
              music.openArtistByName(context, item.primaryArtist);
            }
          },
      onTap: onTap ??
          () async {
            if (syncState == SpotifySyncState.syncing) return;
            HapticFeedback.mediumImpact();
            final track = await music.convertAndSyncSpotifyTrack(item);
            if (track != null && context.mounted) {
              await player.playTrack(track);
            }
          },
    );
  }

  Widget _buildTrailing(
    SpotifySyncState syncState,
    double progress,
    bool isPlaying,
  ) {
    if (syncState == SpotifySyncState.syncing) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: AppColors.primary.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: AppColors.primary.withValues(alpha: 0.4)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: 14,
              height: 14,
              child: CircularProgressIndicator(
                value: progress > 0 ? progress : null,
                strokeWidth: 2,
                valueColor: const AlwaysStoppedAnimation<Color>(AppColors.primary),
                backgroundColor: progress > 0 ? AppColors.primary.withValues(alpha: 0.2) : null,
              ),
            ),
            const SizedBox(width: 6),
            Text(
              progress > 0 ? '${(progress * 100).toInt()}%' : 'Syncing...',
              style: AppTypography.labelSmall.copyWith(
                color: AppColors.primary,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      );
    }

    if (syncState == SpotifySyncState.error) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: AppColors.error.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: AppColors.error.withValues(alpha: 0.5)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.refresh_rounded, color: AppColors.error, size: 16),
            const SizedBox(width: 4),
            Text(
              'Retry',
              style: AppTypography.labelSmall.copyWith(
                color: AppColors.error,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      );
    }

    if (isPlaying) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: AppColors.primary,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.equalizer_rounded, color: Colors.black, size: 16),
            const SizedBox(width: 4),
            Text(
              'Playing',
              style: AppTypography.labelSmall.copyWith(
                color: Colors.black,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: AppColors.primary.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.primary.withValues(alpha: 0.4)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.play_arrow_rounded, color: AppColors.primary, size: 16),
          const SizedBox(width: 4),
          Text(
            'Play & Sync',
            style: AppTypography.labelSmall.copyWith(
              color: AppColors.primary,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
}

bool isSpotifyItemPlaying(SpotifyTrackItem item, AudioPlayerProvider player) {
  if (!player.isPlaying) return false;
  final current = player.currentTrack;
  if (current == null) return false;

  final pseudoId = 'spotify_${item.title.hashCode.abs()}_${item.artist.hashCode.abs()}';
  if (current.id == pseudoId) return true;

  String clean(String s) => s.trim().toLowerCase().replaceAll(RegExp(r'[^\w\s]'), '');
  final currentTitle = clean(current.title);
  final itemTitle = clean(item.title);
  if (currentTitle.isEmpty || currentTitle != itemTitle) return false;

  final currentArtist = clean(current.artist);
  final itemArtist = clean(item.artist);
  final itemPrimaryArtist = clean(item.primaryArtist);

  if (currentArtist == itemArtist || currentArtist == itemPrimaryArtist) return true;
  if (itemPrimaryArtist.isNotEmpty &&
      (currentArtist.contains(itemPrimaryArtist) || itemPrimaryArtist.contains(currentArtist))) {
    return true;
  }
  if (itemArtist.isNotEmpty &&
      (currentArtist.contains(itemArtist) || itemArtist.contains(currentArtist))) {
    return true;
  }

  return false;
}

void showSpotifyArtistsSheet(BuildContext context, SpotifyTrackItem item, MusicProvider music) {
  showModalBottomSheet(
    context: context,
    backgroundColor: AppColors.card,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    builder: (ctx) {
      return SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                child: Row(
                  children: [
                    const Icon(Icons.people_alt_rounded, color: AppColors.primary, size: 22),
                    const SizedBox(width: 10),
                    Text(
                      'Artists',
                      style: AppTypography.titleLarge.copyWith(fontWeight: FontWeight.bold),
                    ),
                    const Spacer(),
                    Text(
                      '${item.individualArtists.length} found',
                      style: AppTypography.bodySmall.copyWith(color: AppColors.textMuted),
                    ),
                  ],
                ),
              ),
              const Divider(color: AppColors.border),
              Flexible(
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: item.individualArtists.length,
                  itemBuilder: (context, index) {
                    final artistName = item.individualArtists[index];
                    return ListTile(
                      leading: CircleAvatar(
                        backgroundColor: AppColors.card,
                        child: Text(
                          artistName.isNotEmpty ? artistName[0].toUpperCase() : '?',
                          style: AppTypography.titleMedium.copyWith(color: AppColors.primary),
                        ),
                      ),
                      title: Text(
                        artistName,
                        style: AppTypography.bodyLarge.copyWith(fontWeight: FontWeight.w600),
                      ),
                      subtitle: Text(
                        'View artist profile & tracks',
                        style: AppTypography.bodySmall.copyWith(color: AppColors.textMuted),
                      ),
                      trailing: const Icon(Icons.chevron_right_rounded, color: AppColors.textMuted),
                      onTap: () {
                        Navigator.pop(ctx);
                        music.openArtistByName(context, artistName);
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      );
    },
  );
}
