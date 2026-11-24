// =============================================================================
// Page de l'annuaire réel de Koudougou.
// -----------------------------------------------------------------------------
// Les fiches affichées proviennent de sources publiques datées. Chaque carte
// porte son niveau de vérification : l'application ne prétend JAMAIS qu'un
// établissement est « ouvert et fonctionnel » sans vérification sur place.
// =============================================================================

// Appels asynchrones non attendus depuis un geste.
import 'dart:async';

// Widgets et Material.
import 'package:flutter/material.dart';

// BLoC.
import 'package:flutter_bloc/flutter_bloc.dart';

// Routes nommées (ouverture de la fiche commandable).
import '../../../../core/constants/app_routes.dart';

// Erreurs.
import '../../../../core/error/failures.dart';

// Point GPS de la fiche sourcée.
import '../../../../core/location/geo_point.dart';

// Garde-fou des liens externes.
import '../../../../core/security/url_guard.dart';

// Palette et espacements.
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';

// Entité.
import '../../domain/entities/koudougou_listing.dart';

// Cubit et état.
import '../bloc/directory_cubit.dart';
import '../bloc/directory_state.dart';

// Vues d'état et retour de liens.
import '../widgets/async_state_views.dart';
import '../widgets/delivery_panel.dart';
import '../widgets/link_feedback.dart';

/// Annuaire complet des établissements sourcés de Koudougou.
final class DirectoryPage extends StatelessWidget {
  /// Construit la page avec le garde-fou des liens externes.
  const DirectoryPage({required this.urlGuard, super.key});

  // Garde-fou injecté par le routeur.
  final UrlGuard urlGuard;

  /// Construit l'interface.
  @override
  Widget build(BuildContext context) {
    // Ouverture automatique au premier affichage.
    context.read<DirectoryCubit>().load();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Annuaire de Koudougou'),
        actions: <Widget>[
          IconButton(
            tooltip: 'Réinitialiser les filtres',
            icon: const Icon(Icons.filter_alt_off_outlined),
            onPressed: () => context.read<DirectoryCubit>().clearFilters(),
          ),
        ],
      ),
      body: BlocBuilder<DirectoryCubit, DirectoryState>(
        builder: (BuildContext context, DirectoryState state) {
          // Premier chargement : indicateur.
          if (state.isLoading) {
            return const AppLoadingView(
              message: 'Chargement de l’annuaire de Koudougou...',
            );
          }

          // Échec sans données : erreur avec réessai.
          final Failure? failure = state.failure;
          if (state.hasError && state.listings.isEmpty && failure != null) {
            return AppErrorView(
              failure: failure,
              onRetry: () => context.read<DirectoryCubit>().load(),
            );
          }

          // Contenu nominal.
          return RefreshIndicator(
            onRefresh: () => context.read<DirectoryCubit>().load(),
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.all(AppSpacing.pagePadding),
              children: <Widget>[
                // Avertissement de vérification, toujours visible.
                const _VerificationNotice(),

                const SizedBox(height: AppSpacing.md),

                // Recherche locale.
                TextField(
                  decoration: const InputDecoration(
                    labelText: 'Rechercher un établissement',
                    hintText: 'Nom, quartier, spécialité...',
                    prefixIcon: Icon(Icons.search),
                    border: OutlineInputBorder(),
                  ),
                  onChanged: (String value) =>
                      context.read<DirectoryCubit>().searchChanged(value),
                ),

                const SizedBox(height: AppSpacing.sm),

                // Filtres par niveau de vérification.
                Wrap(
                  spacing: AppSpacing.xs,
                  children: <Widget>[
                    for (final DirectoryVerification? option
                        in <DirectoryVerification?>[
                          null,
                          ...DirectoryVerification.values,
                        ])
                      ChoiceChip(
                        label: Text(option?.label ?? 'Tous'),
                        selected: state.verification == option,
                        onSelected: (bool _) => context
                            .read<DirectoryCubit>()
                            .verificationChanged(option),
                      ),
                  ],
                ),

                const SizedBox(height: AppSpacing.md),

                // Compteur.
                Text(
                  '${state.visibleListings.length} établissement(s) recensé(s)',
                  style: Theme.of(context).textTheme.titleSmall,
                ),

                const SizedBox(height: AppSpacing.xs),

                // Fiches.
                for (final KoudougouListing listing in state.visibleListings)
                  Padding(
                    padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                    child: _DirectoryCard(
                      listing: listing,
                      urlGuard: urlGuard,
                      // Tout appui sur la carte ouvre la fiche commandable ;
                      // la fiche sourcée est transmise sans rechargement.
                      onOpen: () => Navigator.of(context).pushNamed(
                        AppRoutes.directoryListing(listing.id),
                        arguments: listing,
                      ),
                      onSourceTap: listing.hasSource
                          ? () => unawaited(
                              LinkFeedback.run(
                                context,
                                () => urlGuard.openRaw(listing.sourceUrl),
                              ),
                            )
                          : null,
                      onPhoneTap: listing.hasPhone
                          ? () => unawaited(
                              LinkFeedback.run(
                                context,
                                () => urlGuard.openPhoneCall(listing.phone),
                              ),
                            )
                          : null,
                    ),
                  ),

                // Aucun résultat.
                if (state.visibleListings.isEmpty)
                  const AppEmptyView(
                    icon: Icons.search_off,
                    title: 'Aucun résultat',
                    message:
                        'Essayez un autre terme ou réinitialisez les filtres.',
                  ),
              ],
            ),
          );
        },
      ),
    );
  }
}

/// Avertissement permanent sur la portée des données de l'annuaire.
final class _VerificationNotice extends StatelessWidget {
  /// Construit l'avertissement.
  const _VerificationNotice();

  /// Construit l'interface.
  @override
  Widget build(BuildContext context) {
    // Thème local.
    final ThemeData theme = Theme.of(context);
    final AppPalette palette = AppPalette.of(context);

    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: AppSpacing.cardRadius,
        border: Border.all(color: palette.warning),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Icon(Icons.verified_user_outlined, color: palette.warning),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Text(
              'Ces établissements sont cités par des sources publiques. '
              'Leur ouverture actuelle n’est pas certifiée : confirmez par '
              'téléphone ou sur place avant de vous déplacer.',
              style: theme.textTheme.bodyMedium,
            ),
          ),
        ],
      ),
    );
  }
}

/// Carte d'un établissement sourcé.
final class _DirectoryCard extends StatelessWidget {
  /// Construit la carte.
  const _DirectoryCard({
    required this.listing,
    required this.urlGuard,
    required this.onOpen,
    required this.onSourceTap,
    required this.onPhoneTap,
  });

  // Données et gestes.
  final KoudougouListing listing;
  final UrlGuard urlGuard;
  final VoidCallback onOpen;
  final VoidCallback? onSourceTap;
  final VoidCallback? onPhoneTap;

  /// Construit l'interface.
  @override
  Widget build(BuildContext context) {
    // Thème et palette.
    final ThemeData theme = Theme.of(context);
    final AppPalette palette = AppPalette.of(context);
    final Color statusColor = _colorFor(listing.verification, palette);

    // Seule la fiche Snack Time sourcée dispose de coordonnées exploitables.
    final GeoPoint? snackPosition = listing.id == 'snack-time-bcb'
        ? listing.position
        : null;

    return Card(
      clipBehavior: Clip.antiAlias,
      // Toute la carte est cliquable : elle ouvre la fiche commandable.
      // Les boutons qu'elle contient gardent leur propre geste prioritaire.
      child: InkWell(
        onTap: onOpen,
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              // Nom et catégorie.
              Text(
                listing.name,
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: AppSpacing.xxs),
              Text(listing.category, style: theme.textTheme.bodyMedium),

              const SizedBox(height: AppSpacing.sm),

              // Adresse et horaires.
              _InfoLine(icon: Icons.place_outlined, text: listing.area),
              if (listing.hours.isNotEmpty)
                _InfoLine(icon: Icons.schedule_outlined, text: listing.hours),
              if (listing.priceInfo.isNotEmpty)
                _InfoLine(
                  icon: Icons.payments_outlined,
                  text: listing.priceInfo,
                ),
              if (listing.specialties.isNotEmpty)
                _InfoLine(
                  icon: Icons.restaurant_outlined,
                  text: listing.specialties,
                ),

              const SizedBox(height: AppSpacing.sm),

              // Statut de vérification : toujours affiché.
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.sm,
                  vertical: AppSpacing.xxs,
                ),
                decoration: BoxDecoration(
                  color: statusColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
                ),
                child: Text(
                  listing.verification.label,
                  style: theme.textTheme.labelMedium?.copyWith(
                    color: statusColor,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),

              // Réserve éventuelle.
              if (listing.note.isNotEmpty) ...<Widget>[
                const SizedBox(height: AppSpacing.xs),
                Text(
                  listing.note,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: palette.mutedText,
                  ),
                ),
              ],

              const SizedBox(height: AppSpacing.sm),

              // Source citée.
              Text(
                'Source : ${listing.sourceName}',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: palette.mutedText,
                ),
              ),

              // Actions sûres : téléphone et source HTTPS.
              Row(
                children: <Widget>[
                  if (onPhoneTap != null)
                    TextButton.icon(
                      onPressed: onPhoneTap,
                      icon: const Icon(Icons.call_outlined),
                      label: const Text('Appeler'),
                    ),
                  if (onSourceTap != null)
                    TextButton.icon(
                      onPressed: onSourceTap,
                      icon: const Icon(Icons.open_in_new),
                      label: const Text('Voir la source'),
                    ),
                ],
              ),

              // Appel explicite à l'ouverture de la fiche et du menu.
              const SizedBox(height: AppSpacing.sm),
              Row(
                children: <Widget>[
                  Icon(
                    Icons.restaurant_menu_outlined,
                    size: 18,
                    color: theme.colorScheme.primary,
                  ),
                  const SizedBox(width: AppSpacing.xs),
                  Expanded(
                    child: Text(
                      'Voir le menu et commander',
                      style: theme.textTheme.labelLarge?.copyWith(
                        color: theme.colorScheme.primary,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  const Icon(Icons.chevron_right, size: 18),
                ],
              ),

              // Devis de livraison simulé autour du point sourcé Snack Time.
              if (snackPosition != null) ...<Widget>[
                const SizedBox(height: AppSpacing.xs),
                DeliveryPanel(
                  targetId: listing.id,
                  targetLabel: listing.name,
                  destination: snackPosition,
                  deliveryAvailable: listing.deliveryAvailable,
                  urlGuard: urlGuard,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  /// Couleur sémantique du niveau de vérification.
  static Color _colorFor(
    DirectoryVerification verification,
    AppPalette palette,
  ) {
    return switch (verification) {
      DirectoryVerification.recentOnlineSignal => palette.success,
      DirectoryVerification.onlineListing => palette.verified,
      DirectoryVerification.pressReport => palette.warning,
      DirectoryVerification.toConfirm => palette.danger,
    };
  }
}

/// Ligne d'information compacte avec icône.
final class _InfoLine extends StatelessWidget {
  /// Construit la ligne.
  const _InfoLine({required this.icon, required this.text});

  // Données.
  final IconData icon;
  final String text;

  /// Construit l'interface.
  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final AppPalette palette = AppPalette.of(context);

    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.xxs),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Icon(icon, size: 16, color: palette.mutedText),
          const SizedBox(width: AppSpacing.xs),
          Expanded(child: Text(text, style: theme.textTheme.bodySmall)),
        ],
      ),
    );
  }
}
