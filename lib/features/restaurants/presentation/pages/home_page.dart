// =============================================================================
// Écran d'accueil « magazine gourmand ».
// -----------------------------------------------------------------------------
// La page ne contient AUCUNE logique métier : elle observe l'état publié par
// `RestaurantListBloc` et `DirectoryCubit`, puis délègue
// chaque geste à un événement ou à un use case. La mise en page privilégie
// une lecture éditoriale : la carte du sur-titre est conservée, puis vient la
// question « Où mangez-vous ce soir ? », la recherche proéminente, les cartes
// « photo », la sélection « À la une », la proximité et l'annuaire réel sourcé.
// Un raccourci placé sous le compteur de résultats ouvre cet annuaire sans
// obliger à défiler jusqu'à l'aperçu. La barre d'application du haut est conservée.
// =============================================================================

// Mathématiques pour le calcul de distance (Haversine).
import 'dart:math' as math;

// Widgets et Material.
import 'package:flutter/material.dart';

// BLoC et Cubit.
import 'package:flutter_bloc/flutter_bloc.dart';

// Constantes (nom, signature, géographie) et routes.
import '../../../../core/constants/app_constants.dart';
import '../../../../core/constants/app_routes.dart';

// Erreur métier affichée par la vue d'échec.
import '../../../../core/error/failures.dart';

// Palette et espacements.
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';

// Entités affichées.
import '../../domain/entities/koudougou_listing.dart';
import '../../domain/entities/restaurant.dart';

// BLoC et états consommés.
import '../bloc/directory_cubit.dart';
import '../bloc/directory_state.dart';
import '../bloc/restaurant_list_bloc.dart';
import '../bloc/restaurant_list_event.dart';
import '../bloc/restaurant_list_state.dart';

// Widgets réutilisables.
import '../widgets/async_state_views.dart';
import '../widgets/restaurant_card.dart';
import '../widgets/restaurant_filter_bar.dart';

/// Page d'accueil de l'application.
final class HomePage extends StatelessWidget {
  /// Construit la page.
  const HomePage({super.key});

  /// Construit la page.
  @override
  Widget build(BuildContext context) {
    // Accès au BLoC du catalogue (fourni par la coquille).
    final RestaurantListBloc listBloc = context.read<RestaurantListBloc>();

    return Scaffold(
      // Barre d'application discrète : le héro porte l'identité visuelle.
      appBar: AppBar(
        title: const Text(AppConstants.appName),
        actions: <Widget>[
          // Rafraîchissement manuel (force une synchronisation si possible).
          IconButton(
            tooltip: 'Actualiser',
            onPressed: () =>
                listBloc.add(const RestaurantListRefreshRequested()),
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),

      // Corps réactif : reconstruit à chaque nouvel état du catalogue.
      body: BlocBuilder<RestaurantListBloc, RestaurantListState>(
        builder: (BuildContext context, RestaurantListState state) {
          // 1. Premier chargement : indicateur plein écran.
          if (state.isLoading && state.allRestaurants.isEmpty) {
            return const AppLoadingView(
              message: 'Chargement des restaurants de Koudougou...',
            );
          }

          // 2. Échec sans données affichables : erreur avec réessai.
          final Failure? failure = state.failure;
          if (state.hasError &&
              state.allRestaurants.isEmpty &&
              failure != null) {
            return AppErrorView(
              failure: failure,
              onRetry: () =>
                  listBloc.add(const RestaurantListRefreshRequested()),
            );
          }

          // 3. État nominal : contenu éditorial défilant.
          return RefreshIndicator(
            // « Tirer pour rafraîchir ».
            onRefresh: () async =>
                listBloc.add(const RestaurantListRefreshRequested()),
            child: ListView(
              // Toujours défilable, même quand le contenu tient à l'écran.
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.only(bottom: AppSpacing.xl),
              children: <Widget>[
                // -------------------------------------------------------------
                // Héro magazine
                // -------------------------------------------------------------
                const _MagazineHero(),

                // La question suit la carte du sur-titre avec un souffle
                // vertical, sans élément intermédiaire.
                const SizedBox(height: AppSpacing.lg),

                const Padding(
                  padding: EdgeInsets.symmetric(
                    horizontal: AppSpacing.pagePadding,
                  ),
                  child: _EveningQuestion(),
                ),

                const SizedBox(height: AppSpacing.md),

                // -------------------------------------------------------------
                // Recherche proéminente et puces de catégories
                // -------------------------------------------------------------
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.pagePadding,
                  ),
                  child: _SearchPanel(
                    child: RestaurantFilterBar(
                      filter: state.filter,
                      onSearchChanged: (String query) =>
                          listBloc.add(RestaurantListSearchChanged(query)),
                      onCategoryToggled: (category) =>
                          listBloc.add(RestaurantListCategoryToggled(category)),
                      onSortChanged: (sort) =>
                          listBloc.add(RestaurantListSortChanged(sort)),
                      onOpenNowToggled: () =>
                          listBloc.add(const RestaurantListOpenNowToggled()),
                      onVerifiedToggled: () =>
                          listBloc.add(const RestaurantListVerifiedToggled()),
                      onClear: () =>
                          listBloc.add(const RestaurantListFiltersCleared()),
                    ),
                  ),
                ),

                const SizedBox(height: AppSpacing.md),

                // -------------------------------------------------------------
                // Sélection éditoriale : À la une
                // -------------------------------------------------------------
                if (state.visibleRestaurants.isNotEmpty)
                  _FeaturedSection(
                    restaurants: state.visibleRestaurants
                        .take(3)
                        .toList(growable: false),
                    onTap: (String id) => _openRestaurant(context, id),
                  ),

                if (state.visibleRestaurants.length > 3)
                  const SizedBox(height: AppSpacing.md),

                // -------------------------------------------------------------
                // Proximité (distance calculée depuis le centre de Koudougou)
                // -------------------------------------------------------------
                if (state.visibleRestaurants.length > 3)
                  _NearbySection(
                    restaurants: state.visibleRestaurants
                        .skip(3)
                        .toList(growable: false),
                    onTap: (String id) => _openRestaurant(context, id),
                  ),

                const SizedBox(height: AppSpacing.md),

                // -------------------------------------------------------------
                // Annuaire réel sourcé
                // -------------------------------------------------------------
                const _DirectoryPreview(),

                const SizedBox(height: AppSpacing.md),

                // -------------------------------------------------------------
                // Résultats complets (liste compacte et filtrable)
                // -------------------------------------------------------------
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.pagePadding,
                  ),
                  child: _ResultCount(count: state.visibleRestaurants.length),
                ),

                const SizedBox(height: AppSpacing.xs),

                // Raccourci contextuel : l'utilisateur qui consulte les
                // résultats peut ouvrir l'annuaire sourcé sans chercher plus bas.
                const Padding(
                  padding: EdgeInsets.symmetric(
                    horizontal: AppSpacing.pagePadding,
                  ),
                  child: _DirectoryShortcut(),
                ),

                const SizedBox(height: AppSpacing.xs),

                // Aucun résultat : message d'aide.
                if (state.isEmpty)
                  const Padding(
                    padding: EdgeInsets.symmetric(
                      horizontal: AppSpacing.pagePadding,
                    ),
                    child: _EmptyResults(),
                  ),

                // Liste des cartes de restaurants.
                for (final Restaurant restaurant in state.visibleRestaurants)
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.pagePadding,
                    ),
                    child: Padding(
                      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                      child: RestaurantCard(
                        restaurant: restaurant,
                        now: state.now,
                        isFavorite: state.favoriteIds.contains(restaurant.id),
                        liveBraise: state.now == null
                            ? null
                            : restaurant.activeLiveBraiseAt(state.now!),
                        onTap: () => _openRestaurant(context, restaurant.id),
                        onFavoriteToggle: () => listBloc.add(
                          RestaurantListFavoriteToggled(restaurant.id),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          );
        },
      ),
    );
  }

  /// Ouvre la fiche détaillée d'un restaurant par son identifiant.
  static void _openRestaurant(BuildContext context, String restaurantId) {
    // Navigation nommée : la route est construite par le routeur central.
    Navigator.of(context).pushNamed(AppRoutes.restaurantDetail(restaurantId));
  }

  /// Ouvre l'annuaire réel sourcé de Koudougou.
  static void _openDirectory(BuildContext context) {
    Navigator.of(context).pushNamed(AppRoutes.directory);
  }
}

/// Carte du sur-titre, conservée seule sans éléments centraux ni boutons.
final class _MagazineHero extends StatelessWidget {
  /// Construit la carte du sur-titre.
  const _MagazineHero();

  /// Construit l'interface.
  @override
  Widget build(BuildContext context) {
    // Typographie locale.
    final TextTheme textTheme = Theme.of(context).textTheme;

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.fromLTRB(
        AppSpacing.pagePadding,
        AppSpacing.sm,
        AppSpacing.pagePadding,
        0,
      ),
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: const BoxDecoration(
        // Dégradé apaisant dans la famille du basilic : le terracotta est
        // réservé aux prix et aux appels à l'action.
        gradient: LinearGradient(
          colors: <Color>[AppColors.basilDeep, AppColors.basil],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: AppSpacing.cardRadius,
        boxShadow: AppShadows.elevatedLight,
      ),
      child: Text(
        'KOUGOUGOU · BURKINA FASO',
        style: textTheme.labelLarge?.copyWith(
          color: AppColors.saffron,
          fontWeight: FontWeight.w800,
          letterSpacing: 1.2,
        ),
      ),
    );
  }
}

/// Question affichée immédiatement après la carte du sur-titre.
final class _EveningQuestion extends StatelessWidget {
  /// Construit la question du soir.
  const _EveningQuestion();

  /// Construit l'interface.
  @override
  Widget build(BuildContext context) {
    final TextTheme textTheme = Theme.of(context).textTheme;

    return Text(
      'Où mangez-vous ce soir ?',
      style: textTheme.headlineMedium?.copyWith(
        fontWeight: FontWeight.w800,
        height: 1.15,
      ),
    );
  }
}

/// Encart qui met la recherche et les puces de catégories en évidence.
final class _SearchPanel extends StatelessWidget {
  /// Construit l'encart.
  const _SearchPanel({required this.child});

  /// Contenu délégué à la barre de filtres existante.
  final Widget child;

  /// Construit l'interface.
  @override
  Widget build(BuildContext context) {
    // La question est déjà posée juste après la carte du sur-titre : on évite
    // de la répéter ici. Le champ porte son indice « Rechercher un maquis... ».
    return Card(
      elevation: 2,
      shape: const RoundedRectangleBorder(borderRadius: AppSpacing.cardRadius),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: child,
      ),
    );
  }
}

/// Section « À la une » : cartes éditoriales horizontales.
final class _FeaturedSection extends StatelessWidget {
  /// Construit la section.
  const _FeaturedSection({required this.restaurants, required this.onTap});

  // Données et geste.
  final List<Restaurant> restaurants;
  final void Function(String restaurantId) onTap;

  /// Construit l'interface.
  @override
  Widget build(BuildContext context) {
    // Typographie locale.
    final TextTheme textTheme = Theme.of(context).textTheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        // Titre de rubrique.
        Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.pagePadding,
          ),
          child: Row(
            children: <Widget>[
              const Icon(Icons.auto_stories, color: AppColors.basil),
              const SizedBox(width: AppSpacing.xs),
              Text(
                'À la une',
                style: textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: AppSpacing.sm),

        // Carrousel de cartes.
        SizedBox(
          // Hauteur suffisante pour le visuel, le nom sur deux lignes,
          // l'accroche et le prix sans débordement sur petit écran.
          height: 244,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.pagePadding,
            ),
            itemCount: restaurants.length,
            separatorBuilder: (BuildContext context, int index) =>
                const SizedBox(width: AppSpacing.sm),
            itemBuilder: (BuildContext context, int index) {
              final Restaurant restaurant = restaurants[index];
              return _FeatureCard(
                restaurant: restaurant,
                onTap: () => onTap(restaurant.id),
              );
            },
          ),
        ),
      ],
    );
  }
}

/// Carte « photo » d'un établissement à la une.
final class _FeatureCard extends StatelessWidget {
  /// Construit la carte.
  const _FeatureCard({required this.restaurant, required this.onTap});

  // Données et geste.
  final Restaurant restaurant;
  final VoidCallback onTap;

  /// Construit l'interface.
  @override
  Widget build(BuildContext context) {
    // Typographie locale.
    final TextTheme textTheme = Theme.of(context).textTheme;

    return SizedBox(
      width: 252,
      child: Card(
        clipBehavior: Clip.antiAlias,
        shape: const RoundedRectangleBorder(
          borderRadius: AppSpacing.cardRadius,
        ),
        child: InkWell(
          onTap: onTap,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              // Faux visuel éditorial : dégradé + icône, sans asset manquant.
              Container(
                height: 112,
                width: double.infinity,
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    colors: <Color>[AppColors.basilDeep, AppColors.basil],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                ),
                child: Center(
                  child: Icon(
                    _iconFor(restaurant),
                    size: 46,
                    color: AppColors.pureWhite,
                  ),
                ),
              ),

              Expanded(
                child: Padding(
                  padding: const EdgeInsets.all(AppSpacing.sm),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      // Catégorie en sur-titre.
                      Text(
                        restaurant.category.label.toUpperCase(),
                        style: textTheme.labelSmall?.copyWith(
                          color: AppColors.basilDeep,
                          letterSpacing: 0.8,
                        ),
                      ),
                      const SizedBox(height: AppSpacing.xxs),

                      // Nom (limité à deux lignes pour garder la carte nette).
                      Text(
                        restaurant.name,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),

                      const Spacer(),

                      // Accroche et prix.
                      Text(
                        restaurant.tagline,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: textTheme.bodySmall?.copyWith(
                          color: AppPalette.of(context).mutedText,
                        ),
                      ),
                      Text(
                        '${restaurant.averagePriceFcfa} FCFA · ${restaurant.sector}',
                        style: textTheme.labelMedium?.copyWith(
                          color: AppColors.basil,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Icône illustrée selon la catégorie de l'établissement.
  static IconData _iconFor(Restaurant restaurant) {
    final String name = restaurant.category.name.toLowerCase();
    if (name.contains('cafe') || name.contains('coffee')) {
      return Icons.coffee_outlined;
    }
    if (name.contains('maquis')) {
      return Icons.outdoor_grill_outlined;
    }
    return Icons.restaurant_outlined;
  }
}

/// Section « Près de vous » : tri par distance depuis le centre de Koudougou.
final class _NearbySection extends StatelessWidget {
  /// Construit la section.
  const _NearbySection({required this.restaurants, required this.onTap});

  // Données et geste.
  final List<Restaurant> restaurants;
  final void Function(String restaurantId) onTap;

  /// Construit l'interface.
  @override
  Widget build(BuildContext context) {
    // Typographie locale.
    final TextTheme textTheme = Theme.of(context).textTheme;

    // Tri local, sans GPS : le centre-ville est la référence affichée.
    final List<Restaurant> nearby = List<Restaurant>.from(restaurants)
      ..sort((Restaurant a, Restaurant b) {
        final double da = _distanceKm(a.latitude, a.longitude);
        final double db = _distanceKm(b.latitude, b.longitude);
        return da.compareTo(db);
      });

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        // Titre et précision honeste sur la référence de distance.
        Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.pagePadding,
          ),
          child: Row(
            children: <Widget>[
              const Icon(Icons.near_me_outlined, color: AppColors.basil),
              const SizedBox(width: AppSpacing.xs),
              Text(
                'Près de vous',
                style: textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.pagePadding,
          ),
          child: Text(
            'Distances estimées depuis le centre de Koudougou.',
            style: textTheme.bodySmall?.copyWith(
              color: AppPalette.of(context).mutedText,
            ),
          ),
        ),

        const SizedBox(height: AppSpacing.sm),

        // Trois établissements les plus proches.
        for (final Restaurant restaurant in nearby.take(3))
          ListTile(
            leading: const CircleAvatar(
              backgroundColor: AppColors.basilSoft,
              child: Icon(Icons.place, color: AppColors.basil),
            ),
            title: Text(restaurant.name),
            subtitle: Text(
              '${restaurant.landmark} · ${_distanceKm(restaurant.latitude, restaurant.longitude).toStringAsFixed(1)} km',
            ),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => onTap(restaurant.id),
          ),
      ],
    );
  }

  /// Distance approximative (Haversine) entre un point et le centre-ville.
  static double _distanceKm(double latitude, double longitude) {
    // Rayon moyen de la Terre en kilomètres.
    const double earthRadiusKm = 6371;

    // Conversion des degrés en radians (dart:math n'expose pas `radians`).
    final double lat1 = _toRadians(AppConstants.cityLatitude);
    final double lon1 = _toRadians(AppConstants.cityLongitude);
    final double lat2 = _toRadians(latitude);
    final double lon2 = _toRadians(longitude);

    // Écarts angulaires.
    final double dLat = lat2 - lat1;
    final double dLon = lon2 - lon1;

    // Formule de Haversine.
    final double a =
        math.pow(math.sin(dLat / 2), 2).toDouble() +
        math.cos(lat1) *
            math.cos(lat2) *
            math.pow(math.sin(dLon / 2), 2).toDouble();
    return earthRadiusKm * 2 * math.asin(math.sqrt(a.clamp(0.0, 1.0)));
  }

  /// Convertit un angle en degrés vers les radians attendus par `dart:math`.
  static double _toRadians(double degrees) => degrees * math.pi / 180;
}

/// Aperçu de l'annuaire réel sourcé.
final class _DirectoryPreview extends StatelessWidget {
  /// Construit l'aperçu.
  const _DirectoryPreview();

  /// Construit l'interface.
  @override
  Widget build(BuildContext context) {
    // Typographie et palette.
    final TextTheme textTheme = Theme.of(context).textTheme;
    final AppPalette palette = AppPalette.of(context);

    return BlocBuilder<DirectoryCubit, DirectoryState>(
      builder: (BuildContext context, DirectoryState state) {
        // Aperçu limité aux indices récents, pour rester lisible.
        final List<KoudougouListing> highlights = state.listings
            .where(
              (KoudougouListing listing) =>
                  listing.verification ==
                  DirectoryVerification.recentOnlineSignal,
            )
            .take(3)
            .toList(growable: false);

        return Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.pagePadding,
          ),
          child: Card(
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.md),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  // Titre.
                  Row(
                    children: <Widget>[
                      const Icon(
                        Icons.menu_book_outlined,
                        color: AppColors.basil,
                      ),
                      const SizedBox(width: AppSpacing.xs),
                      Expanded(
                        child: Text(
                          'L’annuaire de Koudougou',
                          style: textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: AppSpacing.xs),

                  // Précision indispensable : pas de certification d'ouverture.
                  Text(
                    '${state.listings.length} établissements cités par des sources publiques. '
                    'Ouverture à confirmer avant déplacement.',
                    style: textTheme.bodySmall?.copyWith(
                      color: palette.mutedText,
                    ),
                  ),

                  const SizedBox(height: AppSpacing.sm),

                  // Quelques fiches à indice récent.
                  for (final KoudougouListing listing in highlights)
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text(listing.name),
                      subtitle: Text(listing.area),
                      trailing: const Icon(Icons.schedule_outlined),
                    ),

                  const SizedBox(height: AppSpacing.xs),

                  // Accès à l'annuaire complet.
                  FilledButton.tonalIcon(
                    onPressed: () => HomePage._openDirectory(context),
                    icon: const Icon(Icons.arrow_forward),
                    label: const Text('Explorer l’annuaire'),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

/// Compteur de résultats, discret mais rassurant.
final class _ResultCount extends StatelessWidget {
  /// Construit le compteur.
  const _ResultCount({required this.count});

  /// Nombre d'établissements visibles.
  final int count;

  /// Construit le compteur.
  @override
  Widget build(BuildContext context) {
    // Thème et palette locales.
    final TextTheme textTheme = Theme.of(context).textTheme;
    final AppPalette palette = AppPalette.of(context);

    // Accord au singulier / pluriel.
    final String label = count == 1
        ? '1 établissement trouvé'
        : '$count établissements trouvés';

    return Text(
      label,
      style: textTheme.titleSmall?.copyWith(color: palette.mutedText),
    );
  }
}

/// Raccourci vers l'annuaire, placé au niveau du compteur de résultats.
final class _DirectoryShortcut extends StatelessWidget {
  /// Construit le raccourci.
  const _DirectoryShortcut();

  /// Construit l'interface.
  @override
  Widget build(BuildContext context) {
    // Aligné à gauche comme le compteur qu'il prolonge.
    return Align(
      alignment: Alignment.centerLeft,
      child: OutlinedButton.icon(
        onPressed: () => HomePage._openDirectory(context),
        icon: const Icon(Icons.menu_book_outlined, size: 18),
        label: const Text('Consulter l’annuaire'),
      ),
    );
  }
}

/// État vide des résultats, avec réinitialisation des filtres.
final class _EmptyResults extends StatelessWidget {
  /// Construit l'état vide.
  const _EmptyResults();

  /// Construit l'interface.
  @override
  Widget build(BuildContext context) {
    // BLoC du catalogue (fourni par la coquille).
    final RestaurantListBloc listBloc = context.read<RestaurantListBloc>();

    return AppEmptyView(
      icon: Icons.search_off,
      title: 'Aucun résultat',
      message: 'Essayez un autre mot-clé ou réinitialisez les filtres.',
      compact: true,
      action: FilledButton.tonal(
        onPressed: () => listBloc.add(const RestaurantListFiltersCleared()),
        child: const Text('Réinitialiser les filtres'),
      ),
    );
  }
}
