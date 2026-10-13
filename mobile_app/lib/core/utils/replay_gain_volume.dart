import 'dart:math';

double replayGainVolume({required bool normalize, double? gain, double? peak}) {
  if (!normalize || gain == null || !gain.isFinite) return 1.0;
  final gainVolume = pow(10.0, gain / 20.0).toDouble();
  final peakLimit =
      peak != null && peak.isFinite && peak > 0 ? 1.0 / peak : 1.0;
  return min(1.0, min(gainVolume, peakLimit));
}
