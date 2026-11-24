// =============================================================================
// Tests du parcours « fiche d'annuaire → menu → commande WhatsApp ».
// -----------------------------------------------------------------------------
// Aucun plugin natif n'est lancé : une passerelle factice enregistre l'URI
// réellement transmise. On vérifie que la fiche sourcée affiche bien le menu
// d'exemple, l'itinéraire quand il est publié, et que « Confirmer » envoie le
// récapitulatif au numéro sourcé.
// =============================================================================

// Widgets et Material.
import 'package:flutter/material.dart';

// Framework de test.
import 'package:flutter_test/flutter_test.dart';

// BLoC.
import 'package:flutter_bloc/flutter_bloc.dart';

// Garde-fou et passerelle factice.
import 'package:koudougou_gourmet/core/security/url_guard.dart';
import 'package:koudougou_gourmet/core/security/url_launcher_gateway.dart';

// Entité et page testées.
import 'package:koudougou_gourmet/features/restaurants/domain/entities/koudougou_listing.dart';
import 'package:koudougou_gourmet/features/restaurants/presentation/pages/directory_listing_page.dart';

// Composant de menu.
import 'package:koudougou_gourmet/features/restaurants/presentation/widgets/order_menu_tile.dart';

// Panier et horloge de test.
import 'package:koudougou_gourmet/features/restaurants/presentation/bloc/cart_cubit.dart';

import '../support/fixtures.dart';

/// Passerelle qui enregistre les URI sans rien ouvrir.
final class _RecordingGateway implements UrlLauncherGateway {
  /// URI effectivement lancées.
  final List<Uri> launched = <Uri>[];

  @override
  Future<bool> canLaunch(Uri uri) async => true;

  @override
  Future<bool> launch(Uri uri) async {
    launched.add(uri);
    return true;
  }
}

/// Fiche Vivalto sourcée, avec coordonnées publiées dans `area`.
KoudougouListing _vivalto({String phone = '+22657324005'}) =>
    const KoudougouListing(
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
    ).copyWith(phone: phone);

/// Monte la page avec un panier neuf et la passerelle fournie.
Future<void> _pumpPage(
  WidgetTester tester, {
  required KoudougouListing listing,
  required CartCubit cart,
  required UrlGuard guard,
}) async {
  // La page est longue : sans une surface haute, le `ListView` ne monte que
  // les premières lignes et les assertions sur le menu porteraient sur zéro
  // widget. On restaure la taille standard à la fin du test.
  await tester.binding.setSurfaceSize(const Size(1200, 4000));
  addTearDown(() => tester.binding.setSurfaceSize(null));

  await tester.pumpWidget(
    MaterialApp(
      home: BlocProvider<CartCubit>.value(
        value: cart,
        child: DirectoryListingPage(
          listing: listing,
          urlGuard: guard,
          now: testNow,
        ),
      ),
    ),
  );
}

/// Point d'entrée des tests.
void main() {
  testWidgets(
    'affiche le menu d’exemple, l’itinéraire et envoie la commande sur WhatsApp',
    (WidgetTester tester) async {
      final CartCubit cart = CartCubit();
      addTearDown(cart.close);
      final _RecordingGateway gateway = _RecordingGateway();
      final UrlGuard guard = UrlGuard(gateway: gateway);

      await _pumpPage(tester, listing: _vivalto(), cart: cart, guard: guard);

      // Le menu est bien signalé comme démonstration.
      expect(find.text('Menu de démonstration'), findsOneWidget);
      expect(find.text('Démo'), findsWidgets);

      // Les coordonnées sont publiées : l'itinéraire est proposé.
      expect(find.text('Itinéraire'), findsOneWidget);

      // Un plat d'exemple est commandable.
      final Finder cafe = find.widgetWithText(OrderMenuTile, 'Café expresso');
      expect(cafe, findsOneWidget);
      await tester.tap(
        find.descendant(of: cafe, matching: find.byTooltip('Ajouter')),
      );
      await tester.pump();

      // Le récap affiche le montant et la confirmation est active.
      expect(find.text('500 FCFA'), findsWidgets);
      final FilledButton confirm = tester.widget<FilledButton>(
        find.widgetWithText(FilledButton, 'Confirmer'),
      );
      expect(confirm.onPressed, isNotNull);

      // Envoi effectif via le garde-fou, sans plugin natif.
      await tester.tap(find.widgetWithText(FilledButton, 'Confirmer'));
      await tester.pumpAndSettle();

      expect(gateway.launched, hasLength(1));
      final Uri uri = gateway.launched.single;
      expect(uri.scheme, 'https');
      expect(uri.host, 'wa.me');
      expect(uri.path, '/22657324005');
      expect(uri.queryParameters['text'], contains('Café expresso'));
      expect(uri.queryParameters['text'], contains('500 FCFA'));
      expect(uri.queryParameters['text'], contains('Vivalto Café'));
    },
  );

  testWidgets(
    'masque l’itinéraire et désactive la confirmation sans données sourcées',
    (WidgetTester tester) async {
      final CartCubit cart = CartCubit();
      addTearDown(cart.close);
      final _RecordingGateway gateway = _RecordingGateway();
      final UrlGuard guard = UrlGuard(gateway: gateway);

      // Fiche sans coordonnées publiées ni numéro.
      final KoudougouListing incomplete = _vivalto(phone: '')
          .copyWith(area: 'Koudougou');

      await _pumpPage(tester, listing: incomplete, cart: cart, guard: guard);

      expect(find.text('Itinéraire'), findsNothing);
      expect(find.textContaining('Itinéraire indisponible'), findsOneWidget);
      expect(
        find.textContaining('Numéro non publié par la source'),
        findsOneWidget,
      );

      // Même avec un plat choisi, la confirmation reste désactivée.
      final Finder cafe = find.widgetWithText(OrderMenuTile, 'Café expresso');
      await tester.tap(
        find.descendant(of: cafe, matching: find.byTooltip('Ajouter')),
      );
      await tester.pump();

      final FilledButton confirm = tester.widget<FilledButton>(
        find.widgetWithText(FilledButton, 'Confirmer'),
      );
      expect(confirm.onPressed, isNull);
      expect(gateway.launched, isEmpty);
    },
  );

  testWidgets('le bouton Modifier ramène au menu', (WidgetTester tester) async {
    final CartCubit cart = CartCubit();
    addTearDown(cart.close);
    final UrlGuard guard = UrlGuard(gateway: _RecordingGateway());

    await _pumpPage(tester, listing: _vivalto(), cart: cart, guard: guard);

    final Finder modify = find.widgetWithText(OutlinedButton, 'Modifier');
    expect(modify, findsOneWidget);
    expect(tester.widget<OutlinedButton>(modify).onPressed, isNotNull);
    await tester.tap(modify);
    await tester.pumpAndSettle();

    expect(find.text('Menu de démonstration'), findsOneWidget);
  });
}
