// =============================================================================
// BLoC de la fiche détaillée d'un restaurant.
// -----------------------------------------------------------------------------
// Il charge une fiche par identifiant, puis reflète et modifie son état favori.
// La fiche est revalidée côté Domain (`GetRestaurantById` nettoie l'identifiant),
// donc un lien profond forgé ne peut pas atteindre le stockage.
// =============================================================================

// BLoC et émetteur.
import 'package:flutter_bloc/flutter_bloc.dart';

// Type fonctionnel.
import 'package:fpdart/fpdart.dart';

// Erreur métier.
import '../../../../core/error/failures.dart';

// Entité.
import '../../domain/entities/restaurant.dart';

// Use cases consommés.
import '../../domain/usecases/get_favorite_ids.dart';
import '../../domain/usecases/get_restaurant_by_id.dart';
import '../../domain/usecases/toggle_favorite.dart';

// Contrat d'événements et d'état.
import 'restaurant_detail_event.dart';
import 'restaurant_detail_state.dart';

/// BLoC de la fiche restaurant.
final class RestaurantDetailBloc
    extends Bloc<RestaurantDetailEvent, RestaurantDetailState> {
  /// Injection des use cases nécessaires.
  RestaurantDetailBloc({
    required this._getRestaurantById,
    required this._getFavoriteIds,
    required this._toggleFavorite,
  }) : super(const RestaurantDetailState()) {
    // Handlers.
    on<RestaurantDetailRequested>(_onRequested);
    on<RestaurantDetailFavoriteToggled>(_onFavoriteToggled);
  }

  // Dépendances métier.
  final GetRestaurantById _getRestaurantById;
  final GetFavoriteIds _getFavoriteIds;
  final ToggleFavorite _toggleFavorite;

  /// Charge la fiche puis son état favori.
  Future<void> _onRequested(
    RestaurantDetailRequested event,
    Emitter<RestaurantDetailState> emit,
  ) async {
    // État de chargement avec l'identifiant demandé.
    emit(
      state.copyWith(
        status: RestaurantDetailStatus.loading,
        restaurantId: event.restaurantId,
        failure: null,
      ),
    );

    // Lecture de la fiche (cache -> réseau -> seed gérés par la Data).
    final Either<Failure, Restaurant> result = await _getRestaurantById(
      GetRestaurantByIdParams(event.restaurantId),
    );

    await result.fold(
      (Failure failure) async {
        // Échec : message métier, aucun détail technique.
        emit(
          state.copyWith(
            status: RestaurantDetailStatus.failure,
            failure: failure,
          ),
        );
      },
      (Restaurant restaurant) async {
        // Lecture des favoris pour colorer le cœur.
        final Either<Failure, Set<String>> favorites = await _getFavoriteIds();
        final bool isFavorite = favorites.fold(
          (Failure failure) => false,
          (Set<String> ids) => ids.contains(restaurant.id),
        );

        // Publication de la fiche prête.
        emit(
          state.copyWith(
            status: RestaurantDetailStatus.ready,
            restaurant: restaurant,
            isFavorite: isFavorite,
            failure: null,
          ),
        );
      },
    );
  }

  /// Inverse l'état favori de la fiche courante.
  Future<void> _onFavoriteToggled(
    RestaurantDetailFavoriteToggled event,
    Emitter<RestaurantDetailState> emit,
  ) async {
    // Sans fiche chargée, rien à faire.
    final Restaurant? restaurant = state.restaurant;
    if (restaurant == null) {
      return;
    }

    // Appel du use case (identifiant validé côté Domain).
    final Either<Failure, bool> result = await _toggleFavorite(
      ToggleFavoriteParams(restaurantId: restaurant.id),
    );

    // Mise à jour uniquement en cas de succès.
    result.fold(
      (Failure failure) {},
      (bool isFavorite) => emit(state.copyWith(isFavorite: isFavorite)),
    );
  }
}
