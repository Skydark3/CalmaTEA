import 'models/activity_configurations.dart';

List<MotorStepConfig> prepareMotorStepsForSave(
  Iterable<MotorStepConfig> steps,
) {
  return steps
      .map(
        (step) => MotorStepConfig(
          id: step.id,
          instruction: step.instruction.trim(),
          durationSeconds: step.durationSeconds,
          repetitions: step.repetitions,
        ),
      )
      .toList(growable: false);
}

List<MotorStepConfig> reorderMotorSteps(
  List<MotorStepConfig> steps,
  int oldIndex,
  int newIndex,
) {
  final reordered = List<MotorStepConfig>.of(steps);
  if (newIndex > oldIndex) newIndex -= 1;
  final item = reordered.removeAt(oldIndex);
  reordered.insert(newIndex, item);
  return reordered;
}

bool isValidOptionalPositiveIntInput(String value) {
  final normalized = value.trim();
  if (normalized.isEmpty) return true;
  final parsed = int.tryParse(normalized);
  return parsed != null && parsed > 0;
}

int? optionalPositiveIntFromInput(String value) {
  final normalized = value.trim();
  return normalized.isEmpty ? null : int.tryParse(normalized);
}
