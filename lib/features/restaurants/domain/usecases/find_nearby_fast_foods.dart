// =============================================================================
// Redirection hors zone de livraison.
// -----------------------------------------------------------------------------
// Au-delà de 5 km, l'application ne fabrique aucune adresse : elle propose les
// fast-foods DÉJÀ présents dans le catalogue, triés par distance croissante.
// Le use case est pur et déterministe (aucune I/O, aucun état).
// =============================================================================

// Bornes de la suggestion.
import '../../../../core/constants/app_constants.dart';

// Objet-valeur de distance.
import '../../../../core/location/geo_point.dart';

// Entités consommées et produites.
import '../entities/nearby_restaurant.dart';
import '../entities/restaurant.dart';
import '../entities/restaurant_category.dart';

/// Sélectionne les fast-foods les plus proches d'une position.
final class FindNearbyFastFoods {
  /// Use case sans état : constructeur constant.
  const FindNearbyFastFoods();

  /// Retourne au plus [limit] fast-foods, du plus proche au plus loin.
  ///
  /// [excludeId] permet d'écarter le restaurant d'origine (par exemple
  /// Snack Time) pour ne pas le proposer comme alternative à lui-même.
  List<NearbyRestaurant> call({
    required GeoPoint origin,
    required List<Restaurant> restaurants,
    String? excludeId,
    int? limit,
  }) {
    // Copie modifiable : la liste du catalogue reste immuable.
    final List<NearbyRestaurant> nearby = <NearbyRestaurant>[];

    for (final Restaurant restaurant in restaurants) {
      // Uniquement les fast-foods de l'annuaire, pas les maquis.
      if (restaurant.category != RestaurantCategory.fastFood) {
        continue;
      }
      // On ne propose jamais l'établissement d'origine.
      if (excludeId != null && restaurant.id == excludeId) {
        continue;
      }

      nearby.add(
        NearbyRestaurant(
          restaurant: restaurant,
          distanceKm: origin.distanceToKm(
            GeoPoint(
              latitude: restaurant.latitude,
              longitude: restaurant.longitude,
            ),
          ),
        ),
      );
    }

    // Tri par distance croissante, puis par nom pour un ordre stable.
    nearby.sort((NearbyRestaurant left, NearbyRestaurant right) {
      final int byDistance = left.distanceKm.compareTo(right.distanceKm);
      if (byDistance != 0) {
        return byDistance;
      }
      return left.restaurant.name.toLowerCase().compareTo(
        right.restaurant.name.toLowerCase(),
      );
    });

    final int maxResults = limit ?? AppConstants.nearbyFastFoodSuggestions;
    return List<NearbyRestaurant>.unmodifiable(
      nearby.take(maxResults < 0 ? 0 : maxResults),
    );
  }
}
