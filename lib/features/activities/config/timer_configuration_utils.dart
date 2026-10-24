int? durationSecondsFromParts({required int minutes, required int seconds}) {
  if (minutes < 0 || seconds < 0 || seconds > 59) return null;
  final total = (minutes * 60) + seconds;
  return total > 0 ? total : null;
}

({int minutes, int seconds}) timerDurationParts(int durationSeconds) {
  final normalized = durationSeconds < 0 ? 0 : durationSeconds;
  return (minutes: normalized ~/ 60, seconds: normalized % 60);
}

String? normalizeTimerLabel(String label) {
  final normalized = label.trim();
  return normalized.isEmpty ? null : normalized;
}

String formatTimerDuration(int durationSeconds) {
  if (durationSeconds <= 0) return '0 s';
  final minutes = durationSeconds ~/ 60;
  final seconds = durationSeconds % 60;
  if (minutes == 0) return '$seconds s';
  if (seconds == 0) return '$minutes min';
  return '$minutes min $seconds s';
}
