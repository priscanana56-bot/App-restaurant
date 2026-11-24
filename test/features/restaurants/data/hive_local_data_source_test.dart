// =============================================================================
// Tests du cache Hive (DataSource locale).
// -----------------------------------------------------------------------------
// Hive est ouvert sur un répertoire temporaire, sans chiffrement : le but est de
// valider la logique métier (lecture, écriture, migration de schéma, résilience
// aux entrées corrompues), pas le chiffrement AES qui dépend du matériel.
// =============================================================================

// Encodage JSON des entrées de test.
import 'dart:convert';

// Répertoire temporaire isolé.
import 'dart:io';

// Hive (édition communautaire).
import 'package:hive_ce/hive.dart';

// Framework de test.
import 'package:flutter_test/flutter_test.dart';

// Constantes (clé de schéma).
import 'package:koudougou_gourmet/core/constants/app_constants.dart';

// Exceptions attendues.
import 'package:koudougou_gourmet/core/error/exceptions.dart';

// Source testée.
import 'package:koudougou_gourmet/features/restaurants/data/datasources/hive_restaurant_local_data_source.dart';

// Modèles.
import 'package:koudougou_gourmet/features/restaurants/data/models/event_radar_model.dart';
import 'package:koudougou_gourmet/features/restaurants/data/models/restaurant_model.dart';

// Fixtures (catalogue d'exemple).
import '../support/fixtures.dart';

/// Point d'entrée des tests.
void main() {
  // Répertoire temporaire unique pour toute la suite.
  late Directory tempDir;

  // Boîtes ouvertes pour le test courant.
  late Box<String> restaurantsBox;
  late Box<String> eventsBox;
  late Box<String> favoritesBox;
  late Box<String> settingsBox;
  late HiveRestaurantLocalDataSource dataSource;

  setUpAll(() {
    // Hive est initialisé une seule fois sur un dossier jetable.
    tempDir = Directory.systemTemp.createTempSync('kdg_hive_test_');
    Hive.init(tempDir.path);
  });

  setUp(() async {
    // Noms fixes : les boîtes sont fermées et rouvertes entre les tests.
    restaurantsBox = await Hive.openBox<String>('restaurants_test');
    eventsBox = await Hive.openBox<String>('events_test');
    favoritesBox = await Hive.openBox<String>('favorites_test');
    settingsBox = await Hive.openBox<String>('settings_test');
    dataSource = HiveRestaurantLocalDataSource(
      restaurantsBox,
      eventsBox,
      favoritesBox,
      settingsBox,
    );

    // Les fichiers Hive persistent entre les tests : on repart d'un état vierge.
    await restaurantsBox.clear();
    await eventsBox.clear();
    await favoritesBox.clear();
    await settingsBox.clear();
  });

  tearDown(() async {
    // Fermeture propre pour repartir d'un état vierge.
    await restaurantsBox.close();
    await eventsBox.close();
    await favoritesBox.close();
    await settingsBox.close();
  });

  tearDownAll(() {
    // Nettoyage du disque temporaire.
    Hive.close();
    tempDir.deleteSync(recursive: true);
  });

  group('ensureSchemaVersion', () {
    test('purge le catalogue puis marque la version de schéma', () async {
      // Un ancien catalogue présent avant la migration.
      await restaurantsBox.put('r1', '{}');
      await settingsBox.put('catalog_last_sync_at', '2026-01-01T00:00:00Z');

      await dataSource.ensureSchemaVersion();

      // Le catalogue et la date sont purgés, la version est écrite.
      expect(restaurantsBox.isEmpty, isTrue);
      expect(settingsBox.get('catalog_last_sync_at'), isNull);
      expect(
        settingsBox.get(AppConstants.cacheSchemaKey),
        '${AppConstants.cacheSchemaVersion}',
      );
    });

    test('ne purge plus lorsque la version est déjà correcte', () async {
      // Première passe : migration.
      await dataSource.ensureSchemaVersion();

      // Écriture après migration.
      await restaurantsBox.put('r1', '{}');

      // Seconde passe : aucun effet.
      await dataSource.ensureSchemaVersion();
      expect(restaurantsBox.containsKey('r1'), isTrue);
    });
  });

  group('Restaurants', () {
    test('écrit puis relit les restaurants à l’identique', () async {
      // Le catalogue d'exemple contient deux fiches complètes.
      final List<RestaurantModel> models = sampleCatalog().restaurants;

      await dataSource.writeRestaurants(models);
      final List<RestaurantModel> restored = await dataSource.readRestaurants();

      expect(restored, hasLength(2));
      expect(restored.first.id, 'r1');
      expect(restored.first.name, 'Chez Awa');
      expect(restored.first.menu, hasLength(2));
    });

    test('écrase intégralement l’ancien catalogue', () async {
      // Une première écriture, puis une seconde plus petite.
      await dataSource.writeRestaurants(sampleCatalog().restaurants);
      await dataSource.writeRestaurants(<RestaurantModel>[
        sampleCatalog().restaurants.first,
      ]);

      expect(await dataSource.readRestaurants(), hasLength(1));
    });

    test('ignore une entrée corrompue mais conserve les valides', () async {
      // Une entrée illisible ne doit pas casser toute la lecture.
      final String valid = jsonEncode(
        sampleCatalog().restaurants.first.toJson(),
      );
      await restaurantsBox.put('valid', valid);
      await restaurantsBox.put('broken', 'ceci n’est pas du JSON');

      final List<RestaurantModel> restored = await dataSource.readRestaurants();
      expect(restored, hasLength(1));
      expect(restored.single.id, 'r1');
    });

    test('signale un cache entièrement illisible', () async {
      // Toutes les entrées sont corrompues : le cache doit être reconstruit.
      await restaurantsBox.put('broken', 'pas du JSON');
      await expectLater(
        dataSource.readRestaurants(),
        throwsA(isA<CacheException>()),
      );
    });
  });

  group('Événements', () {
    test('écrit puis relit les événements', () async {
      // Le catalogue d'exemple contient un événement rattaché à r1.
      final List<EventRadarModel> models = sampleCatalog().events;

      await dataSource.writeEvents(models);
      final List<EventRadarModel> restored = await dataSource.readEvents();

      expect(restored, hasLength(1));
      expect(restored.single.id, 'evt-r1');
    });
  });

  group('Favoris', () {
    test('ajoute puis retire un favori', () async {
      // Ajout.
      await dataSource.writeFavorite('r1', isFavorite: true);
      expect(await dataSource.readFavoriteIds(), <String>{'r1'});

      // Retrait idempotent.
      await dataSource.writeFavorite('r1', isFavorite: false);
      expect(await dataSource.readFavoriteIds(), isEmpty);
    });

    test('nettoie les clés non conformes à la lecture', () async {
      // Clés injectées directement dans la boîte (simulation d'une corruption).
      await favoritesBox.put('r1', '1');
      await favoritesBox.put('   ', '1');
      await favoritesBox.put('r@2', '1');

      // Seule la clé valide est conservée.
      expect(await dataSource.readFavoriteIds(), <String>{'r1'});
    });

    test('refuse un identifiant de favori invalide', () async {
      // Aucune écriture ne doit accepter une clé dangereuse.
      await expectLater(
        dataSource.writeFavorite('!!!', isFavorite: true),
        throwsA(isA<ValidationException>()),
      );
    });

    test('conserve les favoris lors d’une purge du catalogue', () async {
      // La purge ne doit jamais faire perdre les favoris de l'utilisateur.
      await dataSource.writeFavorite('r1', isFavorite: true);
      await dataSource.clearCatalog();

      expect(await dataSource.readFavoriteIds(), <String>{'r1'});
    });
  });

  group('Date de synchronisation', () {
    test('écrit et relit une date valide en UTC', () async {
      // La date est stockée normalisée en UTC.
      final DateTime instant = DateTime.utc(2026, 11, 16, 20, 30);
      await dataSource.writeLastSyncAt(instant);

      expect(await dataSource.readLastSyncAt(), instant);
    });

    test('renvoie null pour une valeur illisible', () async {
      // Une date corrompue ne doit pas faire échouer la lecture.
      await settingsBox.put('catalog_last_sync_at', 'pas une date');
      expect(await dataSource.readLastSyncAt(), isNull);

      // Une date aberrante (année 1900) est ignorée.
      await settingsBox.put('catalog_last_sync_at', '1900-01-01T00:00:00Z');
      expect(await dataSource.readLastSyncAt(), isNull);
    });

    test('refuse une date hors bornes à l’écriture', () async {
      // Une horloge déréglée ne doit pas polluer le cache.
      await expectLater(
        dataSource.writeLastSyncAt(DateTime.utc(1900)),
        throwsA(isA<ValidationException>()),
      );
    });

    test('clearCatalog supprime la date de synchronisation', () async {
      // Après purge, le catalogue sera rechargé comme « jamais synchronisé ».
      await dataSource.writeLastSyncAt(DateTime.utc(2026, 11, 16));
      await dataSource.clearCatalog();

      expect(await dataSource.readLastSyncAt(), isNull);
    });
  });
}
