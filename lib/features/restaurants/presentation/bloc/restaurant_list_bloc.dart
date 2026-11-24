// =============================================================================
// BLoC du catalogue de restaurants.
// -----------------------------------------------------------------------------
// Il orchestre trois responsabilités :
//   1. charger le catalogue offline-first (use case `GetRestaurants`) ;
//   2. filtrer/trier localement (use case `FilterRestaurants`, pur et rapide) ;
//   3. gérer les favoris et le bandeau Live Braise.
// Aucune exception ne remonte : les use cases renvoient déjà des `Failure`.
// =============================================================================

// BLoC et émetteur d'états.
import 'package:flutter_bloc/flutter_bloc.dart';

// Type fonctionnel Either.
import 'package:fpdart/fpdart.dart';

// Erreur métier.
import '../../../../core/error/failures.dart';

// Horloge injectable (statuts « ouvert maintenant »).
import '../../../../core/utils/app_clock.dart';

// Entités.
import '../../domain/entities/live_braise_status.dart';
import '../../domain/entities/restaurant.dart';
import '../../domain/entities/restaurant_category.dart';
import '../../domain/entities/restaurant_filter.dart';

// Use cases consommés.
import '../../domain/usecases/filter_restaurants.dart';
import '../../domain/usecases/get_favorite_ids.dart';
import '../../domain/usecases/get_live_braise.dart';
import '../../domain/usecases/get_restaurants.dart';
import '../../domain/usecases/toggle_favorite.dart';

// Contrat d'événements et d'état.
import 'restaurant_list_event.dart';
import 'restaurant_list_state.dart';

/// BLoC de l'écran d'accueil.
final class RestaurantListBloc
    extends Bloc<RestaurantListEvent, RestaurantListState> {
  /// Injection de tous les use cases nécessaires et de l'horloge.
  RestaurantListBloc({
    required this._getRestaurants,
    required this._filterRestaurants,
    required this._getLiveBraise,
    required this._getFavoriteIds,
    required this._toggleFavorite,
    required this._clock,
  }) : super(const RestaurantListState()) {
    // Enregistrement des handlers : un événement -> un traitement.
    on<RestaurantListStarted>(_onStarted);
    on<RestaurantListRefreshRequested>(_onRefreshRequested);
    on<RestaurantListSearchChanged>(_onSearchChanged);
    on<RestaurantListCategoryToggled>(_onCategoryToggled);
    on<RestaurantListSortChanged>(_onSortChanged);
    on<RestaurantListOpenNowToggled>(_onOpenNowToggled);
    on<RestaurantListLiveBraiseToggled>(_onLiveBraiseToggled);
    on<RestaurantListVerifiedToggled>(_onVerifiedToggled);
    on<RestaurantListFiltersCleared>(_onFiltersCleared);
    on<RestaurantListFavoriteToggled>(_onFavoriteToggled);
  }

  // Dépendances métier.
  final GetRestaurants _getRestaurants;
  final FilterRestaurants _filterRestaurants;
  final GetLiveBraise _getLiveBraise;
  final GetFavoriteIds _getFavoriteIds;
  final ToggleFavorite _toggleFavorite;
  final AppClock _clock;

  // ---------------------------------------------------------------------------
  // Chargement
  // ---------------------------------------------------------------------------

  /// Chargement initial.
  Future<void> _onStarted(
    RestaurantListStarted event,
    Emitter<RestaurantListState> emit,
  ) => _load(emit: emit, forceRefresh: false);

  /// Rafraîchissement explicite demandé par l'utilisateur.
  Future<void> _onRefreshRequested(
    RestaurantListRefreshRequested event,
    Emitter<RestaurantListState> emit,
  ) => _load(emit: emit, forceRefresh: true);

  /// Cœur du chargement : catalogue + filtrage + braises + favoris.
  Future<void> _load({
    required Emitter<RestaurantListState> emit,
    required bool forceRefresh,
  }) async {
    // Passage en chargement en effaçant l'erreur précédente.
    emit(state.copyWith(status: RestaurantListStatus.loading, failure: null));

    // Appel du use case offline-first.
    final Either<Failure, List<Restaurant>> result = await _getRestaurants(
      GetRestaurantsParams(forceRefresh: forceRefresh),
    );

    // Traitement fonctionnel : erreur ou succès, jamais d'exception.
    await result.fold(
      (Failure failure) async {
        // On conserve la liste déjà affichée en cas d'échec d'un refresh.
        emit(
          state.copyWith(
            status: RestaurantListStatus.failure,
            failure: failure,
          ),
        );
      },
      (List<Restaurant> restaurants) async {
        // 1. Application du filtre courant sur le catalogue frais.
        final List<Restaurant> visible = await _applyFilter(
          restaurants,
          state.filter,
        );

        // 2. Braises actives (lecture de cache, pas d'appel réseau inutile).
        final List<LiveBraiseStatus> braise = await _loadLiveBraise();

        // 3. Favoris locaux.
        final Set<String> favorites = await _loadFavorites();

        // 4. Publication de l'état prêt.
        emit(
          state.copyWith(
            status: RestaurantListStatus.ready,
            allRestaurants: restaurants,
            visibleRestaurants: visible,
            liveBraise: braise,
            favoriteIds: favorites,
            now: _clock.now(),
            failure: null,
          ),
        );
      },
    );
  }

  // ---------------------------------------------------------------------------
  // Filtres et tri (100 % locaux)
  // ---------------------------------------------------------------------------

  /// Recherche plein texte.
  Future<void> _onSearchChanged(
    RestaurantListSearchChanged event,
    Emitter<RestaurantListState> emit,
  ) => _reapplyFilter(emit, state.filter.copyWith(query: event.query));

  /// Sélection/désélection d'une catégorie.
  Future<void> _onCategoryToggled(
    RestaurantListCategoryToggled event,
    Emitter<RestaurantListState> emit,
  ) {
    // Re-taper la catégorie active la désactive.
    final RestaurantCategory? next = state.filter.category == event.category
        ? null
        : event.category;
    return _reapplyFilter(emit, state.filter.copyWith(category: next));
  }

  /// Changement d'ordre.
  Future<void> _onSortChanged(
    RestaurantListSortChanged event,
    Emitter<RestaurantListState> emit,
  ) => _reapplyFilter(emit, state.filter.copyWith(sort: event.sort));

  /// Filtre « ouvert maintenant ».
  Future<void> _onOpenNowToggled(
    RestaurantListOpenNowToggled event,
    Emitter<RestaurantListState> emit,
  ) => _reapplyFilter(
    emit,
    state.filter.copyWith(onlyOpenNow: !state.filter.onlyOpenNow),
  );

  /// Filtre « Live Braise active ».
  Future<void> _onLiveBraiseToggled(
    RestaurantListLiveBraiseToggled event,
    Emitter<RestaurantListState> emit,
  ) => _reapplyFilter(
    emit,
    state.filter.copyWith(onlyLiveBraise: !state.filter.onlyLiveBraise),
  );

  /// Filtre « vérifié sur place ».
  Future<void> _onVerifiedToggled(
    RestaurantListVerifiedToggled event,
    Emitter<RestaurantListState> emit,
  ) => _reapplyFilter(
    emit,
    state.filter.copyWith(onlyVerified: !state.filter.onlyVerified),
  );

  /// Réinitialisation des critères, en conservant l'ordre choisi.
  Future<void> _onFiltersCleared(
    RestaurantListFiltersCleared event,
    Emitter<RestaurantListState> emit,
  ) => _reapplyFilter(emit, RestaurantFilter(sort: state.filter.sort));

  /// Applique un nouveau filtre sur le catalogue déjà chargé.
  Future<void> _reapplyFilter(
    Emitter<RestaurantListState> emit,
    RestaurantFilter filter,
  ) async {
    // Filtrage local pur : aucune I/O, donc instantané.
    final List<Restaurant> visible = await _applyFilter(
      state.allRestaurants,
      filter,
    );

    // Publication du nouvel état (le catalogue complet reste intact).
    emit(state.copyWith(filter: filter, visibleRestaurants: visible));
  }

  // ---------------------------------------------------------------------------
  // Favoris
  // ---------------------------------------------------------------------------

  /// Inverse le favori demandé puis met à jour l'ensemble local.
  Future<void> _onFavoriteToggled(
    RestaurantListFavoriteToggled event,
    Emitter<RestaurantListState> emit,
  ) async {
    final Either<Failure, bool> result = await _toggleFavorite(
      ToggleFavoriteParams(restaurantId: event.restaurantId),
    );

    // Succès : on synchronise l'ensemble des favoris ; échec : on ignore
    // silencieusement (l'état précédent reste affiché, sans crash).
    result.fold((Failure failure) {}, (bool isFavorite) {
      final Set<String> next = Set<String>.of(state.favoriteIds);
      if (isFavorite) {
        next.add(event.restaurantId);
      } else {
        next.remove(event.restaurantId);
      }
      emit(state.copyWith(favoriteIds: next));
    });
  }

  // ---------------------------------------------------------------------------
  // Helpers
  // ---------------------------------------------------------------------------

  /// Applique `FilterRestaurants` et retombe sur la source en cas d'échec
  /// (impossible en pratique : le filtrage local renvoie toujours un succès).
  Future<List<Restaurant>> _applyFilter(
    List<Restaurant> source,
    RestaurantFilter filter,
  ) async {
    final Either<Failure, List<Restaurant>> result = await _filterRestaurants(
      FilterRestaurantsParams(restaurants: source, filter: filter),
    );
    return result.fold(
      (Failure failure) => source,
      (List<Restaurant> value) => value,
    );
  }

  /// Charge les braises actives ; une erreur produit une liste vide.
  Future<List<LiveBraiseStatus>> _loadLiveBraise() async {
    final Either<Failure, List<LiveBraiseStatus>> result = await _getLiveBraise(
      const GetLiveBraiseParams(),
    );
    return result.fold(
      (Failure failure) => const <LiveBraiseStatus>[],
      (List<LiveBraiseStatus> value) => value,
    );
  }

  /// Charge les identifiants favoris ; une erreur produit un ensemble vide.
  Future<Set<String>> _loadFavorites() async {
    final Either<Failure, Set<String>> result = await _getFavoriteIds();
    return result.fold(
      (Failure failure) => const <String>{},
      (Set<String> value) => value,
    );
  }
}
