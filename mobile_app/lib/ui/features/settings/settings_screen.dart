import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../../../state/audio_player_provider.dart';
import '../../../state/auth_provider.dart';
import '../../../state/music_provider.dart';
import '../../core_widgets/pressable_scale.dart';
import '../player/mini_player_bar.dart';
import 'audio_equalizer_screen.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  int _storageBytes = 0;
  bool _isLoadingStorage = true;
  String? _pingResult;
  bool _isPinging = false;

  @override
  void initState() {
    super.initState();
    _loadStorageInfo();
  }

  Future<void> _loadStorageInfo() async {
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
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    if (bytes < 1024 * 1024 * 1024) {
      return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    }
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(2)} GB';
  }

  Future<void> _testPing() async {
    setState(() {
      _isPinging = true;
      _pingResult = null;
    });
    final stopwatch = Stopwatch()..start();
    try {
      final auth = context.read<AuthProvider>();
      final session = auth.session;
      if (session != null) {
        await context.read<MusicProvider>().loadLibrary();
        stopwatch.stop();
        if (mounted) {
          setState(() {
            _pingResult = '${stopwatch.elapsedMilliseconds} ms';
          });
        }
      }
    } catch (_) {
      if (mounted) {
        setState(() => _pingResult = 'Failed');
      }
    } finally {
      if (mounted) setState(() => _isPinging = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final music = context.watch<MusicProvider>();
    final player = context.watch<AudioPlayerProvider>();

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text('Settings', style: AppTypography.titleLarge),
        leading: const BackButton(),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      bottomNavigationBar: player.hasTrack
          ? const MiniPlayerBar(isStandalone: true)
          : null,
      body: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        physics: const BouncingScrollPhysics(),
        children: [
          // 1. Account & Server Profile
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.card,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.border),
            ),
            child: Row(
              children: [
                Container(
                  width: 52,
                  height: 52,
                  decoration: const BoxDecoration(
                    color: AppColors.primary,
                    shape: BoxShape.circle,
                  ),
                  child: Center(
                    child: Text(
                      auth.session?.username.isNotEmpty == true
                          ? auth.session!.username[0].toUpperCase()
                          : 'U',
                      style: AppTypography.titleLarge.copyWith(
                        color: Colors.black,
                        fontWeight: FontWeight.bold,
                        fontSize: 22,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(auth.session?.username ?? 'User', style: AppTypography.titleLarge.copyWith(fontSize: 18)),
                      const SizedBox(height: 2),
                      Text(
                        auth.session?.serverUrl ?? '',
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

          const SizedBox(height: 24),

          // 2. Audio & Equalizer Shortcut
          _buildSectionHeader('AUDIO EXPERIENCE'),
          Container(
            decoration: BoxDecoration(
              color: AppColors.card,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.border),
            ),
            child: ListTile(
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              leading: Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.equalizer_rounded, color: AppColors.primary, size: 20),
              ),
              title: Text('Audio & Equalizer', style: AppTypography.titleMedium.copyWith(fontSize: 15)),
              subtitle: Text('5-band EQ, bass boost, bitrate & playback', style: AppTypography.bodySmall.copyWith(color: AppColors.textMuted)),
              trailing: const Icon(Icons.chevron_right_rounded, color: AppColors.textMuted),
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const AudioEqualizerScreen()),
                );
              },
            ),
          ),

          const SizedBox(height: 24),

          // 3. Server Connection Health
          _buildSectionHeader('SERVER & NETWORK'),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.card,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.border),
            ),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('Server Latency', style: AppTypography.titleMedium.copyWith(fontSize: 14)),
                    if (_isPinging)
                      const SizedBox(
                        width: 14,
                        height: 14,
                        child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.primary),
                      )
                    else if (_pingResult != null)
                      Text(
                        _pingResult!,
                        style: AppTypography.labelLarge.copyWith(
                          color: _pingResult == 'Failed' ? AppColors.error : AppColors.primary,
                        ),
                      )
                    else
                      GestureDetector(
                        onTap: _testPing,
                        child: Text(
                          'Test Ping',
                          style: AppTypography.labelSmall.copyWith(color: AppColors.primary, fontWeight: FontWeight.bold),
                        ),
                      ),
                  ],
                ),
                const Divider(height: 20, color: AppColors.border),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('Subsonic API Version', style: AppTypography.titleMedium.copyWith(fontSize: 14)),
                    Text('1.16.1 (Navidrome)', style: AppTypography.bodySmall.copyWith(color: AppColors.textMuted)),
                  ],
                ),
              ],
            ),
          ),

          const SizedBox(height: 24),

          // 4. Offline Storage Management
          _buildSectionHeader('OFFLINE STORAGE'),
          Container(
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
                    Text('Downloaded Tracks', style: AppTypography.titleMedium.copyWith(fontSize: 14)),
                    Text('${music.offlineTracks.length} songs', style: AppTypography.labelLarge.copyWith(color: AppColors.primary)),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('Disk Space Used', style: AppTypography.titleMedium.copyWith(fontSize: 14)),
                    _isLoadingStorage
                        ? const SizedBox(
                            width: 14,
                            height: 14,
                            child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.primary),
                          )
                        : Text(_formatBytes(_storageBytes), style: AppTypography.bodySmall.copyWith(color: AppColors.textSecondary)),
                  ],
                ),
                if (music.offlineTracks.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  PressableScale(
                    onTap: () => _confirmClearDownloads(context, music),
                    scaleFactor: 0.96,
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      decoration: BoxDecoration(
                        color: const Color(0xFF281418),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: const Color(0xFF5C1B24)),
                      ),
                      child: Center(
                        child: Text(
                          'Clear All Offline Downloads',
                          style: AppTypography.labelLarge.copyWith(color: AppColors.error, fontWeight: FontWeight.bold),
                        ),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),

          const SizedBox(height: 24),

          // 5. Account & Log Out
          _buildSectionHeader('ACCOUNT'),
          PressableScale(
            onTap: () {
              HapticFeedback.heavyImpact();
              auth.logout();
              Navigator.pop(context);
            },
            scaleFactor: 0.96,
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 14),
              decoration: BoxDecoration(
                color: const Color(0xFF282828),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Center(
                child: Text(
                  'Log Out',
                  style: AppTypography.labelLarge.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                  ),
                ),
              ),
            ),
          ),

          const SizedBox(height: 36),
          Center(
            child: Text(
              'LocalSpotify Mobile v1.1.0\nHigh-Performance Native Client',
              textAlign: TextAlign.center,
              style: AppTypography.bodySmall.copyWith(color: AppColors.textMuted, fontSize: 11),
            ),
          ),
          const SizedBox(height: 40),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 8),
      child: Text(
        title,
        style: AppTypography.labelSmall.copyWith(
          color: AppColors.textMuted,
          letterSpacing: 1.2,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  void _confirmClearDownloads(BuildContext context, MusicProvider music) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.card,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text('Delete All Downloads?', style: AppTypography.titleLarge),
        content: Text(
          'This will remove all downloaded songs from local device storage.',
          style: AppTypography.bodyMedium.copyWith(color: AppColors.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel', style: TextStyle(color: AppColors.textSecondary)),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(ctx);
              await music.clearAllDownloads();
              await _loadStorageInfo();
            },
            child: const Text('Clear All', style: TextStyle(color: AppColors.error, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }
}
