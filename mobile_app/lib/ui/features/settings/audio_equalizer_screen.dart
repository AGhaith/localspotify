import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../../../state/audio_player_provider.dart';
import '../../../state/music_provider.dart';
import '../player/mini_player_bar.dart';

class AudioEqualizerScreen extends StatefulWidget {
  const AudioEqualizerScreen({super.key});

  @override
  State<AudioEqualizerScreen> createState() => _AudioEqualizerScreenState();
}

class _AudioEqualizerScreenState extends State<AudioEqualizerScreen> {
  bool _eqEnabled = true;
  String _selectedPreset = 'Flat';
  
  // 5 Equalizer bands in dB (-10 to +10)
  List<double> _bands = [0.0, 0.0, 0.0, 0.0, 0.0];
  final List<String> _bandFrequencies = ['60 Hz', '230 Hz', '910 Hz', '3.6 kHz', '14 kHz'];
  
  double _bassBoost = 0.0;
  double _virtualizer = 0.0;
  
  bool _gaplessPlayback = true;
  bool _volumeNormalization = true;
  double _crossfadeSeconds = 0.0; // 0 = Off, 1 - 12s

  final Map<String, List<double>> _presets = {
    'Flat': [0.0, 0.0, 0.0, 0.0, 0.0],
    'Bass Boost': [6.0, 4.0, 1.0, 0.0, -1.0],
    'Rock': [4.0, 2.0, -1.0, 2.0, 4.0],
    'Pop': [-1.0, 2.0, 4.0, 2.0, -1.0],
    'Vocal Boost': [-2.0, 0.0, 3.0, 4.0, 2.0],
    'Acoustic': [3.0, 2.0, 0.0, 2.0, 3.0],
    'Electronic': [4.0, 3.0, 0.0, 1.0, 4.0],
    'Classical': [4.0, 2.0, -1.0, 2.0, 3.0],
  };

  @override
  void initState() {
    super.initState();
    _loadPreferences();
  }

  Future<void> _loadPreferences() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _eqEnabled = prefs.getBool('eq_enabled') ?? true;
      _selectedPreset = prefs.getString('eq_preset') ?? 'Flat';
      
      final savedBands = prefs.getStringList('eq_bands');
      if (savedBands != null && savedBands.length == 5) {
        _bands = savedBands.map((e) => double.tryParse(e) ?? 0.0).toList();
      } else if (_presets.containsKey(_selectedPreset)) {
        _bands = List.from(_presets[_selectedPreset]!);
      }

      _bassBoost = prefs.getDouble('bass_boost') ?? 0.0;
      _virtualizer = prefs.getDouble('virtualizer') ?? 0.0;
      _gaplessPlayback = prefs.getBool('gapless_playback') ?? true;
      _volumeNormalization = prefs.getBool('volume_normalization') ?? true;
      _crossfadeSeconds = prefs.getDouble('crossfade_seconds') ?? 0.0;
    });
  }

  Future<void> _savePreferences() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('eq_enabled', _eqEnabled);
    await prefs.setString('eq_preset', _selectedPreset);
    await prefs.setStringList('eq_bands', _bands.map((e) => e.toString()).toList());
    await prefs.setDouble('bass_boost', _bassBoost);
    await prefs.setDouble('virtualizer', _virtualizer);
    await prefs.setBool('gapless_playback', _gaplessPlayback);
    await prefs.setBool('volume_normalization', _volumeNormalization);
    await prefs.setDouble('crossfade_seconds', _crossfadeSeconds);
  }

  void _applyPreset(String presetName) {
    HapticFeedback.selectionClick();
    setState(() {
      _selectedPreset = presetName;
      if (_presets.containsKey(presetName)) {
        _bands = List.from(_presets[presetName]!);
      }
    });
    _savePreferences();
  }

  void _onBandChanged(int index, double value) {
    setState(() {
      _bands[index] = value;
      _selectedPreset = 'Custom';
    });
    _savePreferences();
  }

  @override
  Widget build(BuildContext context) {
    final player = context.watch<AudioPlayerProvider>();
    final music = context.watch<MusicProvider>();

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text('Audio & Equalizer', style: AppTypography.titleLarge),
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
          // 1. Equalizer Master Toggle & Visualizer
          _buildEqualizerHeader(),
          const SizedBox(height: 16),

          if (_eqEnabled) ...[
            // Preset Chips
            SizedBox(
              height: 38,
              child: ListView(
                scrollDirection: Axis.horizontal,
                physics: const BouncingScrollPhysics(),
                children: [
                  ..._presets.keys.map((preset) => _buildPresetChip(preset)),
                  if (_selectedPreset == 'Custom')
                    _buildPresetChip('Custom', isCustom: true),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // 5-Band Sliders Card
            Container(
              padding: const EdgeInsets.fromLTRB(12, 18, 12, 12),
              decoration: BoxDecoration(
                color: AppColors.card,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppColors.border),
              ),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: List.generate(5, (index) {
                      return _buildBandSlider(index);
                    }),
                  ),
                  const SizedBox(height: 8),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('-10 dB', style: AppTypography.bodySmall.copyWith(color: AppColors.textMuted, fontSize: 10)),
                        Text('0 dB', style: AppTypography.bodySmall.copyWith(color: AppColors.textMuted, fontSize: 10)),
                        Text('+10 dB', style: AppTypography.bodySmall.copyWith(color: AppColors.textMuted, fontSize: 10)),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Audio Enhancement Sliders (Bass Boost & 3D Surround)
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.card,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppColors.border),
              ),
              child: Column(
                children: [
                  _buildEnhanceSlider(
                    label: 'Bass Boost',
                    icon: Icons.speaker_group_rounded,
                    value: _bassBoost,
                    onChanged: (val) {
                      setState(() => _bassBoost = val);
                      _savePreferences();
                    },
                  ),
                  const Divider(height: 24, color: AppColors.border),
                  _buildEnhanceSlider(
                    label: 'Virtualizer / 3D Audio',
                    icon: Icons.surround_sound_rounded,
                    value: _virtualizer,
                    onChanged: (val) {
                      setState(() => _virtualizer = val);
                      _savePreferences();
                    },
                  ),
                ],
              ),
            ),
          ],

          const SizedBox(height: 28),

          // 2. Streaming Quality
          _buildSectionHeader('STREAMING AUDIO QUALITY'),
          Container(
            decoration: BoxDecoration(
              color: AppColors.card,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.border),
            ),
            child: Column(
              children: [
                _buildQualityOption(
                  title: 'Lossless / Direct FLAC',
                  subtitle: 'Highest fidelity, direct original file stream',
                  bitrate: null,
                  currentBitrate: music.getMaxBitRate(),
                  onSelect: () => music.saveMaxBitRate(null),
                ),
                const Divider(height: 1, color: AppColors.border),
                _buildQualityOption(
                  title: 'Very High (320 kbps)',
                  subtitle: 'Studio-grade MP3/AAC compression',
                  bitrate: 320,
                  currentBitrate: music.getMaxBitRate(),
                  onSelect: () => music.saveMaxBitRate(320),
                ),
                const Divider(height: 1, color: AppColors.border),
                _buildQualityOption(
                  title: 'High (192 kbps)',
                  subtitle: 'Balanced clarity and data consumption',
                  bitrate: 192,
                  currentBitrate: music.getMaxBitRate(),
                  onSelect: () => music.saveMaxBitRate(192),
                ),
                const Divider(height: 1, color: AppColors.border),
                _buildQualityOption(
                  title: 'Data Saver (128 kbps)',
                  subtitle: 'Ideal for low cellular data plans',
                  bitrate: 128,
                  currentBitrate: music.getMaxBitRate(),
                  onSelect: () => music.saveMaxBitRate(128),
                ),
                const Divider(height: 1, color: AppColors.border),
                _buildQualityOption(
                  title: 'Extreme Data Saver (96 kbps)',
                  subtitle: 'Maximum bandwidth savings with Opus/AAC compression',
                  bitrate: 96,
                  currentBitrate: music.getMaxBitRate(),
                  onSelect: () => music.saveMaxBitRate(96),
                ),
              ],
            ),
          ),

          const SizedBox(height: 28),

          // 3. Playback & Dynamics
          _buildSectionHeader('PLAYBACK & DYNAMICS'),
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
                // Gapless Playback Switch
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Gapless Playback', style: AppTypography.titleMedium.copyWith(fontSize: 15)),
                          const SizedBox(height: 2),
                          Text('Seamless transition between consecutive tracks', style: AppTypography.bodySmall.copyWith(color: AppColors.textMuted)),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Switch.adaptive(
                      value: _gaplessPlayback,
                      activeTrackColor: AppColors.primary,
                      onChanged: (val) {
                        setState(() => _gaplessPlayback = val);
                        _savePreferences();
                      },
                    ),
                  ],
                ),
                const Divider(height: 24, color: AppColors.border),

                // Volume Normalization Switch
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Normalize Volume', style: AppTypography.titleMedium.copyWith(fontSize: 15)),
                          const SizedBox(height: 2),
                          Text('Set same volume level for all songs (ReplayGain)', style: AppTypography.bodySmall.copyWith(color: AppColors.textMuted)),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Switch.adaptive(
                      value: _volumeNormalization,
                      activeTrackColor: AppColors.primary,
                      onChanged: (val) {
                        setState(() => _volumeNormalization = val);
                        _savePreferences();
                      },
                    ),
                  ],
                ),
                const Divider(height: 24, color: AppColors.border),

                // Crossfade Slider
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('Crossfade', style: AppTypography.titleMedium.copyWith(fontSize: 15)),
                    Text(
                      _crossfadeSeconds == 0 ? 'Off' : '${_crossfadeSeconds.toInt()} s',
                      style: AppTypography.labelLarge.copyWith(color: AppColors.primary),
                    ),
                  ],
                ),
                SliderTheme(
                  data: SliderTheme.of(context).copyWith(
                    activeTrackColor: AppColors.primary,
                    inactiveTrackColor: AppColors.border,
                    thumbColor: Colors.white,
                    overlayColor: AppColors.primary.withValues(alpha: 0.2),
                    trackHeight: 4,
                    thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 7),
                  ),
                  child: Slider(
                    value: _crossfadeSeconds,
                    min: 0,
                    max: 12,
                    divisions: 12,
                    onChanged: (val) {
                      setState(() => _crossfadeSeconds = val);
                      _savePreferences();
                    },
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 40),
        ],
      ),
    );
  }

  Widget _buildEqualizerHeader() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: _eqEnabled ? AppColors.primary.withValues(alpha: 0.15) : AppColors.border,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.equalizer_rounded,
                  color: _eqEnabled ? AppColors.primary : AppColors.textMuted,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Equalizer', style: AppTypography.titleMedium.copyWith(fontSize: 16)),
                  Text(
                    _eqEnabled ? _selectedPreset : 'Disabled',
                    style: AppTypography.bodySmall.copyWith(
                      color: _eqEnabled ? AppColors.primary : AppColors.textMuted,
                    ),
                  ),
                ],
              ),
            ],
          ),
          Switch.adaptive(
            value: _eqEnabled,
            activeTrackColor: AppColors.primary,
            onChanged: (val) {
              setState(() => _eqEnabled = val);
              _savePreferences();
            },
          ),
        ],
      ),
    );
  }

  Widget _buildPresetChip(String name, {bool isCustom = false}) {
    final isSelected = _selectedPreset == name;

    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: GestureDetector(
        onTap: () => _applyPreset(name),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            color: isSelected ? AppColors.primary : const Color(0xFF282828),
            borderRadius: BorderRadius.circular(99),
          ),
          child: Center(
            child: Text(
              name,
              style: AppTypography.labelSmall.copyWith(
                color: isSelected ? Colors.black : Colors.white,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildBandSlider(int index) {
    final val = _bands[index];

    return Column(
      children: [
        Text(
          '${val >= 0 ? '+' : ''}${val.toInt()} dB',
          style: AppTypography.bodySmall.copyWith(
            color: val != 0 ? AppColors.primary : AppColors.textMuted,
            fontSize: 10,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 4),
        SizedBox(
          height: 140,
          child: RotatedBox(
            quarterTurns: -1,
            child: SliderTheme(
              data: SliderTheme.of(context).copyWith(
                activeTrackColor: AppColors.primary,
                inactiveTrackColor: AppColors.border,
                thumbColor: Colors.white,
                trackHeight: 4,
                thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
                overlayColor: AppColors.primary.withValues(alpha: 0.2),
              ),
              child: Slider(
                value: val,
                min: -10.0,
                max: 10.0,
                divisions: 20,
                onChanged: (newVal) => _onBandChanged(index, newVal),
              ),
            ),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          _bandFrequencies[index],
          style: AppTypography.bodySmall.copyWith(color: AppColors.textMuted, fontSize: 10),
        ),
      ],
    );
  }

  Widget _buildEnhanceSlider({
    required String label,
    required IconData icon,
    required double value,
    required ValueChanged<double> onChanged,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                Icon(icon, color: AppColors.primary, size: 18),
                const SizedBox(width: 8),
                Text(label, style: AppTypography.titleMedium.copyWith(fontSize: 14)),
              ],
            ),
            Text(
              '${(value * 100).toInt()}%',
              style: AppTypography.labelMedium.copyWith(color: AppColors.primary),
            ),
          ],
        ),
        SliderTheme(
          data: SliderTheme.of(context).copyWith(
            activeTrackColor: AppColors.primary,
            inactiveTrackColor: AppColors.border,
            thumbColor: Colors.white,
            trackHeight: 4,
            thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
            overlayColor: AppColors.primary.withValues(alpha: 0.2),
          ),
          child: Slider(
            value: value,
            min: 0.0,
            max: 1.0,
            onChanged: onChanged,
          ),
        ),
      ],
    );
  }

  Widget _buildQualityOption({
    required String title,
    required String subtitle,
    required int? bitrate,
    required int? currentBitrate,
    required VoidCallback onSelect,
  }) {
    final isSelected = bitrate == currentBitrate;

    return ListTile(
      title: Text(title, style: AppTypography.titleMedium.copyWith(fontSize: 15)),
      subtitle: Text(subtitle, style: AppTypography.bodySmall.copyWith(color: AppColors.textMuted)),
      trailing: Icon(
        isSelected ? Icons.radio_button_checked_rounded : Icons.radio_button_unchecked_rounded,
        color: isSelected ? AppColors.primary : AppColors.textMuted,
        size: 20,
      ),
      onTap: () {
        HapticFeedback.selectionClick();
        onSelect();
      },
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
}
