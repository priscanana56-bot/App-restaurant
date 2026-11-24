// =============================================================================
// Failures — erreurs métier exposées au Domain et à la Présentation.
// -----------------------------------------------------------------------------
// Une `Failure` est un objet pur, immuable, comparable (Equatable), sans aucune
// dépendance à Flutter, HTTP ou Hive. Les BLoC peuvent donc l'afficher, la
// comparer et la tester facilement.
// =============================================================================

// Equatable fournit `==`, `hashCode` et `toString` basés sur `props`.
import 'package:equatable/equatable.dart';

/// Erreur métier de base. `sealed` permet un traitement exhaustif côté UI.
sealed class Failure extends Equatable {
  /// Constructeur protégé, réservé aux sous-classes.
  const Failure({required this.message, required this.code});

  /// Message utilisateur en français, déjà sûr à afficher.
  final String message;

  /// Code stable et technique, utile pour les tests, la télémétrie et l'i18n.
  final String code;

  /// Liste des propriétés utilisées par Equatable pour comparer deux Failures.
  @override
  List<Object?> get props => <Object?>[runtimeType, message, code];
}

// =============================================================================
// Failures techniques
// =============================================================================

/// Erreur provenant du serveur distant.
final class ServerFailure extends Failure {
  /// [statusCode] aide l'UI à distinguer un 401 d'un 500.
  const ServerFailure({required super.message, this.statusCode})
    : super(code: 'server_error');

  /// Code HTTP éventuel renvoyé par l'API.
  final int? statusCode;

  /// Ajout du statut HTTP dans la comparaison d'égalité.
  @override
  List<Object?> get props => <Object?>[...super.props, statusCode];
}

/// Absence de connexion ou réseau instable.
final class NetworkFailure extends Failure {
  /// Constructeur avec message personnalisable (offline, timeout...).
  const NetworkFailure({
    super.message =
        'Connexion indisponible. Vérifiez votre réseau puis réessayez.',
  }) : super(code: 'network_error');
}

/// Cache local absent, corrompu ou illisible.
final class CacheFailure extends Failure {
  /// Constructeur avec message personnalisable.
  const CacheFailure({
    super.message = 'Les données locales sont momentanément indisponibles.',
  }) : super(code: 'cache_error');
}

/// Ressource demandée absente (restaurant supprimé, identifiant inconnu).
final class NotFoundFailure extends Failure {
  /// Constructeur avec message utilisateur.
  const NotFoundFailure({
    super.message = 'Cet élément n’est plus disponible dans l’application.',
  }) : super(code: 'not_found');
}

// =============================================================================
// Failures de validation et de sécurité
// =============================================================================

/// Saisie utilisateur invalide.
final class ValidationFailure extends Failure {
  /// [field] identifie le champ concerné pour l'affichage ciblé.
  const ValidationFailure({required super.message, this.field})
    : super(code: 'validation_error');

  /// Champ invalide (ex. `phone`, `price`, `search`).
  final String? field;

  /// Le champ fait partie de l'identité logique de la failure.
  @override
  List<Object?> get props => <Object?>[...super.props, field];
}

/// Action bloquée par la politique de sécurité.
final class SecurityFailure extends Failure {
  /// Constructeur avec message explicite et non technique.
  const SecurityFailure({
    super.message = 'Cette action a été bloquée pour des raisons de sécurité.',
  }) : super(code: 'security_error');
}

/// Permission système manquante ou refusée.
final class PermissionFailure extends Failure {
  /// [isPermanentlyDenied] permet d'afficher un bouton « Ouvrir les réglages ».
  const PermissionFailure({
    required super.message,
    this.isPermanentlyDenied = false,
  }) : super(code: 'permission_error');

  /// Refus définitif de la permission.
  final bool isPermanentlyDenied;

  /// Le caractère définitif modifie l'affichage : il entre dans l'égalité.
  @override
  List<Object?> get props => <Object?>[...super.props, isPermanentlyDenied];
}

/// Position GPS indisponible ou hors zone couverte.
final class LocationFailure extends Failure {
  /// Constructeur avec message personnalisable.
  const LocationFailure({
    super.message = 'Impossible de déterminer votre position pour le moment.',
  }) : super(code: 'location_error');
}

// =============================================================================
// Failures d'intégration externe
// =============================================================================

/// Lien externe invalide ou application cible absente.
final class ExternalLinkFailure extends Failure {
  /// Constructeur avec message utilisateur.
  const ExternalLinkFailure({
    super.message = 'Impossible d’ouvrir ce lien sur votre appareil.',
  }) : super(code: 'external_link_error');
}

/// Coffre-fort natif inaccessible (clé de chiffrement indisponible).
final class SecureStorageFailure extends Failure {
  /// Constructeur avec message utilisateur.
  const SecureStorageFailure({
    super.message = 'Le stockage sécurisé de l’appareil est indisponible.',
  }) : super(code: 'secure_storage_error');
}

/// Erreur inattendue : filet de sécurité de dernier recours.
final class UnknownFailure extends Failure {
  /// Constructeur avec message générique et code dédié.
  const UnknownFailure({
    super.message = 'Une erreur inattendue est survenue. Veuillez réessayer.',
  }) : super(code: 'unknown_error');
}
