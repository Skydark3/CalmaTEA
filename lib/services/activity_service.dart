import 'package:cloud_firestore/cloud_firestore.dart';

import '../features/activities/config/activity_configuration_factory.dart';
import '../models/activity_model.dart';
import 'firestore_service.dart';

/// Encapsula las operaciones de Firestore relacionadas con actividades.
class ActivityService {
  final FirestoreService _firestoreService;

  ActivityService({FirestoreService? firestoreService})
    : _firestoreService = firestoreService ?? FirestoreService();

  CollectionReference<Map<String, dynamic>> get _activities =>
      _firestoreService.activitiesCollection;

  String createActivityId() => _activities.doc().id;

  Future<String> createActivity(ActivityModel activity) async {
    _ensureValidConfiguration(activity);
    await _ensureOwnedTherapy(
      activity.therapyId,
      activity.psychologistId,
      activity.childId,
    );

    final requestedId = activity.id.trim();
    final document = requestedId.isEmpty
        ? _activities.doc()
        : _activities.doc(requestedId);
    await document.set({
      'therapyId': activity.therapyId,
      'childId': activity.childId,
      'psychologistId': activity.psychologistId,
      'title': activity.title,
      'description': activity.description,
      'type': activity.type.name,
      'difficulty': activity.difficulty,
      'instructions': activity.instructions,
      'configuration': activity.configuration,
      'status': activity.status.name,
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });

    return document.id;
  }

  void _ensureValidConfiguration(ActivityModel activity) {
    try {
      final configuration = ActivityConfigurationFactory.fromMap(
        activity.type,
        activity.configuration,
      );
      if (configuration == null || !configuration.isValid) {
        throw ArgumentError.value(
          activity.configuration,
          'configuration',
          'La actividad debe tener una configuracion valida antes de asignarse.',
        );
      }
    } on ArgumentError {
      rethrow;
    } catch (error) {
      throw ArgumentError.value(
        activity.configuration,
        'configuration',
        'La configuracion no corresponde al tipo ${activity.type.name}: $error',
      );
    }
  }

  Future<List<ActivityModel>> getActivitiesByTherapy(
    String therapyId,
    String psychologistId,
  ) async {
    final snapshot = await _activitiesByTherapy(
      therapyId,
      psychologistId,
    ).get();
    return _sortedActivities(snapshot.docs.map(_activityFromDocument).toList());
  }

  Stream<List<ActivityModel>> watchActivitiesByTherapy(
    String therapyId,
    String psychologistId,
  ) {
    return _activitiesByTherapy(therapyId, psychologistId).snapshots().map(
      (snapshot) =>
          _sortedActivities(snapshot.docs.map(_activityFromDocument).toList()),
    );
  }

  Stream<int> watchPendingActivitiesCountByPsychologist(String psychologistId) {
    return _activities
        .where('psychologistId', isEqualTo: psychologistId)
        .where(
          'status',
          whereIn: [
            ActivityStatus.assigned.name,
            ActivityStatus.inProgress.name,
          ],
        )
        .snapshots()
        .map((snapshot) => snapshot.docs.length);
  }

  Future<ActivityModel?> getActivityById(
    String activityId,
    String psychologistId,
  ) async {
    final snapshot = await _activityQuery(
      activityId,
      psychologistId,
    ).limit(1).get();
    if (snapshot.docs.isEmpty) return null;
    return _activityFromDocument(snapshot.docs.first);
  }

  Future<void> updateActivity(ActivityModel activity) async {
    final document = await _ownedActivityDocument(
      activity.id,
      activity.psychologistId,
    );

    await document.reference.update({
      'title': activity.title,
      'description': activity.description,
      'type': activity.type.name,
      'difficulty': activity.difficulty,
      'instructions': activity.instructions,
      'configuration': activity.configuration,
      'status': activity.status.name,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> deleteActivity(String activityId, String psychologistId) async {
    final document = await _ownedActivityDocument(activityId, psychologistId);
    await document.reference.delete();
  }

  Query<Map<String, dynamic>> _activitiesByTherapy(
    String therapyId,
    String psychologistId,
  ) {
    return _activities
        .where('therapyId', isEqualTo: therapyId)
        .where('psychologistId', isEqualTo: psychologistId);
  }

  Query<Map<String, dynamic>> _activityQuery(
    String activityId,
    String psychologistId,
  ) {
    return _activities
        .where('psychologistId', isEqualTo: psychologistId)
        .where(FieldPath.documentId, isEqualTo: activityId);
  }

  Future<QueryDocumentSnapshot<Map<String, dynamic>>> _ownedActivityDocument(
    String activityId,
    String psychologistId,
  ) async {
    final snapshot = await _activityQuery(
      activityId,
      psychologistId,
    ).limit(1).get();
    if (snapshot.docs.isEmpty) {
      throw StateError('Actividad no encontrada para el psicologo indicado.');
    }
    return snapshot.docs.first;
  }

  Future<void> _ensureOwnedTherapy(
    String therapyId,
    String psychologistId,
    String childId,
  ) async {
    final document = await _firestoreService.therapiesCollection
        .doc(therapyId)
        .get();
    final data = document.data();

    if (!document.exists ||
        data == null ||
        data['psychologistId'] != psychologistId ||
        data['childId'] != childId) {
      throw StateError(
        'Terapia no encontrada para el psicologo y paciente indicados.',
      );
    }
  }

  ActivityModel _activityFromDocument(
    QueryDocumentSnapshot<Map<String, dynamic>> document,
  ) {
    final data = Map<String, dynamic>.from(document.data());
    final createdAt = _nullableDateTimeFromFirestore(data['createdAt']);
    if (createdAt == null && !document.metadata.hasPendingWrites) {
      throw StateError('Fecha de actividad ausente o invalida en Firestore.');
    }
    data['createdAt'] = (createdAt ?? DateTime.now()).toIso8601String();

    final updatedAt = _nullableDateTimeFromFirestore(data['updatedAt']);
    data['updatedAt'] = updatedAt?.toIso8601String();

    return ActivityModel.fromMap(data, id: document.id);
  }

  DateTime? _nullableDateTimeFromFirestore(Object? value) {
    if (value is Timestamp) return value.toDate();
    if (value is DateTime) return value;
    if (value is String) return DateTime.tryParse(value);
    return null;
  }

  List<ActivityModel> _sortedActivities(List<ActivityModel> activities) {
    activities.sort(
      (first, second) => second.createdAt.compareTo(first.createdAt),
    );
    return activities;
  }
}
