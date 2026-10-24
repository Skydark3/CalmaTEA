/// Modelo que guarda el resultado de una actividad cognitiva completada.
class ActivityResult {
  final String activityId;
  final String activityName;
  final int totalQuestions;
  final int correctAnswers;
  final int wrongAnswers;
  final Duration timeTaken;
  final int level;
  final DateTime completedAt;

  ActivityResult({
    required this.activityId,
    required this.activityName,
    required this.totalQuestions,
    required this.correctAnswers,
    required this.wrongAnswers,
    required this.timeTaken,
    required this.level,
    DateTime? completedAt,
  }) : completedAt = completedAt ?? DateTime.now();

  /// Porcentaje de aciertos (0.0 a 1.0)
  double get accuracy =>
      totalQuestions == 0 ? 0 : correctAnswers / totalQuestions;

  String get formattedTime {
    final minutes = timeTaken.inMinutes.remainder(60).toString().padLeft(2, '0');
    final seconds = timeTaken.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$minutes:$seconds min';
  }
}
