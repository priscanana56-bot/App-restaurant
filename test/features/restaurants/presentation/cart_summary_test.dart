// =============================================================================
// Tests du récapitulatif de panier (calculs purs).
// -----------------------------------------------------------------------------
// Ces tests garantissent que les totaux et le partage par convive restent
// exacts, y compris avec des identifiants inconnus ou un groupe vide.
// =============================================================================

// Framework de test.
import 'package:flutter_test/flutter_test.dart';

// Entités et sections du menu.
import 'package:koudougou_gourmet/features/restaurants/domain/entities/menu_item.dart';
import 'package:koudougou_gourmet/features/restaurants/domain/entities/restaurant.dart';

// Utilitaire testé.
import 'package:koudougou_gourmet/features/restaurants/presentation/utils/cart_summary.dart';

// Fixtures et constructeurs.
import '../support/fixtures.dart';

/// Point d'entrée des tests.
void main() {
  group('CartSummary', () {
    test('construit les lignes, le total et le nombre d’articles', () {
      // Deux plats à des prix différents.
      final Restaurant restaurant = buildRestaurant(
        id: 'r1',
        menu: <MenuItem>[
          buildMenuItem(id: 'a', priceFcfa: 700),
          buildMenuItem(
            id: 'b',
            name: 'Poulet braisé',
            section: MenuSection.grills,
            priceFcfa: 3000,
          ),
        ],
      );

      final CartSummary summary = CartSummary.from(
        restaurant: restaurant,
        quantities: <String, int>{'a': 2, 'b': 1},
      );

      expect(summary.lines, hasLength(2));
      // Ordre du menu : plats avant grillades.
      expect(summary.lines.first.item.id, 'a');
      expect(summary.lines.first.subtotalFcfa, 1400);
      expect(summary.totalFcfa, 4400);
      expect(summary.itemCount, 3);
      expect(summary.isEmpty, isFalse);
    });

    test('ignore les identifiants inconnus et les quantités nulles', () {
      final Restaurant restaurant = buildRestaurant(
        id: 'r1',
        menu: <MenuItem>[buildMenuItem(id: 'a', priceFcfa: 700)],
      );

      final CartSummary summary = CartSummary.from(
        restaurant: restaurant,
        quantities: <String, int>{'a': 0, 'inconnu': 5},
      );

      expect(summary.isEmpty, isTrue);
      expect(summary.totalFcfa, 0);
      expect(summary.itemCount, 0);
    });

    test('perPersonFcfa arrondit toujours au supérieur', () {
      const CartSummary summary = CartSummary(
        lines: <CartLine>[],
        totalFcfa: 1000,
        itemCount: 0,
      );

      // 1000 / 3 = 333,33 -> 334 (jamais de sous-facturation).
      expect(summary.perPersonFcfa(3), 334);
      // Division exacte.
      expect(summary.perPersonFcfa(4), 250);
      // Un groupe nul est ramené à une personne (pas de division par zéro).
      expect(summary.perPersonFcfa(0), 1000);
    });
  });
}
