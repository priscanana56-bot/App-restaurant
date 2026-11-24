// =============================================================================
// Tests du catalogue de commande de l'annuaire.
// -----------------------------------------------------------------------------
// On vérifie que les coordonnées ne sont jamais inventées, que le menu est
// clairement un exemple et que la fiche construite reste commandable via les
// calculs existants (CartSummary + buildOrderMessage).
// =============================================================================

// Framework de test.
import 'package:flutter_test/flutter_test.dart';

// Route typée.
import 'package:koudougou_gourmet/core/constants/app_routes.dart';

// Point GPS.
import 'package:koudougou_gourmet/core/location/geo_point.dart';

// Entités.
import 'package:koudougou_gourmet/features/restaurants/domain/entities/koudougou_listing.dart';
import 'package:koudougou_gourmet/features/restaurants/domain/entities/menu_item.dart';
import 'package:koudougou_gourmet/features/restaurants/domain/entities/restaurant.dart';
import 'package:koudougou_gourmet/features/restaurants/domain/entities/restaurant_category.dart';

// Service testé.
import 'package:koudougou_gourmet/features/restaurants/domain/services/directory_order_catalog.dart';

// Calculs partagés.
import 'package:koudougou_gourmet/features/restaurants/presentation/utils/cart_summary.dart';
import 'package:koudougou_gourmet/features/restaurants/presentation/utils/order_message.dart';

// Horloge de test.
import '../support/fixtures.dart';

/// Fiche Vivalto telle que publiée dans l'annuaire sourcé.
KoudougouListing _vivalto() => const KoudougouListing(
  id: 'vivalto-cafe',
  name: 'Vivalto Café',
  category: 'Café / restaurant',
  area: 'Koudougou (12,25174 ; -2,34815)',
  phone: '+22657324005',
  hours: 'Tous les jours 06:00–00:00',
  priceInfo: 'Non renseigné',
  specialties: 'Non renseigné',
  sourceName: 'Google Maps / Evendo / Go Africa Online',
  sourceUrl: 'https://www.google.com/maps/place?q=place_id:ChIJMRJE3tIbLg4RtWO0GuNBQRU',
  verification: DirectoryVerification.onlineListing,
  note: 'Avis extraits de 2019 à 2021.',
);

/// Point d'entrée des tests.
void main() {
  group('DirectoryOrderCatalog.coordinatesOf', () {
    test('lit les coordonnées déjà publiées dans area (Vivalto)', () {
      final GeoPoint? point = DirectoryOrderCatalog.coordinatesOf(_vivalto());

      expect(point, isNotNull);
      expect(point!.latitude, 12.25174);
      expect(point.longitude, -2.34815);
    });

    test('ne devine aucune coordonnée quand la source n’en donne pas', () {
      final KoudougouListing withoutPoint = _vivalto().copyWith(
        area: 'Koudougou',
      );

      expect(DirectoryOrderCatalog.coordinatesOf(withoutPoint), isNull);
    });

    test('préfère le champ position structuré (Snack Time)', () {
      const GeoPoint published = GeoPoint(
        latitude: 12.2469375,
        longitude: -2.3885625,
      );
      final KoudougouListing snack = _vivalto().copyWith(
        id: 'snack-time-bcb',
        area: 'Face à la BCB (12,999 ; -2,999)',
        position: published,
      );

      expect(DirectoryOrderCatalog.coordinatesOf(snack), published);
    });
  });

  group('DirectoryOrderCatalog.exampleMenu', () {
    test('est un menu d’exemple préfixé par identifiant de fiche', () {
      final List<MenuItem> menu = DirectoryOrderCatalog.exampleMenu(_vivalto());

      expect(menu, isNotEmpty);
      expect(
        menu.every((MenuItem item) => item.id.startsWith('demo/vivalto-cafe/')),
        isTrue,
      );
      expect(menu.map((MenuItem item) => item.name), contains('Café expresso'));
      expect(menu.every((MenuItem item) => item.isOrderable), isTrue);
      expect(
        DirectoryOrderCatalog.demonstrationNotice.toLowerCase(),
        contains('démonstration'),
      );
    });

    test('adapte la famille de plats à la catégorie sourcée', () {
      final KoudougouListing snack = _vivalto().copyWith(
        category: 'Fast-food / snack',
      );

      expect(
        DirectoryOrderCatalog.categoryOf(snack),
        RestaurantCategory.fastFood,
      );
      expect(
        DirectoryOrderCatalog.exampleMenu(snack)
            .map((MenuItem item) => item.name),
        contains('Sandwich viande'),
      );
    });
  });

  group('DirectoryOrderCatalog.toRestaurant', () {
    test('reste non vérifié et garde le numéro sourcé pour WhatsApp', () {
      final Restaurant restaurant = DirectoryOrderCatalog.toRestaurant(
        _vivalto(),
      );

      expect(restaurant.id, 'vivalto-cafe');
      expect(restaurant.name, 'Vivalto Café');
      expect(restaurant.whatsappPhone, '+22657324005');
      expect(restaurant.isVerified, isFalse);
      expect(restaurant.menu, isNotEmpty);
      expect(restaurant.deliveryAvailable, isFalse);
    });

    test('alimente le récap et le message WhatsApp existants', () {
      final Restaurant restaurant = DirectoryOrderCatalog.toRestaurant(
        _vivalto(),
      );
      final MenuItem first = restaurant.orderableMenu.first;
      final CartSummary summary = CartSummary.from(
        restaurant: restaurant,
        quantities: <String, int>{first.id: 2},
      );

      final String message = buildOrderMessage(
        restaurant: restaurant,
        summary: summary,
        now: testNow,
      );

      expect(message, contains('Bonjour Vivalto Café'));
      expect(message, contains('2 × ${first.name}'));
      expect(message, contains('Total :'));
    });
  });

  group('AppRoutes.directoryListing', () {
    test('construit un chemin paramétré encodé', () {
      expect(
        AppRoutes.directoryListing('vivalto-cafe'),
        '/annuaire/vivalto-cafe',
      );
      expect(
        AppRoutes.directoryListing('café du marché'),
        '/annuaire/caf%C3%A9%20du%20march%C3%A9',
      );
    });
  });
}
