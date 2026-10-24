import 'package:flutter/foundation.dart';

/// Valores resueltos de las funcionalidades opcionales de FASE 10.
///
/// Esta configuracion no conoce ni selecciona el entorno Firebase. Su unica
/// responsabilidad es decidir si cada funcionalidad se presenta en la app.
class Phase10FeatureFlags {
  final bool activityExecutionEnabled;
  final bool activityPreviewEnabled;
  final bool executionHistoryEnabled;
  final bool executionMetricsEnabled;

  const Phase10FeatureFlags({
    required this.activityExecutionEnabled,
    this.activityPreviewEnabled = false,
    required this.executionHistoryEnabled,
    required this.executionMetricsEnabled,
  });

  const Phase10FeatureFlags.resolve({
    required bool activityExecutionRequested,
    bool activityPreviewRequested = false,
    required bool executionHistoryRequested,
    required bool executionMetricsRequested,
    required bool isReleaseBuild,
  }) : activityExecutionEnabled =
           !isReleaseBuild &&
           activityExecutionRequested &&
           !activityPreviewRequested,
       activityPreviewEnabled =
           !isReleaseBuild &&
           activityPreviewRequested &&
           !activityExecutionRequested,
       executionHistoryEnabled = !isReleaseBuild && executionHistoryRequested,
       executionMetricsEnabled = !isReleaseBuild && executionMetricsRequested;

  bool get anyEnabled =>
      activityExecutionEnabled ||
      activityPreviewEnabled ||
      executionHistoryEnabled ||
      executionMetricsEnabled;
}

/// Feature flags de FASE 10 leidos exclusivamente desde `dart-define`.
abstract final class Phase10Features {
  static const String _activityExecutionRaw = String.fromEnvironment(
    'ENABLE_ACTIVITY_EXECUTION',
    defaultValue: 'false',
  );
  static const String _activityPreviewRaw = String.fromEnvironment(
    'ENABLE_ACTIVITY_PREVIEW',
    defaultValue: 'false',
  );
  static const String _executionHistoryRaw = String.fromEnvironment(
    'ENABLE_EXECUTION_HISTORY',
    defaultValue: 'false',
  );
  static const String _executionMetricsRaw = String.fromEnvironment(
    'ENABLE_EXECUTION_METRICS',
    defaultValue: 'false',
  );

  static const bool _activityExecutionRequested = bool.fromEnvironment(
    'ENABLE_ACTIVITY_EXECUTION',
    defaultValue: false,
  );
  static const bool _activityPreviewRequested = bool.fromEnvironment(
    'ENABLE_ACTIVITY_PREVIEW',
    defaultValue: false,
  );
  static const bool _executionHistoryRequested = bool.fromEnvironment(
    'ENABLE_EXECUTION_HISTORY',
    defaultValue: false,
  );
  static const bool _executionMetricsRequested = bool.fromEnvironment(
    'ENABLE_EXECUTION_METRICS',
    defaultValue: false,
  );

  static const bool activityExecutionEnabled =
      !kReleaseMode &&
      _activityExecutionRequested &&
      !_activityPreviewRequested;
  static const bool activityPreviewEnabled =
      !kReleaseMode &&
      _activityPreviewRequested &&
      !_activityExecutionRequested;
  static const bool executionHistoryEnabled =
      !kReleaseMode && _executionHistoryRequested;
  static const bool executionMetricsEnabled =
      !kReleaseMode && _executionMetricsRequested;

  /// Rechaza valores ambiguos como `1`, `yes` o `TRUE` antes de iniciar
  /// Firebase. Solo se admiten los literales exactos `true` y `false`.
  static void validateEnvironment() {
    validateRawValues(
      activityExecution: _activityExecutionRaw,
      activityPreview: _activityPreviewRaw,
      executionHistory: _executionHistoryRaw,
      executionMetrics: _executionMetricsRaw,
    );
  }

  @visibleForTesting
  static void validateRawValues({
    required String activityExecution,
    String activityPreview = 'false',
    required String executionHistory,
    required String executionMetrics,
  }) {
    _requireStrictBoolean('ENABLE_ACTIVITY_EXECUTION', activityExecution);
    _requireStrictBoolean('ENABLE_ACTIVITY_PREVIEW', activityPreview);
    _requireStrictBoolean('ENABLE_EXECUTION_HISTORY', executionHistory);
    _requireStrictBoolean('ENABLE_EXECUTION_METRICS', executionMetrics);
    if (activityExecution == 'true' && activityPreview == 'true') {
      throw StateError(
        'ENABLE_ACTIVITY_EXECUTION y ENABLE_ACTIVITY_PREVIEW no pueden '
        'habilitarse al mismo tiempo.',
      );
    }
  }

  static void _requireStrictBoolean(String name, String value) {
    if (value != 'true' && value != 'false') {
      throw StateError('$name solo admite los valores true o false.');
    }
  }
}
