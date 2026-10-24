import 'models/activity_configurations.dart';

List<EmotionOptionConfig> prepareEmotionOptionsForSave(
  Iterable<EmotionOptionConfig> options,
) {
  return options
      .map(
        (option) => EmotionOptionConfig(
          id: option.id,
          label: option.label.trim(),
          prompt: option.prompt.trim(),
          expectedValue: option.expectedValue.trim(),
        ),
      )
      .toList(growable: false);
}

bool hasDuplicateEmotionOptions(Iterable<EmotionOptionConfig> options) {
  final keys = <String>{};
  for (final option in options) {
    final key =
        '${option.label.trim()}\u0000${option.prompt.trim()}\u0000'
        '${option.expectedValue.trim()}';
    if (!keys.add(key)) return true;
  }
  return false;
}
