// =============================================================================
// Conversion centralisée Exceptions -> Failures.
// -----------------------------------------------------------------------------
// Point unique de traduction entre le monde technique et le monde métier.
// Aucune couche supérieure n'a besoin de connaître HTTP, Hive ou un plugin :
// elle ne reçoit que des `Failure` stables et affichables.
// =============================================================================

// Import des erreurs métier exposées au Domain.
import 'failures.dart';

// Import des exceptions techniques confinées à Core/Data.
import 'exceptions.dart';

/// Traducteur sans état, donc injectable et testable facilement.
final class ErrorMapper {
  /// Constructeur constant : aucune dépendance interne à conserver.
  const ErrorMapper();

  /// Transforme n'importe quelle erreur en `Failure`.
  /// Le `switch` sur un type `sealed` est vérifié par le compilateur.
  Failure map(Object error) {
    // Analyse par motif : chaque exception connue a sa Failure dédiée.
    return switch (error) {
      // Erreur serveur : le message technique n'est pas exposé à l'utilisateur,
      // mais le statut HTTP est conservé pour adapter l'UI (401, 404, 500...).
      ServerException(:final int? statusCode) => ServerFailure(
        message:
            'Le serveur est momentanément indisponible. Réessayez plus tard.',
        statusCode: statusCode,
      ),

      // Erreur réseau : message actionnable pour l'utilisateur.
      NetworkException() => const NetworkFailure(),

      // Cache local : l'application peut proposer de réessayer ou de vider le cache.
      CacheException() => const CacheFailure(),

      // Ressource absente : message dédié, sans détail technique.
      NotFoundException() => const NotFoundFailure(),

      // Validation : le message est rédigé par nos soins, donc sûr à afficher.
      ValidationException(:final String message, :final String? field) =>
        ValidationFailure(message: message, field: field),

      // Sécurité : message volontairement générique, sans détail exploitable.
      SecurityException() => const SecurityFailure(),

      // Permission : on conserve le caractère définitif du refus.
      PermissionException(
        :final String message,
        :final bool isPermanentlyDenied,
      ) =>
        PermissionFailure(
          message: message,
          isPermanentlyDenied: isPermanentlyDenied,
        ),

      // Localisation : message dédié, sans exposer l'état interne du GPS.
      LocationException() => const LocationFailure(),

      // Lien externe : l'utilisateur peut installer l'application manquante.
      ExternalLinkException() => const ExternalLinkFailure(),

      // Coffre-fort natif : l'application continuera en mode lecture seule non chiffré
      // uniquement si la politique le permet (décision prise par le Repository).
      SecureStorageException() => const SecureStorageFailure(),

      // Toute autre exception applicative explicitement levée.
      UnknownException() => const UnknownFailure(),

      // Filet de sécurité : objet non prévu (bug, plugin tiers).
      _ => const UnknownFailure(),
    };
  }

  /// Variante utilitaire pour un `Result` fonctionnel : renvoie toujours une
  /// Failure, jamais une exception. Le paramètre `StackTrace` est accepté pour
  /// permettre à un logger de le consommer, mais il n'est pas inclus dans la
  /// Failure afin de ne pas exposer de chemins internes à l'UI.
  Failure mapWithStack(Object error, StackTrace stackTrace) {
    // Le stack trace n'est volontairement pas stocké dans l'objet métier.
    // Un logger (branché plus tard) peut l'utiliser avant cet appel.
    return map(error);
  }
}
