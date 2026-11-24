// =============================================================================
// Tests de l'authentification locale par PIN / code gérant.
// -----------------------------------------------------------------------------
// Propriétés vérifiées : aucun code en clair, dérivation PBKDF2, migration des
// anciennes empreintes SHA-256, comparaison sûre et verrouillage après plusieurs
// échecs (persisté dans le coffre, remis à zéro après succès).
// =============================================================================

// Encodage pour reproduire l'ancienne empreinte SHA-256.
import 'dart:convert';

// Framework de test.
import 'package:flutter_test/flutter_test.dart';

// Type fonctionnel.
import 'package:fpdart/fpdart.dart';

// HMAC/SHA-256 pour fabriquer une ancienne empreinte dans le test.
import 'package:crypto/crypto.dart';

// Failures métier.
import 'package:koudougou_gourmet/core/error/failures.dart';

// Horloge et politique testées.
import 'package:koudougou_gourmet/core/utils/app_clock.dart';
import 'package:koudougou_gourmet/core/security/pin_auth.dart';
import 'package:koudougou_gourmet/core/security/security_policy.dart';

// Coffre simulé.
import '../../support/fake_secure_key_store.dart';

/// Horloge modifiable pour avancer le temps du verrouillage sans attendre.
final class _MutableClock implements AppClock {
  /// Construit une horloge fixée à [instant].
  _MutableClock(this.instant);

  /// Instant courant.
  DateTime instant;

  /// Renvoie l'instant courant.
  @override
  DateTime now() => instant;

  /// Avance l'horloge de [duration].
  void advance(Duration duration) => instant = instant.add(duration);
}

/// Extrait la valeur de droite, ou échoue le test.
T _ok<T>(Either<Failure, T> result) => result.fold(
  (Failure failure) => throw StateError('Échec inattendu : ${failure.code}'),
  (T value) => value,
);

/// Extrait la `Failure` de gauche, ou échoue le test.
Failure _failure<T>(Either<Failure, T> result) => result.fold(
  (Failure failure) => failure,
  (T _) => throw StateError('Succès inattendu.'),
);

/// Construit un service rapide pour les tests (coût PBKDF2 réduit).
PinAuthService _auth(FakeSecureKeyStore store, {AppClock? clock}) =>
    PinAuthService(store, iterations: 1000, clock: clock);

void main() {
  group('PIN administrateur', () {
    test('un PIN valide est accepté puis vérifié', () async {
      final FakeSecureKeyStore store = FakeSecureKeyStore();
      final PinAuthService auth = _auth(store);

      expect(await auth.hasCreatorPin(), isFalse);
      expect(_ok(await auth.setCreatorPin('1234')), unit);
      expect(await auth.hasCreatorPin(), isTrue);
      expect(_ok(await auth.verifyCreatorPin('1234')), isTrue);
      expect(_ok(await auth.verifyCreatorPin('9999')), isFalse);
    });

    test('le PIN n’est jamais stocké en clair', () async {
      final FakeSecureKeyStore store = FakeSecureKeyStore();
      final PinAuthService auth = _auth(store);

      await auth.setCreatorPin('4821');

      expect(store.containsPlainText('4821'), isFalse);
      // Empreinte + sel : deux écritures distinctes dans le coffre.
      expect(store.secrets.length, 2);
      // Une empreinte PBKDF2 (64 hex) et un sel de 16 octets (32 hex).
      expect(store.secrets.values.map((String value) => value.length), <int>[
        64,
        32,
      ]);
      // Une clé PBKDF2 n'est pas l'ancien SHA-256 du code.
      final String salt = store.secrets['creator_salt_v1']!;
      final String legacy = sha256
          .convert(utf8.encode('$salt:4821'))
          .toString();
      expect(store.secrets['creator_pin_v1'], isNot(legacy));
    });

    test('un PIN mal formé est refusé avant toute écriture', () async {
      final FakeSecureKeyStore store = FakeSecureKeyStore();
      final PinAuthService auth = _auth(store);

      for (final String pin in <String>['123', '1234567', 'abcd', '12a4', '']) {
        final Either<Failure, Unit> result = await auth.setCreatorPin(pin);
        expect(_failure(result), isA<ValidationFailure>());
      }
      expect(store.secrets, isEmpty);
    });

    test('vérifier sans PIN défini renvoie une Failure de sécurité', () async {
      final PinAuthService auth = _auth(FakeSecureKeyStore());

      expect(
        _failure(await auth.verifyCreatorPin('1234')),
        isA<SecurityFailure>(),
      );
    });

    test('redéfinir le PIN invalide l’ancien code', () async {
      final PinAuthService auth = _auth(FakeSecureKeyStore());
      await auth.setCreatorPin('1111');
      await auth.setCreatorPin('2222');

      expect(_ok(await auth.verifyCreatorPin('1111')), isFalse);
      expect(_ok(await auth.verifyCreatorPin('2222')), isTrue);
    });

    test('une ancienne empreinte SHA-256 est migrée vers PBKDF2', () async {
      final FakeSecureKeyStore store = FakeSecureKeyStore();
      const String salt = '0123456789abcdef0123456789abcdef';
      await store.writeSecret(key: 'creator_salt_v1', value: salt);
      await store.writeSecret(
        key: 'creator_pin_v1',
        value: sha256.convert(utf8.encode('$salt:4321')).toString(),
      );
      final PinAuthService auth = _auth(store);

      expect(_ok(await auth.verifyCreatorPin('4321')), isTrue);
      expect(
        store.secrets['creator_pin_v1'],
        isNot(sha256.convert(utf8.encode('$salt:4321')).toString()),
      );
      // La migration est définitive : le code fonctionne toujours ensuite.
      expect(_ok(await auth.verifyCreatorPin('4321')), isTrue);
    });
  });

  group('Verrouillage après échecs', () {
    test('cinq échecs verrouillent l’accès pour 30 secondes', () async {
      final _MutableClock clock = _MutableClock(DateTime.utc(2026, 1, 1, 12));
      final PinAuthService auth = _auth(FakeSecureKeyStore(), clock: clock);
      await auth.setCreatorPin('1234');

      for (
        int attempt = 1;
        attempt < SecurityPolicy.maxFailedAttempts;
        attempt++
      ) {
        expect(_ok(await auth.verifyCreatorPin('9999')), isFalse);
        expect(await auth.failedAttempts(PinAuthService.creatorScope), attempt);
      }
      // Le cinquième échec renvoie directement la raison du blocage.
      final Failure failure = _failure(await auth.verifyCreatorPin('9999'));
      expect(failure, isA<SecurityFailure>());
      expect(failure.message, contains('30 s'));

      // Même le bon code est refusé tant que le délai n'est pas écoulé.
      expect(
        _failure(await auth.verifyCreatorPin('1234')),
        isA<SecurityFailure>(),
      );

      clock.advance(const Duration(seconds: 31));
      expect(_ok(await auth.verifyCreatorPin('1234')), isTrue);
      expect(await auth.failedAttempts(PinAuthService.creatorScope), 0);
      expect(
        await auth.remainingLock(PinAuthService.creatorScope),
        Duration.zero,
      );
    });

    test('le verrouillage est propre à chaque établissement', () async {
      final _MutableClock clock = _MutableClock(DateTime.utc(2026, 1, 1, 12));
      final PinAuthService auth = _auth(FakeSecureKeyStore(), clock: clock);
      await auth.setOwnerCode(restaurantId: 'r1', code: '1234');
      await auth.setOwnerCode(restaurantId: 'r2', code: '5678');

      for (
        int attempt = 0;
        attempt < SecurityPolicy.maxFailedAttempts;
        attempt++
      ) {
        await auth.verifyOwnerCode(restaurantId: 'r1', code: '9999');
      }

      expect(
        _failure(await auth.verifyOwnerCode(restaurantId: 'r1', code: '1234')),
        isA<SecurityFailure>(),
      );
      expect(
        _ok(await auth.verifyOwnerCode(restaurantId: 'r2', code: '5678')),
        isTrue,
      );
    });
  });

  group('Code gérant', () {
    test('les codes sont indépendants d’un établissement à l’autre', () async {
      final PinAuthService auth = _auth(FakeSecureKeyStore());
      await auth.setOwnerCode(restaurantId: 'r1', code: '1234');
      await auth.setOwnerCode(restaurantId: 'r2', code: '5678');

      expect(
        _ok(await auth.verifyOwnerCode(restaurantId: 'r1', code: '1234')),
        isTrue,
      );
      expect(
        _ok(await auth.verifyOwnerCode(restaurantId: 'r1', code: '5678')),
        isFalse,
      );
      expect(
        _ok(await auth.verifyOwnerCode(restaurantId: 'r2', code: '5678')),
        isTrue,
      );
    });

    test('un identifiant d’établissement invalide est refusé', () async {
      final PinAuthService auth = _auth(FakeSecureKeyStore());

      expect(
        _failure(
          await auth.setOwnerCode(restaurantId: 'r1/../r2', code: '1234'),
        ),
        isA<ValidationFailure>(),
      );
    });

    test('le code gérant n’est jamais stocké en clair', () async {
      final FakeSecureKeyStore store = FakeSecureKeyStore();
      final PinAuthService auth = _auth(store);

      await auth.setOwnerCode(restaurantId: 'r1', code: '0000');

      expect(store.containsPlainText('0000'), isFalse);
      expect(await auth.hasOwnerCode('r1'), isTrue);
      expect(await auth.hasOwnerCode('r2'), isFalse);
    });
  });
}
