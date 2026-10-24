import 'models/activity_configurations.dart';

List<PictogramOptionConfig> preparePictogramOptionsForSave(
  Iterable<PictogramOptionConfig> options,
) {
  return options
      .map(
        (option) => PictogramOptionConfig(
          id: option.id,
          label: option.label.trim(),
          resourceReference: option.resourceReference,
        ),
      )
      .toList(growable: false);
}

bool hasDuplicatePictogramLabels(Iterable<PictogramOptionConfig> options) {
  final labels = <String>{};
  for (final option in options) {
    if (!labels.add(option.label.trim().toLowerCase())) return true;
  }
  return false;
}
