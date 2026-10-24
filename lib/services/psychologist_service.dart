import 'package:cloud_firestore/cloud_firestore.dart';
import '../core/constants/firestore_collections.dart';
import '../models/psychologist_model.dart';

/// Servicio para consultar información del perfil profesional del psicólogo.
class PsychologistService {
  final FirebaseFirestore _firestore;

  PsychologistService({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  /// Obtiene los datos del profesional desde psychologists/{uid}.
  Future<PsychologistModel?> getPsychologistProfile(String uid) async {
    final doc = await _firestore
        .collection(FirestoreCollections.psychologists)
        .doc(uid)
        .get();

    if (!doc.exists) return null;

    final data = doc.data();
    if (data == null) return null;

    // Conversión segura de Timestamps de Firestore a ISO-8601 String
    // para mantener el modelo de dominio libre de dependencias de Firebase SDK.
    final rawCreatedAt = data['createdAt'];
    if (rawCreatedAt is Timestamp) {
      data['createdAt'] = rawCreatedAt.toDate().toIso8601String();
    }

    final rawUpdatedAt = data['updatedAt'];
    if (rawUpdatedAt is Timestamp) {
      data['updatedAt'] = rawUpdatedAt.toDate().toIso8601String();
    }

    return PsychologistModel.fromMap(data, id: doc.id);
  }
}
