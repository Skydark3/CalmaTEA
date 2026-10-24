import 'package:flutter_test/flutter_test.dart';

import 'package:tea_app/models/activity_execution_session_model.dart';
import 'package:tea_app/services/activity_execution_session_service.dart';

void main() {
  group('ActivityExecutionSessionService transitions', () {
    test('permite cerrar una sesion activa', () {
      expect(
        ActivityExecutionSessionService.isAllowedTransition(
          ActivityExecutionSessionStatus.inProgress,
          ActivityExecutionSessionStatus.completed,
        ),
        isTrue,
      );
      expect(
        ActivityExecutionSessionService.isAllowedTransition(
          ActivityExecutionSessionStatus.inProgress,
          ActivityExecutionSessionStatus.interrupted,
        ),
        isTrue,
      );
    });

    test('impide reabrir o volver a cerrar estados terminales', () {
      for (final terminalStatus in [
        ActivityExecutionSessionStatus.completed,
        ActivityExecutionSessionStatus.interrupted,
      ]) {
        for (final targetStatus in ActivityExecutionSessionStatus.values) {
          expect(
            ActivityExecutionSessionService.isAllowedTransition(
              terminalStatus,
              targetStatus,
            ),
            isFalse,
          );
        }
      }
    });

    test('no acepta una transicion inProgress a inProgress', () {
      expect(
        ActivityExecutionSessionService.isAllowedTransition(
          ActivityExecutionSessionStatus.inProgress,
          ActivityExecutionSessionStatus.inProgress,
        ),
        isFalse,
      );
    });
  });
}
