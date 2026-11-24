// =============================================================================
// Récapitulatif du panier (calculs purs, sans état ni I/O).
// -----------------------------------------------------------------------------
// Le panier (`CartCubit`) ne stocke QUE des quantités indexées par identifiant
// de plat. Les prix restent dans l'entité `Restaurant`, seule source de vérité.
// Ce fichier réunit la logique de calcul (lignes, sous-totaux, total) afin que
// les écrans « Commande » et « Partage d'addition » ne la dupliquent pas.
// =============================================================================

// Entités consommées.
import '../../domain/entities/menu_item.dart';
import '../../domain/entities/restaurant.dart';

/// Ligne de commande : un plat et sa quantité.
final class CartLine {
  /// Construit une ligne déjà validée (quantité strictement positive).
  const CartLine({required this.item, required this.quantity});

  /// Plat commandé.
  final MenuItem item;

  /// Quantité choisie (toujours > 0 dans un récapitulatif).
  final int quantity;

  /// Sous-total de la ligne, en FCFA.
  int get subtotalFcfa => item.priceFcfa * quantity;
}

/// Récapitulatif complet du panier pour un restaurant donné.
final class CartSummary {
  /// Construit un récapitulatif immuable.
  const CartSummary({
    required this.lines,
    required this.totalFcfa,
    required this.itemCount,
  });

  /// Lignes non vides, dans l'ordre du menu.
  final List<CartLine> lines;

  /// Montant total, en FCFA.
  final int totalFcfa;

  /// Nombre total d'articles (somme des quantités).
  final int itemCount;

  /// `true` si aucune ligne n'est sélectionnée.
  bool get isEmpty => lines.isEmpty;

  /// `true` si au moins un article est sélectionné.
  bool get isNotEmpty => lines.isNotEmpty;

  /// Montant par convive, arrondi au FCFA SUPÉRIEUR pour ne jamais sous-facturer.
  int perPersonFcfa(int partySize) {
    // Un groupe d'au moins une personne évite toute division par zéro.
    final int safeParty = partySize < 1 ? 1 : partySize;

    // Arrondi supérieur : la somme des parts couvre toujours le total.
    return (totalFcfa + safeParty - 1) ~/ safeParty;
  }

  /// Construit un récapitulatif à partir des quantités du `CartCubit`.
  /// Les identifiants inconnus du restaurant sont ignorés silencieusement.
  static CartSummary from({
    required Restaurant restaurant,
    required Map<String, int> quantities,
  }) {
    // Accumulateurs locaux, entièrement typés.
    final List<CartLine> lines = <CartLine>[];
    var total = 0;
    var count = 0;

    // Parcours du menu commandable : l'ordre d'affichage reste stable.
    for (final MenuItem item in restaurant.orderableMenu) {
      // Quantité éventuelle pour ce plat.
      final int quantity = quantities[item.id] ?? 0;

      // Les quantités nulles ou négatives ne créent pas de ligne.
      if (quantity <= 0) {
        continue;
      }

      // Enregistrement de la ligne et mise à jour des totaux.
      lines.add(CartLine(item: item, quantity: quantity));
      total += item.priceFcfa * quantity;
      count += quantity;
    }

    // Collections immuables pour éviter toute mutation accidentelle par l'UI.
    return CartSummary(
      lines: List<CartLine>.unmodifiable(lines),
      totalFcfa: total,
      itemCount: count,
    );
  }
}
