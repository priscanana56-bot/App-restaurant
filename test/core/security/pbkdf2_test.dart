// =============================================================================
// Tests de la dérivation PBKDF2-HMAC-SHA256.
// -----------------------------------------------------------------------------
// Les vecteurs attendus ont été calculés avec `hashlib.pbkdf2_hmac` de Python
// (implémentation de référence), afin de ne pas tester la fonction par elle-même.
// =============================================================================

// Framework de test.
import 'package:flutter_test/flutter_test.dart';

// Fonction testée.
import 'package:koudougou_gourmet/core/security/pbkdf2.dart';

/// Encode une liste d'octets en hexadécimal minuscule.
String _hex(List<int> bytes) =>
    bytes.map((int byte) => byte.toRadixString(16).padLeft(2, '0')).join();

void main() {
  group('derivePbkdf2Sha256', () {
    test('correspond aux vecteurs de référence (1 et 2 itérations)', () {
      final List<int> password = 'password'.codeUnits;
      final List<int> salt = 'salt'.codeUnits;

      final List<int> one = derivePbkdf2Sha256(
        password: password,
        salt: salt,
        iterations: 1,
      );
      final List<int> two = derivePbkdf2Sha256(
        password: password,
        salt: salt,
        iterations: 2,
      );

      expect(
        _hex(one),
        '120fb6cffcf8b32c43e7225256c4f837a86548c92ccc35480805987cb70be17b',
      );
      expect(
        _hex(two),
        'ae4d0c95af6b46d32d0adff928f06dd02a303f8ef3c251dfd6e2d85a95474c43',
      );
    });

    test('un changement de mot de passe ou de sel change la clé', () {
      final List<int> reference = derivePbkdf2Sha256(
        password: '1234'.codeUnits,
        salt: 'abc'.codeUnits,
        iterations: 3,
      );

      expect(
        derivePbkdf2Sha256(
          password: '1235'.codeUnits,
          salt: 'abc'.codeUnits,
          iterations: 3,
        ),
        isNot(reference),
      );
      expect(
        derivePbkdf2Sha256(
          password: '1234'.codeUnits,
          salt: 'abd'.codeUnits,
          iterations: 3,
        ),
        isNot(reference),
      );
    });

    test('refuse un nombre d’itérations nul', () {
      expect(
        () => derivePbkdf2Sha256(
          password: '1234'.codeUnits,
          salt: 'abc'.codeUnits,
          iterations: 0,
        ),
        throwsArgumentError,
      );
    });
  });
}
