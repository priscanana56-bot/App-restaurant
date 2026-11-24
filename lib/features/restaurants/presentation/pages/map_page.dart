// =============================================================================
// Écran « Carte & proximité ».
// -----------------------------------------------------------------------------
// L'application n'embarque pas de SDK cartographique propriétaire : elle affiche
// une liste triée par distance et ouvre Google Maps (via `UrlGuard`) pour la
// vue cartographique et l'itinéraire. La position GPS de l'utilisateur reste
// locale : elle n'est jamais transmise à un serveur.
// =============================================================================

// `unawaited` pour les appels asynchrones déclenchés par un geste.
import 'dart:async';

// Widgets et Material.
import 'package:flutter/material.dart';

// BLoC et Cubit.
import 'package:flutter_bloc/flutter_bloc.dart';

// Routes.
import '../../../../core/constants/app_routes.dart';

// Objet-valeur géographique.
import '../../../../core/location/geo_point.dart';

// Garde-fou des liens externes.
import '../../../../core/security/url_guard.dart';

// Palette et espacements.
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';

// Formatage des distances.
import '../../../../core/utils/formatters.dart';

// Entité affichée.
import '../../domain/entities/restaurant.dart';

// Cubit et état de localisation.
import '../bloc/location_cubit.dart';

// BLoC et état du catalogue.
import '../bloc/restaurant_list_bloc.dart';
import '../bloc/restaurant_list_state.dart';

// Vues d'état.
import '../widgets/async_state_views.dart';

// Retour utilisateur des liens externes.
import '../widgets/link_feedback.dart';

/// Page de proximité et d'itinéraires.
final class MapPage extends StatelessWidget {
  /// Construit la page.
  const MapPage({required this.urlGuard, super.key});

  /// Garde-fou d'ouverture des liens (Google Maps).
  final UrlGuard urlGuard;

  /// Construit la page.
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Carte & proximité')),

      body: Column(
        children: <Widget>[
          // En-tête : état de la demande de position.
          _LocationHeader(urlGuard: urlGuard),

          // Liste des restaurants triée par distance.
          Expanded(
            child: BlocBuilder<RestaurantListBloc, RestaurantListState>(
              builder: (BuildContext context, RestaurantListState state) {
                // Chargement initial du catalogue.
                if (state.isLoading && state.allRestaurants.isEmpty) {
                  return const AppLoadingView(
                    message: 'Chargement des établissements...',
                  );
                }

                // Catalogue vide : message neutre.
                if (state.allRestaurants.isEmpty) {
                  return const AppEmptyView(
                    icon: Icons.map_outlined,
                    title: 'Aucun établissement à afficher',
                  );
                }

                // Position éventuelle de l'utilisateur.
                final GeoPoint? origin = context
                    .select<LocationCubit, GeoPoint?>(
                      (LocationCubit cubit) => cubit.state.position,
                    );

                // Copie triée : le catalogue d'origine n'est jamais modifié.
                final List<Restaurant> restaurants = List<Restaurant>.of(
                  state.allRestaurants,
                );

                if (origin != null) {
                  // Tri par distance croissante lorsque la position est connue.
                  restaurants.sort(
                    (Restaurant a, Restaurant b) => _distanceKm(
                      origin,
                      a,
                    ).compareTo(_distanceKm(origin, b)),
                  );
                }

                // Liste des établissements.
                return ListView.separated(
                  padding: const EdgeInsets.all(AppSpacing.pagePadding),
                  itemCount: restaurants.length,
                  separatorBuilder: (_, _) =>
                      const SizedBox(height: AppSpacing.sm),
                  itemBuilder: (BuildContext context, int index) {
                    // Restaurant courant.
                    final Restaurant restaurant = restaurants[index];

                    // Distance éventuelle.
                    final double? distance = origin == null
                        ? null
                        : _distanceKm(origin, restaurant);

                    return _NearbyTile(
                      restaurant: restaurant,
                      distanceKm: distance,
                      // Ouverture de la fiche.
                      onTap: () => Navigator.of(context)
                          .pushNamed(AppRoutes.restaurantDetail(restaurant.id)),
                      // Ouverture de l'itinéraire Google Maps.
                      onDirections: () => unawaited(
                        LinkFeedback.run(
                          context,
                          () => urlGuard.openDirections(
                            latitude: restaurant.latitude,
                            longitude: restaurant.longitude,
                          ),
                          successMessage: 'Ouverture de l’itinéraire...',
                        ),
                      ),
                      // Ouverture du point sur Google Maps.
                      onShowOnMap: () => unawaited(
                        LinkFeedback.run(
                          context,
                          () => urlGuard.openMaps(
                            latitude: restaurant.latitude,
                            longitude: restaurant.longitude,
                            label: restaurant.name,
                          ),
                          successMessage: 'Ouverture de la carte...',
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  /// Distance en kilomètres entre [origin] et un restaurant.
  static double _distanceKm(GeoPoint origin, Restaurant restaurant) {
    // Le point du restaurant est validé par les invariants de l'entité.
    final GeoPoint target = GeoPoint(
      latitude: restaurant.latitude,
      longitude: restaurant.longitude,
    );
    return origin.distanceToKm(target);
  }
}

/// En-tête présentant l'état de la géolocalisation.
final class _LocationHeader extends StatelessWidget {
  /// Construit l'en-tête.
  const _LocationHeader({required this.urlGuard});

  /// Garde-fou conservé pour cohérence de construction (non utilisé ici).
  final UrlGuard urlGuard;

  /// Construit l'en-tête.
  @override
  Widget build(BuildContext context) {
    // Cubit de localisation (fourni par la coquille).
    final LocationCubit cubit = context.read<LocationCubit>();

    // Thème, typographie et palette locales.
    final ThemeData theme = Theme.of(context);
    final TextTheme textTheme = theme.textTheme;
    final AppPalette palette = AppPalette.of(context);

    return BlocBuilder<LocationCubit, LocationState>(
      builder: (BuildContext context, LocationState state) {
        // Contenu principal : icône, titre et action.
        final Widget leading = Icon(
          state.hasPosition ? Icons.my_location : Icons.location_searching,
          color: theme.colorScheme.primary,
        );

        // Texte d'état.
        final String title;
        final String subtitle;
        if (state.hasPosition) {
          title = 'Position détectée';
          subtitle =
              'Les établissements sont triés du plus proche au plus loin.';
        } else if (state.isLoading) {
          title = 'Localisation en cours...';
          subtitle = 'Autorisez l’accès à votre position si demandé.';
        } else {
          title = 'Trier par proximité';
          subtitle = 'Activez la localisation pour connaître les distances.';
        }

        return Card(
          margin: const EdgeInsets.all(AppSpacing.pagePadding),
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.md),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                // Ligne d'information.
                Row(
                  children: <Widget>[
                    // Icône d'état.
                    leading,
                    const SizedBox(width: AppSpacing.sm),

                    // Titre et sous-titre.
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Text(
                            title,
                            style: textTheme.titleSmall?.copyWith(
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          Text(
                            subtitle,
                            style: textTheme.bodySmall?.copyWith(
                              color: palette.mutedText,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),

                // Message d'erreur éventuel.
                if (state.failure != null) ...<Widget>[
                  const SizedBox(height: AppSpacing.sm),
                  Text(
                    state.failure!.message,
                    style: textTheme.bodySmall?.copyWith(color: palette.danger),
                  ),
                ],

                // Action : demander ou relancer la localisation.
                const SizedBox(height: AppSpacing.sm),
                FilledButton.icon(
                  // Une demande est ignorée si elle est déjà en cours.
                  onPressed: state.isLoading
                      ? null
                      : () => unawaited(cubit.request()),
                  icon: const Icon(Icons.gps_fixed),
                  label: Text(
                    state.hasPosition
                        ? 'Actualiser ma position'
                        : 'Me localiser',
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

/// Tuile compacte d'un établissement avec distance et actions cartographiques.
final class _NearbyTile extends StatelessWidget {
  /// Construit la tuile.
  const _NearbyTile({
    required this.restaurant,
    required this.distanceKm,
    required this.onTap,
    required this.onDirections,
    required this.onShowOnMap,
  });

  /// Restaurant affiché.
  final Restaurant restaurant;

  /// Distance éventuelle depuis l'utilisateur.
  final double? distanceKm;

  /// Ouverture de la fiche détaillée.
  final VoidCallback onTap;

  /// Ouverture de l'itinéraire.
  final VoidCallback onDirections;

  /// Ouverture du point sur la carte.
  final VoidCallback onShowOnMap;

  /// Construit la tuile.
  @override
  Widget build(BuildContext context) {
    // Typographie et palette locales.
    final TextTheme textTheme = Theme.of(context).textTheme;
    final AppPalette palette = AppPalette.of(context);

    // Distance éventuelle.
    final double? distance = distanceKm;

    return Card(
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              // Nom et distance.
              Row(
                children: <Widget>[
                  Expanded(
                    child: Text(
                      restaurant.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  if (distance != null)
                    Text(
                      AppFormatters.distanceKm(distance),
                      style: textTheme.labelMedium?.copyWith(
                        color: palette.mutedText,
                      ),
                    ),
                ],
              ),

              // Localisation descriptive.
              Text(
                restaurant.locationLabel,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: textTheme.bodySmall?.copyWith(color: palette.mutedText),
              ),

              // Espacement.
              const SizedBox(height: AppSpacing.xs),

              // Actions cartographiques.
              Row(
                children: <Widget>[
                  // Itinéraire.
                  TextButton.icon(
                    onPressed: onDirections,
                    icon: const Icon(Icons.directions_outlined, size: 18),
                    label: const Text('Itinéraire'),
                  ),

                  // Vue carte.
                  TextButton.icon(
                    onPressed: onShowOnMap,
                    icon: const Icon(Icons.map_outlined, size: 18),
                    label: const Text('Voir sur la carte'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
