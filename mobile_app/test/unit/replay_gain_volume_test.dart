import 'package:flutter_test/flutter_test.dart';
import 'package:localspotify/core/utils/replay_gain_volume.dart';

void main() {
  test('ReplayGain attenuation respects gain and peak ceilings', () {
    expect(replayGainVolume(normalize: true, gain: -6), closeTo(0.501, 0.001));
    expect(replayGainVolume(normalize: true, gain: 3), 1.0);
    expect(replayGainVolume(normalize: true, gain: 0, peak: 1.2),
        closeTo(0.833, 0.001));
    expect(replayGainVolume(normalize: true), 1.0);
    expect(replayGainVolume(normalize: false, gain: -6), 1.0);
  });
}
