import 'package:firebase_auth/firebase_auth.dart';

class AuthErrorMapper {
  /// Traduce los códigos de error de FirebaseAuthException a mensajes claros en español.
  static String toSpanishMessage(Object error) {
    if (error is! FirebaseAuthException) {
      return 'Ocurrió un error inesperado. Por favor, intenta nuevamente.';
    }

    switch (error.code) {
      case 'invalid-email':
        return 'El formato del correo electrónico no es válido.';
      case 'user-disabled':
        return 'Esta cuenta ha sido deshabilitada por el administrador.';
      case 'user-not-found':
        return 'No se encontró una cuenta con este correo electrónico.';
      case 'wrong-password':
      case 'invalid-credential':
        return 'El correo o la contraseña ingresados son incorrectos.';
      case 'email-already-in-use':
        return 'Ya existe una cuenta registrada con este correo electrónico.';
      case 'operation-not-allowed':
        return 'El método de acceso por correo y contraseña no está habilitado.';
      case 'weak-password':
        return 'La contraseña es muy débil. Debe tener al menos 6 caracteres.';
      case 'too-many-requests':
        return 'Demasiados intentos fallidos. Por seguridad, inténtalo más tarde.';
      case 'network-request-failed':
        return 'Error de conexión. Verifica tu conexión a internet e inténtalo de nuevo.';
      case 'requires-recent-login':
        return 'Esta operación requiere que inicies sesión nuevamente.';
      default:
        return 'Error de autenticación (${error.code}). Por favor, intenta nuevamente.';
    }
  }
}
