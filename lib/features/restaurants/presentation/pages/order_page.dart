// =============================================================================
// Écran de commande (panier local + récapitulatif + envoi WhatsApp).
// -----------------------------------------------------------------------------
// Cette page ne calcule AUCUN prix des plats : elle lit la fiche du restaurant
// (`RestaurantDetailBloc`) et les quantités du panier (`CartCubit`), puis
// recompose le total via `CartSummary`. Le seul montant ajouté est le devis de
// livraison calculé par le Domain. La commande n'est jamais envoyée à un
// serveur : le message est transmis à WhatsApp, qui devient le canal officiel
// avec le gérant. Les instructions Mobile Money sont purement informatives et
// ne collectent jamais de code PIN.
// =============================================================================

// `unawaited` pour les ouvertures de liens déclenchées par un geste.
import 'dart:async';

// Widgets et Material.
import 'package:flutter/material.dart';

// BLoC et Cubit.
import 'package:flutter_bloc/flutter_bloc.dart';

// Routes nommées.
import '../../../../core/constants/app_routes.dart';

// Référentiel local (opérateurs Mobile Money, consignes de sécurité).
import '../../../../core/constants/koudougou_reference.dart';

// Erreur métier affichable.
import '../../../../core/error/failures.dart';

// Point GPS transmis au panneau de devis.
import '../../../../core/location/geo_point.dart';

// Garde-fou d'ouverture des liens externes (WhatsApp).
import '../../../../core/security/url_guard.dart';

// Palette et espacements.
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';

// Formatage FCFA.
import '../../../../core/utils/formatters.dart';

// Entités affichées.
import '../../domain/entities/delivery_quote.dart';
import '../../domain/entities/menu_item.dart';
import '../../domain/entities/restaurant.dart';

// Cubit du panier et état.
import '../bloc/cart_cubit.dart';

// État du devis de livraison.
import '../bloc/delivery_cubit.dart';

// BLoC de la fiche, événements et état.
import '../bloc/restaurant_detail_bloc.dart';
import '../bloc/restaurant_detail_event.dart';
import '../bloc/restaurant_detail_state.dart';

// Récapitulatif partagé et message WhatsApp.
import '../utils/cart_summary.dart';
import '../utils/order_message.dart';

// Vues d'état, devis et retour des liens.
import '../widgets/async_state_views.dart';
import '../widgets/delivery_panel.dart';
import '../widgets/link_feedback.dart';

// Tuile de menu partagée avec la fiche commandable de l'annuaire.
import '../widgets/order_menu_tile.dart';

/// Page de composition et d'envoi d'une commande.
final class OrderPage extends StatefulWidget {
  /// Construit la page.
  const OrderPage({
    required this.restaurantId,
    required this.urlGuard,
    required this.now,
    super.key,
  });

  /// Identifiant du restaurant (sert au réessai).
  final String restaurantId;

  /// Garde-fou des liens externes.
  final UrlGuard urlGuard;

  /// Instant de référence (heure de Koudougou) pour les statuts dynamiques.
  final DateTime now;

  @override
  State<OrderPage> createState() => _OrderPageState();
}

/// État qui pilote le retour au panier depuis le récapitulatif fixe.
class _OrderPageState extends State<OrderPage> {
  /// Contrôleur de la liste du menu : « Modifier » ramène en haut de page.
  final ScrollController _scrollController = ScrollController();

  /// Libère le contrôleur avec la page.
  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  /// Construit la page.
  @override
  Widget build(BuildContext context) {
    // BLoC de la fiche, fourni par le routeur pour cette route.
    final RestaurantDetailBloc detailBloc = context
        .read<RestaurantDetailBloc>();

    // Panier partagé (singleton applicatif), fourni par le routeur.
    final CartCubit cart = context.read<CartCubit>();

    return Scaffold(
      // Barre d'application.
      appBar: AppBar(title: const Text('Commander')),

      // Corps : le menu et les quantités, réactifs à la fiche.
      body: BlocBuilder<RestaurantDetailBloc, RestaurantDetailState>(
        builder: (BuildContext context, RestaurantDetailState state) {
          // Fiche éventuellement chargée.
          final Restaurant? restaurant = state.restaurant;

          // 1. Premier chargement.
          if (restaurant == null && state.isLoading) {
            return const AppLoadingView(message: 'Chargement du menu...');
          }

          // 2. Échec : erreur avec réessai sur le même identifiant.
          final Failure? failure = state.failure;
          if (restaurant == null && failure != null) {
            return AppErrorView(
              failure: failure,
              onRetry: () =>
                  detailBloc.add(RestaurantDetailRequested(state.restaurantId)),
            );
          }

          // 3. Cas limite : aucune fiche exploitable.
          if (restaurant == null) {
            return const AppLoadingView(message: 'Chargement du menu...');
          }

          // 4. Contenu complet.
          return _OrderContent(
            restaurant: restaurant,
            cart: cart,
            now: widget.now,
            scrollController: _scrollController,
            urlGuard: widget.urlGuard,
          );
        },
      ),

      // Récapitulatif fixe en bas : Modifier (panier) / Confirmer (WhatsApp).
      bottomNavigationBar:
          BlocBuilder<RestaurantDetailBloc, RestaurantDetailState>(
            builder: (BuildContext context, RestaurantDetailState state) {
              // Fiche éventuellement chargée.
              final Restaurant? restaurant = state.restaurant;

              // Tant que la fiche n'est pas prête, aucune barre n'est affichée.
              if (restaurant == null) {
                return const SizedBox.shrink();
              }

              return BlocBuilder<CartCubit, CartState>(
                builder: (BuildContext context, CartState cartState) {
                  // Récapitulatif recalculé à chaque changement de panier.
                  final CartSummary summary = CartSummary.from(
                    restaurant: restaurant,
                    quantities: cartState.quantities,
                  );

                  return BlocBuilder<DeliveryCubit, DeliveryState>(
                    builder: (BuildContext context, DeliveryState delivery) {
                      // Le frais n'est ajouté que si la livraison est demandée
                      // ET si le devis calculé est réellement disponible.
                      final DeliveryQuote? quote =
                          cartState.deliveryRequested &&
                              delivery.hasQuote &&
                              delivery.quote!.isAvailable
                          ? delivery.quote
                          : null;

                      return _OrderBottomBar(
                        restaurant: restaurant,
                        summary: summary,
                        quote: quote,
                        urlGuard: widget.urlGuard,
                        now: widget.now,
                        onModify: _backToCart,
                      );
                    },
                  );
                },
              );
            },
          ),
    );
  }

  /// Ramène l'utilisateur à la composition du panier (haut de la liste).
  void _backToCart() {
    if (_scrollController.hasClients) {
      _scrollController.animateTo(
        0,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    }
  }
}

/// Contenu défilant : menu, livraison éventuelle et informations paiement.
final class _OrderContent extends StatelessWidget {
  /// Construit le contenu.
  const _OrderContent({
    required this.restaurant,
    required this.cart,
    required this.now,
    required this.scrollController,
    required this.urlGuard,
  });

  /// Restaurant ciblé.
  final Restaurant restaurant;

  /// Panier partagé.
  final CartCubit cart;

  /// Instant de référence.
  final DateTime now;

  /// Contrôleur partagé avec la barre de récapitulatif.
  final ScrollController scrollController;

  /// Garde-fou des liens externes.
  final UrlGuard urlGuard;

  /// Construit le contenu.
  @override
  Widget build(BuildContext context) {
    // Typographie et palette locales.
    final TextTheme textTheme = Theme.of(context).textTheme;
    final AppPalette palette = AppPalette.of(context);

    return BlocBuilder<CartCubit, CartState>(
      builder: (BuildContext context, CartState cartState) {
        // Sections du menu, dans l'ordre de déclaration.
        final Map<MenuSection, List<MenuItem>> sections =
            restaurant.menuBySection;

        return ListView(
          controller: scrollController,
          padding: const EdgeInsets.all(AppSpacing.pagePadding),
          children: <Widget>[
            // ---------------------------------------------------------------
            // En-tête : rappel de l'établissement
            // ---------------------------------------------------------------
            Text(
              restaurant.name,
              style: textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            Text(
              restaurant.locationLabel,
              style: textTheme.bodySmall?.copyWith(color: palette.mutedText),
            ),
            const SizedBox(height: AppSpacing.md),

            // ---------------------------------------------------------------
            // Menu commandable, regroupé par section
            // ---------------------------------------------------------------
            if (sections.isEmpty)
              Text(
                'Aucun plat commandable pour le moment.',
                style: textTheme.bodyMedium?.copyWith(color: palette.mutedText),
              ),

            for (final MapEntry<MenuSection, List<MenuItem>> entry
                in sections.entries) ...<Widget>[
              // Titre de section.
              Text(
                entry.key.label,
                style: textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: AppSpacing.xs),

              // Plats de la section, avec sélecteur de quantité.
              for (final MenuItem item in entry.value)
                OrderMenuTile(
                  item: item,
                  quantity: cartState.quantityOf(item.id),
                  onIncrement: () => cart.increment(item.id),
                  onDecrement: () => cart.decrement(item.id),
                ),

              // Espacement entre sections.
              const SizedBox(height: AppSpacing.sm),
            ],

            // ---------------------------------------------------------------
            // Livraison : option et devis selon la distance
            // ---------------------------------------------------------------
            if (restaurant.deliveryAvailable) ...<Widget>[
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                value: cartState.deliveryRequested,
                onChanged: cart.setDeliveryRequested,
                title: const Text('Livraison à domicile'),
                subtitle: const Text(
                  'Devis selon la distance : 500 FCFA + 200 FCFA/km, '
                  'jusqu’à 5 km.',
                ),
              ),
              if (cartState.deliveryRequested)
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
              const SizedBox(height: AppSpacing.md),
            ],

            // ---------------------------------------------------------------
            // Rappel : la commande part sur WhatsApp
            // ---------------------------------------------------------------
            Card(
              color: Theme.of(context).colorScheme.secondaryContainer,
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.md),
                child: Row(
                  children: <Widget>[
                    Icon(
                      Icons.chat_outlined,
                      color: Theme.of(context).colorScheme.onSecondaryContainer,
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    Expanded(
                      child: Text(
                        'Votre commande est envoyée au gérant via WhatsApp. '
                        'Aucun paiement n’est effectué dans l’application.',
                        style: textTheme.bodySmall?.copyWith(
                          color: Theme.of(context)
                              .colorScheme
                              .onSecondaryContainer,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // Partage d'addition (disponible ici, le bas étant le récapitulatif).
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                onPressed: () =>
                    Navigator.of(context)
                        .pushNamed(AppRoutes.splitBill(restaurant.id)),
                icon: const Icon(Icons.receipt_long_outlined),
                label: const Text('Partager l’addition'),
              ),
            ),
            const SizedBox(height: AppSpacing.md),

            // ---------------------------------------------------------------
            // Instructions Mobile Money (purement informatives)
            // ---------------------------------------------------------------
            Text(
              'Paiement mobile',
              style: textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: AppSpacing.xs),
            for (final MobileMoneyOperator operator
                in KoudougouReference.mobileMoneyOperators)
              _PaymentOperatorTile(operator: operator),

            // Avertissement de sécurité : jamais de code PIN.
            const SizedBox(height: AppSpacing.xs),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Icon(Icons.lock_outline, size: 16, color: palette.warning),
                const SizedBox(width: AppSpacing.xs),
                Expanded(
                  child: Text(
                    KoudougouReference.paymentSafetyNotice,
                    style: textTheme.bodySmall?.copyWith(
                      color: palette.mutedText,
                    ),
                  ),
                ),
              ],
            ),

            // Marge basse pour ne pas coller au récapitulatif.
            const SizedBox(height: AppSpacing.lg),
          ],
        );
      },
    );
  }
}

/// Tuile d'information sur un opérateur Mobile Money.
final class _PaymentOperatorTile extends StatelessWidget {
  /// Construit la tuile.
  const _PaymentOperatorTile({required this.operator});

  /// Opérateur affiché.
  final MobileMoneyOperator operator;

  /// Construit la tuile.
  @override
  Widget build(BuildContext context) {
    // Typographie et palette locales.
    final TextTheme textTheme = Theme.of(context).textTheme;
    final AppPalette palette = AppPalette.of(context);

    return Card(
      margin: const EdgeInsets.only(bottom: AppSpacing.xs),
      child: ListTile(
        leading: const Icon(Icons.smartphone_outlined),
        title: Text('${operator.name} · ${operator.ussdCode}'),
        subtitle: Text(operator.instructions),
        subtitleTextStyle: textTheme.bodySmall?.copyWith(
          color: palette.mutedText,
        ),
      ),
    );
  }
}

/// Récapitulatif fixe en bas d'écran : détail, total et deux actions.
final class _OrderBottomBar extends StatelessWidget {
  /// Construit la barre.
  const _OrderBottomBar({
    required this.restaurant,
    required this.summary,
    required this.quote,
    required this.urlGuard,
    required this.now,
    required this.onModify,
  });

  /// Restaurant ciblé.
  final Restaurant restaurant;

  /// Récapitulatif courant du panier.
  final CartSummary summary;

  /// Devis de livraison retenu, ou `null` si la livraison n'est pas demandée.
  final DeliveryQuote? quote;

  /// Garde-fou des liens externes.
  final UrlGuard urlGuard;

  /// Instant de référence (horodatage du message).
  final DateTime now;

  /// Retour à la composition du panier.
  final VoidCallback onModify;

  /// Construit la barre.
  @override
  Widget build(BuildContext context) {
    // Thème et palette locales.
    final ThemeData theme = Theme.of(context);
    final AppPalette palette = AppPalette.of(context);

    // Un panier vide désactive la confirmation.
    final bool canOrder = summary.isNotEmpty;
    final int deliveryFeeFcfa = quote?.feeFcfa ?? 0;
    final int totalFcfa = summary.totalFcfa + deliveryFeeFcfa;

    return SafeArea(
      child: Container(
        decoration: BoxDecoration(
          color: theme.colorScheme.surface,
          border: Border(
            top: BorderSide(color: theme.colorScheme.outlineVariant),
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.sm),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              // Titre du récapitulatif.
              Row(
                children: <Widget>[
                  Icon(
                    Icons.receipt_long_outlined,
                    size: 18,
                    color: theme.colorScheme.primary,
                  ),
                  const SizedBox(width: AppSpacing.xs),
                  Expanded(
                    child: Text(
                      'Récapitulatif de la commande',
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  Text(
                    '${summary.lines.length} plat(s)',
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: palette.mutedText,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.xs),

              // Lignes (on limite la hauteur du récap pour laisser le menu visible).
              for (final CartLine line in summary.lines.take(3))
                Padding(
                  padding: const EdgeInsets.only(bottom: AppSpacing.xxs),
                  child: Row(
                    children: <Widget>[
                      Expanded(
                        child: Text(
                          '${line.quantity} × ${line.item.name}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.bodySmall,
                        ),
                      ),
                      Text(
                        AppFormatters.fcfa(line.subtotalFcfa),
                        style: theme.textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
              if (summary.lines.length > 3)
                Text(
                  '… et ${summary.lines.length - 3} autre(s) plat(s)',
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: palette.mutedText,
                  ),
                ),

              const Divider(height: AppSpacing.sm),

              // Frais de livraison, uniquement si un devis est retenu.
              if (quote != null)
                Row(
                  children: <Widget>[
                    Expanded(
                      child: Text(
                        'Livraison · ${AppFormatters.distanceKm(quote!.distanceKm)}',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: palette.mutedText,
                        ),
                      ),
                    ),
                    Text(
                      AppFormatters.fcfa(deliveryFeeFcfa),
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: palette.mutedText,
                      ),
                    ),
                  ],
                ),

              // Total, plats + livraison.
              Row(
                children: <Widget>[
                  Text(
                    'Total',
                    style: theme.textTheme.titleSmall?.copyWith(
                      color: palette.mutedText,
                    ),
                  ),
                  const Spacer(),
                  Text(
                    AppFormatters.fcfa(totalFcfa),
                    style: theme.textTheme.titleLarge?.copyWith(
                      color: palette.price,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.xs),

              // Actions : modifier le panier ou confirmer sur WhatsApp.
              Row(
                children: <Widget>[
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: onModify,
                      icon: const Icon(Icons.edit_outlined),
                      label: const Text('Modifier'),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    flex: 2,
                    child: FilledButton.icon(
                      onPressed: canOrder
                          ? () => unawaited(
                              LinkFeedback.run(
                                context,
                                () => urlGuard.openWhatsApp(
                                  phone: restaurant.whatsappPhone,
                                  message: buildOrderMessage(
                                    restaurant: restaurant,
                                    summary: summary,
                                    quote: quote,
                                    now: now,
                                  ),
                                ),
                                successMessage: 'Ouverture de WhatsApp...',
                              ),
                            )
                          : null,
                      icon: const Icon(Icons.send_outlined),
                      label: const Text('Confirmer'),
                    ),
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
