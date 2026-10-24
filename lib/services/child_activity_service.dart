import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../core/constants/firestore_collections.dart';
import '../models/activity_model.dart';
import '../models/user_model.dart';

/// Servicio de solo lectura para las actividades visibles por una cuenta child.
class ChildActivityService {
  final FirebaseAuth _auth;
  final FirebaseFirestore _firestore;

  ChildActivityService({FirebaseAuth? auth, FirebaseFirestore? firestore})
    : _auth = auth ?? FirebaseAuth.instance,
      _firestore = firestore ?? FirebaseFirestore.instance;

  Stream<List<ActivityModel>> watchAvailableActivities() async* {
    final uid = _auth.currentUser?.uid;
    if (uid == null) {
      throw StateError('No hay una sesión autenticada disponible.');
    }

    final profile = await _firestore
        .collection(FirestoreCollections.users)
        .doc(uid)
        .get();
    final data = profile.data();
    final role = UserRole.fromString(data?['role'] as String?);
    final childId = (data?['childId'] as String?)?.trim();

    if (!profile.exists ||
        role != UserRole.child ||
        childId == null ||
        childId.isEmpty ||
        childId.contains('/')) {
      throw StateError('La cuenta no tiene un vínculo infantil válido.');
    }

    yield* _firestore
        .collection(FirestoreCollections.activities)
        .where('childId', isEqualTo: childId)
        .where(
          'status',
          whereIn: [
            ActivityStatus.assigned.name,
            ActivityStatus.inProgress.name,
          ],
        )
        .snapshots()
        .map((snapshot) {
          final activities = snapshot.docs.map(_activityFromDocument).toList();
          activities.sort(
            (first, second) => second.createdAt.compareTo(first.createdAt),
          );
          return activities;
        });
  }

  ActivityModel _activityFromDocument(
    QueryDocumentSnapshot<Map<String, dynamic>> document,
  ) {
    final data = Map<String, dynamic>.from(document.data());
    final createdAt = _dateTimeFromFirestore(data['createdAt']);
    if (createdAt == null) {
      throw StateError('La actividad no tiene una fecha válida.');
    }
    data['createdAt'] = createdAt.toIso8601String();

    final updatedAt = _dateTimeFromFirestore(data['updatedAt']);
    data['updatedAt'] = updatedAt?.toIso8601String();

    return ActivityModel.fromMap(data, id: document.id);
  }

  DateTime? _dateTimeFromFirestore(Object? value) {
    if (value is Timestamp) return value.toDate();
    if (value is DateTime) return value;
    if (value is String) return DateTime.tryParse(value);
    return null;
  }
}
