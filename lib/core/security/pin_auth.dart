// =============================================================================
// Authentification locale par code PIN (administration) et code gérant.
// -----------------------------------------------------------------------------
// Aucun code n'est stocké en clair : le coffre natif ne contient qu'une clé
// dérivée PBKDF2-HMAC-SHA256 (210 000 itérations) et un sel aléatoire de
// 16 octets. Les anciennes empreintes SHA-256 sont encore acceptées une fois,
// puis migrées automatiquement vers PBKDF2.
//
// Une politique de verrouillage persistée bloque la force brute : après cinq
// échecs, l'accès est suspendu avec un délai progressif (30 s, 1 min, 2 min...)
// plafonné à 15 minutes. Un succès remet le compteur à zéro. Les compteurs
// vivent dans le coffre natif : redémarrer l'application ne les efface pas.
//
// Ce service reste LOCAL et fonctionne hors ligne. Il protège les espaces de
// l'application contre une usage opportuniste, mais il ne résiste pas à un
// appareil compromis (cf. section « Limites » du README).
// =============================================================================

// Encodage UTF-8 du couple sel + code avant hachage.
import 'dart:convert';

// Générateur cryptographiquement sûr du sel.
import 'dart:math';

// Type fonctionnel : jamais d'exception à la frontière Présentation.
import 'package:fpdart/fpdart.dart';

// HMAC/SHA-256 pour la compatibilité avec les anciennes empreintes.
import 'package:crypto/crypto.dart';

// Erreurs métier.
import '../error/failures.dart';

// Horloge injectable pour les tests de verrouillage.
import '../utils/app_clock.dart';

// Dérivation PBKDF2 et politique de sécurité.
import 'pbkdf2.dart';
import 'security_policy.dart';

// Coffre-fort natif injectable.
import 'secure_key_store.dart';

/// Service d'authentification locale, sans serveur.
final class PinAuthService {
  /// Injection du coffre-fort natif et, en test, de l'horloge et du coût PBKDF2.
  PinAuthService(
    this._store, {
    AppClock? clock,
    this.iterations = SecurityPolicy.pbkdf2Iterations,
  }) : _clock = clock ?? const SystemClock();

  // Dépendances uniques.
  final SecureKeyStore _store;
  final AppClock _clock;

  /// Coût de dérivation (réduit en test uniquement).
  final int iterations;

  // Clés logiques des secrets. Elles sont préfixées par le coffre lui-même.
  static const String _creatorKey = 'creator_pin_v1';
  static const String _creatorSaltKey = 'creator_salt_v1';

  /// Portée du compteur pour le code administrateur.
  static const String creatorScope = 'creator';

  /// Longueur minimale et maximale acceptée pour un code (4 à 6 chiffres).
  static const int minCodeLength = 4;
  static const int maxCodeLength = 6;

  /// Clé du code gérant d'un établissement donné.
  static String ownerKey(String restaurantId) => 'owner_pin_v1_$restaurantId';

  /// Clé du sel d'un établissement donné.
  static String ownerSaltKey(String restaurantId) =>
      'owner_salt_v1_$restaurantId';

  /// Portée du compteur pour le code gérant d'un établissement.
  static String ownerScope(String restaurantId) => 'owner_$restaurantId';

  // ---------------------------------------------------------------------------
  // Compteurs de tentatives (coffre natif, donc persistés entre deux lancements)
  // ---------------------------------------------------------------------------

  static String _attemptsKey(String scope) => 'auth_attempts_$scope';
  static String _lockKey(String scope) => 'auth_lock_until_$scope';

  /// Indique si l'administrateur a déjà défini son PIN (premier lancement).
  Future<bool> hasCreatorPin() async {
    final String? stored = await _store.readSecret(_creatorKey);
    return stored != null && stored.isNotEmpty;
  }

  /// Crée ou remplace le PIN administrateur.
  Future<Either<Failure, Unit>> setCreatorPin(String pin) async {
    // Validation stricte avant toute écriture.
    final String? error = _validate(pin);
    if (error != null) {
      return left(ValidationFailure(message: error, field: 'pin'));
    }

    // Sel aléatoire propre à cette installation.
    final String salt = _newSalt();

    // Écriture de l'empreinte puis du sel dans le coffre natif.
    await _store.writeSecret(key: _creatorKey, value: _hash(pin, salt));
    await _store.writeSecret(key: _creatorSaltKey, value: salt);

    // Changer le code efface aussi l'historique d'échecs.
    await _clearAttempts(creatorScope);

    // `Unit` est le « rien » typé de fpdart (équivalent de void).
    return right<Failure, Unit>(unit);
  }

  /// Vérifie le PIN administrateur. `true` seulement si l'empreinte correspond.
  Future<Either<Failure, bool>> verifyCreatorPin(String pin) async {
    // Verrouillage actif : aucune comparaison n'est même tentée.
    final Failure? locked = await _checkLock(creatorScope);
    if (locked != null) {
      return left(locked);
    }

    final String? error = _validate(pin);
    if (error != null) {
      return left(ValidationFailure(message: error, field: 'pin'));
    }

    final String? stored = await _store.readSecret(_creatorKey);
    final String? salt = await _store.readSecret(_creatorSaltKey);
    if (stored == null || salt == null) {
      return left(
        const SecurityFailure(
          message: 'Aucun PIN administrateur n’est encore défini.',
        ),
      );
    }

    final String candidate = _hash(pin, salt);
    if (_constantTimeEquals(candidate, stored)) {
      await _clearAttempts(creatorScope);
      return right<Failure, bool>(true);
    }

    // Migration transparente d'une empreinte SHA-256 de l'ancienne version.
    if (_constantTimeEquals(_legacyHash(pin, salt), stored)) {
      await _store.writeSecret(key: _creatorKey, value: candidate);
      await _clearAttempts(creatorScope);
      return right<Failure, bool>(true);
    }

    return _registerFailure(creatorScope);
  }

  /// Indique si un établissement possède déjà un code gérant.
  Future<bool> hasOwnerCode(String restaurantId) async {
    final String? stored = await _store.readSecret(ownerKey(restaurantId));
    return stored != null && stored.isNotEmpty;
  }

  /// Crée ou remplace le code gérant d'un établissement.
  Future<Either<Failure, Unit>> setOwnerCode({
    required String restaurantId,
    required String code,
  }) async {
    // L'identifiant est vérifié avant de construire une clé de stockage.
    final String? idError = _validateRestaurantId(restaurantId);
    if (idError != null) {
      return left(ValidationFailure(message: idError, field: 'restaurantId'));
    }

    // Validation du code lui-même.
    final String? error = _validate(code);
    if (error != null) {
      return left(ValidationFailure(message: error, field: 'code'));
    }

    // Même mécanisme que le PIN administrateur, avec un sel distinct.
    final String salt = _newSalt();
    await _store.writeSecret(
      key: ownerKey(restaurantId),
      value: _hash(code, salt),
    );
    await _store.writeSecret(key: ownerSaltKey(restaurantId), value: salt);
    await _clearAttempts(ownerScope(restaurantId));

    return right<Failure, Unit>(unit);
  }

  /// Vérifie le code gérant d'un établissement.
  Future<Either<Failure, bool>> verifyOwnerCode({
    required String restaurantId,
    required String code,
  }) async {
    final String scope = ownerScope(restaurantId);
    final Failure? locked = await _checkLock(scope);
    if (locked != null) {
      return left(locked);
    }

    final String? error = _validate(code);
    if (error != null) {
      return left(ValidationFailure(message: error, field: 'code'));
    }

    final String? stored = await _store.readSecret(ownerKey(restaurantId));
    final String? salt = await _store.readSecret(ownerSaltKey(restaurantId));
    if (stored == null || salt == null) {
      return left(
        const SecurityFailure(
          message: 'Aucun code gérant n’est défini pour cet établissement.',
        ),
      );
    }

    final String candidate = _hash(code, salt);
    if (_constantTimeEquals(candidate, stored)) {
      await _clearAttempts(scope);
      return right<Failure, bool>(true);
    }
    if (_constantTimeEquals(_legacyHash(code, salt), stored)) {
      await _store.writeSecret(key: ownerKey(restaurantId), value: candidate);
      await _clearAttempts(scope);
      return right<Failure, bool>(true);
    }

    return _registerFailure(scope);
  }

  /// Nombre d'échecs enregistrés pour une portée (diagnostic, sans secret).
  Future<int> failedAttempts(String scope) async {
    final String? raw = await _store.readSecret(_attemptsKey(scope));
    return int.tryParse(raw ?? '') ?? 0;
  }

  /// Temps de verrouillage restant pour une portée (zéro si déverrouillé).
  Future<Duration> remainingLock(String scope) async {
    final String? raw = await _store.readSecret(_lockKey(scope));
    final int? untilMicros = int.tryParse(raw ?? '');
    if (untilMicros == null) {
      return Duration.zero;
    }
    final int remaining = untilMicros - _clock.now().microsecondsSinceEpoch;
    if (remaining <= 0) {
      await _store.deleteSecret(_lockKey(scope));
      return Duration.zero;
    }
    return Duration(microseconds: remaining);
  }

  /// Renvoie une Failure quand la portée est verrouillée, sinon `null`.
  Future<Failure?> _checkLock(String scope) async {
    final Duration remaining = await remainingLock(scope);
    if (remaining == Duration.zero) {
      return null;
    }
    return SecurityFailure(
      message:
          'Trop de tentatives échouées. Réessayez dans '
          '${SecurityPolicy.formatRemaining(remaining)}.',
    );
  }

  /// Incrémente le compteur, applique un délai si le seuil est franchi, puis
  /// renvoie le résultat typé attendu par les use cases.
  Future<Either<Failure, bool>> _registerFailure(String scope) async {
    final int attempts = await failedAttempts(scope) + 1;
    await _store.writeSecret(
      key: _attemptsKey(scope),
      value: attempts.toString(),
    );

    final Duration delay = SecurityPolicy.lockDurationFor(attempts);
    if (delay > Duration.zero) {
      await _store.writeSecret(
        key: _lockKey(scope),
        value: '${_clock.now().add(delay).microsecondsSinceEpoch}',
      );
      // On renvoie immédiatement la raison du blocage, plus claire qu'un
      // simple « code incorrect » pour l'utilisateur.
      return left(
        SecurityFailure(
          message:
              'Trop de tentatives échouées. Réessayez dans '
              '${SecurityPolicy.formatRemaining(delay)}.',
        ),
      );
    }
    return right<Failure, bool>(false);
  }

  /// Efface les compteurs après une authentification réussie.
  Future<void> _clearAttempts(String scope) async {
    await _store.deleteSecret(_attemptsKey(scope));
    await _store.deleteSecret(_lockKey(scope));
  }

  /// Valide un code : chiffres seulement, longueur bornée.
  static String? _validate(String code) {
    if (!RegExp(r'^\d+$').hasMatch(code)) {
      return 'Le code ne doit contenir que des chiffres.';
    }
    if (code.length < minCodeLength || code.length > maxCodeLength) {
      return 'Le code doit comporter entre $minCodeLength et $maxCodeLength chiffres.';
    }
    // Aucune erreur.
    return null;
  }

  /// Valide l'identifiant utilisé dans les clés du coffre.
  static String? _validateRestaurantId(String restaurantId) {
    if (restaurantId.isEmpty ||
        restaurantId.contains(RegExp(r'[^a-zA-Z0-9_-]'))) {
      return 'Identifiant d’établissement invalide.';
    }
    return null;
  }

  /// Génère un sel aléatoire de 16 octets encodé en hexadécimal.
  static String _newSalt() {
    final Random random = Random.secure();
    final List<int> bytes = List<int>.generate(
      16,
      (int index) => random.nextInt(256),
      growable: false,
    );
    return bytes
        .map((int byte) => byte.toRadixString(16).padLeft(2, '0'))
        .join();
  }

  /// Empreinte PBKDF2 du sel et du code (format hexadécimal).
  String _hash(String code, String salt) {
    final List<int> key = derivePbkdf2Sha256(
      password: utf8.encode(code),
      salt: utf8.encode(salt),
      iterations: iterations,
    );
    return key.map((int byte) => byte.toRadixString(16).padLeft(2, '0')).join();
  }

  /// Ancienne empreinte SHA-256, uniquement pour migrer les installations
  /// déjà en place. Ne jamais réutiliser pour un nouveau code.
  static String _legacyHash(String code, String salt) =>
      sha256.convert(utf8.encode('$salt:$code')).toString();

  /// Comparaison à temps constant : aucune sortie anticipée sur le premier
  /// octet différent, pour ne pas exposer le préfixe de l'empreinte.
  static bool _constantTimeEquals(String left, String right) {
    final List<int> a = utf8.encode(left);
    final List<int> b = utf8.encode(right);
    final int length = a.length > b.length ? a.length : b.length;
    int difference = a.length ^ b.length;
    for (int index = 0; index < length; index++) {
      final int byteA = index < a.length ? a[index] : 0;
      final int byteB = index < b.length ? b[index] : 0;
      difference |= byteA ^ byteB;
    }
    return difference == 0;
  }
}
