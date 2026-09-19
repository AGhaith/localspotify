import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../../../state/audio_player_provider.dart';

class EqualizerSheet extends StatefulWidget {
  const EqualizerSheet({super.key});

  @override
  State<EqualizerSheet> createState() => _EqualizerSheetState();
}

class _EqualizerSheetState extends State<EqualizerSheet> {
  String _selectedPreset = 'Flat';
  final List<double> _bandGains = [0.0, 0.0, 0.0, 0.0, 0.0];
  final List<String> _bandLabels = ['60Hz', '230Hz', '910Hz', '3.6kHz', '14kHz'];

  static const Map<String, List<double>> _presets = {
    'Flat': [0.0, 0.0, 0.0, 0.0, 0.0],
    'Bass Boost': [6.0, 4.5, 1.0, 0.0, -1.0],
    'Rock': [4.5, 2.5, -1.0, 2.0, 4.0],
    'Pop': [-1.0, 2.0, 4.0, 2.5, -1.0],
    'Vocal Boost': [-2.0, 0.0, 5.0, 3.0, 1.0],
    'Acoustic': [3.0, 2.0, 1.0, 3.5, 4.5],
  };

  void _applyPreset(String name) {
    HapticFeedback.selectionClick();
    setState(() {
      _selectedPreset = name;
      final gains = _presets[name];
      if (gains != null) {
        for (int i = 0; i < 5; i++) {
          _bandGains[i] = gains[i];
        }
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final player = context.watch<AudioPlayerProvider>();

    return Container(
      decoration: const BoxDecoration(
        color: Color(0xFF10121A),
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      child: SafeArea(
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Drag Handle
              Center(
                child: Container(
                  width: 40,
                  height: 4.5,
                  decoration: BoxDecoration(
                    color: Colors.white24,
                    borderRadius: BorderRadius.circular(99),
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Title Bar
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.graphic_eq_rounded, color: AppColors.primary, size: 24),
                      const SizedBox(width: 8),
                      Text('Audio & Equalizer', style: AppTypography.titleLarge),
                    ],
                  ),
                  TextButton(
                    onPressed: () => _applyPreset('Flat'),
                    child: Text('Reset', style: AppTypography.labelMedium.copyWith(color: AppColors.textMuted)),
                  ),
                ],
              ),
              const Divider(color: AppColors.border, height: 20),

              // 1. Playback Speed Selector
              Text('PLAYBACK SPEED', style: AppTypography.labelSmall.copyWith(color: AppColors.textMuted, letterSpacing: 1.1)),
              const SizedBox(height: 10),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                physics: const BouncingScrollPhysics(),
                child: Row(
                  children: [0.8, 1.0, 1.25, 1.5, 2.0].map((speed) {
                    final isCurrent = (player.playbackSpeed - speed).abs() < 0.05;
                    return Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: ChoiceChip(
                        label: Text('${speed}x', style: TextStyle(fontWeight: isCurrent ? FontWeight.bold : FontWeight.normal)),
                        selected: isCurrent,
                        selectedColor: AppColors.primary,
                        backgroundColor: const Color(0xFF1B1D28),
                        labelStyle: TextStyle(color: isCurrent ? Colors.black : Colors.white),
                        onSelected: (_) {
                          HapticFeedback.selectionClick();
                          player.setPlaybackSpeed(speed);
                        },
                      ),
                    );
                  }).toList(),
                ),
              ),

              const SizedBox(height: 24),

              // 2. Equalizer Presets
              Text('PRESETS', style: AppTypography.labelSmall.copyWith(color: AppColors.textMuted, letterSpacing: 1.1)),
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: _presets.keys.map((preset) {
                  final isSelected = _selectedPreset == preset;
                  return ChoiceChip(
                    label: Text(preset),
                    selected: isSelected,
                    selectedColor: AppColors.primary,
                    backgroundColor: const Color(0xFF1B1D28),
                    labelStyle: TextStyle(
                      color: isSelected ? Colors.black : Colors.white70,
                      fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                    ),
                    onSelected: (_) => _applyPreset(preset),
                  );
                }).toList(),
              ),

              const SizedBox(height: 24),

              // 3. 5-Band Slider Visualizer
              Text('FREQUENCY BANDS (dB)', style: AppTypography.labelSmall.copyWith(color: AppColors.textMuted, letterSpacing: 1.1)),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFF151824),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppColors.border),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: List.generate(5, (i) {
                    return Column(
                      children: [
                        Text(
                          '${_bandGains[i] >= 0 ? '+' : ''}${_bandGains[i].toStringAsFixed(1)}',
                          style: AppTypography.labelSmall.copyWith(
                            color: _bandGains[i] != 0 ? AppColors.primary : AppColors.textMuted,
                            fontSize: 10,
                          ),
                        ),
                        const SizedBox(height: 6),
                        RotatedBox(
                          quarterTurns: 3,
                          child: SliderTheme(
                            data: SliderTheme.of(context).copyWith(
                              trackHeight: 3,
                              thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
                              overlayShape: const RoundSliderOverlayShape(overlayRadius: 12),
                              activeTrackColor: AppColors.primary,
                              inactiveTrackColor: Colors.white12,
                              thumbColor: Colors.white,
                            ),
                            child: Slider(
                              value: _bandGains[i],
                              min: -10.0,
                              max: 10.0,
                              onChanged: (val) {
                                setState(() {
                                  _bandGains[i] = val;
                                  _selectedPreset = 'Custom';
                                });
                              },
                            ),
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          _bandLabels[i],
                          style: AppTypography.labelSmall.copyWith(color: AppColors.textSecondary, fontSize: 10),
                        ),
                      ],
                    );
                  }),
                ),
              ),

              const SizedBox(height: 20),

              // 4. Crossfade Duration
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('CROSSFADE', style: AppTypography.labelSmall.copyWith(color: AppColors.textMuted, letterSpacing: 1.1)),
                  Text(
                    player.crossfadeDurationSeconds > 0 ? '${player.crossfadeDurationSeconds}s' : 'Off',
                    style: AppTypography.labelSmall.copyWith(color: AppColors.primary, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
              SliderTheme(
                data: SliderTheme.of(context).copyWith(
                  trackHeight: 3,
                  thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
                  activeTrackColor: AppColors.primary,
                  inactiveTrackColor: Colors.white12,
                  thumbColor: Colors.white,
                ),
                child: Slider(
                  value: player.crossfadeDurationSeconds.toDouble(),
                  min: 0,
                  max: 12,
                  divisions: 12,
                  onChanged: (val) {
                    player.setCrossfadeDuration(val.toInt());
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
