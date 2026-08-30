class DurationFormatter {
  DurationFormatter._();

  static String format(int seconds) {
    if (seconds <= 0) return '0:00';
    final minutes = seconds ~/ 60;
    final remainingSeconds = seconds % 60;
    final secStr = remainingSeconds < 10 ? '0$remainingSeconds' : '$remainingSeconds';
    if (minutes >= 60) {
      final hours = minutes ~/ 60;
      final remMinutes = minutes % 60;
      final minStr = remMinutes < 10 ? '0$remMinutes' : '$remMinutes';
      return '$hours:$minStr:$secStr';
    }
    return '$minutes:$secStr';
  }

  static String formatDuration(Duration duration) {
    return format(duration.inSeconds);
  }
}
