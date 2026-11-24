// =============================================================================
// Politique de sécurité locale (paramètres centralisés et testables).
// -----------------------------------------------------------------------------
// Ces valeurs s'appliquent aux espaces gérant et administration. Elles sont
// volontairement explicites : une politique cachée dans le code ne peut pas
// être revue, testée ni expliquée à l'utilisateur.
// =============================================================================

/// Règles de verrouillage et de dérivation des codes.
final class SecurityPolicy {
  // Espace de noms statique uniquement.
  const SecurityPolicy._();

  /// Itérations PBKDF2-HMAC-SHA256 (ordre de grandeur OWASP).
  static const int pbkdf2Iterations = 210000;

  /// Nombre d'échecs autorisés avant le premier verrouillage.
  static const int maxFailedAttempts = 5;

  /// Durée du premier verrouillage.
  static const Duration baseLockDuration = Duration(seconds: 30);

  /// Plafond du verrouillage, même après de nombreuses séries d'échecs.
  static const Duration maxLockDuration = Duration(minutes: 15);

  /// Durée d'inactivité après laquelle un espace déverrouillé se reverrouille.
  static const Duration sessionTimeout = Duration(minutes: 5);

  /// Durée du verrouillage pour un nombre d'échecs donné.
  ///
  /// Tant que le seuil n'est pas atteint, la durée est nulle. Ensuite elle
  /// double à chaque série de [maxFailedAttempts] échecs, sans dépasser
  /// [maxLockDuration].
  static Duration lockDurationFor(int failedAttempts) {
    if (failedAttempts < maxFailedAttempts) {
      return Duration.zero;
    }
    final int tier = failedAttempts ~/ maxFailedAttempts - 1;
    final int multiplier = 1 << tier.clamp(0, 5);
    final Duration candidate = baseLockDuration * multiplier;
    return candidate > maxLockDuration ? maxLockDuration : candidate;
  }

  /// Texte court affiché à l'utilisateur pour un verrouillage restant.
  static String formatRemaining(Duration remaining) {
    final int seconds = (remaining.inMilliseconds / 1000).ceil();
    if (seconds < 60) {
      return '$seconds s';
    }
    final int minutes = (seconds / 60).ceil();
    return '$minutes min';
  }
}
