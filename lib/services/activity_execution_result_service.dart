import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../models/activity_execution_result_model.dart';
import 'activity_execution_firestore_mapper.dart';
import 'firestore_service.dart';

/// Servicio de solo lectura para resultados consolidados.
///
/// Los resultados se crean únicamente mediante
/// `ActivityExecutionSessionService.completeSession`.
class ActivityExecutionResultService {
  final FirebaseAuth _auth;
  final FirestoreService _firestoreService;

  ActivityExecutionResultService({
    FirebaseAuth? auth,
    FirestoreService? firestoreService,
  }) : _auth = auth ?? FirebaseAuth.instance,
       _firestoreService = firestoreService ?? FirestoreService();

  CollectionReference<Map<String, dynamic>> get _results =>
      _firestoreService.activityResultsCollection;

  Future<ActivityExecutionResultModel?> getOwnResult(String sessionId) async {
    _requireIdentifier(sessionId, 'sessionId');
    final uid = _requireAuthenticatedUid();
    final document = await _results.doc(sessionId).get();
    if (!document.exists) return null;

    final result = _resultFromDocument(document);
    if (result.childUserId != uid) {
      throw StateError('El resultado no pertenece al usuario autenticado.');
    }
    return result;
  }

  Stream<List<ActivityExecutionResultModel>> watchPsychologistResults({
    String? childId,
    String? activityId,
  }) {
    final psychologistId = _requireAuthenticatedUid();
    Query<Map<String, dynamic>> query = _results.where(
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
      final results = snapshot.docs.map(_resultFromDocument).toList();
      results.sort(
        (first, second) => second.completedAt.compareTo(first.completedAt),
      );
      return results;
    });
  }

  ActivityExecutionResultModel _resultFromDocument(
    DocumentSnapshot<Map<String, dynamic>> document,
  ) {
    final data = document.data();
    if (!document.exists || data == null) {
      throw StateError('El resultado no existe.');
    }
    return ActivityExecutionFirestoreMapper.resultFromData(
      id: document.id,
      data: data,
      hasPendingWrites: document.metadata.hasPendingWrites,
    );
  }

  String _requireAuthenticatedUid() {
    final uid = _auth.currentUser?.uid;
    if (uid == null || uid.trim().isEmpty) {
      throw StateError('No hay una sesión autenticada disponible.');
    }
    return uid;
  }

  static void _requireIdentifier(String value, String field) {
    if (value.trim().isEmpty || value.contains('/')) {
      throw ArgumentError.value(value, field, 'Identificador inválido.');
    }
  }
}
