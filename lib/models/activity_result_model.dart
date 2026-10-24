class ActivityResultModel {
  final String id;
  final String activityId;
  final String childId;
  final String therapyId;
  final int score;
  final int correctAnswers;
  final int errors;
  final int attempts;
  final int hintsUsed;
  final int durationSeconds;
  final bool completed;
  final DateTime completedAt;

  const ActivityResultModel({
    required this.id,
    required this.activityId,
    required this.childId,
    required this.therapyId,
    required this.score,
    required this.correctAnswers,
    required this.errors,
    required this.attempts,
    required this.hintsUsed,
    required this.durationSeconds,
    required this.completed,
    required this.completedAt,
  });

  /// Porcentaje de aciertos calculado (0.0 a 1.0)
  double get accuracy {
    final total = correctAnswers + errors;
    if (total == 0) return 0.0;
    return correctAnswers / total;
  }

  /// Duración formateada en minutos y segundos (ej. "02:25 min")
  String get formattedDuration {
    final minutes = (durationSeconds ~/ 60).toString().padLeft(2, '0');
    final seconds = (durationSeconds % 60).toString().padLeft(2, '0');
    return '$minutes:$seconds min';
  }

  ActivityResultModel copyWith({
    String? id,
    String? activityId,
    String? childId,
    String? therapyId,
    int? score,
    int? correctAnswers,
    int? errors,
    int? attempts,
    int? hintsUsed,
    int? durationSeconds,
    bool? completed,
    DateTime? completedAt,
  }) {
    return ActivityResultModel(
      id: id ?? this.id,
      activityId: activityId ?? this.activityId,
      childId: childId ?? this.childId,
      therapyId: therapyId ?? this.therapyId,
      score: score ?? this.score,
      correctAnswers: correctAnswers ?? this.correctAnswers,
      errors: errors ?? this.errors,
      attempts: attempts ?? this.attempts,
      hintsUsed: hintsUsed ?? this.hintsUsed,
      durationSeconds: durationSeconds ?? this.durationSeconds,
      completed: completed ?? this.completed,
      completedAt: completedAt ?? this.completedAt,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'activityId': activityId,
      'childId': childId,
      'therapyId': therapyId,
      'score': score,
      'correctAnswers': correctAnswers,
      'errors': errors,
      'attempts': attempts,
      'hintsUsed': hintsUsed,
      'durationSeconds': durationSeconds,
      'completed': completed,
      'completedAt': completedAt.toIso8601String(),
    };
  }

  factory ActivityResultModel.fromMap(Map<String, dynamic> map, {String? id}) {
    final rawCompletedAt = map['completedAt'];
    DateTime parsedCompletedAt;
    if (rawCompletedAt is String) {
      parsedCompletedAt = DateTime.tryParse(rawCompletedAt) ?? DateTime.now();
    } else {
      parsedCompletedAt = DateTime.now();
    }

    return ActivityResultModel(
      id: id ?? (map['id'] as String? ?? ''),
      activityId: map['activityId'] as String? ?? '',
      childId: map['childId'] as String? ?? '',
      therapyId: map['therapyId'] as String? ?? '',
      score: (map['score'] as num?)?.toInt() ?? 0,
      correctAnswers: (map['correctAnswers'] as num?)?.toInt() ?? 0,
      errors: (map['errors'] as num?)?.toInt() ?? 0,
      attempts: (map['attempts'] as num?)?.toInt() ?? 1,
      hintsUsed: (map['hintsUsed'] as num?)?.toInt() ?? 0,
      durationSeconds: (map['durationSeconds'] as num?)?.toInt() ?? 0,
      completed: map['completed'] as bool? ?? true,
      completedAt: parsedCompletedAt,
    );
  }
}
