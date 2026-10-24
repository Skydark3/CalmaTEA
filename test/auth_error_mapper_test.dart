import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tea_app/core/utils/auth_error_mapper.dart';

void main() {
  group('AuthErrorMapper tests', () {
    test('maps common FirebaseAuthException error codes to Spanish', () {
      final invalidEmailEx = FirebaseAuthException(code: 'invalid-email');
      expect(
        AuthErrorMapper.toSpanishMessage(invalidEmailEx),
        contains('El formato del correo electrónico no es válido'),
      );

      final emailInUseEx = FirebaseAuthException(code: 'email-already-in-use');
      expect(
        AuthErrorMapper.toSpanishMessage(emailInUseEx),
        contains('Ya existe una cuenta registrada'),
      );

      final wrongPassEx = FirebaseAuthException(code: 'wrong-password');
      expect(
        AuthErrorMapper.toSpanishMessage(wrongPassEx),
        contains('correo o la contraseña ingresados son incorrectos'),
      );

      final invalidCredentialEx = FirebaseAuthException(code: 'invalid-credential');
      expect(
        AuthErrorMapper.toSpanishMessage(invalidCredentialEx),
        contains('correo o la contraseña ingresados son incorrectos'),
      );

      final weakPassEx = FirebaseAuthException(code: 'weak-password');
      expect(
        AuthErrorMapper.toSpanishMessage(weakPassEx),
        contains('La contraseña es muy débil'),
      );
    });

    test('handles unknown errors with generic fallback message', () {
      final genericError = Exception('Algún error arbitrario');
      expect(
        AuthErrorMapper.toSpanishMessage(genericError),
        'Ocurrió un error inesperado. Por favor, intenta nuevamente.',
      );
    });
  });
}
