// =============================================================================
// Ligne de menu avec sélecteur de quantité.
// -----------------------------------------------------------------------------
// Utilisée par l'écran de commande du catalogue et par la fiche commandable de
// l'annuaire. Le prix affiché vient TOUJOURS de l'entité `MenuItem` : aucun
// montant n'est recalculé ici. Un badge optionnel permet de signaler un plat
// d'exemple sans modifier la logique de commande.
// =============================================================================

// Widgets et Material.
import 'package:flutter/material.dart';

// Palette et espacements.
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';

// Formatage des montants.
import '../../../../core/utils/formatters.dart';

// Entité affichée.
import '../../domain/entities/menu_item.dart';

// Sélecteur partagé.
import 'quantity_stepper.dart';

/// Tuile d'un plat commandable.
final class OrderMenuTile extends StatelessWidget {
  /// Construit la tuile.
  const OrderMenuTile({
    required this.item,
    required this.quantity,
    required this.onIncrement,
    required this.onDecrement,
    this.badge,
    super.key,
  });

  /// Plat affiché.
  final MenuItem item;

  /// Quantité actuellement sélectionnée (0 si absent du panier).
  final int quantity;

  /// Ajout d'une unité.
  final VoidCallback onIncrement;

  /// Retrait d'une unité.
  final VoidCallback onDecrement;

  /// Badge facultatif (ex. « Démo » pour un menu d'exemple).
  final String? badge;

  /// Construit l'interface.
  @override
  Widget build(BuildContext context) {
    // Typographie et palette locales.
    final TextTheme textTheme = Theme.of(context).textTheme;
    final AppPalette palette = AppPalette.of(context);

    return Card(
      margin: const EdgeInsets.only(bottom: AppSpacing.xs),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.sm),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            // Nom, description et prix unitaire.
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    item.name,
                    style: textTheme.bodyLarge?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  if (item.description.isNotEmpty)
                    Text(
                      item.description,
                      style: textTheme.bodySmall?.copyWith(
                        color: palette.mutedText,
                      ),
                    ),
                  // Badge d'exemple, uniquement quand l'appelant le demande.
                  if (badge != null && badge!.isNotEmpty) ...<Widget>[
                    const SizedBox(height: AppSpacing.xxs),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.xs,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: palette.warning.withValues(alpha: 0.16),
                        borderRadius: BorderRadius.circular(
                          AppSpacing.radiusSm,
                        ),
                      ),
                      child: Text(
                        badge!,
                        style: textTheme.labelSmall?.copyWith(
                          color: palette.warning,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                  const SizedBox(height: AppSpacing.xxs),
                  Text(
                    AppFormatters.fcfa(item.priceFcfa),
                    style: textTheme.labelLarge?.copyWith(
                      color: palette.price,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: AppSpacing.sm),

            // Sélecteur de quantité.
            QuantityStepper(
              quantity: quantity,
              onIncrement: onIncrement,
              onDecrement: onDecrement,
            ),
          ],
        ),
      ),
    );
  }
}
