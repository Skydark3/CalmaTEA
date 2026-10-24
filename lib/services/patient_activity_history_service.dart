import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../models/activity_execution_result_model.dart';
import '../models/child_model.dart';
import '../models/patient_activity_history_model.dart';
import 'activity_execution_firestore_mapper.dart';
import 'activity_service.dart';
import 'firestore_service.dart';

abstract interface class PatientActivityHistoryDataSource {
  Future<PatientActivityHistoryPage> loadFirstPage({required ChildModel child});

  Future<PatientActivityHistoryPage> loadNextPage({required ChildModel child});

  Future<ActivityExecutionResultModel?> getResult({
    required PatientActivityHistoryEntry entry,
  });
}

class PatientActivityHistoryAccessDenied implements Exception {
  const PatientActivityHistoryAccessDenied();
}

class PatientActivityHistoryDataException implements Exception {
  final String message;

  const PatientActivityHistoryDataException(this.message);

  @override
  String toString() => message;
}

/// Lectura profesional, acotada y paginada del historial de un paciente.
///
/// El cursor Firestore permanece encapsulado para no introducir Firebase en
/// los modelos ni en los widgets.
class PatientActivityHistoryService
    implements PatientActivityHistoryDataSource {
  static const int pageSize = 20;

  final FirebaseAuth _auth;
  final FirestoreService _firestoreService;
  final ActivityService _activityService;

  DocumentSnapshot<Map<String, dynamic>>? _lastDocument;
  String? _activeChildId;
  String? _activePsychologistId;
  bool _hasMore = true;

  PatientActivityHistoryService({
    FirebaseAuth? auth,
    FirestoreService? firestoreService,
    ActivityService? activityService,
  }) : _auth = auth ?? FirebaseAuth.instance,
       _firestoreService = firestoreService ?? FirestoreService(),
       _activityService =
           activityService ??
           ActivityService(firestoreService: firestoreService);

  @override
  Future<PatientActivityHistoryPage> loadFirstPage({
    required ChildModel child,
  }) async {
    _lastDocument = null;
    _hasMore = true;
    _activeChildId = null;
    _activePsychologistId = null;

    final psychologistId = _requireAuthenticatedUid();
    await _verifyProfessionalAndChild(child, psychologistId);
    _activeChildId = child.id;
    _activePsychologistId = psychologistId;
    return _loadPage(child: child, psychologistId: psychologistId);
  }

  @override
  Future<PatientActivityHistoryPage> loadNextPage({
    required ChildModel child,
  }) async {
    final psychologistId = _requireAuthenticatedUid();
    if (_activeChildId != child.id ||
        _activePsychologistId != psychologistId ||
        child.psychologistId != psychologistId) {
      throw const PatientActivityHistoryAccessDenied();
    }
    if (!_hasMore) {
      return PatientActivityHistoryPage(entries: const [], hasMore: false);
    }
    return _loadPage(child: child, psychologistId: psychologistId);
  }

  @override
  Future<ActivityExecutionResultModel?> getResult({
    required PatientActivityHistoryEntry entry,
  }) async {
    final psychologistId = _requireAuthenticatedUid();
    final session = entry.session;
    if (_activeChildId != session.childId ||
        _activePsychologistId != psychologistId ||
        session.psychologistId != psychologistId) {
      throw const PatientActivityHistoryAccessDenied();
    }

    DocumentSnapshot<Map<String, dynamic>> document;
    try {
      document = await _firestoreService.activityResultsCollection
          .doc(session.id)
          .get();
    } on FirebaseException catch (error) {
      if (error.code == 'permission-denied') {
        throw const PatientActivityHistoryDataException(
          'No fue posible verificar el resultado de esta sesion.',
        );
      }
      rethrow;
    }
    if (!document.exists) return null;
    final data = document.data();
    if (data == null) {
      throw const PatientActivityHistoryDataException(
        'El resultado no contiene datos.',
      );
    }

    try {
      final result = ActivityExecutionFirestoreMapper.resultFromData(
        id: document.id,
        data: data,
        hasPendingWrites: document.metadata.hasPendingWrites,
      );
      final endedAt = session.endedAt;
      if (result.id != session.id ||
          result.activityId != session.activityId ||
          result.therapyId != session.therapyId ||
          result.childId != session.childId ||
          result.psychologistId != psychologistId ||
          result.childUserId != session.childUserId ||
          result.activityType != entry.activity.type ||
          endedAt == null ||
          result.completedAt.isBefore(session.startedAt) ||
          !result.completedAt.isAtSameMomentAs(endedAt)) {
        throw const FormatException(
          'El resultado no coincide con la sesion vinculada.',
        );
      }
      return result;
    } on PatientActivityHistoryDataException {
      rethrow;
    } catch (error) {
      throw PatientActivityHistoryDataException(error.toString());
    }
  }

  Future<PatientActivityHistoryPage> _loadPage({
    required ChildModel child,
    required String psychologistId,
  }) async {
    Query<Map<String, dynamic>> query = _firestoreService.sessionsCollection
        .where('psychologistId', isEqualTo: psychologistId)
        .where('childId', isEqualTo: child.id)
        .orderBy('startedAt', descending: true)
        .limit(pageSize);
    final cursor = _lastDocument;
    if (cursor != null) query = query.startAfterDocument(cursor);

    final snapshot = await query.get();
    final entries = <PatientActivityHistoryEntry>[];
    for (final document in snapshot.docs) {
      try {
        final session = ActivityExecutionFirestoreMapper.sessionFromData(
          id: document.id,
          data: document.data(),
          hasPendingWrites: document.metadata.hasPendingWrites,
        );
        if (session.psychologistId != psychologistId ||
            session.childId != child.id) {
          throw const FormatException(
            'La sesion no pertenece al profesional y paciente consultados.',
          );
        }
        final activity = await _activityService.getActivityById(
          session.activityId,
          psychologistId,
        );
        if (activity == null) {
          throw const FormatException(
            'No existe la actividad vinculada a la sesion.',
          );
        }
        entries.add(
          PatientActivityHistoryEntry(session: session, activity: activity),
        );
      } catch (error) {
        throw PatientActivityHistoryDataException(error.toString());
      }
    }

    _lastDocument = snapshot.docs.isEmpty ? _lastDocument : snapshot.docs.last;
    _hasMore = snapshot.docs.length == pageSize;
    return PatientActivityHistoryPage(entries: entries, hasMore: _hasMore);
  }

  Future<void> _verifyProfessionalAndChild(
    ChildModel child,
    String psychologistId,
  ) async {
    if (child.id.trim().isEmpty ||
        child.id.contains('/') ||
        child.psychologistId != psychologistId) {
      throw const PatientActivityHistoryAccessDenied();
    }

    final profile = await _firestoreService.usersCollection
        .doc(psychologistId)
        .get();
    if (!profile.exists || profile.data()?['role'] != 'psychologist') {
      throw const PatientActivityHistoryAccessDenied();
    }

    final childDocument = await _firestoreService.childrenCollection
        .doc(child.id)
        .get();
    if (!childDocument.exists ||
        childDocument.data()?['psychologistId'] != psychologistId) {
      throw const PatientActivityHistoryAccessDenied();
    }
  }

  String _requireAuthenticatedUid() {
    final uid = _auth.currentUser?.uid;
    if (uid == null || uid.trim().isEmpty) {
      throw const PatientActivityHistoryAccessDenied();
    }
    return uid;
  }
}
