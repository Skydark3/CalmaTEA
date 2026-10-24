import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../models/activity_execution_result_model.dart';
import '../models/activity_execution_session_model.dart';
import '../models/activity_model.dart';
import 'activity_execution_firestore_mapper.dart';
import 'firestore_service.dart';

abstract interface class ActiveExecutionSessionCoordinator {
  Future<String> startSession({required String activityId});

  Future<void> interruptSession(String sessionId);
}

class ActiveExecutionSessionConflict implements Exception {
  final String sessionId;
  final String activityId;
  final bool canInterrupt;

  const ActiveExecutionSessionConflict({
    required this.sessionId,
    required this.activityId,
    required this.canInterrupt,
  });
}

class ActiveExecutionSessionDataException implements Exception {
  final String message;

  const ActiveExecutionSessionDataException(this.message);

  @override
  String toString() => message;
}

/// Coordina el ciclo de vida de una ejecución infantil.
///
/// La creación de resultados existe exclusivamente en [completeSession] para
/// que el cierre de la sesión y su resultado se confirmen en una transacción.
class ActivityExecutionSessionService
    implements ActiveExecutionSessionCoordinator {
  final FirebaseAuth _auth;
  final FirestoreService _firestoreService;

  ActivityExecutionSessionService({
    FirebaseAuth? auth,
    FirestoreService? firestoreService,
  }) : _auth = auth ?? FirebaseAuth.instance,
       _firestoreService = firestoreService ?? FirestoreService();

  CollectionReference<Map<String, dynamic>> get _users =>
      _firestoreService.usersCollection;

  CollectionReference<Map<String, dynamic>> get _activities =>
      _firestoreService.activitiesCollection;

  CollectionReference<Map<String, dynamic>> get _sessions =>
      _firestoreService.sessionsCollection;

  CollectionReference<Map<String, dynamic>> get _results =>
      _firestoreService.activityResultsCollection;

  CollectionReference<Map<String, dynamic>> get _activeSessions =>
      _firestoreService.activeExecutionSessionsCollection;

  Future<String> startSession({required String activityId}) async {
    _requireIdentifier(activityId, 'activityId');
    final uid = _requireAuthenticatedUid();

    for (var attempt = 0; attempt < 2; attempt++) {
      final newSessionReference = _sessions.doc();
      final decision = await _firestoreService.instance.runTransaction(
        (transaction) async {
          final profile = await transaction.get(_users.doc(uid));
          final activity = await transaction.get(_activities.doc(activityId));
          final identity = _childIdentityFromProfile(profile, uid);
          final activityData = _authorizedActivityData(
            activity,
            identity.childId,
            requireAvailableStatus: true,
          );
          final activeReference = _activeSessions.doc(identity.childId);
          final activeDocument = await transaction.get(activeReference);

          if (activeDocument.exists) {
            final active = _activeSessionFromDocument(activeDocument);
            _ensureActiveSessionBelongsToChild(
              active,
              childId: identity.childId,
            );
            final activeSessionDocument = await transaction.get(
              _sessions.doc(active.sessionId),
            );
            if (!activeSessionDocument.exists) {
              throw const ActiveExecutionSessionDataException(
                'El bloqueo activo no tiene una sesión vinculada.',
              );
            }
            final activeSession = _sessionFromDocument(activeSessionDocument);
            _ensureLockMatchesSession(active, activeSession);

            if (activeSession.status ==
                ActivityExecutionSessionStatus.inProgress) {
              if (active.activityId == activityId &&
                  active.childUserId == uid) {
                return _SessionStartDecision.recovered(active.sessionId);
              }
              throw ActiveExecutionSessionConflict(
                sessionId: active.sessionId,
                activityId: active.activityId,
                canInterrupt: active.childUserId == uid,
              );
            }

            transaction.delete(activeReference);
            return const _SessionStartDecision.retry();
          }

          final timestamp = FieldValue.serverTimestamp();
          transaction.set(newSessionReference, {
            'id': newSessionReference.id,
            'activityId': activity.id,
            'therapyId': activityData.therapyId,
            'childId': identity.childId,
            'psychologistId': activityData.psychologistId,
            'childUserId': uid,
            'status': ActivityExecutionSessionStatus.inProgress.name,
            'startedAt': timestamp,
          });
          transaction.set(activeReference, {
            'sessionId': newSessionReference.id,
            'activityId': activity.id,
            'childId': identity.childId,
            'psychologistId': activityData.psychologistId,
            'childUserId': uid,
            'startedAt': timestamp,
          });
          return _SessionStartDecision.created(newSessionReference.id);
        },
      );

      if (!decision.shouldRetry) return decision.sessionId!;
    }

    throw const ActiveExecutionSessionDataException(
      'No fue posible liberar un bloqueo de sesión antiguo.',
    );
  }

  Future<ActivityExecutionSessionModel?> getOwnSession(String sessionId) async {
    _requireIdentifier(sessionId, 'sessionId');
    final uid = _requireAuthenticatedUid();
    final document = await _sessions.doc(sessionId).get();
    if (!document.exists) return null;

    final session = _sessionFromDocument(document);
    if (session.childUserId != uid) {
      throw StateError('La sesión no pertenece al usuario autenticado.');
    }
    return session;
  }

  Future<void> completeSession({
    required String sessionId,
    required ActivityExecutionMetrics metrics,
    int? durationSeconds,
  }) async {
    _requireIdentifier(sessionId, 'sessionId');
    if (durationSeconds != null && durationSeconds < 0) {
      throw ArgumentError.value(
        durationSeconds,
        'durationSeconds',
        'No puede ser negativo.',
      );
    }

    final uid = _requireAuthenticatedUid();
    final sessionReference = _sessions.doc(sessionId);
    final resultReference = _results.doc(sessionId);

    await _firestoreService.instance.runTransaction((transaction) async {
      final sessionDocument = await transaction.get(sessionReference);
      if (!sessionDocument.exists) {
        throw StateError('La sesión no existe.');
      }

      final session = _sessionFromDocument(sessionDocument);
      final activeReference = _activeSessions.doc(session.childId);
      final activeDocument = await transaction.get(activeReference);

      if (session.status == ActivityExecutionSessionStatus.completed) {
        final existingResult = await transaction.get(resultReference);
        _ensurePersistedCompletion(
          session: session,
          resultDocument: existingResult,
          uid: uid,
          expectedType: metrics.activityType,
        );
        if (activeDocument.exists) {
          final active = _activeSessionFromDocument(activeDocument);
          if (active.sessionId == session.id) {
            transaction.delete(activeReference);
          }
        }
        return;
      }

      _ensureOwnInProgressSession(session, uid);
      _requireMatchingActiveSession(activeDocument, session, uid);

      final activityDocument = await transaction.get(
        _activities.doc(session.activityId),
      );
      final activityData = _authorizedActivityData(
        activityDocument,
        session.childId,
        requireAvailableStatus: false,
      );
      _ensureSessionMatchesActivity(session, activityData);
      if (metrics.activityType != activityData.type) {
        throw ArgumentError(
          'Las métricas no corresponden al tipo de la actividad.',
        );
      }

      transaction.update(sessionReference, {
        'status': ActivityExecutionSessionStatus.completed.name,
        'endedAt': FieldValue.serverTimestamp(),
      });
      transaction.set(resultReference, {
        'id': sessionId,
        'activityId': session.activityId,
        'therapyId': session.therapyId,
        'childId': session.childId,
        'psychologistId': session.psychologistId,
        'childUserId': uid,
        'activityType': activityData.type.name,
        'completedAt': FieldValue.serverTimestamp(),
        if (durationSeconds != null) 'durationSeconds': durationSeconds,
        'metrics': metrics.toMap(),
        'schemaVersion': ActivityExecutionResultModel.currentSchemaVersion,
      });
      transaction.delete(activeReference);
    });
  }

  Future<void> interruptSession(String sessionId) async {
    _requireIdentifier(sessionId, 'sessionId');
    final uid = _requireAuthenticatedUid();
    final sessionReference = _sessions.doc(sessionId);

    await _firestoreService.instance.runTransaction((transaction) async {
      final document = await transaction.get(sessionReference);
      if (!document.exists) throw StateError('La sesión no existe.');

      final session = _sessionFromDocument(document);
      final activeReference = _activeSessions.doc(session.childId);
      final activeDocument = await transaction.get(activeReference);

      if (session.status == ActivityExecutionSessionStatus.interrupted) {
        if (session.childUserId != uid) {
          throw StateError('La sesión no pertenece al usuario autenticado.');
        }
        if (activeDocument.exists) {
          final active = _activeSessionFromDocument(activeDocument);
          if (active.sessionId == session.id) {
            transaction.delete(activeReference);
          }
        }
        return;
      }

      _ensureOwnInProgressSession(session, uid);
      _requireMatchingActiveSession(activeDocument, session, uid);
      transaction.update(sessionReference, {
        'status': ActivityExecutionSessionStatus.interrupted.name,
        'endedAt': FieldValue.serverTimestamp(),
      });
      transaction.delete(activeReference);
    });
  }

  Stream<List<ActivityExecutionSessionModel>> watchPsychologistSessions({
    String? childId,
    String? activityId,
  }) {
    final psychologistId = _requireAuthenticatedUid();
    Query<Map<String, dynamic>> query = _sessions.where(
      'psychologistId',
      isEqualTo: psychologistId,
    );
    if (childId != null) {
      _requireIdentifier(childId, 'childId');
      query = query.where('childId', isEqualTo: childId);
    }
    if (activityId != null) {
      _requireIdentifier(activityId, 'activityId');
      query = query.where('activityId', isEqualTo: activityId);
    }

    return query.snapshots().map((snapshot) {
      final sessions = snapshot.docs.map(_sessionFromDocument).toList();
      sessions.sort(
        (first, second) => second.startedAt.compareTo(first.startedAt),
      );
      return sessions;
    });
  }

  static bool isAllowedTransition(
    ActivityExecutionSessionStatus from,
    ActivityExecutionSessionStatus to,
  ) {
    return from == ActivityExecutionSessionStatus.inProgress &&
        (to == ActivityExecutionSessionStatus.completed ||
            to == ActivityExecutionSessionStatus.interrupted);
  }

  String _requireAuthenticatedUid() {
    final uid = _auth.currentUser?.uid;
    if (uid == null || uid.trim().isEmpty) {
      throw StateError('No hay una sesión autenticada disponible.');
    }
    return uid;
  }

  _ChildIdentity _childIdentityFromProfile(
    DocumentSnapshot<Map<String, dynamic>> document,
    String uid,
  ) {
    final data = document.data();
    final childId = data?['childId'];
    if (!document.exists ||
        data?['role'] != 'child' ||
        childId is! String ||
        childId.trim().isEmpty ||
        childId.contains('/')) {
      throw StateError('La cuenta no tiene un vínculo infantil válido.');
    }
    return _ChildIdentity(childId: childId);
  }

  _AuthorizedActivityData _authorizedActivityData(
    DocumentSnapshot<Map<String, dynamic>> document,
    String childId, {
    required bool requireAvailableStatus,
  }) {
    final data = document.data();
    if (!document.exists || data == null || data['childId'] != childId) {
      throw StateError('La actividad no pertenece al paciente autenticado.');
    }

    final therapyId = _requiredString(data, 'therapyId');
    final psychologistId = _requiredString(data, 'psychologistId');
    final type = _activityTypeFromValue(data['type']);
    final status = _activityStatusFromValue(data['status']);
    if (requireAvailableStatus &&
        status != ActivityStatus.assigned &&
        status != ActivityStatus.inProgress) {
      throw StateError('La actividad no está disponible para ejecución.');
    }

    return _AuthorizedActivityData(
      therapyId: therapyId,
      psychologistId: psychologistId,
      type: type,
    );
  }

  ActivityExecutionSessionModel _sessionFromDocument(
    DocumentSnapshot<Map<String, dynamic>> document,
  ) {
    final data = document.data();
    if (!document.exists || data == null) {
      throw StateError('La sesión no existe.');
    }
    return ActivityExecutionFirestoreMapper.sessionFromData(
      id: document.id,
      data: data,
      hasPendingWrites: document.metadata.hasPendingWrites,
    );
  }

  _ActiveExecutionSession _activeSessionFromDocument(
    DocumentSnapshot<Map<String, dynamic>> document,
  ) {
    final data = document.data();
    if (!document.exists || data == null) {
      throw const ActiveExecutionSessionDataException(
        'El bloqueo de ejecución no existe.',
      );
    }
    final startedAt = data['startedAt'];
    if (startedAt is! Timestamp) {
      throw const ActiveExecutionSessionDataException(
        'El bloqueo de ejecución contiene una fecha inválida.',
      );
    }
    return _ActiveExecutionSession(
      sessionId: _requiredString(data, 'sessionId'),
      activityId: _requiredString(data, 'activityId'),
      childId: _requiredString(data, 'childId'),
      psychologistId: _requiredString(data, 'psychologistId'),
      childUserId: _requiredString(data, 'childUserId'),
      startedAt: startedAt.toDate(),
    );
  }

  _ActiveExecutionSession _requireMatchingActiveSession(
    DocumentSnapshot<Map<String, dynamic>> document,
    ActivityExecutionSessionModel session,
    String uid,
  ) {
    if (!document.exists) {
      throw const ActiveExecutionSessionDataException(
        'La sesión no conserva su bloqueo activo.',
      );
    }
    final active = _activeSessionFromDocument(document);
    if (active.childUserId != uid) {
      throw StateError('El bloqueo no pertenece al usuario autenticado.');
    }
    _ensureLockMatchesSession(active, session);
    return active;
  }

  void _ensureActiveSessionBelongsToChild(
    _ActiveExecutionSession active, {
    required String childId,
  }) {
    if (active.childId != childId) {
      throw const ActiveExecutionSessionDataException(
        'El bloqueo no pertenece al paciente vinculado.',
      );
    }
  }

  void _ensureLockMatchesSession(
    _ActiveExecutionSession active,
    ActivityExecutionSessionModel session,
  ) {
    if (active.sessionId != session.id ||
        active.activityId != session.activityId ||
        active.childId != session.childId ||
        active.psychologistId != session.psychologistId ||
        active.childUserId != session.childUserId ||
        !active.startedAt.isAtSameMomentAs(session.startedAt)) {
      throw const ActiveExecutionSessionDataException(
        'El bloqueo activo no coincide con la sesión vinculada.',
      );
    }
  }

  void _ensurePersistedCompletion({
    required ActivityExecutionSessionModel session,
    required DocumentSnapshot<Map<String, dynamic>> resultDocument,
    required String uid,
    required ActivityType expectedType,
  }) {
    if (session.childUserId != uid || !resultDocument.exists) {
      throw StateError('La finalización de la sesión no está completa.');
    }
    final data = resultDocument.data();
    if (data == null) {
      throw StateError('El resultado guardado no contiene datos.');
    }
    final result = ActivityExecutionFirestoreMapper.resultFromData(
      id: resultDocument.id,
      data: data,
      hasPendingWrites: resultDocument.metadata.hasPendingWrites,
    );
    if (result.id != session.id ||
        result.activityId != session.activityId ||
        result.therapyId != session.therapyId ||
        result.childId != session.childId ||
        result.psychologistId != session.psychologistId ||
        result.childUserId != session.childUserId ||
        result.activityType != expectedType) {
      throw const ActiveExecutionSessionDataException(
        'El resultado existente no coincide con la sesión completada.',
      );
    }
  }

  void _ensureOwnInProgressSession(
    ActivityExecutionSessionModel session,
    String uid,
  ) {
    if (session.childUserId != uid) {
      throw StateError('La sesión no pertenece al usuario autenticado.');
    }
    if (!isAllowedTransition(
      session.status,
      ActivityExecutionSessionStatus.completed,
    )) {
      throw StateError('La sesión ya está cerrada.');
    }
  }

  void _ensureSessionMatchesActivity(
    ActivityExecutionSessionModel session,
    _AuthorizedActivityData activity,
  ) {
    if (session.therapyId != activity.therapyId ||
        session.psychologistId != activity.psychologistId) {
      throw StateError('La sesión no coincide con la actividad vinculada.');
    }
  }

  static void _requireIdentifier(String value, String field) {
    if (value.trim().isEmpty || value.contains('/')) {
      throw ArgumentError.value(value, field, 'Identificador inválido.');
    }
  }

  static String _requiredString(Map<String, dynamic> data, String field) {
    final value = data[field];
    if (value is! String || value.trim().isEmpty) {
      throw FormatException('$field debe ser un String no vacío.');
    }
    return value;
  }

  static ActivityType _activityTypeFromValue(Object? value) {
    if (value is String) {
      for (final type in ActivityType.values) {
        if (type.name == value) return type;
      }
    }
    throw const FormatException('Tipo de actividad ausente o inválido.');
  }

  static ActivityStatus _activityStatusFromValue(Object? value) {
    if (value is String) {
      for (final status in ActivityStatus.values) {
        if (status.name == value) return status;
      }
    }
    throw const FormatException('Estado de actividad ausente o inválido.');
  }
}

class _ChildIdentity {
  final String childId;

  const _ChildIdentity({required this.childId});
}

class _AuthorizedActivityData {
  final String therapyId;
  final String psychologistId;
  final ActivityType type;

  const _AuthorizedActivityData({
    required this.therapyId,
    required this.psychologistId,
    required this.type,
  });
}

class _ActiveExecutionSession {
  final String sessionId;
  final String activityId;
  final String childId;
  final String psychologistId;
  final String childUserId;
  final DateTime startedAt;

  const _ActiveExecutionSession({
    required this.sessionId,
    required this.activityId,
    required this.childId,
    required this.psychologistId,
    required this.childUserId,
    required this.startedAt,
  });
}

class _SessionStartDecision {
  final String? sessionId;
  final bool shouldRetry;

  const _SessionStartDecision.created(String value)
    : sessionId = value,
      shouldRetry = false;

  const _SessionStartDecision.recovered(String value)
    : sessionId = value,
      shouldRetry = false;

  const _SessionStartDecision.retry()
    : sessionId = null,
      shouldRetry = true;
}
