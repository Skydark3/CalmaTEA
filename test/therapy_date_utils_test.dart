import 'package:flutter_test/flutter_test.dart';
import 'package:tea_app/models/therapy_date_utils.dart';

void main() {
  group('Therapy date-only handling', () {
    test('preserves the selected calendar day through storage conversion', () {
      final selected = DateTime.utc(2026, 10, 3);
      final stored = therapyDateForStorage(selected);
      final read = therapyDateFromStorage(stored);

      expect((read.year, read.month, read.day), (2026, 10, 3));
      expect(stored.hour, 12);
    });

    test('accepts both inclusive end-date boundaries', () {
      final startDate = DateTime(2026, 10, 3);
      final today = DateTime(2026, 10, 4);

      expect(
        isTherapyDateInRange(
          DateTime(2026, 10, 3),
          firstDate: startDate,
          lastDate: today,
        ),
        isTrue,
      );
      expect(
        isTherapyDateInRange(
          DateTime(2026, 10, 4),
          firstDate: startDate,
          lastDate: today,
        ),
        isTrue,
      );
      expect(
        isTherapyDateInRange(
          DateTime(2026, 10, 2),
          firstDate: startDate,
          lastDate: today,
        ),
        isFalse,
      );
      expect(
        isTherapyDateInRange(
          DateTime(2026, 10, 5),
          firstDate: startDate,
          lastDate: today,
        ),
        isFalse,
      );
    });

    test('clamps an initial date to the picker interval', () {
      final startDate = DateTime(2026, 10, 3);
      final today = DateTime(2026, 10, 4);

      expect(
        clampTherapyDate(
          DateTime(2026, 10, 2),
          firstDate: startDate,
          lastDate: today,
        ),
        startDate,
      );
      expect(
        clampTherapyDate(
          DateTime(2026, 10, 5),
          firstDate: startDate,
          lastDate: today,
        ),
        today,
      );
    });
  });
}
