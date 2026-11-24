// =============================================================================
// Coffre-fort de clés (Keychain iOS / Keystore Android).
// -----------------------------------------------------------------------------
// Le cache Hive est chiffré avec AES-256. La clé de 32 octets est générée par
// le générateur cryptographique du système (`Random.secure`) et conservée dans
// le stockage natif sécurisé, JAMAIS dans le code ni dans un fichier en clair.
// =============================================================================

// Encodage/décodage Base64 pour stocker la clé sous forme de texte.
import 'dart:convert';

// Générateur aléatoire cryptographiquement sûr.
import 'dart:math';

// Type de tableau d'octets utilisé par Hive.
import 'dart:typed_data';

// Plugin de stockage sécurisé natif.
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

// Exception dédiée au coffre-fort.
import '../error/exceptions.dart';

/// Contrat du coffre-fort, injectable et remplaçable dans les tests.
abstract interface class SecureKeyStore {
  /// Récupère la clé AES existante ou en crée une nouvelle de 32 octets.
  Future<Uint8List> getOrCreateHiveKey();

  /// Supprime la clé (déconnexion totale / réinitialisation du cache).
  Future<void> deleteHiveKey();

  /// Lit un secret arbitraire (empreinte de PIN, code gérant...) stocké sous [key].
  /// Retourne `null` si aucune valeur n'a jamais été enregistrée.
  Future<String?> readSecret(String key);

  /// Écrit un secret arbitraire sous [key] dans le stockage natif chiffré.
  Future<void> writeSecret({required String key, required String value});

  /// Supprime définitivement le secret stocké sous [key].
  Future<void> deleteSecret(String key);
}

/// Implémentation native basée sur `flutter_secure_storage`.
final class FlutterSecureKeyStore implements SecureKeyStore {
  /// Injection optionnelle du stockage pour les tests.
  FlutterSecureKeyStore({FlutterSecureStorage? storage})
    : _storage = storage ?? const FlutterSecureStorage();

  // Instance native, jamais exposée.
  final FlutterSecureStorage _storage;

  // Nom de l'entrée dans le Keychain/Keystore. La version permet une rotation.
  static const String _storageKey = 'koudougou_hive_aes_key_v1';

  // Taille attendue de la clé AES-256, en octets.
  static const int _keyLength = 32;

  /// Récupère ou génère la clé de chiffrement du cache.
  @override
  Future<Uint8List> getOrCreateHiveKey() async {
    // Bloc de capture : les erreurs natives sont converties en exception métier.
    try {
      // Lecture de la clé existante (null si première exécution).
      final String? stored = await _storage.read(key: _storageKey);

      // Si une valeur existe, on tente de la décoder.
      if (stored != null && stored.isNotEmpty) {
        try {
          final Uint8List decoded = base64Decode(stored);

          // Une clé valide doit faire exactement 32 octets.
          if (decoded.length == _keyLength) {
            return decoded;
          }
        } on FormatException {
          // Valeur corrompue : on ignore et régénère une clé propre ci-dessous.
        }
      }

      // Génération d'une clé de 32 octets avec le RNG cryptographique système.
      final Random secureRandom = Random.secure();
      final Uint8List key = Uint8List(_keyLength);
      for (var index = 0; index < _keyLength; index++) {
        // `nextInt(256)` fournit un octet non signé.
        key[index] = secureRandom.nextInt(256);
      }

      // Persistance dans le coffre natif, encodée en Base64.
      await _storage.write(key: _storageKey, value: base64Encode(key));

      // Retour de la clé fraîchement créée.
      return key;
    } on Object catch (error) {
      // Aucun détail sensible n'est inclus dans le message public.
      throw SecureStorageException(
        'Impossible d’accéder à la clé de chiffrement locale.',
        cause: error,
      );
    }
  }

  /// Supprime définitivement la clé de chiffrement.
  @override
  Future<void> deleteHiveKey() async {
    // Bloc de capture pour conserver un contrat d'erreur stable.
    try {
      await _storage.delete(key: _storageKey);
    } on Object catch (error) {
      throw SecureStorageException(
        'Impossible de supprimer la clé de chiffrement locale.',
        cause: error,
      );
    }
  }

  /// Lit un secret arbitraire dans le Keychain/Keystore.
  @override
  Future<String?> readSecret(String key) async {
    // Capture des erreurs natives : la Présentation ne voit que des Failure.
    try {
      return await _storage.read(key: _secretKey(key));
    } on Object catch (error) {
      throw SecureStorageException(
        'Impossible de lire le secret demandé.',
        cause: error,
      );
    }
  }

  /// Écrit un secret arbitraire dans le Keychain/Keystore.
  @override
  Future<void> writeSecret({required String key, required String value}) async {
    // Capture des erreurs natives : la Présentation ne voit que des Failure.
    try {
      await _storage.write(key: _secretKey(key), value: value);
    } on Object catch (error) {
      throw SecureStorageException(
        'Impossible d’enregistrer le secret.',
        cause: error,
      );
    }
  }

  /// Supprime un secret arbitraire du Keychain/Keystore.
  @override
  Future<void> deleteSecret(String key) async {
    // Capture des erreurs natives : la Présentation ne voit que des Failure.
    try {
      await _storage.delete(key: _secretKey(key));
    } on Object catch (error) {
      throw SecureStorageException(
        'Impossible de supprimer le secret.',
        cause: error,
      );
    }
  }

  /// Préfixe les clés pour éviter toute collision avec la clé AES du cache.
  static String _secretKey(String key) => 'koudougou_secret_v1_$key';
}
