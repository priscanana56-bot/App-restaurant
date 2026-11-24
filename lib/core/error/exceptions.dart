// =============================================================================
// Exceptions techniques de l'application.
// -----------------------------------------------------------------------------
// Les exceptions restent confinées aux couches Data / Core. Elles ne traversent
// JAMAIS la frontière du Domain : elles sont converties en `Failure` par
// `ErrorMapper`. Cela évite qu'un détail d'implémentation (HTTP, Hive, plugin)
// ne fuite dans l'interface.
// =============================================================================

/// Exception racine de toutes les erreurs applicatives connues.
/// `sealed` garantit que le compilateur connaît toutes les sous-classes et
/// permet un `switch` exhaustif dans `ErrorMapper`.
sealed class AppException implements Exception {
  /// Constructeur protégé : seules les sous-classes de ce fichier l'utilisent.
  const AppException(this.message, {this.cause});

  /// Message lisible par les développeurs (jamais affiché tel quel à l'utilisateur).
  final String message;

  /// Erreur d'origine, conservée pour le diagnostic local.
  /// Type `Object?` plutôt que `dynamic` : aucune opération non typée.
  final Object? cause;

  /// Représentation technique utile pour les logs de développement.
  @override
  String toString() {
    // Le préfixe contient le type concret pour faciliter le tri des logs.
    return '$runtimeType: $message';
  }
}

// =============================================================================
// Exceptions réseau / serveur
// =============================================================================

/// Erreur renvoyée par une API distante (statut HTTP incorrect, payload invalide).
final class ServerException extends AppException {
  /// [statusCode] est optionnel : certaines erreurs surviennent sans réponse HTTP.
  const ServerException(super.message, {this.statusCode, super.cause});

  /// Code HTTP observé (401, 404, 500...), utile pour choisir un message UX.
  final int? statusCode;
}

/// Absence de connexion ou échec de résolution DNS/timeout.
final class NetworkException extends AppException {
  /// Constructeur simple : un message et la cause technique éventuelle.
  const NetworkException(super.message, {super.cause});
}

/// Données illisibles ou corrompues dans le cache local.
final class CacheException extends AppException {
  /// Constructeur simple, avec la cause technique pour le diagnostic.
  const CacheException(super.message, {super.cause});
}

/// Ressource demandée absente du catalogue local ou distant.
final class NotFoundException extends AppException {
  /// Constructeur simple, avec l'identifiant recherché pour le diagnostic.
  const NotFoundException(super.message, {this.resourceId});

  /// Identifiant technique non trouvé (déjà validé par le sanitizer).
  final String? resourceId;
}

// =============================================================================
// Exceptions de validation / sécurité
// =============================================================================

/// Entrée utilisateur invalide après nettoyage (téléphone, prix, texte...).
final class ValidationException extends AppException {
  /// Constructeur avec le champ fautif, pour cibler l'erreur dans le formulaire.
  const ValidationException(super.message, {this.field});

  /// Nom technique du champ invalide (ex. `phone`, `price`, `search`).
  final String? field;
}

/// Tentative d'action interdite par la politique de sécurité.
/// Exemple : ouverture d'une URL `javascript:` ou d'un hôte non autorisé.
final class SecurityException extends AppException {
  /// Constructeur simple.
  const SecurityException(super.message);
}

/// Permission système refusée (localisation, notifications...).
final class PermissionException extends AppException {
  /// Constructeur indiquant si le refus est définitif.
  const PermissionException(super.message, {this.isPermanentlyDenied = false});

  /// `true` si l'utilisateur a coché « ne plus demander » : l'app doit alors
  /// proposer un lien vers les réglages système.
  final bool isPermanentlyDenied;
}

/// Échec de récupération de la position GPS.
final class LocationException extends AppException {
  /// Constructeur simple.
  const LocationException(super.message);
}

// =============================================================================
// Exceptions liées aux intégrations externes
// =============================================================================

/// Échec d'ouverture d'un lien (WhatsApp, téléphone, carte).
final class ExternalLinkException extends AppException {
  /// Constructeur conservant l'URI cible pour le diagnostic.
  const ExternalLinkException(super.message, {this.uri});

  /// URI refusée ou non ouvrable, sous forme de chaîne déjà nettoyée.
  final String? uri;
}

/// Échec d'accès au coffre-fort natif (Keychain / Keystore).
final class SecureStorageException extends AppException {
  /// Constructeur simple, avec la cause native.
  const SecureStorageException(super.message, {super.cause});
}

/// Erreur inattendue, non couverte par les catégories précédentes.
/// Elle termine la hiérarchie `sealed` et Force `ErrorMapper` à traiter le cas.
final class UnknownException extends AppException {
  /// Constructeur simple, avec la cause d'origine.
  const UnknownException(super.message, {super.cause});
}
