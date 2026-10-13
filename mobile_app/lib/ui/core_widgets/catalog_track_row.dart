import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_typography.dart';
import '../../data/services/spotify_service.dart';
import '../../state/audio_player_provider.dart';
import '../../state/music_provider.dart';
import 'cached_cover_art.dart';
import 'track_row.dart';

class CatalogTrackRow extends StatelessWidget {
  final SpotifyTrackItem item;
  final int? index;
  final bool showCover;
  final EdgeInsetsGeometry? contentPadding;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;

  const CatalogTrackRow({
    super.key,
    required this.item,
    this.index,
    this.showCover = true,
    this.contentPadding,
    this.onTap,
    this.onLongPress,
  });

  @override
  Widget build(BuildContext context) {
    final music = context.watch<MusicProvider>();
    final player = context.watch<AudioPlayerProvider>();

    final syncState = music.getSpotifySyncState(item.id);
    final syncProgress = music.getSpotifySyncProgress(item.id);
    final isCurrent = isSpotifyItemCurrent(item, player);
    final isPlaying = isCurrent && player.isPlaying;
    final isSyncing = syncState == SpotifySyncState.syncing;
    final isError = syncState == SpotifySyncState.error;

    Widget? coverOverlay;
    Widget? indexOverlay;

    if (isSyncing) {
      coverOverlay = Container(
        width: 48,
        height: 48,
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.55),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Center(
          child: SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(
              value: syncProgress > 0 ? syncProgress : null,
              strokeWidth: 2.5,
              valueColor: const AlwaysStoppedAnimation<Color>(AppColors.primary),
              backgroundColor: syncProgress > 0 ? AppColors.primary.withValues(alpha: 0.2) : null,
            ),
          ),
        ),
      );
      indexOverlay = Center(
        child: SizedBox(
          width: 16,
          height: 16,
          child: CircularProgressIndicator(
            value: syncProgress > 0 ? syncProgress : null,
            strokeWidth: 2,
            valueColor: const AlwaysStoppedAnimation<Color>(AppColors.primary),
            backgroundColor: syncProgress > 0 ? AppColors.primary.withValues(alpha: 0.2) : null,
          ),
        ),
      );
    } else if (isError) {
      coverOverlay = Container(
        width: 48,
        height: 48,
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.55),
          borderRadius: BorderRadius.circular(8),
        ),
        child: const Icon(
          Icons.refresh_rounded,
          color: AppColors.error,
          size: 22,
        ),
      );
      indexOverlay = const Icon(
        Icons.refresh_rounded,
        color: AppColors.error,
        size: 18,
      );
    } else if (isPlaying) {
      coverOverlay = Container(
        width: 48,
        height: 48,
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.55),
          borderRadius: BorderRadius.circular(8),
        ),
        child: const Icon(
          Icons.graphic_eq_rounded,
          color: AppColors.primary,
          size: 22,
        ),
      );
    }

    final rowPadding = contentPadding ?? const EdgeInsets.symmetric(horizontal: 16, vertical: 8);

    return SwipeToQueue(
      id: item.id,
      gestureKey: Key('catalog_row_${item.id}_${index ?? 0}'),
      onSwipe: () async {
        if (isSyncing) return;
        final messenger = ScaffoldMessenger.of(context);
        final ap = context.read<AudioPlayerProvider>();
        final mp = context.read<MusicProvider>();
        final track = await mp.convertAndSyncSpotifyTrack(item);
        if (track != null) {
          ap.addToQueue(track);
          messenger.hideCurrentSnackBar();
          messenger.showSnackBar(
            const SnackBar(
              content: Text('Added to queue'),
              duration: Duration(seconds: 1),
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      },
      child: TrackRowLayout(
        isCurrent: isCurrent,
        isPlaying: isPlaying,
        index: index,
        showCover: showCover,
        padding: rowPadding,
        cover: CachedCoverArt(
          imageUrl: item.coverUrl,
          width: 48,
          height: 48,
          borderRadius: 8,
        ),
        coverOverlay: coverOverlay,
        indexOverlay: indexOverlay,
        title: item.title,
        subtitle: Text(
          (item.album != null && item.album!.isNotEmpty)
              ? '${item.artist} • ${item.album}'
              : item.artist,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: AppTypography.bodySmall.copyWith(color: AppColors.textMuted),
        ),
        durationText: item.durationFormatted,
        onTap: onTap ??
            () async {
              if (isSyncing) return;
              HapticFeedback.mediumImpact();
              final ap = context.read<AudioPlayerProvider>();
              final mp = context.read<MusicProvider>();
              final track = await mp.convertAndSyncSpotifyTrack(item);
              if (track != null) {
                await ap.playTrack(track);
              }
            },
        onLongPress: onLongPress ??
            () {
              HapticFeedback.selectionClick();
              if (item.individualArtists.length > 1) {
                showSpotifyArtistsSheet(context, item, music);
              } else {
                music.openArtistByName(context, item.primaryArtist);
              }
            },
        onMoreTap: () => showCatalogTrackOptions(context, item, music, player),
      ),
    );
  }
}

void showCatalogTrackOptions(
  BuildContext context,
  SpotifyTrackItem item,
  MusicProvider music,
  AudioPlayerProvider player,
) {
  final syncState = music.getSpotifySyncState(item.id);

  showModalBottomSheet(
    context: context,
    backgroundColor: AppColors.card,
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    builder: (ctx) {
      return SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(vertical: 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Row(
                  children: [
                    CachedCoverArt(
                      imageUrl: item.coverUrl,
                      width: 54,
                      height: 54,
                      borderRadius: 10,
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            item.title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: AppTypography.titleMedium.copyWith(fontSize: 16),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            (item.album != null && item.album!.isNotEmpty)
                                ? '${item.artist} • ${item.album}'
                                : item.artist,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: AppTypography.bodySmall.copyWith(color: AppColors.textMuted),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              const Divider(color: AppColors.border),
              ListTile(
                leading: const Icon(Icons.playlist_play_rounded, color: Colors.white70, size: 22),
                title: Text(
                  'Play Next',
                  style: AppTypography.bodyLarge.copyWith(color: Colors.white, fontSize: 15),
                ),
                onTap: () async {
                  Navigator.pop(ctx);
                  if (syncState == SpotifySyncState.syncing) return;
                  final track = await music.convertAndSyncSpotifyTrack(item);
                  if (track != null && context.mounted) {
                    player.playNext(track);
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Playing next'), duration: Duration(seconds: 1)),
                    );
                  }
                },
              ),
              ListTile(
                leading: const Icon(Icons.queue_music_rounded, color: Colors.white70, size: 22),
                title: Text(
                  'Add to Queue',
                  style: AppTypography.bodyLarge.copyWith(color: Colors.white, fontSize: 15),
                ),
                onTap: () async {
                  Navigator.pop(ctx);
                  if (syncState == SpotifySyncState.syncing) return;
                  final track = await music.convertAndSyncSpotifyTrack(item);
                  if (track != null && context.mounted) {
                    player.addToQueue(track);
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Added to queue'), duration: Duration(seconds: 1)),
                    );
                  }
                },
              ),
              if (item.individualArtists.length > 1) ...[
                for (final artistName in item.individualArtists)
                  ListTile(
                    leading: const Icon(Icons.person_rounded, color: Colors.white70, size: 22),
                    title: Text(
                      'View $artistName',
                      style: AppTypography.bodyLarge.copyWith(color: Colors.white, fontSize: 15),
                    ),
                    onTap: () {
                      Navigator.pop(ctx);
                      music.openArtistByName(context, artistName);
                    },
                  ),
              ] else ...[
                ListTile(
                  leading: const Icon(Icons.person_rounded, color: Colors.white70, size: 22),
                  title: Text(
                    'View ${item.primaryArtist}',
                    style: AppTypography.bodyLarge.copyWith(color: Colors.white, fontSize: 15),
                  ),
                  onTap: () {
                    Navigator.pop(ctx);
                    music.openArtistByName(context, item.primaryArtist);
                  },
                ),
              ],
            ],
          ),
        ),
      );
    },
  );
}

bool isSpotifyItemCurrent(SpotifyTrackItem item, AudioPlayerProvider player) {
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

bool isSpotifyItemPlaying(SpotifyTrackItem item, AudioPlayerProvider player) {
  return player.isPlaying && isSpotifyItemCurrent(item, player);
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
