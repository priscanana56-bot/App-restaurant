// =============================================================================
// Fiche détaillée d'un restaurant.
// -----------------------------------------------------------------------------
// La page observe `RestaurantDetailBloc` (créé par le routeur pour cette route)
// et délègue chaque geste à un événement. Les liens externes (itinéraire,
// carte, appel, WhatsApp) passent tous par `UrlGuard` : aucune URL n'est ouverte
// directement. L'instant de référence `now` est fourni par le routeur (horloge
// injectée) afin que les badges « Ouvert » et « Live Braise » restent testables.
// =============================================================================

// `unawaited` pour les appels asynchrones déclenchés par un geste.
import 'dart:async';

// Widgets et Material.
import 'package:flutter/material.dart';

// BLoC.
import 'package:flutter_bloc/flutter_bloc.dart';

// Routes nommées.
import '../../../../core/constants/app_routes.dart';

// Erreur métier affichable.
import '../../../../core/error/failures.dart';

// Point GPS de la fiche, transmis au panneau de devis.
import '../../../../core/location/geo_point.dart';

// Garde-fou d'ouverture des liens externes.
import '../../../../core/security/url_guard.dart';

// Palette et espacements.
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';

// Formatage FCFA, téléphone et dates.
import '../../../../core/utils/formatters.dart';

// Entités affichées.
import '../../domain/entities/live_braise_status.dart';
import '../../domain/entities/menu_item.dart';
import '../../domain/entities/restaurant.dart';
import '../../domain/entities/restaurant_category.dart';

// BLoC, événements et état consommés.
import '../bloc/restaurant_detail_bloc.dart';
import '../bloc/restaurant_detail_event.dart';
import '../bloc/restaurant_detail_state.dart';

// Vues d'état et retour des liens.
import '../widgets/async_state_views.dart';
import '../widgets/delivery_panel.dart';
import '../widgets/link_feedback.dart';
import '../widgets/live_braise_banner.dart';
import '../widgets/status_badges.dart';

/// Page de la fiche restaurant.
final class RestaurantDetailPage extends StatelessWidget {
  /// Construit la page.
  const RestaurantDetailPage({
    required this.restaurantId,
    required this.urlGuard,
    required this.now,
    super.key,
  });

  /// Identifiant du restaurant demandé (utilisé pour réessayer).
  final String restaurantId;

  /// Garde-fou des liens externes.
  final UrlGuard urlGuard;

  /// Instant de référence (heure de Koudougou) pour les statuts dynamiques.
  final DateTime now;

  /// Construit la page.
  @override
  Widget build(BuildContext context) {
    // Accès au BLoC fourni par le routeur pour cette route.
    final RestaurantDetailBloc bloc = context.read<RestaurantDetailBloc>();

    // Palette locale (cœur favori coloré).
    final AppPalette palette = AppPalette.of(context);

    return BlocBuilder<RestaurantDetailBloc, RestaurantDetailState>(
      builder: (BuildContext context, RestaurantDetailState state) {
        // Fiche éventuellement chargée.
        final Restaurant? restaurant = state.restaurant;

        return Scaffold(
          // Barre d'application : nom du restaurant et bouton favori.
          appBar: AppBar(
            title: Text(restaurant?.name ?? 'Fiche restaurant'),
            actions: <Widget>[
              // Le favori n'est proposé qu'une fois la fiche chargée.
              if (restaurant != null)
                IconButton(
                  tooltip: state.isFavorite
                      ? 'Retirer des favoris'
                      : 'Ajouter aux favoris',
                  onPressed: () =>
                      bloc.add(const RestaurantDetailFavoriteToggled()),
                  icon: Icon(
                    state.isFavorite ? Icons.favorite : Icons.favorite_border,
                    color: state.isFavorite ? palette.danger : null,
                  ),
                ),
            ],
          ),

          // Corps réactif selon l'étape du chargement.
          body: _buildBody(context: context, bloc: bloc, state: state),

          // Barre inférieure : commande et partage d'addition.
          bottomNavigationBar: restaurant == null
              ? null
              : _DetailBottomBar(restaurant: restaurant),
        );
      },
    );
  }

  /// Construit le corps de la page selon l'état du BLoC.
  Widget _buildBody({
    required BuildContext context,
    required RestaurantDetailBloc bloc,
    required RestaurantDetailState state,
  }) {
    // Fiche éventuellement chargée.
    final Restaurant? restaurant = state.restaurant;

    // 1. Premier chargement : indicateur plein écran.
    if (restaurant == null && state.isLoading) {
      return const AppLoadingView(message: 'Chargement de la fiche...');
    }

    // 2. Échec : erreur avec réessai sur le même identifiant.
    final Failure? failure = state.failure;
    if (restaurant == null && failure != null) {
      return AppErrorView(
        failure: failure,
        onRetry: () => bloc.add(RestaurantDetailRequested(state.restaurantId)),
      );
    }

    // 3. Cas limite : aucun contenu et aucun état exploitable.
    if (restaurant == null) {
      return const AppLoadingView(message: 'Chargement de la fiche...');
    }

    // 4. Contenu complet, défilant.
    return _DetailContent(
      restaurant: restaurant,
      now: now,
      urlGuard: urlGuard,
      isFavorite: state.isFavorite,
    );
  }
}

/// Contenu défilant de la fiche.
final class _DetailContent extends StatelessWidget {
  /// Construit le contenu.
  const _DetailContent({
    required this.restaurant,
    required this.now,
    required this.urlGuard,
    required this.isFavorite,
  });

  /// Restaurant affiché.
  final Restaurant restaurant;

  /// Instant de référence.
  final DateTime now;

  /// Garde-fou des liens.
  final UrlGuard urlGuard;

  /// État favori courant (utilisé par l'en-tête).
  final bool isFavorite;

  /// Construit le contenu.
  @override
  Widget build(BuildContext context) {
    // Braise éventuellement active à l'instant de référence.
    final LiveBraiseStatus? braise = restaurant.activeLiveBraiseAt(now);

    return ListView(
      padding: const EdgeInsets.all(AppSpacing.pagePadding),
      children: <Widget>[
        // ---------------------------------------------------------------
        // En-tête : accroche et badges
        // ---------------------------------------------------------------
        Text(
          restaurant.tagline,
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const SizedBox(height: AppSpacing.xs),

        // Badges de statut, sur plusieurs lignes si nécessaire.
        Wrap(
          spacing: AppSpacing.xs,
          runSpacing: AppSpacing.xs,
          children: <Widget>[
            OpenStatusBadge(isOpen: restaurant.isOpenAt(now)),
            if (braise != null) LiveBraiseBadge(braise: braise, now: now),
            if (restaurant.isVerified) const VerifiedBadge(),
            CategoryBadge(category: restaurant.category),
            DeliveryBadge(available: restaurant.deliveryAvailable),
            PriceRangeBadge(range: restaurant.priceRange),
            RatingBadge(
              rating: restaurant.rating,
              reviewCount: restaurant.reviewCount,
            ),
          ],
        ),

        // Espacement.
        const SizedBox(height: AppSpacing.md),

        // Mise en avant de la braise active.
        if (braise != null) ...<Widget>[
          LiveBraiseHighlight(braise: braise, now: now),
          const SizedBox(height: AppSpacing.md),
        ],

        // ---------------------------------------------------------------
        // Description
        // ---------------------------------------------------------------
        const _SectionTitle(icon: Icons.info_outline, title: 'À propos'),
        const SizedBox(height: AppSpacing.xs),
        Text(restaurant.description),

        // Espacement.
        const SizedBox(height: AppSpacing.md),

        // ---------------------------------------------------------------
        // Localisation et contact
        // ---------------------------------------------------------------
        const _SectionTitle(
          icon: Icons.place_outlined,
          title: 'Adresse et contact',
        ),
        const SizedBox(height: AppSpacing.xs),
        Text(restaurant.locationLabel),
        const SizedBox(height: AppSpacing.xxs),
        Text(
          restaurant.address,
          style: Theme.of(context).textTheme.bodySmall
              ?.copyWith(color: AppPalette.of(context).mutedText),
        ),
        const SizedBox(height: AppSpacing.sm),

        // Actions de contact et de navigation.
        _ActionButtons(restaurant: restaurant, urlGuard: urlGuard),

        // Espacement.
        const SizedBox(height: AppSpacing.md),

        // ---------------------------------------------------------------
        // Livraison : indicatif, devis selon la distance et redirection
        // ---------------------------------------------------------------
        DeliveryPanel(
          targetId: restaurant.id,
          targetLabel: restaurant.name,
          destination: GeoPoint(
            latitude: restaurant.latitude,
            longitude: restaurant.longitude,
          ),
          deliveryAvailable: restaurant.deliveryAvailable,
          urlGuard: urlGuard,
        ),

        // Espacement.
        const SizedBox(height: AppSpacing.md),

        // ---------------------------------------------------------------
        // Horaires
        // ---------------------------------------------------------------
        const _SectionTitle(icon: Icons.schedule_outlined, title: 'Horaires'),
        const SizedBox(height: AppSpacing.xs),
        Text('Aujourd’hui : ${restaurant.openingHours.todayLabel(now)}'),
        if (restaurant.isVerified && restaurant.verifiedAt != null) ...<Widget>[
          const SizedBox(height: AppSpacing.xxs),
          Text(
            AppFormatters.verificationAge(restaurant.verifiedAt!, now),
            style: Theme.of(context).textTheme.bodySmall
                ?.copyWith(color: AppPalette.of(context).verified),
          ),
        ],

        // Espacement.
        const SizedBox(height: AppSpacing.md),

        // ---------------------------------------------------------------
        // Ambiance
        // ---------------------------------------------------------------
        const _SectionTitle(icon: Icons.graphic_eq, title: 'Ambiance'),
        const SizedBox(height: AppSpacing.xs),
        Row(
          children: <Widget>[
            AmbianceBadge(score: restaurant.ambiance.score),
            const SizedBox(width: AppSpacing.xs),
            Expanded(
              child: Text(
                '${restaurant.ambiance.musicGenre} · ${restaurant.ambiance.note}',
                style: Theme.of(context).textTheme.bodySmall
                    ?.copyWith(color: AppPalette.of(context).mutedText),
              ),
            ),
          ],
        ),

        // Espacement.
        const SizedBox(height: AppSpacing.md),

        // ---------------------------------------------------------------
        // Équipements et paiement
        // ---------------------------------------------------------------
        const _SectionTitle(
          icon: Icons.room_service_outlined,
          title: 'Services',
        ),
        const SizedBox(height: AppSpacing.xs),
        _AmenityChips(restaurant: restaurant),

        // Espacement.
        const SizedBox(height: AppSpacing.md),

        // ---------------------------------------------------------------
        // Plats signatures
        // ---------------------------------------------------------------
        if (restaurant.signatureDishes.isNotEmpty) ...<Widget>[
          const _SectionTitle(
            icon: Icons.star_outline,
            title: 'Plats signatures',
          ),
          const SizedBox(height: AppSpacing.xs),
          for (final MenuItem item in restaurant.signatureDishes)
            _SignatureDishTile(item: item),
          const SizedBox(height: AppSpacing.md),
        ],

        // ---------------------------------------------------------------
        // Menu complet, regroupé par section
        // ---------------------------------------------------------------
        const _SectionTitle(icon: Icons.restaurant_menu, title: 'Menu'),
        const SizedBox(height: AppSpacing.xs),
        if (restaurant.menuBySection.isEmpty)
          Text(
            'Aucun plat disponible pour le moment.',
            style: Theme.of(context).textTheme.bodyMedium
                ?.copyWith(color: AppPalette.of(context).mutedText),
          ),
        for (final MapEntry<MenuSection, List<MenuItem>> entry
            in restaurant.menuBySection.entries)
          _MenuSectionCard(section: entry.key, items: entry.value),

        // Marge basse pour ne pas coller à la barre de navigation.
        const SizedBox(height: AppSpacing.lg),
      ],
    );
  }
}

/// Titre de section avec icône.
final class _SectionTitle extends StatelessWidget {
  /// Construit le titre.
  const _SectionTitle({required this.icon, required this.title});

  /// Icône de la section.
  final IconData icon;

  /// Libellé de la section.
  final String title;

  /// Construit le titre.
  @override
  Widget build(BuildContext context) {
    // Thème local.
    final ThemeData theme = Theme.of(context);

    return Row(
      children: <Widget>[
        Icon(icon, size: 20, color: theme.colorScheme.primary),
        const SizedBox(width: AppSpacing.xs),
        Text(
          title,
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }
}

/// Boutons d'action vers les liens externes et le téléphone.
final class _ActionButtons extends StatelessWidget {
  /// Construit la rangée d'actions.
  const _ActionButtons({required this.restaurant, required this.urlGuard});

  /// Restaurant ciblé.
  final Restaurant restaurant;

  /// Garde-fou des liens.
  final UrlGuard urlGuard;

  /// Construit les boutons.
  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: AppSpacing.xs,
      runSpacing: AppSpacing.xs,
      children: <Widget>[
        // Itinéraire Google Maps.
        FilledButton.tonalIcon(
          onPressed: () => unawaited(
            LinkFeedback.run(
              context,
              () => urlGuard.openDirections(
                latitude: restaurant.latitude,
                longitude: restaurant.longitude,
              ),
              successMessage: 'Ouverture de l’itinéraire...',
            ),
          ),
          icon: const Icon(Icons.directions_outlined),
          label: const Text('Itinéraire'),
        ),

        // Point sur la carte.
        OutlinedButton.icon(
          onPressed: () => unawaited(
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
          icon: const Icon(Icons.map_outlined),
          label: const Text('Carte'),
        ),

        // Appel téléphonique.
        OutlinedButton.icon(
          onPressed: () => unawaited(
            LinkFeedback.run(
              context,
              () => urlGuard.openPhoneCall(restaurant.phone),
            ),
          ),
          icon: const Icon(Icons.call_outlined),
          label: const Text('Appeler'),
        ),

        // Conversation WhatsApp.
        OutlinedButton.icon(
          onPressed: () => unawaited(
            LinkFeedback.run(
              context,
              () => urlGuard.openWhatsApp(
                phone: restaurant.whatsappPhone,
                message: 'Bonjour ${restaurant.name}, ',
              ),
            ),
          ),
          icon: const Icon(Icons.chat_outlined),
          label: const Text('WhatsApp'),
        ),

        // Accès direct de la fiche à l'espace gérant, présélectionné sur cette
        // fiche. L'authentification reste exigée dans le portail lui-même.
        FilledButton.tonalIcon(
          onPressed: () =>
              Navigator.of(context)
                  .pushNamed(AppRoutes.ownerPortal, arguments: restaurant.id),
          icon: const Icon(Icons.restaurant_menu_outlined),
          label: const Text('Gérer le menu'),
        ),
      ],
    );
  }
}

/// Puces des équipements et moyens de paiement.
final class _AmenityChips extends StatelessWidget {
  /// Construit les puces.
  const _AmenityChips({required this.restaurant});

  /// Restaurant dont on affiche les services.
  final Restaurant restaurant;

  /// Construit les puces.
  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: AppSpacing.xs,
      runSpacing: AppSpacing.xs,
      children: <Widget>[
        // Équipements déclarés, dans l'ordre de déclaration de l'énumération.
        for (final RestaurantAmenity amenity in RestaurantAmenity.values)
          if (restaurant.amenities.contains(amenity))
            Chip(
              avatar: const Icon(Icons.check, size: 16),
              label: Text(amenity.label),
            ),

        // Moyens de paiement acceptés.
        for (final PaymentMethod method in PaymentMethod.values)
          if (restaurant.paymentMethods.contains(method))
            Chip(
              avatar: const Icon(Icons.payments_outlined, size: 16),
              label: Text(method.label),
            ),
      ],
    );
  }
}

/// Tuile compacte d'un plat signature.
final class _SignatureDishTile extends StatelessWidget {
  /// Construit la tuile.
  const _SignatureDishTile({required this.item});

  /// Plat signature.
  final MenuItem item;

  /// Construit la tuile.
  @override
  Widget build(BuildContext context) {
    // Thème local.
    final ThemeData theme = Theme.of(context);

    return Card(
      child: ListTile(
        leading: Icon(
          Icons.local_fire_department,
          color: theme.colorScheme.tertiary,
        ),
        title: Text(item.name),
        subtitle: Text(item.description),
        trailing: Text(
          AppFormatters.fcfa(item.priceFcfa),
          style: theme.textTheme.titleSmall?.copyWith(
            color: AppPalette.of(context).price,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }
}

/// Carte présentant une section du menu.
final class _MenuSectionCard extends StatelessWidget {
  /// Construit la carte.
  const _MenuSectionCard({required this.section, required this.items});

  /// Section affichée.
  final MenuSection section;

  /// Plats de la section.
  final List<MenuItem> items;

  /// Construit la carte.
  @override
  Widget build(BuildContext context) {
    // Thème local.
    final ThemeData theme = Theme.of(context);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.sm),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            // Nom de la section.
            Text(
              section.label,
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            const Divider(height: AppSpacing.md),

            // Liste des plats de la section.
            for (final MenuItem item in items)
              Padding(
                padding: const EdgeInsets.only(bottom: AppSpacing.xs),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    // Nom et détails du plat.
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Text(
                            item.name,
                            style: theme.textTheme.bodyMedium?.copyWith(
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          if (item.description.isNotEmpty)
                            Text(
                              item.description,
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: AppPalette.of(context).mutedText,
                              ),
                            ),
                        ],
                      ),
                    ),

                    // Prix du plat.
                    Text(
                      AppFormatters.fcfa(item.priceFcfa),
                      style: theme.textTheme.labelLarge?.copyWith(
                        color: AppPalette.of(context).price,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// Barre inférieure : commande WhatsApp et partage d'addition.
final class _DetailBottomBar extends StatelessWidget {
  /// Construit la barre.
  const _DetailBottomBar({required this.restaurant});

  /// Restaurant ciblé.
  final Restaurant restaurant;

  /// Construit la barre.
  @override
  Widget build(BuildContext context) {
    // Les couleurs des boutons viennent du thème global (AppPalette.cta).
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.sm),
        child: Row(
          children: <Widget>[
            // Bouton secondaire : partage d'addition.
            Expanded(
              child: OutlinedButton.icon(
                onPressed: () =>
                    Navigator.of(context)
                        .pushNamed(AppRoutes.splitBill(restaurant.id)),
                icon: const Icon(Icons.receipt_long_outlined),
                label: const Text('Partager'),
              ),
            ),
            const SizedBox(width: AppSpacing.sm),

            // Bouton principal : commander sur WhatsApp.
            Expanded(
              flex: 2,
              child: FilledButton.icon(
                // Couleur pilotée par le thème (AppPalette.cta) : on ne fixe
                // que la hauteur pour rester cohérent avec les autres CTAs.
                style: FilledButton.styleFrom(
                  minimumSize: const Size.fromHeight(AppSpacing.buttonHeight),
                ),
                onPressed: () =>
                    Navigator.of(context)
                        .pushNamed(AppRoutes.order(restaurant.id)),
                icon: const Icon(Icons.shopping_bag_outlined),
                label: const Text('Commander'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
