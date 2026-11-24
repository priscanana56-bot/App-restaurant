// =============================================================================
// Tests du BLoC de la fiche détaillée.
// -----------------------------------------------------------------------------
// Ils couvrent les trois scénarios essentiels :
//   - chargement réussi d'une fiche (avec son état favori) ;
//   - fiche introuvable (Failure métier, jamais d'exception) ;
//   - bascule du favori, y compris sans fiche chargée.
// =============================================================================

// Framework de test.
import 'package:flutter_test/flutter_test.dart';

// Erreurs métier.
import 'package:koudougou_gourmet/core/error/failures.dart';

// Entité.
import 'package:koudougou_gourmet/features/restaurants/domain/entities/restaurant.dart';

// Use cases réels.
import 'package:koudougou_gourmet/features/restaurants/domain/usecases/get_favorite_ids.dart';
import 'package:koudougou_gourmet/features/restaurants/domain/usecases/get_restaurant_by_id.dart';
import 'package:koudougou_gourmet/features/restaurants/domain/usecases/toggle_favorite.dart';

// BLoC testé.
import 'package:koudougou_gourmet/features/restaurants/presentation/bloc/restaurant_detail_bloc.dart';
import 'package:koudougou_gourmet/features/restaurants/presentation/bloc/restaurant_detail_event.dart';
import 'package:koudougou_gourmet/features/restaurants/presentation/bloc/restaurant_detail_state.dart';

// Fixtures et doublures.
import '../support/fixtures.dart';

/// Construit le BLoC sur un faux repository.
RestaurantDetailBloc _buildBloc(FakeRestaurantRepository repository) {
  return RestaurantDetailBloc(
    getRestaurantById: GetRestaurantById(repository),
    getFavoriteIds: GetFavoriteIds(repository),
    toggleFavorite: ToggleFavorite(repository),
  );
}

/// Matcher d'un état au statut [status] donné.
Matcher _stateWith(RestaurantDetailStatus status) =>
    isA<RestaurantDetailState>().having(
      (RestaurantDetailState state) => state.status,
      'status',
      status,
    );

/// Point d'entrée des tests.
void main() {
  group('RestaurantDetailBloc', () {
    test('charge une fiche puis son état favori', () async {
      final FakeRestaurantRepository repository = FakeRestaurantRepository(
        restaurants: <Restaurant>[buildRestaurant(id: 'r1', name: 'Chez Awa')],
      );
      final RestaurantDetailBloc bloc = _buildBloc(repository);
      addTearDown(bloc.close);

      final Future<void> expected = expectLater(
        bloc.stream,
        emitsInOrder(<Matcher>[
          _stateWith(RestaurantDetailStatus.loading),
          _stateWith(RestaurantDetailStatus.ready),
        ]),
      );

      bloc.add(const RestaurantDetailRequested('r1'));
      await expected;

      expect(bloc.state.restaurant?.id, 'r1');
      expect(bloc.state.restaurantId, 'r1');
      // Aucun favori stocké dans le fake.
      expect(bloc.state.isFavorite, isFalse);
    });

    test('publie NotFoundFailure pour un identifiant inconnu', () async {
      // Repository vide : la fiche est introuvable.
      final RestaurantDetailBloc bloc = _buildBloc(FakeRestaurantRepository());
      addTearDown(bloc.close);

      final Future<void> expected = expectLater(
        bloc.stream,
        emitsInOrder(<Matcher>[
          _stateWith(RestaurantDetailStatus.loading),
          isA<RestaurantDetailState>()
              .having(
                (RestaurantDetailState state) => state.status,
                'status',
                RestaurantDetailStatus.failure,
              )
              .having(
                (RestaurantDetailState state) => state.failure,
                'failure',
                isA<NotFoundFailure>(),
              ),
        ]),
      );

      bloc.add(const RestaurantDetailRequested('inconnu'));
      await expected;
    });

    test('bascule le favori de la fiche chargée', () async {
      final FakeRestaurantRepository repository = FakeRestaurantRepository(
        restaurants: <Restaurant>[buildRestaurant(id: 'r1')],
      );
      final RestaurantDetailBloc bloc = _buildBloc(repository);
      addTearDown(bloc.close);

      bloc.add(const RestaurantDetailRequested('r1'));
      await bloc.stream.firstWhere(
        (RestaurantDetailState state) =>
            state.status == RestaurantDetailStatus.ready,
      );

      final Future<RestaurantDetailState> next = bloc.stream.firstWhere(
        (RestaurantDetailState state) => state.isFavorite,
      );
      bloc.add(const RestaurantDetailFavoriteToggled());
      final RestaurantDetailState state = await next;

      expect(state.isFavorite, isTrue);
    });

    test('ignore la bascule tant qu’aucune fiche n’est chargée', () async {
      final FakeRestaurantRepository repository = FakeRestaurantRepository(
        restaurants: <Restaurant>[buildRestaurant(id: 'r1')],
      );
      final RestaurantDetailBloc bloc = _buildBloc(repository);
      addTearDown(bloc.close);

      // Aucun chargement préalable : l'événement doit être sans effet.
      bloc.add(const RestaurantDetailFavoriteToggled());
      await pumpEventQueue();

      expect(bloc.state.status, RestaurantDetailStatus.initial);
      expect(bloc.state.isFavorite, isFalse);
    });
  });
}
