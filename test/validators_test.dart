import 'package:flutter_test/flutter_test.dart';
import 'package:tea_app/core/utils/validators.dart';

void main() {
  group('Validators tests', () {
    test('required validator detects empty or null strings', () {
      expect(Validators.required(null), isNotNull);
      expect(Validators.required(''), isNotNull);
      expect(Validators.required('   '), isNotNull);
      expect(Validators.required('Hola'), isNull);
    });

    test('email validator validates format', () {
      expect(Validators.email(null), isNotNull);
      expect(Validators.email(''), isNotNull);
      expect(Validators.email('correo-invalido'), isNotNull);
      expect(Validators.email('usuario@dominio'), isNotNull);
      expect(Validators.email('psicologo@calmatea.com'), isNull);
      expect(Validators.email('test.user@sub.domain.org'), isNull);
    });

    test('password validator enforces minimum 6 characters', () {
      expect(Validators.password(null), isNotNull);
      expect(Validators.password(''), isNotNull);
      expect(Validators.password('12345'), isNotNull);
      expect(Validators.password('123456'), isNull);
      expect(Validators.password('MiPasswordSeguro123'), isNull);
    });

    test('name validator checks minimum length and presence', () {
      expect(Validators.name(null), isNotNull);
      expect(Validators.name(''), isNotNull);
      expect(Validators.name('a'), isNotNull);
      expect(Validators.name('Dr. Carlos Gómez'), isNull);
    });
  });
}
