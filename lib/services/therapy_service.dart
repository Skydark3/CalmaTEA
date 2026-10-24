import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/therapy_date_utils.dart';
import '../models/therapy_model.dart';
import 'firestore_service.dart';

/// Encapsula las operaciones de Firestore relacionadas con terapias.
class TherapyService {
  final FirestoreService _firestoreService;

  TherapyService({FirestoreService? firestoreService})
    : _firestoreService = firestoreService ?? FirestoreService();

  CollectionReference<Map<String, dynamic>> get _therapies =>
      _firestoreService.therapiesCollection;

  Future<String> createTherapy(TherapyModel therapy) async {
    await _ensureOwnedChild(therapy.childId, therapy.psychologistId);

    final document = _therapies.doc();
    await document.set({
      'childId': therapy.childId,
      'psychologistId': therapy.psychologistId,
      'type': therapy.type.name,
      'status': therapy.status.name,
      'startDate': Timestamp.fromDate(therapyDateForStorage(therapy.startDate)),
      if (therapy.endDate != null)
        'endDate': Timestamp.fromDate(therapyDateForStorage(therapy.endDate!)),
      if (therapy.notes != null) 'notes': therapy.notes,
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });

    return document.id;
  }

  Future<List<TherapyModel>> getTherapiesByChild(
    String childId,
    String psychologistId,
  ) async {
    final snapshot = await _therapiesByChild(childId, psychologistId).get();
    return _sortedTherapies(snapshot.docs.map(_therapyFromDocument).toList());
  }

  Stream<List<TherapyModel>> watchTherapiesByChild(
    String childId,
    String psychologistId,
  ) {
    return _therapiesByChild(childId, psychologistId).snapshots().map(
      (snapshot) =>
          _sortedTherapies(snapshot.docs.map(_therapyFromDocument).toList()),
    );
  }

  Stream<int> watchActiveTherapiesCountByPsychologist(String psychologistId) {
    return _therapies
        .where('psychologistId', isEqualTo: psychologistId)
        .where('status', isEqualTo: TherapyStatus.active.name)
        .snapshots()
        .map((snapshot) => snapshot.docs.length);
  }

  Future<TherapyModel?> getTherapyById(
    String therapyId,
    String psychologistId,
  ) async {
    final snapshot = await _therapyQuery(
      therapyId,
      psychologistId,
    ).limit(1).get();
    if (snapshot.docs.isEmpty) return null;
    return _therapyFromDocument(snapshot.docs.first);
  }

  Future<void> updateTherapy(TherapyModel therapy) async {
    final document = await _ownedTherapyDocument(
      therapy.id,
      therapy.psychologistId,
    );

    await document.reference.update({
      'type': therapy.type.name,
      'status': therapy.status.name,
      'startDate': Timestamp.fromDate(therapyDateForStorage(therapy.startDate)),
      'endDate': therapy.endDate == null
          ? FieldValue.delete()
          : Timestamp.fromDate(therapyDateForStorage(therapy.endDate!)),
      'notes': therapy.notes == null ? FieldValue.delete() : therapy.notes,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> deleteTherapy(String therapyId, String psychologistId) async {
    final document = await _ownedTherapyDocument(therapyId, psychologistId);
    await document.reference.delete();
  }

  Query<Map<String, dynamic>> _therapiesByChild(
    String childId,
    String psychologistId,
  ) {
    return _therapies
        .where('childId', isEqualTo: childId)
        .where('psychologistId', isEqualTo: psychologistId);
  }

  Query<Map<String, dynamic>> _therapyQuery(
    String therapyId,
    String psychologistId,
  ) {
    return _therapies
        .where('psychologistId', isEqualTo: psychologistId)
        .where(FieldPath.documentId, isEqualTo: therapyId);
  }

  Future<QueryDocumentSnapshot<Map<String, dynamic>>> _ownedTherapyDocument(
    String therapyId,
    String psychologistId,
  ) async {
    final snapshot = await _therapyQuery(
      therapyId,
      psychologistId,
    ).limit(1).get();
    if (snapshot.docs.isEmpty) {
      throw StateError('Terapia no encontrada para el psicologo indicado.');
    }
    return snapshot.docs.first;
  }

  Future<void> _ensureOwnedChild(String childId, String psychologistId) async {
    final snapshot = await _firestoreService.childrenCollection
        .where('psychologistId', isEqualTo: psychologistId)
        .where(FieldPath.documentId, isEqualTo: childId)
        .limit(1)
        .get();

    if (snapshot.docs.isEmpty) {
      throw StateError('Paciente no encontrado para el psicologo indicado.');
    }
  }

  TherapyModel _therapyFromDocument(
    QueryDocumentSnapshot<Map<String, dynamic>> document,
  ) {
    final data = Map<String, dynamic>.from(document.data());
    data['startDate'] = therapyDateFromStorage(
      _dateTimeFromFirestore(data['startDate']),
    ).toIso8601String();
    data['createdAt'] = _dateTimeFromFirestore(data['createdAt'])
        .toIso8601String();

    final storedEndDate = _nullableDateTimeFromFirestore(data['endDate']);
    final endDate = storedEndDate == null
        ? null
        : therapyDateFromStorage(storedEndDate);
    data['endDate'] = endDate?.toIso8601String();

    final updatedAt = _nullableDateTimeFromFirestore(data['updatedAt']);
    data['updatedAt'] = updatedAt?.toIso8601String();

    return TherapyModel.fromMap(data, id: document.id);
  }

  DateTime _dateTimeFromFirestore(Object? value) {
    final dateTime = _nullableDateTimeFromFirestore(value);
    if (dateTime == null) {
      throw StateError('Fecha de terapia ausente o invalida en Firestore.');
    }
    return dateTime;
  }

  DateTime? _nullableDateTimeFromFirestore(Object? value) {
    if (value is Timestamp) return value.toDate();
    if (value is DateTime) return value;
    if (value is String) return DateTime.tryParse(value);
    return null;
  }

  List<TherapyModel> _sortedTherapies(List<TherapyModel> therapies) {
    therapies.sort(
      (first, second) => second.startDate.compareTo(first.startDate),
    );
    return therapies;
  }
}
