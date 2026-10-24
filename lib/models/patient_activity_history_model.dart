import 'activity_execution_session_model.dart';
import 'activity_model.dart';

/// Una ejecucion profesional ya vinculada con su actividad.
class PatientActivityHistoryEntry {
  final ActivityExecutionSessionModel session;
  final ActivityModel activity;

  PatientActivityHistoryEntry({required this.session, required this.activity}) {
    if (session.activityId != activity.id ||
        session.therapyId != activity.therapyId ||
        session.childId != activity.childId ||
        session.psychologistId != activity.psychologistId) {
      throw const FormatException(
        'La sesion no coincide con la actividad vinculada.',
      );
    }
  }
}

/// Pagina acotada del historial; no expone cursores de Firebase a la UI.
class PatientActivityHistoryPage {
  final List<PatientActivityHistoryEntry> entries;
  final bool hasMore;

  PatientActivityHistoryPage({
    required List<PatientActivityHistoryEntry> entries,
    required this.hasMore,
  }) : entries = List.unmodifiable(entries);
}
