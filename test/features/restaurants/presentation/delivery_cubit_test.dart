// =============================================================================
// Tests du Cubit de devis de livraison.
// -----------------------------------------------------------------------------
// Le GPS est remplacé par une doublure : aucun test n'accède à la position réelle
// de l'appareil. On vérifie le cycle de vie (attente -> devis ou échec) et la
// redirection proposée au-delà de 5 km.
// =============================================================================

// Erreurs métier.
import 'package:koudougou_gourmet/core/error/failures.dart';

// Objet-valeur géographique.
import 'package:koudougou_gourmet/core/location/geo_point.dart';

// Entités utilisées dans le catalogue simulé.
import 'package:koudougou_gourmet/features/restaurants/domain/entities/restaurant.dart';
import 'package:koudougou_gourmet/features/restaurants/domain/entities/restaurant_category.dart';

// Cubit testé.
import 'package:koudougou_gourmet/features/restaurants/presentation/bloc/delivery_cubit.dart';

// Use cases injectés.
import 'package:koudougou_gourmet/features/restaurants/domain/usecases/find_nearby_fast_foods.dart';
import 'package:koudougou_gourmet/features/restaurants/domain/usecases/get_restaurants.dart';
import 'package:koudougou_gourmet/features/restaurants/domain/usecases/quote_delivery.dart';

// Framework de test.
import 'package:flutter_test/flutter_test.dart';

// Fixtures et doublures.
import '../support/fixtures.dart';

/// Point de référence : Snack Time (source publiée).
const GeoPoint _snackTime = GeoPoint(
  latitude: 12.2469375,
  longitude: -2.3885625,
);

/// Construit le Cubit avec un GPS et un catalogue contrôlés.
DeliveryCubit _buildCubit({
  required FakeLocationService location,
  List<Restaurant> restaurants = const <Restaurant>[],
}) {
  return DeliveryCubit(
    location,
    const QuoteDelivery(),
    const FindNearbyFastFoods(),
    GetRestaurants(FakeRestaurantRepository(restaurants: restaurants)),
  );
}

/// Demande un devis avec la cible fournie.
Future<void> _request(
  DeliveryCubit cubit, {
  GeoPoint destination = _snackTime,
  bool available = true,
}) {
  return cubit.requestLocation(
    id: 'snack-time-bcb',
    label: 'Snack Time',
    destination: destination,
    deliveryAvailable: available,
  );
}

/// Point d'entrée des tests.
void main() {
  group('DeliveryCubit', () {
    test('démarre sans devis', () {
      final DeliveryCubit cubit = _buildCubit(
        location: FakeLocationService(position: _snackTime),
      );
      addTearDown(cubit.close);

      expect(cubit.state.status, DeliveryStatus.initial);
      expect(cubit.state.hasQuote, isFalse);
    });

    test('publie un devis disponible après localisation', () async {
      final DeliveryCubit cubit = _buildCubit(
        location: FakeLocationService(position: _snackTime),
      );
      addTearDown(cubit.close);

      await _request(cubit);

      expect(cubit.state.status, DeliveryStatus.ready);
      expect(cubit.state.hasQuote, isTrue);
      expect(cubit.state.quote!.isAvailable, isTrue);
      expect(cubit.state.quote!.distanceKm, 0);
      expect(cubit.state.targetId, 'snack-time-bcb');
      expect(
        cubit.state.matchesTarget(
          id: 'snack-time-bcb',
          destinationPoint: _snackTime,
          available: true,
        ),
        isTrue,
      );
    });

    test(
      'propose des fast-foods proches quand la distance dépasse 5 km',
      () async {
        // Position à environ 6 km au nord de Snack Time.
        const GeoPoint farOrigin = GeoPoint(
          latitude: 12.305,
          longitude: -2.3885625,
        );
        final DeliveryCubit cubit = _buildCubit(
          location: FakeLocationService(position: farOrigin),
          restaurants: <Restaurant>[
            buildRestaurant(
              id: 'fast-near',
              name: 'Fast-food proche',
              category: RestaurantCategory.fastFood,
              latitude: 12.299,
              longitude: -2.3885625,
            ),
            buildRestaurant(
              id: 'maquis',
              name: 'Maquis proche',
              category: RestaurantCategory.maquis,
              latitude: 12.298,
              longitude: -2.3885625,
            ),
          ],
        );
        addTearDown(cubit.close);

        await _request(cubit);

        expect(cubit.state.status, DeliveryStatus.ready);
        expect(cubit.state.quote!.isAvailable, isFalse);
        expect(cubit.state.quote!.reason, contains('Hors zone'));
        expect(cubit.state.nearbyFastFoods, hasLength(1));
        expect(cubit.state.nearbyFastFoods.single.restaurant.id, 'fast-near');
      },
    );

    test('publie une Failure de localisation sans calculer de devis', () async {
      final DeliveryCubit cubit = _buildCubit(
        location: FakeLocationService(
          failure: const PermissionFailure(message: 'Position refusée.'),
        ),
      );
      addTearDown(cubit.close);

      await _request(cubit);

      expect(cubit.state.status, DeliveryStatus.failure);
      expect(cubit.state.failure, isA<PermissionFailure>());
      expect(cubit.state.hasQuote, isFalse);
    });

    test('un devis périmé ne correspond plus à une autre cible', () async {
      final DeliveryCubit cubit = _buildCubit(
        location: FakeLocationService(position: _snackTime),
      );
      addTearDown(cubit.close);

      await _request(cubit);
      expect(cubit.state.hasQuote, isTrue);

      expect(
        cubit.state.matchesTarget(
          id: 'autre-fiche',
          destinationPoint: _snackTime,
          available: true,
        ),
        isFalse,
      );
    });
  });
}
