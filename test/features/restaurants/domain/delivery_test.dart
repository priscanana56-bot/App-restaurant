// =============================================================================
// Tests des règles métier de livraison (calcul pur, sans Flutter ni GPS réel).
// -----------------------------------------------------------------------------
// On vérifie trois règles : le tarif 500 FCFA + 200 FCFA/km (arrondi au FCFA
// supérieur), le plafond
// de 5 km et la redirection vers les fast-foods déjà présents dans l'annuaire.
// =============================================================================

// Type Either des use cases.
import 'package:fpdart/fpdart.dart';

// Framework de test.
import 'package:flutter_test/flutter_test.dart';

// Tarif et rayon maximal.
import 'package:koudougou_gourmet/core/constants/app_constants.dart';

// Erreur métier.
import 'package:koudougou_gourmet/core/error/failures.dart';

// Objet-valeur de distance.
import 'package:koudougou_gourmet/core/location/geo_point.dart';

// Entités produites.
import 'package:koudougou_gourmet/features/restaurants/domain/entities/delivery_quote.dart';
import 'package:koudougou_gourmet/features/restaurants/domain/entities/nearby_restaurant.dart';
import 'package:koudougou_gourmet/features/restaurants/domain/entities/restaurant.dart';
import 'package:koudougou_gourmet/features/restaurants/domain/entities/restaurant_category.dart';

// Use cases testés.
import 'package:koudougou_gourmet/features/restaurants/domain/usecases/find_nearby_fast_foods.dart';
import 'package:koudougou_gourmet/features/restaurants/domain/usecases/quote_delivery.dart';

// Fixtures.
import '../support/fixtures.dart';

/// Point de référence : Snack Time (source publiée).
const GeoPoint _snackTime = GeoPoint(
  latitude: 12.2469375,
  longitude: -2.3885625,
);

/// Construit un point situé [kilometers] au nord de [origin].
///
/// Un degré de latitude vaut environ 111,195 km ; l'approximation est sans
/// conséquence ici car les scénarios sont volontairement éloignés des bornes.
GeoPoint _northOf(GeoPoint origin, double kilometers) {
  const double kmPerDegree = 111.195;
  return GeoPoint(
    latitude: origin.latitude + kilometers / kmPerDegree,
    longitude: origin.longitude,
  );
}

/// Extrait le devis d'un `Either`, en échouant explicitement sur une Failure.
DeliveryQuote _quoteOf(Either<Failure, DeliveryQuote> result) {
  return result.fold(
    (Failure failure) => throw StateError(failure.message),
    (DeliveryQuote quote) => quote,
  );
}

/// Point d'entrée des tests.
void main() {
  group('QuoteDelivery', () {
    const QuoteDelivery useCase = QuoteDelivery();

    test('calcule 500 FCFA + 200 FCFA/km', () {
      // Destination à environ 1 km : 500 + 200 = 700 FCFA.
      final DeliveryQuote quote = _quoteOf(
        useCase(
          origin: _snackTime,
          destination: _northOf(_snackTime, 1),
          deliveryAvailable: true,
        ),
      );

      expect(quote.isAvailable, isTrue);
      expect(quote.reason, isEmpty);
      expect(quote.distanceKm, greaterThan(0.9));
      expect(quote.distanceKm, lessThan(1.1));
      expect(
        quote.feeFcfa,
        AppConstants.deliveryBaseFeeFcfa +
            (quote.distanceKm * AppConstants.deliveryFeePerKmFcfa).ceil(),
      );
      expect(quote.feeFcfa, inInclusiveRange(600, 900));
    });

    test('arrondit le supplément au FCFA supérieur', () {
      final DeliveryQuote quote = _quoteOf(
        useCase(
          origin: _snackTime,
          destination: _northOf(_snackTime, 1.2),
          deliveryAvailable: true,
        ),
      );

      // La distance réelle est légèrement supérieure à 1,2 km : le prorata
      // dépasse 240 FCFA et doit être arrondi à 241 FCFA, jamais tronqué.
      expect(quote.distanceKm, greaterThan(1.2));
      expect(
        quote.feeFcfa,
        AppConstants.deliveryBaseFeeFcfa +
            (quote.distanceKm * AppConstants.deliveryFeePerKmFcfa).ceil(),
      );
      expect(quote.feeFcfa, 741);
    });

    test('refuse un service non proposé, même à faible distance', () {
      final DeliveryQuote quote = _quoteOf(
        useCase(
          origin: _snackTime,
          destination: _northOf(_snackTime, 0.5),
          deliveryAvailable: false,
        ),
      );

      expect(quote.isAvailable, isFalse);
      expect(quote.feeFcfa, 0);
      expect(quote.reason, contains('pas proposée'));
    });

    test('refuse au-delà de 5 km avec un message de redirection', () {
      final DeliveryQuote quote = _quoteOf(
        useCase(
          origin: _snackTime,
          destination: _northOf(_snackTime, 6),
          deliveryAvailable: true,
        ),
      );

      expect(quote.isAvailable, isFalse);
      expect(quote.feeFcfa, 0);
      expect(quote.distanceKm, greaterThan(AppConstants.deliveryMaxDistanceKm));
      expect(quote.reason, contains('Hors zone'));
      expect(quote.reason, contains('5 km'));
    });

    test('accepte une distance dans la limite des 5 km', () {
      final DeliveryQuote quote = _quoteOf(
        useCase(
          origin: _snackTime,
          destination: _northOf(_snackTime, 4.9),
          deliveryAvailable: true,
        ),
      );

      expect(quote.isAvailable, isTrue);
      expect(quote.feeFcfa, greaterThan(AppConstants.deliveryBaseFeeFcfa));
    });
  });

  group('FindNearbyFastFoods', () {
    const FindNearbyFastFoods useCase = FindNearbyFastFoods();

    test('ne garde que les fast-foods, triés du plus proche au plus loin', () {
      final List<NearbyRestaurant> nearby = useCase(
        origin: _snackTime,
        restaurants: <Restaurant>[
          buildRestaurant(
            id: 'maquis',
            name: 'Maquis éloigné',
            latitude: _snackTime.latitude + 0.001,
            longitude: _snackTime.longitude,
          ),
          buildRestaurant(
            id: 'far',
            name: 'Fast-food loin',
            category: RestaurantCategory.fastFood,
            latitude: _snackTime.latitude + 0.02,
            longitude: _snackTime.longitude,
          ),
          buildRestaurant(
            id: 'near',
            name: 'Fast-food proche',
            category: RestaurantCategory.fastFood,
            latitude: _snackTime.latitude + 0.002,
            longitude: _snackTime.longitude,
          ),
        ],
      );

      expect(
        nearby.map((NearbyRestaurant item) => item.restaurant.id).toList(),
        <String>['near', 'far'],
      );
      expect(nearby.first.distanceKm, lessThan(nearby.last.distanceKm));
    });

    test('exclut la fiche d’origine et limite le nombre de suggestions', () {
      final List<NearbyRestaurant> nearby = useCase(
        origin: _snackTime,
        restaurants: <Restaurant>[
          buildRestaurant(
            id: 'source',
            name: 'Snack Time',
            category: RestaurantCategory.fastFood,
            latitude: _snackTime.latitude,
            longitude: _snackTime.longitude,
          ),
          for (var index = 0; index < 5; index++)
            buildRestaurant(
              id: 'fast-$index',
              name: 'Fast-food $index',
              category: RestaurantCategory.fastFood,
              latitude: _snackTime.latitude + (index + 1) / 1000,
              longitude: _snackTime.longitude,
            ),
        ],
        excludeId: 'source',
        limit: 3,
      );

      expect(nearby, hasLength(AppConstants.nearbyFastFoodSuggestions));
      expect(
        nearby.map((NearbyRestaurant item) => item.restaurant.id),
        isNot(contains('source')),
      );
    });

    test('ne modifie jamais la liste du catalogue', () {
      final List<Restaurant> catalog = <Restaurant>[
        buildRestaurant(
          id: 'b',
          category: RestaurantCategory.fastFood,
          latitude: _snackTime.latitude + 0.02,
        ),
        buildRestaurant(
          id: 'a',
          category: RestaurantCategory.fastFood,
          latitude: _snackTime.latitude + 0.001,
        ),
      ];

      useCase(origin: _snackTime, restaurants: catalog);

      expect(catalog.map((Restaurant item) => item.id).toList(), <String>[
        'b',
        'a',
      ]);
    });
  });
}
