// =============================================================================
// Tests du message WhatsApp pré-rempli (fonction pure).
// -----------------------------------------------------------------------------
// Le récapitulatif est la seule source des montants des plats ; le devis de
// livraison est ajouté séparément. On vérifie que le message reste lisible,
// exact et qu'il ne contient aucune coordonnée GPS personnelle.
// =============================================================================

// Framework de test.
import 'package:flutter_test/flutter_test.dart';

// Entités du domaine.
import 'package:koudougou_gourmet/features/restaurants/domain/entities/delivery_quote.dart';
import 'package:koudougou_gourmet/features/restaurants/domain/entities/menu_item.dart';
import 'package:koudougou_gourmet/features/restaurants/domain/entities/restaurant.dart';

// Récapitulatif et message testés.
import 'package:koudougou_gourmet/features/restaurants/presentation/utils/cart_summary.dart';
import 'package:koudougou_gourmet/features/restaurants/presentation/utils/order_message.dart';

// Fixtures.
import '../support/fixtures.dart';

/// Point d'entrée des tests.
void main() {
  group('buildOrderMessage', () {
    // Une fiche avec un plat à 700 FCFA et un numéro WhatsApp valide.
    final Restaurant restaurant = buildRestaurant(
      id: 'snack-time-bcb',
      name: 'Snack Time',
      menu: <MenuItem>[
        buildMenuItem(id: 'snack-1', name: 'Sandwich', priceFcfa: 700),
      ],
    );

    // Deux sandwichs : 1 400 FCFA.
    final CartSummary summary = CartSummary.from(
      restaurant: restaurant,
      quantities: const <String, int>{'snack-1': 2},
    );

    test('détaille les lignes et le total sans livraison', () {
      final String message = buildOrderMessage(
        restaurant: restaurant,
        summary: summary,
        now: testNow,
      );

      expect(message, contains('Bonjour Snack Time'));
      expect(message, contains('2 × Sandwich'));
      expect(message, contains('1 400 FCFA'));
      expect(message, contains('Total : 1 400 FCFA'));
      expect(message, contains('16/11/2026 à 19:00'));
      expect(message, isNot(contains('Livraison demandée')));
    });

    test('ajoute le devis au sous-total quand la livraison est retenue', () {
      const DeliveryQuote quote = DeliveryQuote(distanceKm: 1.2, feeFcfa: 800);

      final String message = buildOrderMessage(
        restaurant: restaurant,
        summary: summary,
        now: testNow,
        quote: quote,
      );

      expect(message, contains('Livraison demandée'));
      expect(message, contains('Frais de livraison : 800 FCFA'));
      expect(message, contains('Sous-total : 1 400 FCFA'));
      expect(message, contains('Total : 2 200 FCFA'));
    });

    test('ignore un devis refusé (hors zone)', () {
      const DeliveryQuote quote = DeliveryQuote.unavailable(
        distanceKm: 8,
        reason: 'Hors zone',
      );

      final String message = buildOrderMessage(
        restaurant: restaurant,
        summary: summary,
        now: testNow,
        quote: quote,
      );

      expect(message, contains('Total : 1 400 FCFA'));
      expect(message, isNot(contains('Frais de livraison')));
    });

    test('ne divulgue ni latitude ni longitude', () {
      final String message = buildOrderMessage(
        restaurant: restaurant,
        summary: summary,
        now: testNow,
        quote: const DeliveryQuote(distanceKm: 1.2, feeFcfa: 800),
      );

      expect(message, isNot(contains('12.24')));
      expect(message, isNot(contains('-2.38')));
    });
  });
}
