// =============================================================================
// PBKDF2-HMAC-SHA256 (RFC 8018) sans dépendance native supplémentaire.
// -----------------------------------------------------------------------------
// `package:crypto` fournit le HMAC éprouvé ; cette fonction se contente
// d'assembler les blocs selon la spécification PBKDF2. Elle remplace l'ancien
// SHA-256 unique, beaucoup trop rapide à attaquer par force brute.
//
// Fonction pure, sans état et sans Flutter : testable avec les vecteurs connus.
// =============================================================================

// Tableau d'octets-indexé (fourni par `crypto`).
import 'dart:typed_data';

// HMAC et SHA-256 éprouvés.
import 'package:crypto/crypto.dart';

/// Longueur du digest SHA-256, en octets (un bloc PBKDF2).
const int _sha256BlockBytes = 32;

/// Dérive [keyLength] octets d'une clé depuis [password] et [salt].
///
/// [iterations] doit être strictement positif. La valeur de production est
/// définie dans `SecurityPolicy.pbkdf2Iterations` ; les tests peuvent utiliser
/// une valeur plus faible pour rester rapides.
List<int> derivePbkdf2Sha256({
  required List<int> password,
  required List<int> salt,
  required int iterations,
  int keyLength = _sha256BlockBytes,
}) {
  // Gardes : une dérivation avec zéro itération ne protégerait rien.
  if (iterations < 1) {
    throw ArgumentError.value(iterations, 'iterations', 'Doit être >= 1.');
  }
  if (keyLength < 1) {
    throw ArgumentError.value(keyLength, 'keyLength', 'Doit être >= 1.');
  }

  final Hmac hmac = Hmac(sha256, password);
  final int blockCount = (keyLength / _sha256BlockBytes).ceil();
  final List<int> derived = <int>[];

  for (int blockIndex = 1; blockIndex <= blockCount; blockIndex++) {
    // U1 = PRF(password, salt || INT_32_BE(blockIndex)).
    final List<int> blockInput = <int>[...salt, ..._bigEndian32(blockIndex)];
    List<int> u = hmac.convert(blockInput).bytes;
    final List<int> accumulated = List<int>.from(u);

    // U2..Uc, cumulés par XOR dans `accumulated`.
    for (int iteration = 1; iteration < iterations; iteration++) {
      u = hmac.convert(u).bytes;
      for (int byteIndex = 0; byteIndex < _sha256BlockBytes; byteIndex++) {
        accumulated[byteIndex] ^= u[byteIndex];
      }
    }
    derived.addAll(accumulated);
  }

  // PBKDF2 tronque le dernier bloc à la longueur demandée.
  return Uint8List.fromList(derived.sublist(0, keyLength));
}

/// Encode un entier sur 4 octets, suite de gauche (big endian).
List<int> _bigEndian32(int value) => <int>[
  (value >> 24) & 0xFF,
  (value >> 16) & 0xFF,
  (value >> 8) & 0xFF,
  value & 0xFF,
];
