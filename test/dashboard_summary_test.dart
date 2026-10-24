import 'package:flutter_test/flutter_test.dart';
import 'package:tea_app/features/psychologist/dashboard/models/dashboard_summary.dart';

void main() {
  group('DashboardSummary Model Tests', () {
    test('Default values represent a completely empty state', () {
      const summary = DashboardSummary();

      expect(summary.patientsCount, 0);
      expect(summary.activeTherapiesCount, 0);
      expect(summary.pendingActivitiesCount, 0);
    });

    test('DashboardSummary.empty() initializes all indicators to zero', () {
      const emptySummary = DashboardSummary.empty();

      expect(emptySummary.patientsCount, 0);
      expect(emptySummary.activeTherapiesCount, 0);
      expect(emptySummary.pendingActivitiesCount, 0);
    });

    test('Custom initialization preserves passed values', () {
      const summary = DashboardSummary(
        patientsCount: 5,
        activeTherapiesCount: 3,
        pendingActivitiesCount: 2,
      );

      expect(summary.patientsCount, 5);
      expect(summary.activeTherapiesCount, 3);
      expect(summary.pendingActivitiesCount, 2);
    });

    test('copyWith updates specified fields and preserves others', () {
      const original = DashboardSummary(
        patientsCount: 2,
        activeTherapiesCount: 1,
        pendingActivitiesCount: 4,
      );

      final updated = original.copyWith(patientsCount: 7);

      expect(updated.patientsCount, 7);
      expect(updated.activeTherapiesCount, 1);
      expect(updated.pendingActivitiesCount, 4);

      final updatedMultiple = original.copyWith(
        activeTherapiesCount: 5,
        pendingActivitiesCount: 0,
      );

      expect(updatedMultiple.patientsCount, 2);
      expect(updatedMultiple.activeTherapiesCount, 5);
      expect(updatedMultiple.pendingActivitiesCount, 0);
    });
  });
}
