// =============================================================================
// Tests de la source embarquée (seed Koudougou).
// -----------------------------------------------------------------------------
// Le seed est le dernier filet de sécurité hors ligne : il doit être présent,
// valide et cohérent AVANT toute mise en production. Ces tests chargent le
// véritable fichier `assets/seed/restaurants_koudougou.json` depuis le disque
// et vérifient qu'il respecte le schéma attendu par l'application.
// =============================================================================

// Encodage des octets du faux bundle.
import 'dart:convert';

// Lecture du fichier réel sur le disque de développement.
import 'dart:io';

// Type ByteData du faux bundle.
import 'package:flutter/services.dart';

// Framework de test.
import 'package:flutter_test/flutter_test.dart';

// Constantes (chemin du seed).
import 'package:koudougou_gourmet/core/constants/app_constants.dart';

// Exception attendue.
import 'package:koudougou_gourmet/core/error/exceptions.dart';

// Source testée.
import 'package:koudougou_gourmet/features/restaurants/data/datasources/restaurant_seed_data_source.dart';

// Modèle de catalogue.
import 'package:koudougou_gourmet/features/restaurants/data/models/restaurant_catalog_model.dart';

/// Faux bundle qui renvoie une chaîne fixe (ou lève une erreur).
final class _FakeAssetBundle extends AssetBundle {
  /// [contents] est renvoyé par `load` ; [error] simule un asset absent.
  _FakeAssetBundle({this.contents, this.error});

  /// Contenu JSON servi.
  final String? contents;

  /// Erreur éventuelle, levée à la place du contenu.
  final Exception? error;

  /// Nombre de chargements demandés.
  int loadCalls = 0;

  /// Simule la lecture d'un asset par Flutter.
  @override
  Future<ByteData> load(String key) async {
    loadCalls++;
    final Exception? failure = error;
    if (failure != null) {
      throw failure;
    }
    final Uint8List bytes = Uint8List.fromList(utf8.encode(contents ?? ''));
    return ByteData.sublistView(bytes);
  }
}

/// Lit le vrai fichier de seed depuis la racine du projet.
String _readRealSeed() =>
    File(AppConstants.seedAssetPath).readAsStringSync(encoding: utf8);

/// Point d'entrée des tests.
void main() {
  group('AssetRestaurantSeedDataSource', () {
    test('charge et valide le catalogue de démonstration réel', () async {
      // Le bundle sert le contenu réel du fichier versionné.
      final _FakeAssetBundle bundle = _FakeAssetBundle(
        contents: _readRealSeed(),
      );
      final AssetRestaurantSeedDataSource source =
          AssetRestaurantSeedDataSource(bundle: bundle);

      final RestaurantCatalogModel catalog = await source.load();

      // Enveloppe versionnée.
      expect(catalog.schemaVersion, AppConstants.catalogSchemaVersion);

      // Le catalogue de Koudougou contient dix établissements réalistes.
      expect(catalog.restaurants, hasLength(10));

      // Tous les téléphones sont normalisés en E.164 burkinabè.
      for (final restaurant in catalog.restaurants) {
        expect(restaurant.phone, startsWith('+226'));
        expect(restaurant.phone.length, 12);
      }

      // Le radar contient au moins une animation.
      expect(catalog.events, isNotEmpty);

      // Aucun événement orphelin : chaque cible existe réellement.
      final Set<String> ids = catalog.restaurants
          .map((restaurant) => restaurant.id)
          .toSet();
      for (final event in catalog.events) {
        expect(ids, contains(event.restaurantId));
      }

      // Le bundle n'a été sollicité qu'une fois.
      expect(bundle.loadCalls, 1);
    });

    test('convertit les entités à l’instant fourni sans lever d’exception', () {
      // La matérialisation (braises, événements relatifs) doit rester sûre.
      final AssetRestaurantSeedDataSource source =
          AssetRestaurantSeedDataSource(
            bundle: _FakeAssetBundle(contents: _readRealSeed()),
          );

      return source.load().then((catalog) {
        final DateTime now = DateTime.utc(2026, 11, 16, 20);
        expect(catalog.toEntities(now), hasLength(10));
        // Les événements relatifs sont résolus par rapport à `now`.
        expect(() => catalog.toEventEntities(now), returnsNormally);
      });
    });

    test('traduit un asset illisible en CacheException', () async {
      // Un asset absent ne doit pas propager d'erreur native au Domain.
      final AssetRestaurantSeedDataSource source =
          AssetRestaurantSeedDataSource(
            bundle: _FakeAssetBundle(error: Exception('asset absent')),
          );

      await expectLater(source.load(), throwsA(isA<CacheException>()));
    });

    test('traduit un JSON corrompu en CacheException', () async {
      // Un contenu non JSON est rejeté proprement.
      final AssetRestaurantSeedDataSource source =
          AssetRestaurantSeedDataSource(
            bundle: _FakeAssetBundle(contents: '{ ceci n’est pas du JSON'),
          );

      await expectLater(source.load(), throwsA(isA<CacheException>()));
    });
  });
}
