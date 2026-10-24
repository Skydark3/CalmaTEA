import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

import '../models/child_model.dart';
import 'firestore_service.dart';

/// Encapsula las operaciones de Firestore relacionadas con pacientes.
class ChildService {
  final FirestoreService _firestoreService;

  ChildService({FirestoreService? firestoreService})
    : _firestoreService = firestoreService ?? FirestoreService();

  CollectionReference<Map<String, dynamic>> get _children =>
      _firestoreService.childrenCollection;

  Future<String> createChild(ChildModel child) async {
    final document = child.id.isEmpty
        ? _children.doc()
        : _children.doc(child.id);

    await document.set({
      'psychologistId': child.psychologistId,
      'fullName': child.fullName,
      'birthDate': Timestamp.fromDate(child.birthDate),
      'supportLevel': child.supportLevel,
      'notes': child.notes,
      'photoUrl': child.photoUrl,
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });

    return document.id;
  }

  Future<List<ChildModel>> getChildren(String psychologistId) async {
    final snapshot = await _children
        .where('psychologistId', isEqualTo: psychologistId)
        .get();

    return _sortedChildren(snapshot.docs.map(_childFromDocument).toList());
  }

  Stream<List<ChildModel>> watchChildren(String psychologistId) {
    return _children
        .where('psychologistId', isEqualTo: psychologistId)
        .snapshots()
        .map((snapshot) {
          debugPrint('documents received: ${snapshot.docs.length}');
          final children = snapshot.docs.map((document) {
            debugPrint('child document: ${document.id}');
            return _childFromDocument(document);
          }).toList();
          return _sortedChildren(children);
        });
  }

  Future<ChildModel?> getChildById(
    String childId,
    String psychologistId,
  ) async {
    final snapshot = await _childQuery(childId, psychologistId).limit(1).get();

    if (snapshot.docs.isEmpty) return null;
    return _childFromDocument(snapshot.docs.first);
  }

  Future<void> updateChild(ChildModel child) async {
    final document = await _ownedChildDocument(child.id, child.psychologistId);

    await document.reference.update({
      'fullName': child.fullName,
      'birthDate': Timestamp.fromDate(child.birthDate),
      'supportLevel': child.supportLevel,
      'notes': child.notes,
      'photoUrl': child.photoUrl,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> deleteChild(String childId, String psychologistId) async {
    final document = await _ownedChildDocument(childId, psychologistId);
    await document.reference.delete();
  }

  Query<Map<String, dynamic>> _childQuery(
    String childId,
    String psychologistId,
  ) {
    return _children
        .where('psychologistId', isEqualTo: psychologistId)
        .where(FieldPath.documentId, isEqualTo: childId);
  }

  Future<QueryDocumentSnapshot<Map<String, dynamic>>> _ownedChildDocument(
    String childId,
    String psychologistId,
  ) async {
    final snapshot = await _childQuery(childId, psychologistId).limit(1).get();
    if (snapshot.docs.isEmpty) {
      throw StateError('Paciente no encontrado para el psicologo indicado.');
    }
    return snapshot.docs.first;
  }

  ChildModel _childFromDocument(
    QueryDocumentSnapshot<Map<String, dynamic>> document,
  ) {
    final data = Map<String, dynamic>.from(document.data());
    data['birthDate'] = _dateTimeFromFirestore(data['birthDate'])
        .toIso8601String();
    data['createdAt'] = _dateTimeFromFirestore(data['createdAt'])
        .toIso8601String();

    final updatedAt = _nullableDateTimeFromFirestore(data['updatedAt']);
    data['updatedAt'] = updatedAt?.toIso8601String();

    return ChildModel.fromMap(data, id: document.id);
  }

  DateTime _dateTimeFromFirestore(Object? value) {
    final dateTime = _nullableDateTimeFromFirestore(value);
    if (dateTime == null) {
      throw StateError('Fecha de paciente ausente o invalida en Firestore.');
    }
    return dateTime;
  }

  DateTime? _nullableDateTimeFromFirestore(Object? value) {
    if (value is Timestamp) return value.toDate();
    if (value is DateTime) return value;
    if (value is String) return DateTime.tryParse(value);
    return null;
  }

  List<ChildModel> _sortedChildren(List<ChildModel> children) {
    children.sort(
      (first, second) =>
          first.fullName.toLowerCase().compareTo(second.fullName.toLowerCase()),
    );
    return children;
  }
}
