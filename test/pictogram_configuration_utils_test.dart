import 'package:flutter_test/flutter_test.dart';

import 'package:tea_app/features/activities/config/models/activity_configurations.dart';
import 'package:tea_app/features/activities/config/pictogram_configuration_utils.dart';

void main() {
  test('normaliza label y conserva id y referencia visual', () {
    final result = preparePictogramOptionsForSave(const [
      PictogramOptionConfig(
        id: 'pictogram-1',
        label: '  Lavarse las manos  ',
        resourceReference: 'existing-resource',
      ),
    ]);

    expect(result.single.id, 'pictogram-1');
    expect(result.single.label, 'Lavarse las manos');
    expect(result.single.resourceReference, 'existing-resource');
  });

  test('detecta labels duplicados ignorando espacios y mayúsculas', () {
    const options = [
      PictogramOptionConfig(id: 'pictogram-1', label: 'Comer'),
      PictogramOptionConfig(id: 'pictogram-2', label: ' comer '),
    ];

    expect(hasDuplicatePictogramLabels(options), isTrue);
  });

  test('exige label y permite construir una configuración válida', () {
    const invalid = PictogramOptionConfig(id: 'pictogram-1', label: '   ');
    const valid = PictogramOptionConfig(id: 'pictogram-2', label: 'Dormir');

    expect(invalid.isValid, isFalse);
    expect(valid.isValid, isTrue);
    expect(const PictogramActivityConfig(options: [valid]).isValid, isTrue);
  });
}
