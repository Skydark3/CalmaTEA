import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:tea_app/features/psychologist/dashboard/models/dashboard_summary.dart';
import 'package:tea_app/features/psychologist/dashboard/models/psychologist_execution_metrics.dart';
import 'package:tea_app/features/psychologist/dashboard/presentation/widgets/execution_metrics_section.dart';
import 'package:tea_app/models/activity_model.dart';
import 'package:tea_app/models/user_model.dart';
import 'package:tea_app/services/psychologist_execution_metrics_service.dart';

void main() {
  group('PsychologistExecutionMetrics', () {
    test('representa cuatro contadores cero confirmados', () {
      final metrics = PsychologistExecutionMetrics.zero();
      expect(metrics.totalExecutions, 0);
      expect(metrics.completedExecutions, 0);
      expect(metrics.interruptedExecutions, 0);
      expect(metrics.unclosedExecutions, 0);
    });

    test('conserva contadores coherentes', () {
      final metrics = _metrics(total: 10, completed: 6, interrupted: 3);
      expect(metrics.totalExecutions, 10);
      expect(metrics.completedExecutions, 6);
      expect(metrics.interruptedExecutions, 3);
      expect(metrics.unclosedExecutions, 1);
    });

    test('rechaza valores negativos', () {
      expect(
        () => PsychologistExecutionMetrics(
          totalExecutions: -1,
          completedExecutions: 0,
          interruptedExecutions: 0,
          unclosedExecutions: 0,
        ),
        throwsArgumentError,
      );
    });

    test('rechaza un total incoherente con los estados', () {
      expect(
        () => PsychologistExecutionMetrics(
          totalExecutions: 5,
          completedExecutions: 1,
          interruptedExecutions: 1,
          unclosedExecutions: 1,
        ),
        throwsArgumentError,
      );
    });

    test('reintenta una lectura incoherente por concurrencia', () async {
      var calls = 0;
      final aggregator = PsychologistExecutionMetricsAggregator(
        loadCounts: () async {
          calls++;
          return calls == 1 ? [4, 1, 1, 1] : [4, 2, 1, 1];
        },
      );

      final metrics = await aggregator.loadConsistentMetrics();

      expect(calls, 2);
      expect(metrics.totalExecutions, 4);
      expect(metrics.completedExecutions, 2);
      expect(metrics.interruptedExecutions, 1);
      expect(metrics.unclosedExecutions, 1);
    });

    test('rechaza conteos persistentemente incoherentes', () async {
      var calls = 0;
      final aggregator = PsychologistExecutionMetricsAggregator(
        loadCounts: () async {
          calls++;
          return [4, 1, 1, 1];
        },
      );

      await expectLater(
        aggregator.loadConsistentMetrics(),
        throwsA(isA<PsychologistExecutionMetricsDataException>()),
      );
      expect(calls, 2);
    });
  });

  group('ExecutionMetricsSection', () {
    testWidgets('consulta las estadisticas del psicologo indicado', (
      tester,
    ) async {
      final source = _FakeMetricsSource()..enqueueValue(_metrics());
      await _pumpSection(tester, user: _psychologistA, source: source);
      expect(source.requestedIds, ['psych-a']);
      expect(find.text('Actividad en CalmaTEA'), findsOneWidget);
    });

    testWidgets('muestra los cuatro indicadores descriptivos', (tester) async {
      final source = _FakeMetricsSource()
        ..enqueueValue(_metrics(total: 10, completed: 6, interrupted: 3));
      await _pumpSection(tester, user: _psychologistA, source: source);
      expect(find.text('Ejecuciones registradas'), findsOneWidget);
      expect(find.text('Ejecuciones completadas'), findsOneWidget);
      expect(find.text('Ejecuciones interrumpidas'), findsOneWidget);
      expect(find.text('Sesiones sin cierre registrado'), findsOneWidget);
      expect(find.text('10'), findsOneWidget);
      expect(find.text('6'), findsOneWidget);
      expect(find.text('3'), findsOneWidget);
      expect(find.text('1'), findsOneWidget);
    });

    testWidgets('muestra ceros reales cuando no existen sesiones', (
      tester,
    ) async {
      final source = _FakeMetricsSource()
        ..enqueueValue(PsychologistExecutionMetrics.zero());
      await _pumpSection(tester, user: _psychologistA, source: source);
      expect(find.text('0'), findsNWidgets(4));
    });

    testWidgets('un usuario infantil no inicia consultas profesionales', (
      tester,
    ) async {
      final source = _FakeMetricsSource()..enqueueValue(_metrics());
      await _pumpSection(tester, user: _childUser, source: source);
      expect(source.calls, 0);
      expect(
        find.text('No tienes permiso para consultar estas estadísticas.'),
        findsOneWidget,
      );
    });

    testWidgets('presenta carga sin inventar ceros', (tester) async {
      final source = _FakeMetricsSource()
        ..enqueueFuture(Completer<PsychologistExecutionMetrics>().future);
      await _pumpSection(
        tester,
        user: _psychologistA,
        source: source,
        settle: false,
      );
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(find.text('0'), findsNothing);
    });

    testWidgets('presenta error de conexion controlado', (tester) async {
      final source = _FakeMetricsSource()..enqueueError(Exception('offline'));
      await _pumpSection(tester, user: _psychologistA, source: source);
      expect(
        find.text('No pudimos cargar las estadísticas de actividad.'),
        findsOneWidget,
      );
      expect(find.textContaining('FirebaseException'), findsNothing);
    });

    testWidgets('distingue un error de permisos', (tester) async {
      final source = _FakeMetricsSource()
        ..enqueueError(const PsychologistExecutionMetricsAccessDenied());
      await _pumpSection(tester, user: _psychologistA, source: source);
      expect(
        find.text('No tienes permiso para consultar estas estadísticas.'),
        findsOneWidget,
      );
      expect(find.text('Reintentar'), findsNothing);
    });

    testWidgets('permite reintentar una carga fallida', (tester) async {
      final source = _FakeMetricsSource()
        ..enqueueError(Exception('offline'))
        ..enqueueValue(_metrics());
      await _pumpSection(tester, user: _psychologistA, source: source);
      await tester.tap(find.text('Reintentar'));
      await tester.pumpAndSettle();
      expect(source.calls, 2);
      expect(find.text('Ejecuciones registradas'), findsOneWidget);
    });

    testWidgets('permite actualizacion manual accesible', (tester) async {
      final source = _FakeMetricsSource()
        ..enqueueValue(_metrics())
        ..enqueueValue(_metrics(total: 4, completed: 2, interrupted: 1));
      await _pumpSection(tester, user: _psychologistA, source: source);
      await tester.tap(find.byKey(const Key('refresh-execution-metrics')));
      await tester.pumpAndSettle();
      expect(source.calls, 2);
      expect(find.text('4'), findsOneWidget);
    });

    testWidgets('bloquea solicitudes duplicadas durante una carga', (
      tester,
    ) async {
      final pending = Completer<PsychologistExecutionMetrics>();
      final source = _FakeMetricsSource()..enqueueFuture(pending.future);
      await _pumpSection(
        tester,
        user: _psychologistA,
        source: source,
        settle: false,
      );
      final button = tester.widget<IconButton>(
        find.byKey(const Key('refresh-execution-metrics')),
      );
      expect(button.onPressed, isNull);
      await tester.pump();
      expect(source.calls, 1);
      pending.complete(_metrics());
      await tester.pumpAndSettle();
    });

    testWidgets('rebuilds no ejecutan consultas adicionales', (tester) async {
      final source = _FakeMetricsSource()..enqueueValue(_metrics());
      await _pumpSection(tester, user: _psychologistA, source: source);
      await tester.pumpWidget(
        _sectionApp(user: _psychologistA, source: source),
      );
      await tester.pumpAndSettle();
      expect(source.calls, 1);
    });

    testWidgets('volver a visualizar el dashboard actualiza los conteos', (
      tester,
    ) async {
      final source = _FakeMetricsSource()
        ..enqueueValue(_metrics())
        ..enqueueValue(_metrics(total: 2, completed: 1));
      await tester.pumpWidget(
        _sectionApp(user: _psychologistA, source: source, isVisible: false),
      );
      await tester.pumpAndSettle();
      expect(source.calls, 0);
      await tester.pumpWidget(
        _sectionApp(user: _psychologistA, source: source, isVisible: true),
      );
      await tester.pumpAndSettle();
      expect(source.calls, 1);
      await tester.pumpWidget(
        _sectionApp(user: _psychologistA, source: source, isVisible: false),
      );
      await tester.pumpWidget(
        _sectionApp(user: _psychologistA, source: source, isVisible: true),
      );
      await tester.pumpAndSettle();
      expect(source.calls, 2);
      expect(find.text('2'), findsOneWidget);
    });

    testWidgets('un cambio de psicologo consulta el nuevo UID', (tester) async {
      final source = _FakeMetricsSource()
        ..enqueueValue(_metrics())
        ..enqueueValue(_metrics(total: 7, completed: 5, interrupted: 1));
      await _pumpSection(tester, user: _psychologistA, source: source);
      await tester.pumpWidget(
        _sectionApp(user: _psychologistB, source: source),
      );
      await tester.pumpAndSettle();
      expect(source.requestedIds, ['psych-a', 'psych-b']);
      expect(find.text('7'), findsOneWidget);
    });

    testWidgets('una respuesta antigua no sobrescribe al usuario nuevo', (
      tester,
    ) async {
      final first = Completer<PsychologistExecutionMetrics>();
      final second = Completer<PsychologistExecutionMetrics>();
      final source = _FakeMetricsSource()
        ..enqueueFuture(first.future)
        ..enqueueFuture(second.future);
      await _pumpSection(
        tester,
        user: _psychologistA,
        source: source,
        settle: false,
      );
      await tester.pumpWidget(
        _sectionApp(user: _psychologistB, source: source),
      );
      second.complete(_metrics(total: 8, completed: 6, interrupted: 1));
      await tester.pumpAndSettle();
      expect(find.text('8'), findsOneWidget);
      first.complete(_metrics(total: 99, completed: 99, interrupted: 0));
      await tester.pumpAndSettle();
      expect(find.text('99'), findsNothing);
      expect(find.text('8'), findsOneWidget);
    });

    testWidgets('produccion mantiene el modulo oculto y sin consultas', (
      tester,
    ) async {
      final source = _FakeMetricsSource()..enqueueValue(_metrics());
      await tester.pumpWidget(
        _sectionApp(user: _psychologistA, source: source, enabled: false),
      );
      await tester.pumpAndSettle();
      expect(source.calls, 0);
      expect(find.byKey(const Key('execution-metrics-section')), findsNothing);
      expect(find.text('Actividad en CalmaTEA'), findsNothing);
    });

    testWidgets('no presenta evaluaciones clinicas ni score universal', (
      tester,
    ) async {
      final source = _FakeMetricsSource()..enqueueValue(_metrics());
      await _pumpSection(tester, user: _psychologistA, source: source);
      expect(find.textContaining('score'), findsNothing);
      expect(find.textContaining('mejoría'), findsNothing);
      expect(find.textContaining('diagnóstico'), findsNothing);
      expect(find.textContaining('efectividad'), findsNothing);
    });

    testWidgets('no ofrece operaciones de escritura', (tester) async {
      final source = _FakeMetricsSource()..enqueueValue(_metrics());
      await _pumpSection(tester, user: _psychologistA, source: source);
      expect(find.textContaining('Editar'), findsNothing);
      expect(find.textContaining('Eliminar'), findsNothing);
      expect(find.textContaining('Finalizar'), findsNothing);
    });

    testWidgets('no presenta una sesion sin cierre como conexion actual', (
      tester,
    ) async {
      final source = _FakeMetricsSource()..enqueueValue(_metrics());
      await _pumpSection(tester, user: _psychologistA, source: source);
      expect(find.text('Sesiones sin cierre registrado'), findsOneWidget);
      expect(find.textContaining('conectado'), findsNothing);
      expect(find.textContaining('abandon'), findsNothing);
    });

    testWidgets('la actualizacion manual tiene etiqueta accesible', (
      tester,
    ) async {
      final source = _FakeMetricsSource()..enqueueValue(_metrics());
      await _pumpSection(tester, user: _psychologistA, source: source);
      expect(find.byTooltip('Actualizar estadísticas'), findsOneWidget);
    });

    testWidgets('no etiqueta los conteos como diarios o mensuales', (
      tester,
    ) async {
      final source = _FakeMetricsSource()..enqueueValue(_metrics());
      await _pumpSection(tester, user: _psychologistA, source: source);
      expect(find.textContaining('hoy'), findsNothing);
      expect(find.textContaining('este mes'), findsNothing);
      expect(find.textContaining('del día'), findsNothing);
    });

    testWidgets('no muestra respuestas ni contenido personal infantil', (
      tester,
    ) async {
      final source = _FakeMetricsSource()..enqueueValue(_metrics());
      await _pumpSection(tester, user: _psychologistA, source: source);
      expect(find.textContaining('respuesta'), findsNothing);
      expect(find.textContaining('pictograma seleccionado'), findsNothing);
      expect(find.textContaining('coordenada'), findsNothing);
    });

    testWidgets('conserva los ultimos datos si una actualizacion falla', (
      tester,
    ) async {
      final source = _FakeMetricsSource()
        ..enqueueValue(_metrics(total: 5, completed: 3, interrupted: 1))
        ..enqueueError(Exception('offline'));
      await _pumpSection(tester, user: _psychologistA, source: source);
      await tester.tap(find.byKey(const Key('refresh-execution-metrics')));
      await tester.pumpAndSettle();
      expect(find.text('5'), findsOneWidget);
      expect(find.textContaining('últimos datos confirmados'), findsOneWidget);
    });
  });

  test('ActivityStatus conserva su contrato sin estados de sesion', () {
    expect(ActivityStatus.values.map((status) => status.name), [
      'assigned',
      'inProgress',
      'completed',
      'cancelled',
    ]);
  });

  test('las metricas nuevas no alteran el resumen existente', () {
    const summary = DashboardSummary(
      patientsCount: 4,
      activeTherapiesCount: 2,
      pendingActivitiesCount: 3,
    );
    final metrics = _metrics();
    expect(summary.patientsCount, 4);
    expect(summary.activeTherapiesCount, 2);
    expect(summary.pendingActivitiesCount, 3);
    expect(metrics.totalExecutions, 3);
  });
}

final _psychologistA = UserModel(
  id: 'psych-a',
  name: 'Psicóloga A',
  email: 'a@calmatea.test',
  role: UserRole.psychologist,
  createdAt: DateTime.utc(2026, 1, 1),
);

final _psychologistB = UserModel(
  id: 'psych-b',
  name: 'Psicólogo B',
  email: 'b@calmatea.test',
  role: UserRole.psychologist,
  createdAt: DateTime.utc(2026, 1, 1),
);

final _childUser = UserModel(
  id: 'child-a-auth',
  name: 'Paciente',
  email: 'child@calmatea.test',
  role: UserRole.child,
  childId: 'child-a',
  createdAt: DateTime.utc(2026, 1, 1),
);

PsychologistExecutionMetrics _metrics({
  int total = 3,
  int completed = 1,
  int interrupted = 1,
}) {
  return PsychologistExecutionMetrics(
    totalExecutions: total,
    completedExecutions: completed,
    interruptedExecutions: interrupted,
    unclosedExecutions: total - completed - interrupted,
  );
}

Widget _sectionApp({
  required UserModel user,
  required PsychologistExecutionMetricsDataSource source,
  bool enabled = true,
  bool isVisible = true,
}) {
  return MaterialApp(
    home: Scaffold(
      body: ExecutionMetricsSection(
        key: const ValueKey('execution-section'),
        user: user,
        enabled: enabled,
        isVisible: isVisible,
        dataSource: source,
      ),
    ),
  );
}

Future<void> _pumpSection(
  WidgetTester tester, {
  required UserModel user,
  required PsychologistExecutionMetricsDataSource source,
  bool settle = true,
}) async {
  await tester.pumpWidget(_sectionApp(user: user, source: source));
  if (settle) {
    await tester.pumpAndSettle();
  } else {
    await tester.pump();
  }
}

class _FakeMetricsSource implements PsychologistExecutionMetricsDataSource {
  final List<Future<PsychologistExecutionMetrics> Function()> _responses = [];
  final List<String> requestedIds = [];

  int get calls => requestedIds.length;

  void enqueueValue(PsychologistExecutionMetrics metrics) {
    _responses.add(() async => metrics);
  }

  void enqueueError(Object error) {
    _responses.add(() async => throw error);
  }

  void enqueueFuture(Future<PsychologistExecutionMetrics> future) {
    _responses.add(() => future);
  }

  @override
  Future<PsychologistExecutionMetrics> loadMetrics({
    required String psychologistId,
  }) {
    requestedIds.add(psychologistId);
    if (_responses.isEmpty) {
      throw StateError('No hay respuesta de prueba configurada.');
    }
    return _responses.removeAt(0)();
  }
}
