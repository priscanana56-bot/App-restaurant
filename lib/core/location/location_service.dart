// =============================================================================
// Service de localisation GPS.
// -----------------------------------------------------------------------------
// La Présentation ne parle JAMAIS directement à `geolocator` : elle consomme ce
// contrat et reçoit un `Either<Failure, GeoPoint>`. Toute erreur native
// (permission refusée, service désactivé, timeout) devient une `Failure`
// affichable, et un fake peut être injecté dans les tests.
// =============================================================================

// Type fonctionnel : jamais d'exception traversant la couche Présentation.
import 'package:fpdart/fpdart.dart';

// Plugin natif de géolocalisation.
import 'package:geolocator/geolocator.dart';

// Erreurs métier.
import '../error/failures.dart';

// Objet-valeur retourné.
import 'geo_point.dart';

/// Contrat de récupération de la position courante.
abstract interface class LocationService {
  /// Demande la permission si nécessaire puis renvoie la position courante.
  Future<Either<Failure, GeoPoint>> currentPosition();
}

/// Implémentation réelle basée sur `geolocator`.
final class GeolocatorLocationService implements LocationService {
  /// Constructeur constant : aucune ressource à conserver.
  const GeolocatorLocationService();

  /// Vérifie service + permission, puis lit la position.
  @override
  Future<Either<Failure, GeoPoint>> currentPosition() async {
    // Bloc de capture : aucune exception native ne doit remonter à l'UI.
    try {
      // 1. Le service de localisation du téléphone doit être activé.
      final bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        return left(
          const LocationFailure(
            message:
                'Activez la localisation de votre appareil puis réessayez.',
          ),
        );
      }

      // 2. Permission éventuellement déjà accordée.
      LocationPermission permission = await Geolocator.checkPermission();

      // 3. Demande explicite si elle n'a pas encore été faite.
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }

      // 4. Refus simple : l'utilisateur peut réessayer.
      if (permission == LocationPermission.denied) {
        return left(
          const PermissionFailure(
            message: 'L’accès à votre position a été refusé.',
          ),
        );
      }

      // 5. Refus définitif : l'UI proposera d'ouvrir les réglages.
      if (permission == LocationPermission.deniedForever) {
        return left(
          const PermissionFailure(
            message: 'L’accès à votre position est bloqué. Activez-le dans les réglages.',
            isPermanentlyDenied: true,
          ),
        );
      }

      // 6. Lecture effective de la position (précision par défaut du plugin).
      final Position position = await Geolocator.getCurrentPosition();

      // 7. Conversion en objet-valeur du Domain.
      return right(
        GeoPoint(latitude: position.latitude, longitude: position.longitude),
      );
    } on Object {
      // Filet de sécurité : message générique, sans détail technique.
      return left(const LocationFailure());
    }
  }
}
