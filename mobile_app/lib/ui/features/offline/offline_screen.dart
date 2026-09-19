import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../../../state/audio_player_provider.dart';
import '../../../state/music_provider.dart';
import '../../core_widgets/neo_button.dart';
import '../../core_widgets/track_row.dart';

class OfflineScreen extends StatefulWidget {
  const OfflineScreen({super.key});

  @override
  State<OfflineScreen> createState() => _OfflineScreenState();
}

class _OfflineScreenState extends State<OfflineScreen> {
  int _storageBytes = 0;
  bool _isLoadingStorage = false;

  @override
  void initState() {
    super.initState();
    _loadStorageSize();
  }

  Future<void> _loadStorageSize() async {
    setState(() => _isLoadingStorage = true);
    final bytes = await context.read<MusicProvider>().getOfflineStorageBytes();
    if (mounted) {
      setState(() {
        _storageBytes = bytes;
        _isLoadingStorage = false;
      });
    }
  }

  String _formatBytes(int bytes) {
    if (bytes <= 0) return '0 MB';
    final mb = bytes / (1024 * 1024);
    if (mb >= 1000) {
      return '${(mb / 1024).toStringAsFixed(2)} GB';
    }
    return '${mb.toStringAsFixed(1)} MB';
  }

  @override
  Widget build(BuildContext context) {
    final music = context.watch<MusicProvider>();
    final player = context.read<AudioPlayerProvider>();
    final offlineTracks = music.offlineTracks;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text('Downloaded Music', style: AppTypography.titleLarge),
        leading: const BackButton(),
        actions: [
          if (offlineTracks.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.delete_sweep_rounded, color: AppColors.error),
              tooltip: 'Clear All Downloads',
              onPressed: () => _confirmClearDownloads(context, music),
            ),
        ],
      ),
      body: offlineTracks.isEmpty
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(
                      Icons.arrow_circle_down_rounded,
                      color: AppColors.textMuted,
                      size: 56,
                    ),
                    const SizedBox(height: 16),
                    Text('No downloaded songs', style: AppTypography.titleLarge),
                    const SizedBox(height: 6),
                    Text(
                      'Tap the three dots on any track or use "Download All" on albums & playlists for offline listening.',
                      textAlign: TextAlign.center,
                      style: AppTypography.bodySmall,
                    ),
                  ],
                ),
              ),
            )
          : CustomScrollView(
              physics: const BouncingScrollPhysics(),
              slivers: [
                // Storage and Playback Header Card
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: AppColors.card,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: AppColors.border),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    '${offlineTracks.length} tracks offline',
                                    style: AppTypography.titleMedium,
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    _isLoadingStorage
                                        ? 'Calculating storage...'
                                        : 'Disk space: ${_formatBytes(_storageBytes)}',
                                    style: AppTypography.bodySmall.copyWith(
                                      color: AppColors.primary,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ),
                              const Icon(
                                Icons.offline_pin_rounded,
                                color: AppColors.primary,
                                size: 32,
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          Wrap(
                            spacing: 10,
                            runSpacing: 10,
                            children: [
                              NeoButton(
                                text: 'Play All',
                                icon: Icons.play_arrow_rounded,
                                onPressed: () {
                                  HapticFeedback.heavyImpact();
                                  player.playTracks(tracks: offlineTracks, initialIndex: 0);
                                },
                              ),
                              NeoButton(
                                text: 'Shuffle',
                                icon: Icons.shuffle_rounded,
                                backgroundColor: const Color(0xFF222430),
                                textColor: AppColors.textPrimary,
                                borderColor: AppColors.border,
                                onPressed: () {
                                  HapticFeedback.heavyImpact();
                                  final shuffled = List.of(offlineTracks)..shuffle();
                                  player.playTracks(tracks: shuffled, initialIndex: 0);
                                },
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ),

                // Downloaded Tracks List
                SliverPadding(
                  padding: const EdgeInsets.only(bottom: 100),
                  sliver: SliverList(
                    delegate: SliverChildBuilderDelegate(
                      (ctx, i) {
                        final track = offlineTracks[i];
                        return TrackRow(
                          track: track,
                          index: i + 1,
                          showCover: true,
                          onTap: () {
                            player.playTracks(tracks: offlineTracks, initialIndex: i);
                          },
                        );
                      },
                      childCount: offlineTracks.length,
                    ),
                  ),
                ),
              ],
            ),
    );
  }

  void _confirmClearDownloads(BuildContext context, MusicProvider music) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.card,
        title: const Text('Clear All Downloads?'),
        content: const Text('This will delete all locally cached audio files and offline cover art.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel', style: TextStyle(color: AppColors.textSecondary)),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(ctx);
              await music.clearAllDownloads();
              await _loadStorageSize();
            },
            child: const Text('Delete All', style: TextStyle(color: AppColors.error)),
          ),
        ],
      ),
    );
  }
}
