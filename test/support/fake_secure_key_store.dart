// =============================================================================
// Coffre-fort natif simulé, partagé par les tests de sécurité et de portails.
// -----------------------------------------------------------------------------
// Il respecte exactement le contrat `SecureKeyStore` : aucune implémentation
// Flutter n'est nécessaire. Les valeurs sont conservées en mémoire le temps du
// test, ce qui permet de vérifier qu'aucun code n'y est écrit en clair.
// =============================================================================

// Tableau d'octets de la clé AES (contrat du coffre).
import 'dart:typed_data';

// Contrat simulé.
import 'package:koudougou_gourmet/core/security/secure_key_store.dart';

/// Coffre-fort en mémoire pour les tests.
final class FakeSecureKeyStore implements SecureKeyStore {
  /// Valeurs secrètes indexées par clé logique.
  final Map<String, String> secrets = <String, String>{};

  /// Compteur d'écritures, utile pour vérifier l'ordre des opérations.
  final List<String> writeOrder = <String>[];

  @override
  Future<Uint8List> getOrCreateHiveKey() async => Uint8List(32);

  @override
  Future<void> deleteHiveKey() async {
    secrets.clear();
    writeOrder.clear();
  }

  @override
  Future<String?> readSecret(String key) async => secrets[key];

  @override
  Future<void> writeSecret({required String key, required String value}) async {
    secrets[key] = value;
    writeOrder.add(key);
  }

  @override
  Future<void> deleteSecret(String key) async {
    secrets.remove(key);
  }

  /// Vrai si une valeur en clair a été stockée (ce qui ne doit jamais arriver).
  bool containsPlainText(String value) => secrets.values.contains(value);
}
