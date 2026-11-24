// =============================================================================
// Écran de partage d'addition.
// -----------------------------------------------------------------------------
// À partir du panier local (`CartCubit`) et de la fiche du restaurant
// (`RestaurantDetailBloc`), la page calcule la part de chaque convive. Le calcul
// est arrondi au FCFA SUPÉRIEUR (`CartSummary.perPersonFcfa`) pour que la somme
// des parts couvre toujours le total. Le récapitulatif peut être partagé via
// WhatsApp ; aucun paiement n'est traité dans l'application.
// =============================================================================

// `unawaited` pour l'ouverture du lien de partage.
import 'dart:async';

// Widgets et Material.
import 'package:flutter/material.dart';

// BLoC et Cubit.
import 'package:flutter_bloc/flutter_bloc.dart';

// Bornes métier (nombre maximal de convives).
import '../../../../core/constants/app_constants.dart';

// Routes nommées.
import '../../../../core/constants/app_routes.dart';

// Erreur métier affichable.
import '../../../../core/error/failures.dart';

// Garde-fou d'ouverture des liens externes (WhatsApp).
import '../../../../core/security/url_guard.dart';

// Palette et espacements.
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';

// Formatage FCFA.
import '../../../../core/utils/formatters.dart';

// Entité affichée.
import '../../domain/entities/restaurant.dart';

// Cubit du panier et son état.
import '../bloc/cart_cubit.dart';

// BLoC de la fiche, événements et état.
import '../bloc/restaurant_detail_bloc.dart';
import '../bloc/restaurant_detail_event.dart';
import '../bloc/restaurant_detail_state.dart';

// Récapitulatif partagé (lignes, total, part par convive).
import '../utils/cart_summary.dart';

// Vues d'état et retour des liens.
import '../widgets/async_state_views.dart';
import '../widgets/link_feedback.dart';

/// Page de partage d'addition entre convives.
final class SplitBillPage extends StatelessWidget {
  /// Construit la page.
  const SplitBillPage({
    required this.restaurantId,
    required this.urlGuard,
    required this.now,
    super.key,
  });

  /// Identifiant du restaurant (sert au réessai).
  final String restaurantId;

  /// Garde-fou des liens externes.
  final UrlGuard urlGuard;

  /// Instant de référence (horodatage du partage).
  final DateTime now;

  /// Construit la page.
  @override
  Widget build(BuildContext context) {
    // BLoC de la fiche, fourni par le routeur.
    final RestaurantDetailBloc detailBloc = context
        .read<RestaurantDetailBloc>();

    // Panier partagé (singleton applicatif).
    final CartCubit cart = context.read<CartCubit>();

    return Scaffold(
      // Barre d'application.
      appBar: AppBar(title: const Text('Partager l’addition')),

      // Corps réactif à la fiche puis au panier.
      body: BlocBuilder<RestaurantDetailBloc, RestaurantDetailState>(
        builder: (BuildContext context, RestaurantDetailState state) {
          // Fiche éventuellement chargée.
          final Restaurant? restaurant = state.restaurant;

          // 1. Premier chargement.
          if (restaurant == null && state.isLoading) {
            return const AppLoadingView(message: 'Chargement du panier...');
          }

          // 2. Échec : erreur avec réessai.
          final Failure? failure = state.failure;
          if (restaurant == null && failure != null) {
            return AppErrorView(
              failure: failure,
              onRetry: () =>
                  detailBloc.add(RestaurantDetailRequested(state.restaurantId)),
            );
          }

          // 3. Cas limite.
          if (restaurant == null) {
            return const AppLoadingView(message: 'Chargement du panier...');
          }

          // 4. Contenu réactif au panier.
          return BlocBuilder<CartCubit, CartState>(
            builder: (BuildContext context, CartState cartState) {
              // Récapitulatif recalculé à chaque changement.
              final CartSummary summary = CartSummary.from(
                restaurant: restaurant,
                quantities: cartState.quantities,
              );

              // Panier vide : rien à partager.
              if (summary.isEmpty) {
                return AppEmptyView(
                  icon: Icons.receipt_long_outlined,
                  title: 'Votre panier est vide',
                  message:
                      'Ajoutez des plats depuis l’écran de commande pour '
                      'pouvoir partager l’addition.',
                  action: FilledButton.tonal(
                    onPressed: () =>
                        Navigator.of(context)
                            .pushNamed(AppRoutes.order(restaurant.id)),
                    child: const Text('Composer une commande'),
                  ),
                );
              }

              // Contenu complet.
              return _SplitContent(
                restaurant: restaurant,
                summary: summary,
                partySize: cartState.partySize,
                urlGuard: urlGuard,
                now: now,
                onPartySizeChanged: cart.setPartySize,
              );
            },
          );
        },
      ),
    );
  }
}

/// Contenu défilant du partage d'addition.
final class _SplitContent extends StatelessWidget {
  /// Construit le contenu.
  const _SplitContent({
    required this.restaurant,
    required this.summary,
    required this.partySize,
    required this.urlGuard,
    required this.now,
    required this.onPartySizeChanged,
  });

  /// Restaurant ciblé.
  final Restaurant restaurant;

  /// Récapitulatif courant.
  final CartSummary summary;

  /// Nombre de convives.
  final int partySize;

  /// Garde-fou des liens externes.
  final UrlGuard urlGuard;

  /// Instant de référence.
  final DateTime now;

  /// Mise à jour du nombre de convives.
  final void Function(int value) onPartySizeChanged;

  /// Construit le contenu.
  @override
  Widget build(BuildContext context) {
    // Thème, typographie et palette locales.
    final ThemeData theme = Theme.of(context);
    final TextTheme textTheme = theme.textTheme;
    final AppPalette palette = AppPalette.of(context);

    // Part de chaque convive, arrondie au FCFA supérieur.
    final int perPerson = summary.perPersonFcfa(partySize);

    return ListView(
      padding: const EdgeInsets.all(AppSpacing.pagePadding),
      children: <Widget>[
        // ---------------------------------------------------------------
        // En-tête
        // ---------------------------------------------------------------
        Text(
          restaurant.name,
          style: textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
        ),
        Text(
          '${summary.itemCount} article(s) · '
          '${AppFormatters.fcfa(summary.totalFcfa)}',
          style: textTheme.bodySmall?.copyWith(color: palette.mutedText),
        ),
        const SizedBox(height: AppSpacing.md),

        // ---------------------------------------------------------------
        // Sélecteur du nombre de convives
        // ---------------------------------------------------------------
        Card(
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.md),
            child: Row(
              children: <Widget>[
                // Libellé.
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        'Nombre de convives',
                        style: textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      Text(
                        'Entre 1 et ${AppConstants.maxPartySize} personnes.',
                        style: textTheme.bodySmall?.copyWith(
                          color: palette.mutedText,
                        ),
                      ),
                    ],
                  ),
                ),

                // Sélecteur « −  n  + ».
                _PartySizeStepper(
                  partySize: partySize,
                  onChanged: onPartySizeChanged,
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.md),

        // ---------------------------------------------------------------
        // Mise en avant de la part par convive
        // ---------------------------------------------------------------
        Card(
          color: theme.colorScheme.primaryContainer,
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.md),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  'Part par convive',
                  style: textTheme.labelLarge?.copyWith(
                    color: theme.colorScheme.onPrimaryContainer,
                  ),
                ),
                const SizedBox(height: AppSpacing.xxs),
                Text(
                  AppFormatters.fcfa(perPerson),
                  style: textTheme.headlineSmall?.copyWith(
                    color: theme.colorScheme.onPrimaryContainer,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: AppSpacing.xxs),
                Text(
                  'Montant arrondi à l’unité supérieure : la somme des parts '
                  'couvre toujours le total.',
                  style: textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onPrimaryContainer,
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.md),

        // ---------------------------------------------------------------
        // Détail des articles
        // ---------------------------------------------------------------
        Text(
          'Détail de la commande',
          style: textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: AppSpacing.xs),
        for (final CartLine line in summary.lines)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: AppSpacing.xxs),
            child: Row(
              children: <Widget>[
                // Quantité et nom.
                Expanded(
                  child: Text(
                    '${line.quantity} × ${line.item.name}',
                    style: textTheme.bodyMedium,
                  ),
                ),

                // Sous-total de la ligne.
                Text(
                  AppFormatters.fcfa(line.subtotalFcfa),
                  style: textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),

        // Séparation puis total.
        const Divider(height: AppSpacing.lg),
        Row(
          children: <Widget>[
            Text(
              'Total',
              style: textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            const Spacer(),
            Text(
              AppFormatters.fcfa(summary.totalFcfa),
              style: textTheme.titleMedium?.copyWith(
                color: palette.price,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.lg),

        // ---------------------------------------------------------------
        // Partage WhatsApp
        // ---------------------------------------------------------------
        FilledButton.icon(
          onPressed: () => unawaited(
            LinkFeedback.run(
              context,
              () => urlGuard.openWhatsApp(
                phone: restaurant.whatsappPhone,
                message: _buildSplitMessage(
                  restaurant: restaurant,
                  summary: summary,
                  partySize: partySize,
                  perPerson: perPerson,
                  now: now,
                ),
              ),
              successMessage: 'Ouverture de WhatsApp...',
            ),
          ),
          icon: const Icon(Icons.share_outlined),
          label: const Text('Partager sur WhatsApp'),
        ),

        // Marge basse.
        const SizedBox(height: AppSpacing.lg),
      ],
    );
  }

  /// Construit le message de partage d'addition.
  static String _buildSplitMessage({
    required Restaurant restaurant,
    required CartSummary summary,
    required int partySize,
    required int perPerson,
    required DateTime now,
  }) {
    // Tampon de construction, lisible sur WhatsApp.
    final StringBuffer buffer = StringBuffer()
      ..writeln('Addition — ${restaurant.name}')
      ..writeln(
        '${summary.itemCount} article(s) · '
        '${AppFormatters.fcfa(summary.totalFcfa)}',
      );

    // Détail des articles.
    for (final CartLine line in summary.lines) {
      buffer.writeln(
        '• ${line.quantity} × ${line.item.name} '
        '(${AppFormatters.fcfa(line.subtotalFcfa)})',
      );
    }

    // Répartition.
    buffer
      ..writeln('')
      ..writeln('À partager entre $partySize convive(s) :')
      ..writeln('${AppFormatters.fcfa(perPerson)} par personne')
      ..write('Partagé le ${AppFormatters.dateTimeFr(now)}.');

    return buffer.toString();
  }
}

/// Sélecteur du nombre de convives, borné par les constantes métier.
final class _PartySizeStepper extends StatelessWidget {
  /// Construit le sélecteur.
  const _PartySizeStepper({required this.partySize, required this.onChanged});

  /// Nombre de convives courant.
  final int partySize;

  /// Mise à jour du nombre de convives.
  final void Function(int value) onChanged;

  /// Construit le sélecteur.
  @override
  Widget build(BuildContext context) {
    // Thème local pour les icônes.
    final ThemeData theme = Theme.of(context);

    // Bornes de désactivation explicites.
    final bool canDecrease = partySize > 1;
    final bool canIncrease = partySize < AppConstants.maxPartySize;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        // Retrait d'un convive.
        IconButton(
          onPressed: canDecrease ? () => onChanged(partySize - 1) : null,
          tooltip: 'Moins de convives',
          icon: const Icon(Icons.remove_circle_outline),
          color: theme.colorScheme.primary,
        ),

        // Valeur courante, largeur fixe.
        SizedBox(
          width: 32,
          child: Text(
            '$partySize',
            textAlign: TextAlign.center,
            style: theme.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
        ),

        // Ajout d'un convive.
        IconButton(
          onPressed: canIncrease ? () => onChanged(partySize + 1) : null,
          tooltip: 'Plus de convives',
          icon: const Icon(Icons.add_circle_outline),
          color: theme.colorScheme.primary,
        ),
      ],
    );
  }
}
