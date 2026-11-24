// =============================================================================
// Fixtures et doublures partagées par les tests Domain / Data.
// -----------------------------------------------------------------------------
// Aucun test ne dépend d'un vrai réseau, d'un vrai GPS ou d'un stockage natif :
// ces fakes reproduisent les contrats et rendent chaque scénario déterministe.
// =============================================================================

// Type fonctionnel utilisé par le faux repository.
import 'package:fpdart/fpdart.dart';

// Erreurs métier.
import 'package:koudougou_gourmet/core/error/exceptions.dart';
import 'package:koudougou_gourmet/core/error/failures.dart';

// Objet-valeur géographique et contrat du service GPS.
import 'package:koudougou_gourmet/core/location/geo_point.dart';
import 'package:koudougou_gourmet/core/location/location_service.dart';

// Connectivité simulée.
import 'package:koudougou_gourmet/core/network/network_info.dart';

// Contrats Data.
import 'package:koudougou_gourmet/features/restaurants/data/datasources/restaurant_local_data_source.dart';
import 'package:koudougou_gourmet/features/restaurants/data/datasources/restaurant_remote_data_source.dart';
import 'package:koudougou_gourmet/features/restaurants/data/datasources/restaurant_seed_data_source.dart';

// Modèles Data.
import 'package:koudougou_gourmet/features/restaurants/data/models/event_radar_model.dart';
import 'package:koudougou_gourmet/features/restaurants/data/models/restaurant_catalog_model.dart';
import 'package:koudougou_gourmet/features/restaurants/data/models/restaurant_model.dart';

// Entités Domain.
import 'package:koudougou_gourmet/features/restaurants/domain/entities/event_radar.dart';
import 'package:koudougou_gourmet/features/restaurants/domain/entities/koudougou_listing.dart';
import 'package:koudougou_gourmet/features/restaurants/domain/entities/live_braise_status.dart';
import 'package:koudougou_gourmet/features/restaurants/domain/entities/menu_item.dart';
import 'package:koudougou_gourmet/features/restaurants/domain/entities/opening_hours.dart';
import 'package:koudougou_gourmet/features/restaurants/domain/entities/restaurant.dart';
import 'package:koudougou_gourmet/features/restaurants/domain/entities/restaurant_category.dart';

// Contrat du repository (faux use case repository).
import 'package:koudougou_gourmet/features/restaurants/domain/repositories/koudougou_directory_repository.dart';
import 'package:koudougou_gourmet/features/restaurants/domain/repositories/restaurant_repository.dart';

/// Instant de référence : lundi 16 novembre 2026, 19 h à Koudougou.
final DateTime testNow = DateTime.utc(2026, 11, 16, 19, 0);

/// Catalogue minimal mais réaliste, utilisé par les tests Data.
///
/// Le premier restaurant est ouvert et possède une braise active à [testNow].
/// Le second est fermé à cette heure, sans braise.
const String sampleCatalogJson = '''
{
  "schemaVersion": 1,
  "restaurants": [
    {
      "id": "r1",
      "name": "Chez Awa",
      "tagline": "Cuisine du terroir",
      "category": "maquis",
      "sector": "Secteur 4",
      "landmark": "Grand marché",
      "latitude": 12.2521,
      "longitude": -2.3674,
      "phone": "+22670000001",
      "rating": 4.6,
      "reviewCount": 10,
      "averagePriceFcfa": 1000,
      "priceRange": "budget",
      "ambianceScore": 80,
      "musicGenre": "Musique burkinabè",
      "ambianceNote": "Terrasse animée",
      "openingHours": {
        "monday": { "open": "18:00", "close": "23:00" },
        "tuesday": { "open": "18:00", "close": "23:00" },
        "wednesday": { "open": "18:00", "close": "23:00" },
        "thursday": { "open": "18:00", "close": "23:00" },
        "friday": { "open": "18:00", "close": "23:00" },
        "saturday": { "open": "18:00", "close": "23:00" },
        "sunday": { "open": "18:00", "close": "23:00" }
      },
      "menu": [
        {
          "id": "r1-to",
          "name": "Tô sauce gombo",
          "section": "mainDishes",
          "priceFcfa": 700,
          "isSignature": true
        },
        {
          "id": "r1-poulet",
          "name": "Poulet braisé",
          "section": "grills",
          "priceFcfa": 3000
        }
      ],
      "isVerified": true,
      "verifiedAt": "2026-10-01T00:00:00Z",
      "updatedAt": "2026-11-01T00:00:00Z",
      "liveBraise": {
        "dishName": "Mouton braisé",
        "description": "Mouton mariné et braisé.",
        "priceFcfa": 2500,
        "portionsTotal": 10,
        "portionsRemaining": 4,
        "startTime": "18:00",
        "endTime": "23:00",
        "days": [1, 2, 3, 4, 5, 6, 7]
      }
    },
    {
      "id": "r2",
      "name": "Le Baobab",
      "category": "grillades",
      "sector": "Secteur 5",
      "landmark": "Centre-ville",
      "latitude": 12.2536,
      "longitude": -2.3652,
      "phone": "+22670000002",
      "rating": 4.2,
      "reviewCount": 20,
      "averagePriceFcfa": 3500,
      "priceRange": "premium",
      "ambianceScore": 40,
      "openingHours": {
        "monday": { "open": "10:00", "close": "15:00" },
        "tuesday": { "open": "10:00", "close": "15:00" },
        "wednesday": { "open": "10:00", "close": "15:00" },
        "thursday": { "open": "10:00", "close": "15:00" },
        "friday": { "open": "10:00", "close": "15:00" },
        "saturday": { "open": "10:00", "close": "15:00" },
        "sunday": { "open": "10:00", "close": "15:00" }
      },
      "menu": [
        {
          "id": "r2-brochettes",
          "name": "Brochettes de bœuf",
          "section": "grills",
          "priceFcfa": 1500
        }
      ],
      "isVerified": false,
      "updatedAt": "2026-11-02T00:00:00Z"
    }
  ],
  "events": [
    {
      "id": "evt-r1",
      "title": "Soirée braise",
      "type": "specialMenu",
      "restaurantId": "r1",
      "restaurantName": "Chez Awa",
      "dayOffset": 1,
      "startTime": "20:00",
      "durationHours": 3,
      "entryPriceFcfa": 0,
      "crowdLevel": 70
    }
  ]
}
''';

/// Parse le catalogue minimal.
RestaurantCatalogModel sampleCatalog() =>
    RestaurantCatalogModel.fromJsonString(sampleCatalogJson);

/// Construit des horaires simples pour tous les jours.
OpeningHours standardOpeningHours({
  int opensAtMinute = 600,
  int closesAtMinute = 1380,
}) {
  return OpeningHours(
    weekly: <int, DaySchedule?>{
      for (var weekday = 1; weekday <= 7; weekday++)
        weekday: DaySchedule(
          opensAtMinute: opensAtMinute,
          closesAtMinute: closesAtMinute,
        ),
    },
  );
}

/// Construit un plat avec des valeurs réalistes par défaut.
MenuItem buildMenuItem({
  String id = 'dish-1',
  String name = 'Tô sauce gombo',
  MenuSection section = MenuSection.mainDishes,
  int priceFcfa = 700,
  bool isAvailable = true,
  bool isSignature = false,
  Set<Allergen> allergens = const <Allergen>{},
}) {
  return MenuItem(
    id: id,
    name: name,
    description: 'Description de démonstration.',
    section: section,
    priceFcfa: priceFcfa,
    isAvailable: isAvailable,
    isSignature: isSignature,
    portionLabel: '1 personne',
    preparationMinutes: 10,
    photoAsset: null,
    allergens: allergens,
  );
}

/// Construit une fiche restaurant indépendante du JSON.
Restaurant buildRestaurant({
  String id = 'r1',
  String name = 'Chez Awa',
  RestaurantCategory category = RestaurantCategory.maquis,
  String sector = 'Secteur 4',
  String landmark = 'Grand marché',
  double rating = 4.5,
  int reviewCount = 10,
  PriceRange priceRange = PriceRange.budget,
  int averagePriceFcfa = 1000,
  int ambianceScore = 70,
  OpeningHours? openingHours,
  List<MenuItem>? menu,
  bool isVerified = true,
  Set<PaymentMethod>? paymentMethods,
  Set<RestaurantAmenity>? amenities,
  LiveBraiseStatus? liveBraise,
  double latitude = 12.2528,
  double longitude = -2.3669,
  bool deliveryAvailable = false,
}) {
  return Restaurant(
    id: id,
    name: name,
    tagline: 'Accroche de démonstration',
    description: 'Description de démonstration pour les tests.',
    category: category,
    sector: sector,
    landmark: landmark,
    address: 'Adresse de démonstration',
    latitude: latitude,
    longitude: longitude,
    phone: '+22670000001',
    whatsappPhone: '+22670000001',
    rating: rating,
    reviewCount: reviewCount,
    priceRange: priceRange,
    averagePriceFcfa: averagePriceFcfa,
    ambiance: AmbianceInfo(
      score: ambianceScore,
      musicGenre: 'Musique locale',
      note: 'Note de démonstration',
    ),
    openingHours: openingHours ?? standardOpeningHours(),
    menu: menu ?? <MenuItem>[buildMenuItem(id: '$id-to')],
    isVerified: isVerified,
    verifiedAt: isVerified ? DateTime.utc(2026, 10, 1) : null,
    updatedAt: DateTime.utc(2026, 11, 1),
    paymentMethods: paymentMethods ?? const <PaymentMethod>{PaymentMethod.cash},
    amenities:
        amenities ?? const <RestaurantAmenity>{RestaurantAmenity.terrace},
    photoAsset: null,
    liveBraise: liveBraise,
    deliveryAvailable: deliveryAvailable,
  );
}

/// Construit une braise active ou terminée selon les dates fournies.
LiveBraiseStatus buildLiveBraise({
  String restaurantId = 'r1',
  String restaurantName = 'Chez Awa',
  DateTime? startedAt,
  DateTime? endsAt,
  int portionsTotal = 10,
  int portionsRemaining = 5,
}) {
  return LiveBraiseStatus(
    restaurantId: restaurantId,
    restaurantName: restaurantName,
    dishName: 'Mouton braisé',
    description: 'Mouton mariné et braisé.',
    priceFcfa: 2500,
    portionsTotal: portionsTotal,
    portionsRemaining: portionsRemaining,
    startedAt: startedAt ?? testNow.subtract(const Duration(minutes: 30)),
    endsAt: endsAt ?? testNow.add(const Duration(hours: 1)),
  );
}

/// Construit un événement aux dates choisies.
EventRadar buildEvent({
  String id = 'event-1',
  String title = 'Soirée braise',
  RadarEventType type = RadarEventType.specialMenu,
  String restaurantId = 'r1',
  String restaurantName = 'Chez Awa',
  DateTime? startsAt,
  DateTime? endsAt,
  int entryPriceFcfa = 0,
  int crowdLevel = 60,
}) {
  return EventRadar(
    id: id,
    title: title,
    type: type,
    restaurantId: restaurantId,
    restaurantName: restaurantName,
    description: 'Description de démonstration.',
    startsAt: startsAt ?? testNow.add(const Duration(hours: 1)),
    endsAt: endsAt ?? testNow.add(const Duration(hours: 4)),
    entryPriceFcfa: entryPriceFcfa,
    crowdLevel: crowdLevel,
  );
}

/// Connectivité contrôlable.
final class FakeNetworkInfo implements NetworkInfo {
  /// État retourné par [isConnected].
  FakeNetworkInfo({this.connected = true});

  /// Valeur mutable pour simuler une coupure.
  bool connected;

  @override
  Future<bool> get isConnected async => connected;

  @override
  Stream<bool> get onConnectivityChanged => Stream<bool>.value(connected);
}

/// Cache local en mémoire.
final class FakeLocalDataSource implements RestaurantLocalDataSource {
  /// Initialise le faux cache avec les valeurs du scénario.
  FakeLocalDataSource({
    List<RestaurantModel>? restaurants,
    List<EventRadarModel>? events,
    Set<String>? favoriteIds,
    this.lastSyncAt,
    this.failReads = false,
  }) : restaurants = <RestaurantModel>[...?restaurants],
       events = <EventRadarModel>[...?events],
       favoriteIds = <String>{...?favoriteIds};

  /// Restaurants stockés.
  List<RestaurantModel> restaurants;

  /// Événements stockés.
  List<EventRadarModel> events;

  /// Favoris stockés.
  Set<String> favoriteIds;

  /// Date de synchronisation.
  DateTime? lastSyncAt;

  /// Simule un cache corrompu : seules les LECTURES échouent, l'initialisation
  /// de schéma et les écritures restent possibles (comme un vrai cache abîmé).
  bool failReads;

  /// Compteurs d'appels pour vérifier la stratégie offline-first.
  int ensureSchemaCalls = 0;
  int readRestaurantCalls = 0;
  int writeRestaurantCalls = 0;
  int writeEventCalls = 0;
  int clearCatalogCalls = 0;

  @override
  Future<void> ensureSchemaVersion() async {
    ensureSchemaCalls++;
  }

  @override
  Future<List<RestaurantModel>> readRestaurants() async {
    readRestaurantCalls++;
    if (failReads) {
      throw const CacheException('Cache de test illisible.');
    }
    return List<RestaurantModel>.unmodifiable(restaurants);
  }

  @override
  Future<void> writeRestaurants(List<RestaurantModel> value) async {
    writeRestaurantCalls++;
    restaurants = <RestaurantModel>[...value];
  }

  @override
  Future<List<EventRadarModel>> readEvents() async {
    if (failReads) {
      throw const CacheException('Cache de test illisible.');
    }
    return List<EventRadarModel>.unmodifiable(events);
  }

  @override
  Future<void> writeEvents(List<EventRadarModel> value) async {
    writeEventCalls++;
    events = <EventRadarModel>[...value];
  }

  @override
  Future<Set<String>> readFavoriteIds() async {
    if (failReads) {
      throw const CacheException('Cache de test illisible.');
    }
    return Set<String>.unmodifiable(favoriteIds);
  }

  @override
  Future<void> writeFavorite(
    String restaurantId, {
    required bool isFavorite,
  }) async {
    if (isFavorite) {
      favoriteIds.add(restaurantId);
    } else {
      favoriteIds.remove(restaurantId);
    }
  }

  @override
  Future<DateTime?> readLastSyncAt() async {
    if (failReads) {
      throw const CacheException('Cache de test illisible.');
    }
    return lastSyncAt;
  }

  @override
  Future<void> writeLastSyncAt(DateTime instant) async {
    lastSyncAt = instant.toUtc();
  }

  @override
  Future<void> clearCatalog() async {
    clearCatalogCalls++;
    restaurants = <RestaurantModel>[];
    events = <EventRadarModel>[];
    lastSyncAt = null;
  }
}

/// Seed embarqué simulé.
final class FakeSeedDataSource implements RestaurantSeedDataSource {
  /// [catalog] est renvoyé au chargement ; [error] permet de simuler un échec.
  FakeSeedDataSource({this.catalog, this.error});

  /// Catalogue de secours.
  final RestaurantCatalogModel? catalog;

  /// Erreur éventuelle (toujours une exception, jamais un objet arbitraire).
  final Exception? error;

  /// Compteur d'appels.
  int loadCalls = 0;

  @override
  Future<RestaurantCatalogModel> load() async {
    loadCalls++;
    final Exception? failure = error;
    if (failure != null) {
      throw failure;
    }
    final RestaurantCatalogModel? value = catalog;
    if (value == null) {
      throw const CacheException('Seed de test absent.');
    }
    return value;
  }
}

/// Source distante simulée.
final class FakeRemoteDataSource implements RestaurantRemoteDataSource {
  /// [catalog] est renvoyé au chargement ; [error] permet de simuler un échec.
  FakeRemoteDataSource({this.catalog, this.error});

  /// Catalogue distant.
  final RestaurantCatalogModel? catalog;

  /// Erreur éventuelle (toujours une exception, jamais un objet arbitraire).
  final Exception? error;

  /// Compteur d'appels.
  int fetchCalls = 0;

  @override
  Future<RestaurantCatalogModel> fetchCatalog() async {
    fetchCalls++;
    final Exception? failure = error;
    if (failure != null) {
      throw failure;
    }
    final RestaurantCatalogModel? value = catalog;
    if (value == null) {
      throw const ServerException('Catalogue distant absent.');
    }
    return value;
  }
}

/// Repository de secours pour tester les use cases sans couche Data.
final class FakeRestaurantRepository implements RestaurantRepository {
  /// Construit un repository renvoyant toujours les listes fournies.
  FakeRestaurantRepository({
    List<Restaurant> restaurants = const <Restaurant>[],
    this.events = const <EventRadar>[],
    this.failure,
  }) : restaurants = List<Restaurant>.unmodifiable(restaurants),
       _items = List<Restaurant>.of(restaurants);

  /// Restaurants retournés (instances d'origine quand aucune écriture n'a eu lieu).
  final List<Restaurant> restaurants;

  /// Copie mutable utilisée par les méthodes d'écriture des portails.
  final List<Restaurant> _items;

  /// `true` dès qu'une écriture locale a modifié la copie mutable.
  bool _hasWrites = false;

  /// Événements retournés.
  final List<EventRadar> events;

  /// Failure éventuelle, appliquée à toutes les lectures.
  final Failure? failure;

  /// Compteur de chargements.
  int getRestaurantsCalls = 0;

  @override
  Future<Either<Failure, List<Restaurant>>> getRestaurants({
    bool forceRefresh = false,
  }) async {
    getRestaurantsCalls++;
    final Failure? error = failure;
    if (error != null) {
      return left(error);
    }
    // Tant qu'aucune écriture n'a eu lieu, on renvoie exactement la liste
    // fournie au constructeur (identité préservée pour les tests existants).
    return right(_hasWrites ? List<Restaurant>.of(_items) : restaurants);
  }

  @override
  Future<Either<Failure, Restaurant>> getRestaurantById(String id) async {
    final Failure? error = failure;
    if (error != null) {
      return left(error);
    }
    for (final Restaurant restaurant in restaurants) {
      if (restaurant.id == id) {
        return right(restaurant);
      }
    }
    return left(const NotFoundFailure());
  }

  @override
  Future<Either<Failure, List<EventRadar>>> getEventRadar({
    bool forceRefresh = false,
  }) async {
    final Failure? error = failure;
    if (error != null) {
      return left(error);
    }
    return right(events);
  }

  @override
  Future<Either<Failure, Set<String>>> getFavoriteIds() async =>
      right(<String>{});

  @override
  Future<Either<Failure, bool>> toggleFavorite(
    String restaurantId, {
    bool? isFavorite,
  }) async => right(isFavorite ?? true);

  @override
  Future<Either<Failure, DateTime?>> getLastSyncAt() async => right(null);

  /// Ajoute une fiche dans la copie mutable.
  @override
  Future<Either<Failure, Restaurant>> addRestaurant(
    Restaurant restaurant,
  ) async {
    final Failure? error = failure;
    if (error != null) {
      return left(error);
    }
    if (_items.any((Restaurant item) => item.id == restaurant.id)) {
      return left(
        const ValidationFailure(message: 'Identifiant déjà utilisé.'),
      );
    }
    _items.add(restaurant);
    _hasWrites = true;
    return right(restaurant);
  }

  /// Ajoute un plat au menu de la copie mutable.
  @override
  Future<Either<Failure, Restaurant>> addMenuItem({
    required String restaurantId,
    required MenuItem item,
  }) async {
    final Failure? error = failure;
    if (error != null) {
      return left(error);
    }
    final int index = _items.indexWhere(
      (Restaurant restaurant) => restaurant.id == restaurantId,
    );
    if (index < 0) {
      return left(const NotFoundFailure());
    }
    final Restaurant current = _items[index];
    if (current.menu.any((MenuItem existing) => existing.id == item.id)) {
      return left(const ValidationFailure(message: 'Plat déjà présent.'));
    }
    final Restaurant updated = current.copyWith(
      menu: <MenuItem>[...current.menu, item],
    );
    _items[index] = updated;
    _hasWrites = true;
    return right(updated);
  }

  /// Retire un plat du menu de la copie mutable.
  @override
  Future<Either<Failure, Restaurant>> removeMenuItem({
    required String restaurantId,
    required String itemId,
  }) async {
    final Failure? error = failure;
    if (error != null) {
      return left(error);
    }
    final int index = _items.indexWhere(
      (Restaurant restaurant) => restaurant.id == restaurantId,
    );
    if (index < 0) {
      return left(const NotFoundFailure());
    }
    final Restaurant current = _items[index];
    if (!current.menu.any((MenuItem item) => item.id == itemId)) {
      return left(const NotFoundFailure());
    }
    final Restaurant updated = current.copyWith(
      menu: current.menu
          .where((MenuItem item) => item.id != itemId)
          .toList(growable: false),
    );
    _items[index] = updated;
    _hasWrites = true;
    return right(updated);
  }
}

/// Service de localisation simulé : position fixe ou échec contrôlé.
/// Il remplace `geolocator` dans les tests du `LocationCubit`.
final class FakeLocationService implements LocationService {
  /// [position] est renvoyée en cas de succès ; [failure] simule un refus.
  FakeLocationService({this.position, this.failure});

  /// Position retournée (facultative).
  final GeoPoint? position;

  /// Erreur métier éventuelle (permission refusée, service désactivé...).
  final Failure? failure;

  /// Compteur d'appels pour vérifier que le service est bien sollicité.
  int calls = 0;

  @override
  Future<Either<Failure, GeoPoint>> currentPosition() async {
    calls++;
    final Failure? error = failure;
    if (error != null) {
      return left(error);
    }
    final GeoPoint? point = position;
    if (point == null) {
      return left(const LocationFailure());
    }
    return right(point);
  }
}

/// Annuaire simulé pour les tests de l'accueil et de la page dédiée.
final class FakeDirectoryRepository implements KoudougouDirectoryRepository {
  /// Construit un annuaire contrôlé.
  FakeDirectoryRepository({this.listings = const <KoudougouListing>[]});

  /// Fiches retournées.
  final List<KoudougouListing> listings;

  @override
  Future<Either<Failure, List<KoudougouListing>>> getListings() async =>
      right(listings);
}
