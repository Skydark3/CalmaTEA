import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:tea_app/features/psychologist/patients/presentation/activity_execution_detail_screen.dart';
import 'package:tea_app/features/psychologist/patients/presentation/patient_activity_history_screen.dart';
import 'package:tea_app/features/psychologist/patients/presentation/widgets/execution_metrics_view.dart';
import 'package:tea_app/models/activity_execution_result_model.dart';
import 'package:tea_app/models/activity_execution_session_model.dart';
import 'package:tea_app/models/activity_model.dart';
import 'package:tea_app/models/child_model.dart';
import 'package:tea_app/models/patient_activity_history_model.dart';
import 'package:tea_app/services/patient_activity_history_service.dart';

void main() {
  group('PatientActivityHistoryScreen', () {
    testWidgets('muestra el paciente y su historial autorizado', (
      tester,
    ) async {
      final source = _FakeHistoryDataSource(
        pages: [
          PatientActivityHistoryPage(
            entries: [_entry(id: 'session-1', title: 'Secuencia diaria')],
            hasMore: false,
          ),
        ],
      );

      await _pumpHistory(tester, source: source);

      expect(find.text('Juana Martienz'), findsOneWidget);
      expect(find.text('Secuencia diaria'), findsOneWidget);
      expect(source.firstPageCalls, 1);
    });

    testWidgets('presenta acceso denegado sin exponer excepciones', (
      tester,
    ) async {
      final source = _FakeHistoryDataSource(
        firstError: const PatientActivityHistoryAccessDenied(),
      );
      await _pumpHistory(tester, source: source);
      expect(find.text('Acceso denegado'), findsOneWidget);
      expect(find.textContaining('FirebaseException'), findsNothing);
    });

    testWidgets('presenta historial vacio', (tester) async {
      await _pumpHistory(tester, source: _FakeHistoryDataSource());
      expect(
        find.text('Aún no hay ejecuciones registradas para este paciente.'),
        findsOneWidget,
      );
    });

    testWidgets('ordena las sesiones mas recientes primero', (tester) async {
      final source = _FakeHistoryDataSource(
        pages: [
          PatientActivityHistoryPage(
            entries: [
              _entry(
                id: 'old',
                title: 'Actividad anterior',
                startedAt: DateTime.utc(2026, 10, 1),
              ),
              _entry(
                id: 'new',
                title: 'Actividad reciente',
                startedAt: DateTime.utc(2026, 10, 3),
              ),
            ],
            hasMore: false,
          ),
        ],
      );
      await _pumpHistory(tester, source: source);
      expect(
        tester.getTopLeft(find.text('Actividad reciente')).dy,
        lessThan(tester.getTopLeft(find.text('Actividad anterior')).dy),
      );
    });

    test('la carga Firestore se limita a paginas de veinte', () {
      expect(PatientActivityHistoryService.pageSize, 20);
    });

    testWidgets('carga la pagina siguiente sin duplicar sesiones', (
      tester,
    ) async {
      final source = _FakeHistoryDataSource(
        pages: [
          PatientActivityHistoryPage(
            entries: [_entry(id: 'one', title: 'Primera')],
            hasMore: true,
          ),
          PatientActivityHistoryPage(
            entries: [
              _entry(id: 'one', title: 'Primera'),
              _entry(id: 'two', title: 'Segunda'),
            ],
            hasMore: false,
          ),
        ],
      );
      await _pumpHistory(tester, source: source);
      await tester.tap(find.text('Cargar más'));
      await tester.pumpAndSettle();
      expect(find.text('Primera'), findsOneWidget);
      expect(find.text('Segunda'), findsOneWidget);
      expect(source.nextPageCalls, 1);
    });

    testWidgets('muestra los tres estados reales de sesion', (tester) async {
      final source = _FakeHistoryDataSource(
        pages: [
          PatientActivityHistoryPage(
            entries: [
              _entry(id: 'active', title: 'Uno'),
              _entry(
                id: 'done',
                title: 'Dos',
                status: ActivityExecutionSessionStatus.completed,
              ),
              _entry(
                id: 'stopped',
                title: 'Tres',
                status: ActivityExecutionSessionStatus.interrupted,
              ),
            ],
            hasMore: false,
          ),
        ],
      );
      await _pumpHistory(tester, source: source);
      expect(find.text('En progreso'), findsOneWidget);
      expect(find.text('Completada'), findsOneWidget);
      expect(find.text('Interrumpida'), findsOneWidget);
    });

    testWidgets('permite reintentar despues de un error de conexion', (
      tester,
    ) async {
      final source = _FakeHistoryDataSource(
        firstError: Exception('offline'),
        pages: [
          PatientActivityHistoryPage(
            entries: [_entry(id: 'retry', title: 'Tras reintento')],
            hasMore: false,
          ),
        ],
      );
      await _pumpHistory(tester, source: source);
      expect(find.text('No pudimos cargar el historial'), findsOneWidget);
      await tester.tap(find.text('Reintentar'));
      await tester.pumpAndSettle();
      expect(find.text('Tras reintento'), findsOneWidget);
    });

    testWidgets('no consulta datos cuando el historial esta deshabilitado', (
      tester,
    ) async {
      final source = _FakeHistoryDataSource();
      await tester.pumpWidget(
        MaterialApp(
          home: PatientActivityHistoryScreen(
            child: _child,
            dataSource: source,
            historyEnabled: false,
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Historial no disponible'), findsOneWidget);
      expect(source.firstPageCalls, 0);
    });

    testWidgets('abre el detalle y permite regresar', (tester) async {
      final entry = _entry(
        id: 'detail',
        title: 'Actividad detalle',
        status: ActivityExecutionSessionStatus.completed,
      );
      final source = _FakeHistoryDataSource(
        pages: [
          PatientActivityHistoryPage(entries: [entry], hasMore: false),
        ],
        results: {
          'detail': _result(
            entry,
            SequenceExecutionMetrics(itemsCount: 3, checksCount: 2),
          ),
        },
      );
      await _pumpHistory(tester, source: source);
      await tester.tap(find.text('Actividad detalle'));
      await tester.pumpAndSettle();
      expect(find.text('Detalle de ejecución'), findsOneWidget);
      await tester.pageBack();
      await tester.pumpAndSettle();
      expect(find.text('Historial de actividades'), findsOneWidget);
    });
  });

  group('ActivityExecutionDetailScreen', () {
    testWidgets('una sesion en progreso conserva un mensaje neutral', (
      tester,
    ) async {
      await _pumpDetail(
        tester,
        entry: _entry(id: 'progress', title: 'Activa'),
      );
      expect(
        find.text('Esta ejecución aún no registra una finalización.'),
        findsOneWidget,
      );
    });

    testWidgets('una sesion interrumpida no fabrica un resultado', (
      tester,
    ) async {
      await _pumpDetail(
        tester,
        entry: _entry(
          id: 'interrupted',
          title: 'Pausada',
          status: ActivityExecutionSessionStatus.interrupted,
        ),
      );
      expect(
        find.text(
          'Esta ejecución se interrumpió y no tiene un resultado de finalización.',
        ),
        findsOneWidget,
      );
    });

    testWidgets('una sesion completada muestra su resultado', (tester) async {
      final entry = _entry(
        id: 'completed',
        title: 'Finalizada',
        status: ActivityExecutionSessionStatus.completed,
      );
      await _pumpDetail(
        tester,
        entry: entry,
        source: _FakeHistoryDataSource(
          results: {
            entry.session.id: _result(
              entry,
              SequenceExecutionMetrics(itemsCount: 4, checksCount: 3),
            ),
          },
        ),
      );
      expect(find.text('Cantidad de elementos'), findsOneWidget);
      expect(find.text('4'), findsOneWidget);
    });

    testWidgets('un resultado ausente se presenta como no disponible', (
      tester,
    ) async {
      final entry = _entry(
        id: 'missing',
        title: 'Sin resultado',
        status: ActivityExecutionSessionStatus.completed,
      );
      await _pumpDetail(tester, entry: entry);
      expect(
        find.text('Los datos del resultado no están disponibles.'),
        findsOneWidget,
      );
    });

    testWidgets('un resultado malformado no se sustituye silenciosamente', (
      tester,
    ) async {
      final entry = _entry(
        id: 'malformed',
        title: 'Dato inválido',
        status: ActivityExecutionSessionStatus.completed,
      );
      await _pumpDetail(
        tester,
        entry: entry,
        source: _FakeHistoryDataSource(
          resultErrors: {
            entry.session.id: const PatientActivityHistoryDataException(
              'malformed',
            ),
          },
        ),
      );
      expect(
        find.text('Los datos del resultado no están disponibles.'),
        findsOneWidget,
      );
    });

    testWidgets('un error de resultado ofrece reintento', (tester) async {
      final entry = _entry(
        id: 'offline-result',
        title: 'Resultado remoto',
        status: ActivityExecutionSessionStatus.completed,
      );
      final source = _FakeHistoryDataSource(
        resultErrors: {entry.session.id: Exception('offline')},
      );
      await _pumpDetail(tester, entry: entry, source: source);
      expect(find.text('No pudimos cargar el resultado.'), findsOneWidget);
      source.resultErrors.clear();
      source.results[entry.session.id] = _result(
        entry,
        SequenceExecutionMetrics(itemsCount: 2, checksCount: 1),
      );
      final retryButton = tester.widget<TextButton>(
        find.widgetWithText(TextButton, 'Reintentar'),
      );
      retryButton.onPressed!();
      await tester.pumpAndSettle();
      expect(find.text('Cantidad de elementos'), findsOneWidget);
    });

    testWidgets('no ofrece acciones de escritura', (tester) async {
      await _pumpDetail(
        tester,
        entry: _entry(id: 'read-only', title: 'Solo lectura'),
      );
      expect(find.textContaining('Editar'), findsNothing);
      expect(find.textContaining('Eliminar'), findsNothing);
      expect(find.textContaining('Finalizar sesión'), findsNothing);
    });
  });

  final metricCases = <(String, ActivityExecutionMetrics, List<String>)>[
    (
      'sequence',
      SequenceExecutionMetrics(itemsCount: 3, checksCount: 2),
      ['Cantidad de elementos', 'Comprobaciones realizadas'],
    ),
    (
      'matching',
      MatchingExecutionMetrics(relationsCompleted: 2, checksCount: 3),
      ['Relaciones completadas', 'Comprobaciones realizadas'],
    ),
    (
      'motor',
      MotorExecutionMetrics(stepsVisited: 4),
      ['Pasos visitados en pantalla'],
    ),
    (
      'emotion',
      EmotionExecutionMetrics(exercisesReviewed: 2),
      ['Ejercicios revisados'],
    ),
    (
      'dragDrop',
      DragDropExecutionMetrics(itemsPlaced: 3, checksCount: 2),
      ['Elementos colocados', 'Comprobaciones realizadas'],
    ),
    (
      'pictogram',
      PictogramExecutionMetrics(interactionsCount: 5),
      ['Interacciones realizadas'],
    ),
    (
      'tracing',
      TracingExecutionMetrics(practiceCompleted: true, strokesCount: 6),
      ['Práctica realizada', 'Trazos registrados'],
    ),
    (
      'timer',
      TimerExecutionMetrics(configuredDurationSeconds: 90, elapsedSeconds: 75),
      ['Duración configurada', 'Tiempo activo transcurrido', '1 min 30 s'],
    ),
  ];

  for (final metricCase in metricCases) {
    testWidgets('presenta metricas comprensibles de ${metricCase.$1}', (
      tester,
    ) async {
      final entry = _entry(
        id: 'metric-${metricCase.$1}',
        title: metricCase.$1,
        status: ActivityExecutionSessionStatus.completed,
        type: metricCase.$2.activityType,
      );
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ExecutionMetricsView(result: _result(entry, metricCase.$2)),
          ),
        ),
      );
      for (final label in metricCase.$3) {
        expect(find.text(label), findsOneWidget);
      }
      expect(find.textContaining('score'), findsNothing);
      expect(find.textContaining('diagnóstico'), findsNothing);
    });
  }
}

final _child = ChildModel(
  id: 'child-a',
  psychologistId: 'psych-a',
  fullName: 'Juana Martienz',
  birthDate: DateTime(2014, 5, 12),
  supportLevel: 'Nivel 1',
  createdAt: DateTime(2026, 1, 1),
);

PatientActivityHistoryEntry _entry({
  required String id,
  required String title,
  DateTime? startedAt,
  ActivityExecutionSessionStatus status =
      ActivityExecutionSessionStatus.inProgress,
  ActivityType type = ActivityType.sequence,
}) {
  final start = startedAt ?? DateTime.utc(2026, 10, 10, 14);
  final endedAt = status == ActivityExecutionSessionStatus.inProgress
      ? null
      : start.add(const Duration(minutes: 5));
  final activity = ActivityModel(
    id: 'activity-$id',
    therapyId: 'therapy-a',
    childId: _child.id,
    psychologistId: _child.psychologistId,
    title: title,
    description: '',
    type: type,
    difficulty: 1,
    instructions: '',
    configuration: const {},
    status: ActivityStatus.assigned,
    createdAt: DateTime.utc(2026, 1, 1),
  );
  final session = ActivityExecutionSessionModel(
    id: id,
    activityId: activity.id,
    therapyId: activity.therapyId,
    childId: activity.childId,
    psychologistId: activity.psychologistId,
    childUserId: 'child-user-a',
    status: status,
    startedAt: start,
    endedAt: endedAt,
  );
  return PatientActivityHistoryEntry(session: session, activity: activity);
}

ActivityExecutionResultModel _result(
  PatientActivityHistoryEntry entry,
  ActivityExecutionMetrics metrics,
) {
  return ActivityExecutionResultModel(
    id: entry.session.id,
    activityId: entry.session.activityId,
    therapyId: entry.session.therapyId,
    childId: entry.session.childId,
    psychologistId: entry.session.psychologistId,
    childUserId: entry.session.childUserId,
    activityType: entry.activity.type,
    completedAt:
        entry.session.endedAt ??
        entry.session.startedAt.add(const Duration(minutes: 5)),
    durationSeconds: 300,
    metrics: metrics,
  );
}

Future<void> _pumpHistory(
  WidgetTester tester, {
  required _FakeHistoryDataSource source,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      home: PatientActivityHistoryScreen(
        child: _child,
        dataSource: source,
        historyEnabled: true,
      ),
    ),
  );
  await tester.pumpAndSettle();
}

Future<void> _pumpDetail(
  WidgetTester tester, {
  required PatientActivityHistoryEntry entry,
  _FakeHistoryDataSource? source,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      home: ActivityExecutionDetailScreen(
        child: _child,
        entry: entry,
        dataSource: source ?? _FakeHistoryDataSource(),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

class _FakeHistoryDataSource implements PatientActivityHistoryDataSource {
  final List<PatientActivityHistoryPage> pages;
  final Map<String, ActivityExecutionResultModel?> results;
  final Map<String, Object> resultErrors;
  Object? firstError;
  int firstPageCalls = 0;
  int nextPageCalls = 0;
  int _pageIndex = 0;

  _FakeHistoryDataSource({
    List<PatientActivityHistoryPage>? pages,
    Map<String, ActivityExecutionResultModel?>? results,
    Map<String, Object>? resultErrors,
    this.firstError,
  }) : pages = pages ?? const [],
       results = results ?? {},
       resultErrors = resultErrors ?? {};

  @override
  Future<PatientActivityHistoryPage> loadFirstPage({
    required ChildModel child,
  }) async {
    firstPageCalls++;
    final error = firstError;
    if (error != null) {
      firstError = null;
      throw error;
    }
    _pageIndex = 1;
    return pages.isEmpty
        ? PatientActivityHistoryPage(entries: const [], hasMore: false)
        : pages.first;
  }

  @override
  Future<PatientActivityHistoryPage> loadNextPage({
    required ChildModel child,
  }) async {
    nextPageCalls++;
    if (_pageIndex >= pages.length) {
      return PatientActivityHistoryPage(entries: const [], hasMore: false);
    }
    return pages[_pageIndex++];
  }

  @override
  Future<ActivityExecutionResultModel?> getResult({
    required PatientActivityHistoryEntry entry,
  }) async {
    final error = resultErrors[entry.session.id];
    if (error != null) throw error;
    return results[entry.session.id];
  }
}
