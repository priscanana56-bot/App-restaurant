// =============================================================================
// Tests du BLoC du catalogue (écran d'accueil).
// -----------------------------------------------------------------------------
// Ils verrouillent le câblage entre les use cases et l'état publié :
//   - chargement offline-first (succès / échec) ;
//   - filtrage 100 % local (aucun rappel du repository) ;
//   - favoris et bandeau Live Braise.
// Le repository est un fake : aucun accès réseau, Hive ou GPS.
// =============================================================================

// Framework de test (matchers de flux inclus).
import 'package:flutter_test/flutter_test.dart';

// Erreurs métier.
import 'package:koudougou_gourmet/core/error/failures.dart';

// Horloge figée.
import 'package:koudougou_gourmet/core/utils/app_clock.dart';

// Entités.
import 'package:koudougou_gourmet/features/restaurants/domain/entities/restaurant.dart';

// Use cases réels consommés par le BLoC.
import 'package:koudougou_gourmet/features/restaurants/domain/usecases/filter_restaurants.dart';
import 'package:koudougou_gourmet/features/restaurants/domain/usecases/get_favorite_ids.dart';
import 'package:koudougou_gourmet/features/restaurants/domain/usecases/get_live_braise.dart';
import 'package:koudougou_gourmet/features/restaurants/domain/usecases/get_restaurants.dart';
import 'package:koudougou_gourmet/features/restaurants/domain/usecases/toggle_favorite.dart';

// BLoC testé.
import 'package:koudougou_gourmet/features/restaurants/presentation/bloc/restaurant_list_bloc.dart';
import 'package:koudougou_gourmet/features/restaurants/presentation/bloc/restaurant_list_event.dart';
import 'package:koudougou_gourmet/features/restaurants/presentation/bloc/restaurant_list_state.dart';

// Fixtures et doublures.
import '../support/fixtures.dart';

/// Construit le BLoC sur un faux repository et une horloge figée.
RestaurantListBloc _buildBloc(FakeRestaurantRepository repository) {
  // Horloge déterministe : lundi 16 novembre 2026, 19 h.
  final FixedClock clock = FixedClock(testNow);

  return RestaurantListBloc(
    getRestaurants: GetRestaurants(repository),
    filterRestaurants: FilterRestaurants(clock),
    getLiveBraise: GetLiveBraise(repository, clock),
    getFavoriteIds: GetFavoriteIds(repository),
    toggleFavorite: ToggleFavorite(repository),
    clock: clock,
  );
}

/// Matcher d'un état au statut [status] donné.
Matcher _stateWith(RestaurantListStatus status) => isA<RestaurantListState>()
    .having((RestaurantListState state) => state.status, 'status', status);

/// Point d'entrée des tests.
void main() {
  group('RestaurantListBloc', () {
    test('charge le catalogue et publie l’état prêt', () async {
      // Deux restaurants distincts.
      final FakeRestaurantRepository repository = FakeRestaurantRepository(
        restaurants: <Restaurant>[
          buildRestaurant(id: 'r1', name: 'Chez Awa'),
          buildRestaurant(id: 'r2', name: 'Le Baobab'),
        ],
      );
      final RestaurantListBloc bloc = _buildBloc(repository);
      addTearDown(bloc.close);

      // Abonnement AVANT l'émission de l'événement.
      final Future<void> expected = expectLater(
        bloc.stream,
        emitsInOrder(<Matcher>[
          _stateWith(RestaurantListStatus.loading),
          _stateWith(RestaurantListStatus.ready),
        ]),
      );

      bloc.add(const RestaurantListStarted());
      await expected;

      // État final : catalogue complet et liste visible identiques.
      expect(bloc.state.allRestaurants, hasLength(2));
      expect(bloc.state.visibleRestaurants, hasLength(2));
      expect(bloc.state.now, testNow);
      // Deux lectures du repository : le catalogue (`GetRestaurants`) puis le
      // calcul du Live Braise (`GetLiveBraise`), toutes deux servies par le
      // cache offline-first (aucun second appel réseau).
      expect(repository.getRestaurantsCalls, 2);
    });

    test('publie une Failure quand le repository échoue', () async {
      // Repository en erreur : aucune donnée renvoyée.
      final FakeRestaurantRepository repository = FakeRestaurantRepository(
        failure: const CacheFailure(),
      );
      final RestaurantListBloc bloc = _buildBloc(repository);
      addTearDown(bloc.close);

      final Future<void> expected = expectLater(
        bloc.stream,
        emitsInOrder(<Matcher>[
          _stateWith(RestaurantListStatus.loading),
          isA<RestaurantListState>()
              .having(
                (RestaurantListState state) => state.status,
                'status',
                RestaurantListStatus.failure,
              )
              .having(
                (RestaurantListState state) => state.failure,
                'failure',
                isA<CacheFailure>(),
              ),
        ]),
      );

      bloc.add(const RestaurantListStarted());
      await expected;
    });

    test('filtre localement sans rappeler le repository', () async {
      final FakeRestaurantRepository repository = FakeRestaurantRepository(
        restaurants: <Restaurant>[
          buildRestaurant(id: 'r1', name: 'Chez Awa'),
          buildRestaurant(id: 'r2', name: 'Le Baobab'),
        ],
      );
      final RestaurantListBloc bloc = _buildBloc(repository);
      addTearDown(bloc.close);

      // Chargement initial.
      bloc.add(const RestaurantListStarted());
      await bloc.stream.firstWhere(
        (RestaurantListState state) =>
            state.status == RestaurantListStatus.ready,
      );

      // Nombre de lectures du repository après le chargement initial.
      final int callsAfterLoad = repository.getRestaurantsCalls;

      // Nouvel état prêt attendu après la recherche.
      final Future<RestaurantListState> next = bloc.stream.firstWhere(
        (RestaurantListState state) =>
            state.status == RestaurantListStatus.ready,
      );
      bloc.add(const RestaurantListSearchChanged('Chez'));
      final RestaurantListState state = await next;

      // Un seul résultat, et le repository n'a PAS été rappelé.
      expect(state.visibleRestaurants, hasLength(1));
      expect(state.visibleRestaurants.single.name, 'Chez Awa');
      expect(state.allRestaurants, hasLength(2));
      expect(repository.getRestaurantsCalls, callsAfterLoad);
    });

    test('bascule un favori et met à jour l’ensemble', () async {
      final FakeRestaurantRepository repository = FakeRestaurantRepository(
        restaurants: <Restaurant>[buildRestaurant(id: 'r1')],
      );
      final RestaurantListBloc bloc = _buildBloc(repository);
      addTearDown(bloc.close);

      bloc.add(const RestaurantListStarted());
      await bloc.stream.firstWhere(
        (RestaurantListState state) =>
            state.status == RestaurantListStatus.ready,
      );

      // Attente de l'état contenant le favori.
      final Future<RestaurantListState> next = bloc.stream.firstWhere(
        (RestaurantListState state) => state.favoriteIds.contains('r1'),
      );
      bloc.add(const RestaurantListFavoriteToggled('r1'));
      final RestaurantListState state = await next;

      expect(state.favoriteIds, contains('r1'));
      expect(state.favoriteRestaurants, hasLength(1));
    });

    test('expose les braises actives du moment', () async {
      final FakeRestaurantRepository repository = FakeRestaurantRepository(
        restaurants: <Restaurant>[
          // Braise active à l'instant de référence.
          buildRestaurant(id: 'r1', liveBraise: buildLiveBraise()),
          // Aucune braise.
          buildRestaurant(id: 'r2', name: 'Le Baobab'),
        ],
      );
      final RestaurantListBloc bloc = _buildBloc(repository);
      addTearDown(bloc.close);

      bloc.add(const RestaurantListStarted());
      final RestaurantListState state = await bloc.stream.firstWhere(
        (RestaurantListState value) =>
            value.status == RestaurantListStatus.ready,
      );

      expect(state.liveBraise, hasLength(1));
      expect(state.hasLiveBraise('r1'), isTrue);
      expect(state.hasLiveBraise('r2'), isFalse);
    });

    test('le filtre « braise active » réduit la liste visible', () async {
      final FakeRestaurantRepository repository = FakeRestaurantRepository(
        restaurants: <Restaurant>[
          buildRestaurant(id: 'r1', liveBraise: buildLiveBraise()),
          buildRestaurant(id: 'r2', name: 'Le Baobab'),
        ],
      );
      final RestaurantListBloc bloc = _buildBloc(repository);
      addTearDown(bloc.close);

      bloc.add(const RestaurantListStarted());
      await bloc.stream.firstWhere(
        (RestaurantListState state) =>
            state.status == RestaurantListStatus.ready,
      );

      // Après bascule, un seul restaurant a une braise active.
      final Future<RestaurantListState> next = bloc.stream.firstWhere(
        (RestaurantListState state) =>
            state.status == RestaurantListStatus.ready &&
            state.filter.onlyLiveBraise,
      );
      bloc.add(const RestaurantListLiveBraiseToggled());
      final RestaurantListState state = await next;

      expect(state.visibleRestaurants, hasLength(1));
      expect(state.visibleRestaurants.single.id, 'r1');
    });

    test('le rafraîchissement relance le chargement', () async {
      final FakeRestaurantRepository repository = FakeRestaurantRepository(
        restaurants: <Restaurant>[buildRestaurant(id: 'r1')],
      );
      final RestaurantListBloc bloc = _buildBloc(repository);
      addTearDown(bloc.close);

      bloc.add(const RestaurantListStarted());
      await bloc.stream.firstWhere(
        (RestaurantListState state) =>
            state.status == RestaurantListStatus.ready,
      );

      // Nombre de lectures du repository après le chargement initial.
      final int callsAfterLoad = repository.getRestaurantsCalls;

      final Future<RestaurantListState> next = bloc.stream.firstWhere(
        (RestaurantListState state) =>
            state.status == RestaurantListStatus.ready,
      );
      bloc.add(const RestaurantListRefreshRequested());
      await next;

      // Le rafraîchissement relance le chargement : le repository est relu
      // (catalogue + Live Braise) au-delà des lectures initiales.
      expect(repository.getRestaurantsCalls, greaterThan(callsAfterLoad));
    });
  });
}
