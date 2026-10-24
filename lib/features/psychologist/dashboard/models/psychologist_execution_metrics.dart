class PsychologistExecutionMetrics {
  final int totalExecutions;
  final int completedExecutions;
  final int interruptedExecutions;
  final int unclosedExecutions;

  const PsychologistExecutionMetrics._({
    required this.totalExecutions,
    required this.completedExecutions,
    required this.interruptedExecutions,
    required this.unclosedExecutions,
  });

  factory PsychologistExecutionMetrics({
    required int totalExecutions,
    required int completedExecutions,
    required int interruptedExecutions,
    required int unclosedExecutions,
  }) {
    final values = [
      totalExecutions,
      completedExecutions,
      interruptedExecutions,
      unclosedExecutions,
    ];
    if (values.any((value) => value < 0)) {
      throw ArgumentError(
        'Los contadores de ejecucion no pueden ser negativos.',
      );
    }
    if (totalExecutions !=
        completedExecutions + interruptedExecutions + unclosedExecutions) {
      throw ArgumentError(
        'El total debe coincidir con la suma de los estados admitidos.',
      );
    }

    return PsychologistExecutionMetrics._(
      totalExecutions: totalExecutions,
      completedExecutions: completedExecutions,
      interruptedExecutions: interruptedExecutions,
      unclosedExecutions: unclosedExecutions,
    );
  }

  factory PsychologistExecutionMetrics.zero() {
    return PsychologistExecutionMetrics(
      totalExecutions: 0,
      completedExecutions: 0,
      interruptedExecutions: 0,
      unclosedExecutions: 0,
    );
  }
}
