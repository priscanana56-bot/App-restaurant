// =============================================================================
// Tests de la frontière JSON (modèles Data).
// -----------------------------------------------------------------------------
// Toute donnée externe doit être rejetée si elle est incohérente : secteur
// inconnu, coordonnée hors zone, identifiant dupliqué, téléphone invalide...
// Un mauvais catalogue ne doit jamais atteindre le Domain.
// =============================================================================

// Framework de test.
import 'package:flutter_test/flutter_test.dart';

// Modèles testés.
import 'package:koudougou_gourmet/features/restaurants/data/models/event_radar_model.dart';
import 'package:koudougou_gourmet/features/restaurants/data/models/json_reader.dart';
import 'package:koudougou_gourmet/features/restaurants/data/models/live_braise_model.dart';
import 'package:koudougou_gourmet/features/restaurants/data/models/opening_hours_model.dart';
import 'package:koudougou_gourmet/features/restaurants/data/models/restaurant_catalog_model.dart';
import 'package:koudougou_gourmet/features/restaurants/data/models/restaurant_model.dart';

// Entités produites.
import 'package:koudougou_gourmet/features/restaurants/domain/entities/opening_hours.dart';
import 'package:koudougou_gourmet/features/restaurants/domain/entities/restaurant.dart';

// Fixtures.
import '../support/fixtures.dart';

/// Extrait les restaurants bruts d'un catalogue sérialisé.
List<Object?> _rawRestaurants(Map<String, Object?> json) =>
    json['restaurants']! as List<Object?>;

/// Extrait les événements bruts d'un catalogue sérialisé.
List<Object?> _rawEvents(Map<String, Object?> json) =>
    json['events']! as List<Object?>;

/// Point d'entrée des tests.
void main() {
  group('RestaurantCatalogModel', () {
    test('parse le catalogue de référence', () {
      // Deux restaurants et un événement rattaché.
      final RestaurantCatalogModel catalog = sampleCatalog();
      expect(catalog.schemaVersion, 1);
      expect(catalog.restaurants, hasLength(2));
      expect(catalog.events, hasLength(1));

      // Les entités sont matérialisées à l'instant de référence.
      final List<Restaurant> restaurants = catalog.toEntities(testNow);
      expect(restaurants.first.id, 'r1');
      expect(restaurants.first.phone, '+22670000001');
      expect(restaurants.first.isOpenAt(testNow), isTrue);
      expect(restaurants.first.hasLiveBraiseAt(testNow), isTrue);
      expect(restaurants.last.isOpenAt(testNow), isFalse);
    });

    test('refuse une version de schéma inconnue', () {
      // Une version future ne doit pas être interprétée à l'aveugle.
      final String invalid = sampleCatalogJson.replaceFirst(
        '"schemaVersion": 1',
        '"schemaVersion": 99',
      );
      expect(
        () => RestaurantCatalogModel.fromJsonString(invalid),
        throwsFormatException,
      );
    });

    test('refuse un identifiant de restaurant dupliqué', () {
      // Deux fiches partageant la même clé rendraient le cache ambigu.
      final Map<String, Object?> json = sampleCatalog().toJson();
      final List<Object?> restaurants = List<Object?>.of(_rawRestaurants(json));
      restaurants.add(restaurants.first);
      json['restaurants'] = restaurants;
      expect(
        () => RestaurantCatalogModel.fromJson(json),
        throwsFormatException,
      );
    });

    test('ignore un événement orphelin', () {
      // L'événement ne doit pas créer de lien mort vers une fiche absente.
      final Map<String, Object?> json = sampleCatalog().toJson();
      final Map<String, Object?> event =
          _rawEvents(json).first! as Map<String, Object?>;
      event['restaurantId'] = 'restaurant-inexistant';
      final RestaurantCatalogModel catalog = RestaurantCatalogModel.fromJson(
        json,
      );
      expect(catalog.events, isEmpty);
    });

    test('refuse un identifiant d’événement dupliqué', () {
      // Deux fois le même événement : donnée incohérente.
      final Map<String, Object?> json = sampleCatalog().toJson();
      final List<Object?> events = List<Object?>.of(_rawEvents(json));
      events.add(events.first);
      json['events'] = events;
      expect(
        () => RestaurantCatalogModel.fromJson(json),
        throwsFormatException,
      );
    });

    test('accepte un aller-retour JSON sans perte', () {
      // Le cache Hive réutilise exactement ce format.
      final RestaurantCatalogModel original = sampleCatalog();
      final RestaurantCatalogModel restored = RestaurantCatalogModel.fromJson(
        original.toJson(),
      );
      expect(restored.toJson(), original.toJson());
      expect(restored.restaurants.first.id, 'r1');
    });
  });

  group('RestaurantModel', () {
    test('refuse un secteur absent du référentiel de Koudougou', () {
      // « Secteur 99 » n'existe pas.
      final String invalid = sampleCatalogJson.replaceFirst(
        '"Secteur 4"',
        '"Secteur 99"',
      );
      expect(
        () => RestaurantCatalogModel.fromJsonString(invalid),
        throwsFormatException,
      );
    });

    test('refuse une coordonnée hors de la zone de Koudougou', () {
      // Un point à 45° de latitude ouvrirait un lien GPS hors du Burkina.
      final String invalid = sampleCatalogJson.replaceFirst(
        '"latitude": 12.2521',
        '"latitude": 45.0',
      );
      expect(
        () => RestaurantCatalogModel.fromJsonString(invalid),
        throwsFormatException,
      );
    });

    test('refuse un téléphone non burkinabè', () {
      // Trop court et préfixe invalide : la fiche est rejetée.
      final String invalid = sampleCatalogJson.replaceFirst(
        '"+22670000001"',
        '"+2261234"',
      );
      expect(
        () => RestaurantCatalogModel.fromJsonString(invalid),
        throwsFormatException,
      );
    });

    test('refuse une fiche vérifiée sans date de vérification', () {
      // La cohérence métier est vérifiée dès le parsing.
      final Map<String, Object?> json = sampleCatalog().toJson();
      final Map<String, Object?> restaurant =
          _rawRestaurants(json).first! as Map<String, Object?>;
      restaurant['isVerified'] = true;
      restaurant.remove('verifiedAt');
      expect(
        () => RestaurantCatalogModel.fromJson(json),
        throwsFormatException,
      );
    });

    test('refuse deux plats avec le même identifiant', () {
      // Une clé de panier doit rester unique dans un menu.
      final Map<String, Object?> json = sampleCatalog().toJson();
      final Map<String, Object?> restaurant =
          _rawRestaurants(json).first! as Map<String, Object?>;
      final List<Object?> menu = List<Object?>.of(
        restaurant['menu']! as List<Object?>,
      );
      menu.add(menu.first);
      restaurant['menu'] = menu;
      expect(
        () => RestaurantCatalogModel.fromJson(json),
        throwsFormatException,
      );
    });

    test('sérialise puis relit une fiche complète', () {
      // Les champs optionnels et les collections sont conservés.
      final RestaurantModel model = sampleCatalog().restaurants.first;
      final RestaurantModel restored = RestaurantModel.fromJson(model.toJson());
      expect(restored.id, model.id);
      expect(restored.name, model.name);
      expect(restored.menu, hasLength(2));
      expect(restored.liveBraise, isNotNull);
      expect(restored.toJson(), model.toJson());
    });
  });

  group('OpeningHoursModel', () {
    test('convertit 24:00 en fin de journée', () {
      // 24:00 est une heure de fermeture valide, pas une heure d'ouverture.
      final OpeningHoursModel model = OpeningHoursModel.fromJson(
        <String, Object?>{
          'monday': <String, Object?>{'open': '10:00', 'close': '24:00'},
        },
      );
      final OpeningHours hours = model.toEntity();
      expect(hours.weekly[1]!.closesAtMinute, 1440);
      expect(model.toJson()['monday'], <String, Object?>{
        'open': '10:00',
        'close': '24:00',
      });
    });

    test('gère un créneau qui traverse minuit', () {
      // 18:00 -> 02:00 doit rester ouvert à 01:00 le lendemain.
      final OpeningHoursModel model = OpeningHoursModel.fromJson(
        <String, Object?>{
          'monday': <String, Object?>{'open': '18:00', 'close': '02:00'},
        },
      );
      final OpeningHours hours = model.toEntity();
      expect(hours.isOpenAt(DateTime.utc(2026, 11, 17, 1)), isTrue);
      expect(model.toJson()['monday'], <String, Object?>{
        'open': '18:00',
        'close': '02:00',
      });
    });

    test('refuse un créneau vide', () {
      // Ouverture = fermeture : donnée incohérente.
      expect(
        () => OpeningHoursModel.fromJson(<String, Object?>{
          'monday': <String, Object?>{'open': '10:00', 'close': '10:00'},
        }),
        throwsFormatException,
      );
    });
  });

  group('LiveBraiseModel', () {
    test('matérialise une braise quotidienne au bon moment', () {
      // 22:00 -> 02:00, à 23:00 la session est active.
      final LiveBraiseModel model = LiveBraiseModel.fromJson(<String, Object?>{
        'dishName': 'Mouton braisé',
        'priceFcfa': 2500,
        'portionsTotal': 10,
        'portionsRemaining': 5,
        'startTime': '22:00',
        'endTime': '02:00',
        'days': <int>[1, 2, 3, 4, 5, 6, 7],
      });
      final braise = model.toEntity(
        restaurantId: 'r1',
        restaurantName: 'Chez Awa',
        now: DateTime.utc(2026, 11, 16, 23),
      );
      expect(braise.isActiveAt(DateTime.utc(2026, 11, 16, 23)), isTrue);
      expect(model.toJson()['startTime'], '22:00');
      expect(model.toJson()['endTime'], '02:00');
    });

    test('refuse un mélange des modes absolu et quotidien', () {
      // Les deux formats sont exclusifs.
      expect(
        () => LiveBraiseModel.fromJson(<String, Object?>{
          'dishName': 'Mouton braisé',
          'priceFcfa': 2500,
          'portionsTotal': 10,
          'portionsRemaining': 5,
          'startedAt': '2026-11-16T18:00:00Z',
          'endsAt': '2026-11-16T23:00:00Z',
          'startTime': '18:00',
          'endTime': '23:00',
        }),
        throwsFormatException,
      );
    });
  });

  group('EventRadarModel', () {
    test('résout un événement relatif au jour courant', () {
      // dayOffset 1 + 20:00 : demain soir.
      final EventRadarModel model = EventRadarModel.fromJson(<String, Object?>{
        'id': 'evt-test',
        'title': 'Soirée test',
        'type': 'concert',
        'restaurantId': 'r1',
        'restaurantName': 'Chez Awa',
        'dayOffset': 1,
        'startTime': '20:00',
        'durationHours': 3,
      });
      final event = model.toEntity(testNow);
      expect(event.startsAt, DateTime.utc(2026, 11, 17, 20));
      expect(event.endsAt, DateTime.utc(2026, 11, 17, 23));
      expect(event.type.name, 'concert');
    });

    test('refuse un mode incomplet', () {
      // dayOffset sans startTime ni durée.
      expect(
        () => EventRadarModel.fromJson(<String, Object?>{
          'id': 'evt-test',
          'title': 'Soirée test',
          'restaurantId': 'r1',
          'restaurantName': 'Chez Awa',
          'dayOffset': 1,
        }),
        throwsFormatException,
      );
    });
  });

  group('JsonReader', () {
    test('accepte un entier JSON encodé en double', () {
      // Certains serveurs envoient 1500.0 pour un entier.
      const JsonReader reader = JsonReader(<String, Object?>{
        'priceFcfa': 1500.0,
      });
      expect(reader.requireInt('priceFcfa', min: 0), 1500);
    });

    test('refuse un texte à la place d’un entier', () {
      // Aucun cast implicite : la donnée est rejetée.
      const JsonReader reader = JsonReader(<String, Object?>{
        'priceFcfa': '1500',
      });
      expect(() => reader.requireInt('priceFcfa'), throwsFormatException);
    });

    test('nettoie les bords d’une chaîne', () {
      // Les espaces de bord ne portent pas de sens métier.
      const JsonReader reader = JsonReader(<String, Object?>{
        'name': '  Chez Awa  ',
      });
      expect(reader.requireString('name'), 'Chez Awa');
    });

    test('refuse une date aberrante', () {
      // Une horloge corrompue ne doit pas produire une date de 1900.
      const JsonReader reader = JsonReader(<String, Object?>{
        'updatedAt': '1900-01-01T00:00:00Z',
      });
      expect(() => reader.requireDateTime('updatedAt'), throwsFormatException);
    });
  });
}
