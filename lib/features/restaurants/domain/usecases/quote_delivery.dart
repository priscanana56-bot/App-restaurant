// =============================================================================
// Devis de livraison (règle métier pure).
// -----------------------------------------------------------------------------
// Tarif retenu : 500 FCFA + 200 FCFA/km (arrondi au FCFA supérieur), dans un rayon max
// de 5 km. Le calcul est local : aucune position, aucune adresse et aucun
// montant ne sont envoyés à un serveur. Les erreurs de saisie sont des Failure,
// tandis qu'un refus métier (hors zone, service non proposé) est un devis
// `isAvailable = false` accompagné d'une raison lisible.
// =============================================================================

// Type fonctionnel : jamais d'exception ni de `dynamic` à la frontière.
import 'package:fpdart/fpdart.dart';

// Bornes et tarif.
import '../../../../core/constants/app_constants.dart';

// Erreur métier en cas de position invalide.
import '../../../../core/error/failures.dart';

// Objet-valeur de géolocalisation (Haversine).
import '../../../../core/location/geo_point.dart';

// Validation des coordonnées saisies.
import '../../../../core/security/input_sanitizer.dart';

// Entité produite.
import '../entities/delivery_quote.dart';

/// Calcule le devis de livraison vers un point GPS pour une position donnée.
final class QuoteDelivery {
  /// Use case sans état : constructeur constant.
  const QuoteDelivery();

  /// Calcule le devis entre [origin] (utilisateur) et [destination] (fiche).
  ///
  /// [deliveryAvailable] est le champ pilote de l'entité affichée : il permet
  /// d'utiliser le même calcul pour une fiche de catalogue ou une fiche sourcée
  /// de l'annuaire, sans fabriquer d'entité fictive.
  Either<Failure, DeliveryQuote> call({
    required GeoPoint origin,
    required GeoPoint destination,
    required bool deliveryAvailable,
  }) {
    // Défense en profondeur : `GeoPoint` pose déjà des assertions, mais une
    // position invalide doit rester une Failure et jamais un crash.
    if (!InputSanitizer.isValidCoordinate(origin.latitude, origin.longitude)) {
      return const Left(ValidationFailure(message: 'Position GPS invalide.'));
    }

    // Distance haversine : précision suffisante à l'échelle d'une ville.
    final double distanceKm = origin.distanceToKm(destination);

    // 1. L'établissement doit déclarer le service.
    if (!deliveryAvailable) {
      return Right(
        DeliveryQuote.unavailable(
          distanceKm: distanceKm,
          reason: 'La livraison n’est pas proposée par cet établissement.',
        ),
      );
    }

    // 2. La zone de livraison est limitée à 5 km.
    if (distanceKm > AppConstants.deliveryMaxDistanceKm) {
      return Right(
        DeliveryQuote.unavailable(
          distanceKm: distanceKm,
          reason:
              'Hors zone : la livraison s’arrête à '
              '${AppConstants.deliveryMaxDistanceKm.toStringAsFixed(0)} km. '
              'Choisissez un fast-food proche ci-dessous.',
        ),
      );
    }

    // 3. Tarif : montant fixe + 200 FCFA/km, arrondi au FCFA supérieur
    //    (jamais de montant fractionnaire, jamais de sous-facturation).
    final int variableFee = (distanceKm * AppConstants.deliveryFeePerKmFcfa)
        .ceil();
    final int feeFcfa = AppConstants.deliveryBaseFeeFcfa + variableFee;

    return Right(DeliveryQuote(distanceKm: distanceKm, feeFcfa: feeFcfa));
  }
}
