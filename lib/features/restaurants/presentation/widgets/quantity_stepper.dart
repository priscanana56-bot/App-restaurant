// =============================================================================
// Sélecteur de quantité réutilisable (fiche restaurant et annuaire).
// -----------------------------------------------------------------------------
// Widget purement visuel : il affiche la quantité courante et délègue les deux
// gestes (+ / −) à l'appelant. Aucun état n'est conservé ici : le panier reste
// l'unique source de vérité.
// =============================================================================

// Widgets et Material.
import 'package:flutter/material.dart';

/// Sélecteur « −  n  + » d'une ligne de menu.
final class QuantityStepper extends StatelessWidget {
  /// Construit le sélecteur.
  const QuantityStepper({
    required this.quantity,
    required this.onIncrement,
    required this.onDecrement,
    super.key,
  });

  /// Quantité courante (0 si le plat n'est pas dans le panier).
  final int quantity;

  /// Ajout d'une unité.
  final VoidCallback onIncrement;

  /// Retrait d'une unité (désactivé à zéro).
  final VoidCallback onDecrement;

  /// Construit l'interface.
  @override
  Widget build(BuildContext context) {
    // Thème local pour les icônes.
    final ThemeData theme = Theme.of(context);

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        // Bouton de retrait, grisé tant que la quantité est nulle.
        IconButton(
          onPressed: quantity > 0 ? onDecrement : null,
          tooltip: 'Retirer',
          icon: const Icon(Icons.remove_circle_outline),
          color: theme.colorScheme.primary,
        ),

        // Quantité affichée, largeur fixe pour éviter tout tremblement.
        SizedBox(
          width: 28,
          child: Text(
            '$quantity',
            textAlign: TextAlign.center,
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
        ),

        // Bouton d'ajout.
        IconButton(
          onPressed: onIncrement,
          tooltip: 'Ajouter',
          icon: const Icon(Icons.add_circle_outline),
          color: theme.colorScheme.primary,
        ),
      ],
    );
  }
}
