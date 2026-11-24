// =============================================================================
// Fiche commandable d'un établissement de l'annuaire sourcé.
// -----------------------------------------------------------------------------
// Un appui sur une carte de l'annuaire ouvre cette page : informations sourcées
// (téléphone, horaires, quartier, source), itinéraire QUAND des coordonnées ont
// été publiées, et menu d'exemple clairement étiqueté que l'utilisateur peut
// composer. Le récapitulatif fixe en bas envoie la commande via WhatsApp.
//
// Aucun plat ni prix n'est présenté comme la carte réelle de l'établissement :
// le bandeau « démonstration » est toujours visible au-dessus du menu.
// =============================================================================

// Ouvertures de liens déclenchées par un geste, sans blocage de l'UI.
import 'dart:async';

// Widgets et Material.
import 'package:flutter/material.dart';

// BLoC et Cubit.
import 'package:flutter_bloc/flutter_bloc.dart';

// Point GPS publié (ou absence de point).
import '../../../../core/location/geo_point.dart';

// Garde-fou des liens externes.
import '../../../../core/security/url_guard.dart';

// Palette et espacements.
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';

// Formatage des montants.
import '../../../../core/utils/formatters.dart';

// Entités du domaine.
import '../../domain/entities/delivery_quote.dart';
import '../../domain/entities/koudougou_listing.dart';
import '../../domain/entities/menu_item.dart';
import '../../domain/entities/restaurant.dart';

// Catalogue d'exemple typé (fabrique du `Restaurant` commandable).
import '../../domain/services/directory_order_catalog.dart';

// Panier et devis.
import '../bloc/cart_cubit.dart';
import '../bloc/delivery_cubit.dart';

// Calculs et message partagés avec l'écran de commande du catalogue.
import '../utils/cart_summary.dart';
import '../utils/order_message.dart';

// Composants réutilisables.
import '../widgets/delivery_panel.dart';
import '../widgets/link_feedback.dart';
import '../widgets/order_menu_tile.dart';

/// Fiche détaillée et commandable d'une entrée de l'annuaire.
final class DirectoryListingPage extends StatefulWidget {
  /// Construit la page pour une fiche sourcée.
  const DirectoryListingPage({
    required this.listing,
    required this.urlGuard,
    required this.now,
    super.key,
  });

  /// Fiche sourcée affichée (jamais reconstruite à partir d'un identifiant).
  final KoudougouListing listing;

  /// Garde-fou des liens externes (téléphone, carte, source, WhatsApp).
  final UrlGuard urlGuard;

  /// Instant de référence pour l'horodatage du message WhatsApp.
  final DateTime now;

  @override
  State<DirectoryListingPage> createState() => _DirectoryListingPageState();
}

/// État pilotant le retour au menu depuis le récapitulatif fixe.
class _DirectoryListingPageState extends State<DirectoryListingPage> {
  /// Contrôleur de la liste, utilisé en repli pour « Modifier ».
  final ScrollController _scrollController = ScrollController();

  /// Clé du bandeau du menu : cible privilégiée de « Modifier ».
  final GlobalKey _menuKey = GlobalKey();

  /// Libère le contrôleur avec la page.
  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  /// Ramène l'utilisateur au menu pour Modifier sa commande.
  void _backToMenu() {
    // Cible sûre : le bandeau est présent dès qu'il y a un menu (toujours ici).
    final BuildContext? target = _menuKey.currentContext;
    if (target != null) {
      Scrollable.ensureVisible(
        target,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
      return;
    }
    if (_scrollController.hasClients) {
      _scrollController.animateTo(
        0,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    }
  }

  /// Construit la page.
  @override
  Widget build(BuildContext context) {
    // Fiche commandable dérivée de la fiche sourcée (menu d'exemple inclus).
    final Restaurant restaurant = DirectoryOrderCatalog.toRestaurant(
      widget.listing,
    );

    // Coordonnées réellement publiées : `null` interdit tout bouton d'itinéraire.
    final GeoPoint? point = DirectoryOrderCatalog.coordinatesOf(widget.listing);

    // Panier partagé fourni par le routeur.
    final CartCubit cart = context.read<CartCubit>();

    // La livraison n'est proposée que si la source la déclare et si un point
    // exploitable existe : aucun devis n'est calculé sur une position inventée.
    final bool canQuoteDelivery = restaurant.deliveryAvailable && point != null;

    return Scaffold(
      appBar: AppBar(title: Text(widget.listing.name)),

      // Contenu sourcé + menu d'exemple.
      body: BlocBuilder<CartCubit, CartState>(
        builder: (BuildContext context, CartState cartState) {
          return ListView(
            controller: _scrollController,
            padding: const EdgeInsets.all(AppSpacing.pagePadding),
            children: <Widget>[
              // Rappel que la fiche reste une citation de source.
              const _DirectoryVerificationNotice(),
              const SizedBox(height: AppSpacing.md),

              // Informations sourcées et actions sûres.
              _SourceCard(
                listing: widget.listing,
                position: point,
                urlGuard: widget.urlGuard,
              ),
              const SizedBox(height: AppSpacing.md),

              // Menu d'example : l'avertissement est TOUJOURS affiché.
              _DemoMenuNotice(key: _menuKey),
              const SizedBox(height: AppSpacing.sm),

              // Sections du menu, avec quantités.
              for (final MapEntry<MenuSection, List<MenuItem>> entry
                  in restaurant.menuBySection.entries) ...<Widget>[
                Text(
                  entry.key.label,
                  style: Theme.of(context).textTheme.titleSmall
                      ?.copyWith(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: AppSpacing.xs),
                for (final MenuItem item in entry.value)
                  OrderMenuTile(
                    item: item,
                    quantity: cartState.quantityOf(item.id),
                    badge: DirectoryOrderCatalog.demonstrationBadge,
                    onIncrement: () => cart.increment(item.id),
                    onDecrement: () => cart.decrement(item.id),
                  ),
                const SizedBox(height: AppSpacing.sm),
              ],

              // Devis de livraison simulé, uniquement sur une fiche sourcée
              // qui déclare le service et publie des coordonnées.
              if (canQuoteDelivery) ...<Widget>[
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  value: cartState.deliveryRequested,
                  onChanged: cart.setDeliveryRequested,
                  title: const Text('Livraison à domicile'),
                  subtitle: const Text(
                    'Simulation : 500 FCFA + 200 FCFA/km, jusqu’à 5 km.',
                  ),
                ),
                if (cartState.deliveryRequested)
                  DeliveryPanel(
                    targetId: restaurant.id,
                    targetLabel: restaurant.name,
                    destination: point,
                    deliveryAvailable: restaurant.deliveryAvailable,
                    urlGuard: widget.urlGuard,
                  ),
                const SizedBox(height: AppSpacing.md),
              ],

              // Rappel : aucun paiement n'est traité dans l'application.
              Card(
                color: Theme.of(context).colorScheme.secondaryContainer,
                child: Padding(
                  padding: const EdgeInsets.all(AppSpacing.md),
                  child: Row(
                    children: <Widget>[
                      Icon(
                        Icons.chat_outlined,
                        color: Theme.of(context)
                            .colorScheme
                            .onSecondaryContainer,
                      ),
                      const SizedBox(width: AppSpacing.sm),
                      Expanded(
                        child: Text(
                          'La commande est pré-remplie dans WhatsApp. '
                          'Aucun paiement n’est effectué dans l’application.',
                          style: Theme.of(context).textTheme.bodySmall
                              ?.copyWith(
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

              // Marge basse pour ne pas coller au récapitulatif.
              const SizedBox(height: AppSpacing.lg),
            ],
          );
        },
      ),

      // Récapitulatif fixe : Modifier (menu) / Confirmer (WhatsApp).
      bottomNavigationBar: BlocBuilder<CartCubit, CartState>(
        builder: (BuildContext context, CartState cartState) {
          // Récap calculé à partir du panier et des prix de l'entité.
          final CartSummary summary = CartSummary.from(
            restaurant: restaurant,
            quantities: cartState.quantities,
          );

          // Sans devis disponible, aucun frais n'est ajouté au total.
          Widget bar = _DirectoryOrderBar(
            restaurant: restaurant,
            summary: summary,
            quote: null,
            urlGuard: widget.urlGuard,
            now: widget.now,
            onModify: _backToMenu,
          );

          // Le devis n'est lu que si la fiche peut réellement en avoir un.
          if (canQuoteDelivery) {
            bar = BlocBuilder<DeliveryCubit, DeliveryState>(
              builder: (BuildContext context, DeliveryState delivery) {
                final DeliveryQuote? quote =
                    cartState.deliveryRequested &&
                        delivery.hasQuote &&
                        delivery.quote != null &&
                        delivery.quote!.isAvailable
                    ? delivery.quote
                    : null;

                return _DirectoryOrderBar(
                  restaurant: restaurant,
                  summary: summary,
                  quote: quote,
                  urlGuard: widget.urlGuard,
                  now: widget.now,
                  onModify: _backToMenu,
                );
              },
            );
          }
          return bar;
        },
      ),
    );
  }
}

/// Avertissement permanent : données d'annuaire non certifiées.
final class _DirectoryVerificationNotice extends StatelessWidget {
  /// Construit l'avertissement.
  const _DirectoryVerificationNotice();

  /// Construit l'interface.
  @override
  Widget build(BuildContext context) {
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
              'Établissement cité par des sources publiques. Son ouverture '
              'actuelle n’est pas certifiée : confirmez par téléphone avant '
              'de commander ou de vous déplacer.',
              style: theme.textTheme.bodyMedium,
            ),
          ),
        ],
      ),
    );
  }
}

/// Informations sourcées et actions sûres (aucune donnée inventée).
final class _SourceCard extends StatelessWidget {
  /// Construit la carte.
  const _SourceCard({
    required this.listing,
    required this.position,
    required this.urlGuard,
  });

  /// Fiche sourcée.
  final KoudougouListing listing;

  /// Coordonnées publiées, ou `null`.
  final GeoPoint? position;

  /// Garde-fou des liens externes.
  final UrlGuard urlGuard;

  /// Construit l'interface.
  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final AppPalette palette = AppPalette.of(context);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              listing.category,
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            _InfoLine(icon: Icons.place_outlined, text: listing.area),
            if (listing.hours.isNotEmpty)
              _InfoLine(icon: Icons.schedule_outlined, text: listing.hours),
            if (listing.priceInfo.isNotEmpty)
              _InfoLine(icon: Icons.payments_outlined, text: listing.priceInfo),
            if (listing.specialties.isNotEmpty)
              _InfoLine(
                icon: Icons.restaurant_outlined,
                text: listing.specialties,
              ),
            if (listing.note.isNotEmpty)
              _InfoLine(icon: Icons.info_outline, text: listing.note),

            const SizedBox(height: AppSpacing.sm),

            // Difficulté de la source, toujours indiquée.
            Container(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.sm,
                vertical: AppSpacing.xxs,
              ),
              decoration: BoxDecoration(
                color: theme.colorScheme.primaryContainer,
                borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
              ),
              child: Text(
                listing.verification.label,
                style: theme.textTheme.labelMedium?.copyWith(
                  color: theme.colorScheme.onPrimaryContainer,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              'Source : ${listing.sourceName}',
              style: theme.textTheme.bodySmall?.copyWith(
                color: palette.mutedText,
              ),
            ),

            const SizedBox(height: AppSpacing.sm),

            // Actions : téléphone, itinéraire (si publié) et source HTTPS.
            Wrap(
              spacing: AppSpacing.xs,
              children: <Widget>[
                if (listing.hasPhone)
                  TextButton.icon(
                    onPressed: () => unawaited(
                      LinkFeedback.run(
                        context,
                        () => urlGuard.openPhoneCall(listing.phone),
                      ),
                    ),
                    icon: const Icon(Icons.call_outlined),
                    label: const Text('Appeler'),
                  ),
                if (position != null)
                  TextButton.icon(
                    onPressed: () => unawaited(
                      LinkFeedback.run(
                        context,
                        () => urlGuard.openDirections(
                          latitude: position!.latitude,
                          longitude: position!.longitude,
                        ),
                      ),
                    ),
                    icon: const Icon(Icons.directions_outlined),
                    label: const Text('Itinéraire'),
                  ),
                if (listing.hasSource)
                  TextButton.icon(
                    onPressed: () => unawaited(
                      LinkFeedback.run(
                        context,
                        () => urlGuard.openRaw(listing.sourceUrl),
                      ),
                    ),
                    icon: const Icon(Icons.open_in_new),
                    label: const Text('Voir la source'),
                  ),
              ],
            ),

            // Aucune adresse n'est devinée pour les fiches sans coordonnées.
            if (position == null)
              Text(
                'Itinéraire indisponible : la source ne publie pas de '
                'coordonnées pour cette fiche.',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: palette.mutedText,
                ),
              ),
          ],
        ),
      ),
    );
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

/// Bandeau obligatoire au-dessus du menu d'exemple.
final class _DemoMenuNotice extends StatelessWidget {
  /// Construit le bandeau.
  const _DemoMenuNotice({super.key});

  /// Construit l'interface.
  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final AppPalette palette = AppPalette.of(context);

    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: palette.warning.withValues(alpha: 0.12),
        borderRadius: AppSpacing.cardRadius,
        border: Border.all(color: palette.warning),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Icon(Icons.science_outlined, color: palette.warning),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  'Menu de démonstration',
                  style: theme.textTheme.titleSmall?.copyWith(
                    color: palette.warning,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: AppSpacing.xxs),
                Text(
                  DirectoryOrderCatalog.demonstrationNotice,
                  style: theme.textTheme.bodySmall,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Récapitulatif fixe : détail, total et deux actions.
final class _DirectoryOrderBar extends StatelessWidget {
  /// Construit la barre.
  const _DirectoryOrderBar({
    required this.restaurant,
    required this.summary,
    required this.quote,
    required this.urlGuard,
    required this.now,
    required this.onModify,
  });

  /// Fiche commandable dérivée de l'annuaire.
  final Restaurant restaurant;

  /// Récapitulatif courant du panier.
  final CartSummary summary;

  /// Devis retenu, ou `null` si la livraison n'est pas demandée.
  final DeliveryQuote? quote;

  /// Garde-fou des liens externes.
  final UrlGuard urlGuard;

  /// Instant de référence de l'horodatage.
  final DateTime now;

  /// Retour au menu pour modifier les quantités.
  final VoidCallback onModify;

  /// Construit l'interface.
  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final AppPalette palette = AppPalette.of(context);

    // Une commande n'est confirmable que si des plats sont choisis et si la
    // source publie un numéro exploitable pour WhatsApp.
    final bool hasPhone = restaurant.whatsappPhone.isNotEmpty;
    final bool canOrder = summary.isNotEmpty && hasPhone;
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

              // Lignes visibles ( hauteur limitée pour garder le menu en vue ).
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
              if (summary.isEmpty)
                Text(
                  'Choisissez un plat dans le menu d’exemple.',
                  style: theme.textTheme.bodySmall?.copyWith(
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

              // Numéro absent : explication plutôt qu'un bouton muet.
              if (!hasPhone)
                Padding(
                  padding: const EdgeInsets.only(top: AppSpacing.xxs),
                  child: Text(
                    'Numéro non publié par la source : utilisez « Voir la source ».',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: palette.warning,
                    ),
                  ),
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
