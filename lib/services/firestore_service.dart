import 'package:cloud_firestore/cloud_firestore.dart';
import '../core/constants/firestore_collections.dart';

/// Servicio base para encapsular el acceso a Cloud Firestore.
/// En Fase 2 proporciona acceso a la instancia y referencias base de colecciones.
class FirestoreService {
  final FirebaseFirestore _firestore;

  FirestoreService({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  FirebaseFirestore get instance => _firestore;

  CollectionReference<Map<String, dynamic>> get usersCollection =>
      _firestore.collection(FirestoreCollections.users);

  CollectionReference<Map<String, dynamic>> get psychologistsCollection =>
      _firestore.collection(FirestoreCollections.psychologists);

  CollectionReference<Map<String, dynamic>> get childrenCollection =>
      _firestore.collection(FirestoreCollections.children);

  CollectionReference<Map<String, dynamic>> get therapiesCollection =>
      _firestore.collection(FirestoreCollections.therapies);

  CollectionReference<Map<String, dynamic>> get activitiesCollection =>
      _firestore.collection(FirestoreCollections.activities);

  CollectionReference<Map<String, dynamic>> get activityResultsCollection =>
      _firestore.collection(FirestoreCollections.activityResults);

  CollectionReference<Map<String, dynamic>> get sessionsCollection =>
      _firestore.collection(FirestoreCollections.sessions);

  CollectionReference<Map<String, dynamic>> get activeExecutionSessionsCollection =>
      _firestore.collection(FirestoreCollections.activeExecutionSessions);
}
