String formatDuration(int totalSeconds) {
  final duration = Duration(seconds: totalSeconds);
  final hours = duration.inHours;
  final minutes = duration.inMinutes.remainder(60);

  if (hours > 0) {
    final decimalHours = hours + (minutes / 60);
    return '${decimalHours.toStringAsFixed(1)} hour';
  } else {
    return '$minutes min';
  }
}
