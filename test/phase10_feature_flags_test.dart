import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:tea_app/core/config/phase10_feature_flags.dart';
import 'package:tea_app/core/firebase/firebase_bootstrap.dart';

void main() {
  test(
    'Firebase real y solicitudes desactivadas mantienen FASE 10 apagada',
    () {
      const flags = Phase10FeatureFlags.resolve(
        activityExecutionRequested: false,
        executionHistoryRequested: false,
        executionMetricsRequested: false,
        isReleaseBuild: false,
      );

      expect(flags.activityExecutionEnabled, isFalse);
      expect(flags.activityPreviewEnabled, isFalse);
      expect(flags.executionHistoryEnabled, isFalse);
      expect(flags.executionMetricsEnabled, isFalse);
      expect(flags.anyEnabled, isFalse);
    },
  );

  test('Firebase local puede habilitar explicitamente las tres funciones', () {
    const flags = Phase10FeatureFlags.resolve(
      activityExecutionRequested: true,
      executionHistoryRequested: true,
      executionMetricsRequested: true,
      isReleaseBuild: false,
    );

    expect(flags.activityExecutionEnabled, isTrue);
    expect(flags.activityPreviewEnabled, isFalse);
    expect(flags.executionHistoryEnabled, isTrue);
    expect(flags.executionMetricsEnabled, isTrue);
  });

  test('historial y metricas se resuelven de forma independiente', () {
    const historyOnly = Phase10FeatureFlags.resolve(
      activityExecutionRequested: false,
      executionHistoryRequested: true,
      executionMetricsRequested: false,
      isReleaseBuild: false,
    );
    const metricsOnly = Phase10FeatureFlags.resolve(
      activityExecutionRequested: false,
      executionHistoryRequested: false,
      executionMetricsRequested: true,
      isReleaseBuild: false,
    );

    expect(historyOnly.executionHistoryEnabled, isTrue);
    expect(historyOnly.executionMetricsEnabled, isFalse);
    expect(metricsOnly.executionHistoryEnabled, isFalse);
    expect(metricsOnly.executionMetricsEnabled, isTrue);
  });

  test('release bloquea las funciones aunque sean solicitadas', () {
    const flags = Phase10FeatureFlags.resolve(
      activityExecutionRequested: true,
      executionHistoryRequested: true,
      executionMetricsRequested: true,
      isReleaseBuild: true,
    );

    expect(flags.anyEnabled, isFalse);
  });

  test('preview habilita motores sin activar persistencia', () {
    const flags = Phase10FeatureFlags.resolve(
      activityExecutionRequested: false,
      activityPreviewRequested: true,
      executionHistoryRequested: false,
      executionMetricsRequested: false,
      isReleaseBuild: false,
    );

    expect(flags.activityPreviewEnabled, isTrue);
    expect(flags.activityExecutionEnabled, isFalse);
    expect(flags.executionHistoryEnabled, isFalse);
    expect(flags.executionMetricsEnabled, isFalse);
  });

  test('preview y persistencia simultáneos fallan cerrados', () {
    const flags = Phase10FeatureFlags.resolve(
      activityExecutionRequested: true,
      activityPreviewRequested: true,
      executionHistoryRequested: false,
      executionMetricsRequested: false,
      isReleaseBuild: false,
    );

    expect(flags.activityPreviewEnabled, isFalse);
    expect(flags.activityExecutionEnabled, isFalse);
    expect(
      () => Phase10Features.validateRawValues(
        activityExecution: 'true',
        activityPreview: 'true',
        executionHistory: 'false',
        executionMetrics: 'false',
      ),
      throwsStateError,
    );
  });

  test('release bloquea también el modo Preview', () {
    const flags = Phase10FeatureFlags.resolve(
      activityExecutionRequested: false,
      activityPreviewRequested: true,
      executionHistoryRequested: false,
      executionMetricsRequested: false,
      isReleaseBuild: true,
    );

    expect(flags.activityPreviewEnabled, isFalse);
    expect(flags.anyEnabled, isFalse);
  });

  test('solo acepta literales booleanos estrictos', () {
    expect(
      () => Phase10Features.validateRawValues(
        activityExecution: 'true',
        executionHistory: 'false',
        executionMetrics: 'TRUE',
      ),
      throwsStateError,
    );
    expect(
      () => Phase10Features.validateRawValues(
        activityExecution: 'true',
        executionHistory: 'false',
        executionMetrics: 'false',
      ),
      returnsNormally,
    );
    expect(
      () => FirebaseBootstrap.validateUseEmulatorsValue('1'),
      throwsStateError,
    );
    expect(
      () => FirebaseBootstrap.validateUseEmulatorsValue('true'),
      returnsNormally,
    );
  });

  test('la compilacion lee entorno Firebase y features por separado', () {
    const expectedEmulators = bool.fromEnvironment(
      'TEST_EXPECT_FIREBASE_EMULATORS',
      defaultValue: false,
    );
    const expectedFeatures = bool.fromEnvironment(
      'TEST_EXPECT_PHASE10_FEATURES',
      defaultValue: false,
    );
    const expectedPreview = bool.fromEnvironment(
      'TEST_EXPECT_ACTIVITY_PREVIEW',
      defaultValue: false,
    );

    expect(FirebaseBootstrap.useEmulators, expectedEmulators);
    expect(
      Phase10Features.activityExecutionEnabled,
      kReleaseMode ? false : expectedFeatures,
    );
    expect(
      Phase10Features.activityPreviewEnabled,
      kReleaseMode ? false : expectedPreview,
    );
    expect(
      Phase10Features.executionHistoryEnabled,
      kReleaseMode ? false : expectedFeatures,
    );
    expect(
      Phase10Features.executionMetricsEnabled,
      kReleaseMode ? false : expectedFeatures,
    );
  });
}
