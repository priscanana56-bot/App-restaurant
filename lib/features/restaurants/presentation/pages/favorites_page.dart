// =============================================================================
// Écran des favoris.
// -----------------------------------------------------------------------------
// Les favoris sont stockés localement (Hive) par la couche Data. Cette page ne
// fait que lire la liste déjà présente dans l'état partagé du `RestaurantListBloc`
// (une seule source de vérité) : aucun chargement réseau supplémentaire.
// =============================================================================

// Widgets et Material.
import 'package:flutter/material.dart';

// BLoC.
import 'package:flutter_bloc/flutter_bloc.dart';

// Routes.
import '../../../../core/constants/app_routes.dart';

// Espacements.
import '../../../../core/theme/app_spacing.dart';

// Entité affichée.
import '../../domain/entities/restaurant.dart';

// BLoC et état consommés.
import '../bloc/restaurant_list_bloc.dart';
import '../bloc/restaurant_list_event.dart';
import '../bloc/restaurant_list_state.dart';

// Widgets réutilisables.
import '../widgets/async_state_views.dart';
import '../widgets/restaurant_card.dart';

/// Page listant les restaurants mis en favori.
final class FavoritesPage extends StatelessWidget {
  /// Construit la page.
  const FavoritesPage({super.key});

  /// Construit la page.
  @override
  Widget build(BuildContext context) {
    // Accès au BLoC partagé du catalogue.
    final RestaurantListBloc listBloc = context.read<RestaurantListBloc>();

    return Scaffold(
      // Barre d'application.
      appBar: AppBar(title: const Text('Mes favoris')),

      // Corps réactif.
      body: BlocBuilder<RestaurantListBloc, RestaurantListState>(
        builder: (BuildContext context, RestaurantListState state) {
          // Premier chargement : indicateur centré.
          if (state.isLoading && state.allRestaurants.isEmpty) {
            return const AppLoadingView(message: 'Chargement des favoris...');
          }

          // Favoris extraits du catalogue complet.
          final List<Restaurant> favorites = state.favoriteRestaurants;

          // Aucun favori : message d'aide et retour vers l'accueil.
          if (favorites.isEmpty) {
            return AppEmptyView(
              icon: Icons.favorite_border,
              title: 'Aucun favori pour l’instant',
              message:
                  'Touchez le cœur sur une fiche pour la retrouver ici, même '
                  'hors connexion.',
              action: FilledButton.tonal(
                onPressed: () {
                  // Retour à l'onglet découverte (route racine de la coquille).
                  Navigator.of(context)
                      .popUntil((Route<dynamic> route) => route.isFirst);
                },
                child: const Text('Découvrir des restaurants'),
              ),
            );
          }

          // Liste des cartes favorites.
          return ListView.separated(
            padding: const EdgeInsets.all(AppSpacing.pagePadding),
            itemCount: favorites.length,
            separatorBuilder: (_, _) => const SizedBox(height: AppSpacing.sm),
            itemBuilder: (BuildContext context, int index) {
              // Restaurant favori courant.
              final Restaurant restaurant = favorites[index];

              return RestaurantCard(
                restaurant: restaurant,
                now: state.now,
                // Par construction, tous les éléments sont favoris.
                isFavorite: true,
                liveBraise: state.now == null
                    ? null
                    : restaurant.activeLiveBraiseAt(state.now!),
                onTap: () =>
                    Navigator.of(context)
                        .pushNamed(AppRoutes.restaurantDetail(restaurant.id)),
                // Le retrait met immédiatement à jour l'état partagé.
                onFavoriteToggle: () =>
                    listBloc.add(RestaurantListFavoriteToggled(restaurant.id)),
              );
            },
          );
        },
      ),
    );
  }
}
