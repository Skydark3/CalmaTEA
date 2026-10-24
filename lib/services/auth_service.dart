import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../core/constants/firestore_collections.dart';
import '../models/user_model.dart';

class AuthService {
  final FirebaseAuth _auth;
  final FirebaseFirestore _firestore;

  AuthService({
    FirebaseAuth? auth,
    FirebaseFirestore? firestore,
  })  : _auth = auth ?? FirebaseAuth.instance,
        _firestore = firestore ?? FirebaseFirestore.instance;

  FirebaseAuth get auth => _auth;

  User? get currentUser => _auth.currentUser;

  Stream<User?> get authStateChanges => _auth.authStateChanges();

  /// Inicia sesión con correo electrónico y contraseña.
  Future<UserCredential> signIn({
    required String email,
    required String password,
  }) async {
    return await _auth.signInWithEmailAndPassword(
      email: email.trim(),
      password: password,
    );
  }

  /// Registra un nuevo profesional (psicólogo) en Firebase Authentication
  /// y crea atómicamente sus perfiles en users/{uid} y psychologists/{uid}.
  /// Si la escritura en Firestore falla, se realiza rollback eliminando el usuario Auth.
  Future<UserCredential> registerPsychologist({
    required String fullName,
    required String email,
    required String password,
  }) async {
    final cleanEmail = email.trim();
    final cleanName = fullName.trim();

    // 1. Crear usuario en Firebase Authentication
    final credential = await _auth.createUserWithEmailAndPassword(
      email: cleanEmail,
      password: password,
    );

    final user = credential.user;
    if (user == null) {
      throw FirebaseAuthException(
        code: 'user-not-found',
        message: 'No se pudo obtener el usuario creado.',
      );
    }

    final uid = user.uid;

    try {
      // 2. Actualizar displayName en Auth (opcional para el perfil)
      await user.updateDisplayName(cleanName);

      // 3. Crear documentos en Firestore de forma atómica mediante WriteBatch
      final batch = _firestore.batch();

      final userDocRef = _firestore
          .collection(FirestoreCollections.users)
          .doc(uid);
      final psychologistDocRef = _firestore
          .collection(FirestoreCollections.psychologists)
          .doc(uid);

      final userDocData = {
        'id': uid,
        'name': cleanName,
        'email': cleanEmail,
        'role': UserRole.psychologist.name,
        'createdAt': FieldValue.serverTimestamp(),
      };

      final psychologistDocData = {
        'id': uid,
        'userId': uid,
        'fullName': cleanName,
        'email': cleanEmail,
        'specialty': null,
        'professionalLicense': null,
        'workCenter': null,
        'photoUrl': null,
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      };

      batch.set(userDocRef, userDocData);
      batch.set(psychologistDocRef, psychologistDocData);

      await batch.commit();

      return credential;
    } catch (e) {
      // 4. Rollback: si falla Firestore, eliminar la cuenta creada en Firebase Auth
      try {
        await user.delete();
      } catch (_) {
        // Ignorar error secundario de rollback si ya no existe
      }
      rethrow;
    }
  }

  /// Envía un correo electrónico para restablecer la contraseña.
  Future<void> sendPasswordReset({
    required String email,
  }) async {
    await _auth.setLanguageCode('es');
    await _auth.sendPasswordResetEmail(email: email.trim());
  }

  /// Cierra la sesión activa en Firebase Authentication.
  Future<void> signOut() async {
    await _auth.signOut();
  }

  /// Obtiene el perfil de usuario desde Firestore users/{uid}.
  Future<UserModel?> getUserProfile(String uid) async {
    final doc = await _firestore
        .collection(FirestoreCollections.users)
        .doc(uid)
        .get();

    if (!doc.exists) return null;

    final data = doc.data();
    if (data == null) return null;

    final rawCreatedAt = data['createdAt'];
    if (rawCreatedAt is Timestamp) {
      data['createdAt'] = rawCreatedAt.toDate().toIso8601String();
    }

    return UserModel.fromMap(data, id: doc.id);
  }
}
