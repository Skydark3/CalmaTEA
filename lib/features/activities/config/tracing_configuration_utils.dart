import 'models/activity_configurations.dart';

TracingActivityConfig prepareTracingConfigurationForSave({
  required String pattern,
  required String value,
  String? difficultyHint,
}) {
  final normalizedHint = difficultyHint?.trim();
  return TracingActivityConfig(
    pattern: pattern.trim(),
    value: value.trim(),
    difficultyHint: normalizedHint == null || normalizedHint.isEmpty
        ? null
        : normalizedHint,
  );
}
