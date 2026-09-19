import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../../../state/audio_player_provider.dart';
import '../../../state/auth_provider.dart';
import '../../../state/music_provider.dart';
import '../../core_widgets/neo_button.dart';
import '../player/mini_player_bar.dart';

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
        // Run ping
        await context.read<MusicProvider>().loadLibrary();
        stopwatch.stop();
        if (mounted) {
          setState(() {
            _pingResult = 'Online (${stopwatch.elapsedMilliseconds} ms)';
          });
        }
      }
    } catch (_) {
      if (mounted) {
        setState(() => _pingResult = 'Connection Failed');
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
    final currentBitRate = music.getMaxBitRate();

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text('Settings & Storage', style: AppTypography.titleLarge),
        leading: const BackButton(),
      ),
      bottomNavigationBar: player.hasTrack
          ? const SafeArea(top: false, child: MiniPlayerBar())
          : null,
      body: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        physics: const BouncingScrollPhysics(),
        children: [
          // 1. Server & Account
          _buildSectionHeader('SERVER & ACCOUNT'),
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
                  children: [
                    Container(
                      width: 44,
                      height: 44,
                      decoration: const BoxDecoration(
                        color: AppColors.primary,
                        shape: BoxShape.circle,
                      ),
                      child: Center(
                        child: Text(
                          auth.session?.username.isNotEmpty == true
                              ? auth.session!.username[0].toUpperCase()
                              : 'U',
                          style: AppTypography.titleLarge.copyWith(color: AppColors.textDark),
                        ),
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(auth.session?.username ?? 'Guest', style: AppTypography.titleMedium),
                          const SizedBox(height: 2),
                          Text(
                            auth.session?.serverUrl ?? '',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: AppTypography.bodySmall,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const Divider(height: 24),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('Server Latency', style: AppTypography.bodyMedium),
                    if (_isPinging)
                      const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.primary),
                      )
                    else if (_pingResult != null)
                      Text(
                        _pingResult!,
                        style: AppTypography.bodySmall.copyWith(
                          color: _pingResult!.startsWith('Online') ? AppColors.primary : AppColors.error,
                          fontWeight: FontWeight.bold,
                        ),
                      )
                    else
                      GestureDetector(
                        onTap: _testPing,
                        child: Text(
                          'Test Connection',
                          style: AppTypography.labelSmall.copyWith(color: AppColors.primary),
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),

          const SizedBox(height: 24),

          // 2. Audio Streaming Quality
          _buildSectionHeader('STREAMING AUDIO QUALITY'),
          Container(
            decoration: BoxDecoration(
              color: AppColors.card,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.border),
            ),
            child: Column(
              children: [
                _buildQualityTile('Original / Lossless', 'Direct file streaming', null, currentBitRate, music),
                const Divider(height: 1),
                _buildQualityTile('High (320 kbps)', 'Best MP3 compression quality', 320, currentBitRate, music),
                const Divider(height: 1),
                _buildQualityTile('Standard (192 kbps)', 'Balanced speed and clarity', 192, currentBitRate, music),
                const Divider(height: 1),
                _buildQualityTile('Data Saver (128 kbps)', 'Low mobile data usage', 128, currentBitRate, music),
              ],
            ),
          ),

          const SizedBox(height: 24),

          // 3. Offline Cache & Storage Management
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
                    Text('Downloaded Tracks', style: AppTypography.bodyMedium),
                    Text('${music.offlineTracks.length} songs', style: AppTypography.titleMedium),
                  ],
                ),
                const SizedBox(height: 10),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('Disk Space Used', style: AppTypography.bodyMedium),
                    _isLoadingStorage
                        ? const SizedBox(
                            width: 14,
                            height: 14,
                            child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.primary),
                          )
                        : Text(_formatBytes(_storageBytes), style: AppTypography.titleMedium),
                  ],
                ),
                const SizedBox(height: 16),
                if (music.offlineTracks.isNotEmpty)
                  NeoButton(
                    text: 'Clear All Offline Downloads',
                    icon: Icons.delete_sweep_rounded,
                    backgroundColor: const Color(0xFF2E1218),
                    textColor: AppColors.error,
                    borderColor: AppColors.error,
                    onPressed: () => _confirmClearDownloads(context, music),
                  ),
              ],
            ),
          ),

          const SizedBox(height: 24),

          // 4. Session & Logout
          _buildSectionHeader('SESSION'),
          NeoButton(
            text: 'Log Out of Server',
            icon: Icons.logout_rounded,
            backgroundColor: const Color(0xFF1E2028),
            textColor: AppColors.textPrimary,
            borderColor: AppColors.border,
            onPressed: () {
              HapticFeedback.heavyImpact();
              auth.logout();
              Navigator.pop(context);
            },
          ),

          const SizedBox(height: 40),
          Center(
            child: Text(
              'LocalSpotify Mobile v1.0.0\nHigh-Fidelity Audio Streaming',
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
        ),
      ),
    );
  }

  Widget _buildQualityTile(
    String title,
    String subtitle,
    int? bitrate,
    int? currentBitrate,
    MusicProvider music,
  ) {
    final isSelected = bitrate == currentBitrate;

    return ListTile(
      title: Text(title, style: AppTypography.titleMedium.copyWith(fontSize: 15)),
      subtitle: Text(subtitle, style: AppTypography.bodySmall),
      trailing: Icon(
        isSelected ? Icons.radio_button_checked_rounded : Icons.radio_button_unchecked_rounded,
        color: isSelected ? AppColors.primary : AppColors.textMuted,
      ),
      onTap: () {
        HapticFeedback.selectionClick();
        music.saveMaxBitRate(bitrate);
      },
    );
  }

  void _confirmClearDownloads(BuildContext context, MusicProvider music) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.card,
        title: const Text('Delete All Downloads?'),
        content: const Text('This will permanently delete all downloaded offline audio files from your device.'),
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
            child: const Text('Clear All', style: TextStyle(color: AppColors.error)),
          ),
        ],
      ),
    );
  }
}
