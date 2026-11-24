// =============================================================================
// Tests du repository offline-first.
// -----------------------------------------------------------------------------
// Ces tests verrouillent la stratégie de chargement :
//   cache frais -> API -> cache périmé -> seed -> échec.
// Ils vérifient aussi la conversion systématique des exceptions en `Failure`
// et la validation défensive des identifiants.
// =============================================================================

// Type fonctionnel Either.
import 'package:fpdart/fpdart.dart';

// Framework de test.
import 'package:flutter_test/flutter_test.dart';

// Constantes (version de schéma).
import 'package:koudougou_gourmet/core/constants/app_constants.dart';

// Exceptions simulées.
import 'package:koudougou_gourmet/core/error/exceptions.dart';

// Failures métier.
import 'package:koudougou_gourmet/core/error/failures.dart';

// Horloge figée pour des tests déterministes.
import 'package:koudougou_gourmet/core/utils/app_clock.dart';

// Modèles échangés.
import 'package:koudougou_gourmet/features/restaurants/data/models/event_radar_model.dart';
import 'package:koudougou_gourmet/features/restaurants/data/models/restaurant_catalog_model.dart';
import 'package:koudougou_gourmet/features/restaurants/data/models/restaurant_model.dart';

// Repository testé.
import 'package:koudougou_gourmet/features/restaurants/data/repositories/restaurant_repository_impl.dart';

// Entités produites.
import 'package:koudougou_gourmet/features/restaurants/domain/entities/event_radar.dart';
import 'package:koudougou_gourmet/features/restaurants/domain/entities/restaurant.dart';

// Fixtures et doublures.
import '../support/fixtures.dart';

/// Extrait la valeur de droite, ou échoue le test.
T _ok<T>(Either<Failure, T> result) => result.fold(
  (Failure failure) => throw StateError('Échec inattendu : ${failure.code}'),
  (T value) => value,
);

/// Extrait la `Failure` de gauche, ou échoue le test.
Failure _failure<T>(Either<Failure, T> result) => result.fold(
  (Failure failure) => failure,
  (T _) =>
      throw StateError('Succès inattendu alors qu’un échec était attendu.'),
);

/// Regroupe les doublures et le repository d'un scénario.
final class _Rig {
  /// Construit le banc de test.
  _Rig({
    required this.local,
    required this.seed,
    required this.remote,
    required this.repository,
  });

  /// Cache local simulé.
  final FakeLocalDataSource local;

  /// Seed simulé.
  final FakeSeedDataSource seed;

  /// Source distante simulée.
  final FakeRemoteDataSource remote;

  /// Repository sous test.
  final RestaurantRepositoryImpl repository;
}

/// Construit un repository avec les doublures demandées.
_Rig _rig({
  FakeLocalDataSource? local,
  RestaurantCatalogModel? seedCatalog,
  Exception? seedError,
  RestaurantCatalogModel? remoteCatalog,
  Exception? remoteError,
  bool remoteSyncEnabled = false,
  bool connected = true,
  Duration? cacheTtl,
}) {
  final FakeLocalDataSource effectiveLocal = local ?? FakeLocalDataSource();
  final FakeSeedDataSource seed = FakeSeedDataSource(
    catalog: seedCatalog,
    error: seedError,
  );
  final FakeRemoteDataSource remote = FakeRemoteDataSource(
    catalog: remoteCatalog,
    error: remoteError,
  );
  final bool hasRemote = remoteCatalog != null || remoteError != null;

  return _Rig(
    local: effectiveLocal,
    seed: seed,
    remote: remote,
    repository: RestaurantRepositoryImpl(
      localDataSource: effectiveLocal,
      seedDataSource: seed,
      networkInfo: FakeNetworkInfo(connected: connected),
      clock: FixedClock(testNow),
      remoteDataSource: hasRemote ? remote : null,
      remoteSyncEnabled: remoteSyncEnabled,
      cacheTtl: cacheTtl,
    ),
  );
}

/// Catalogue distant réduit à une seule fiche, pour distinguer les sources.
RestaurantCatalogModel _remoteCatalog() => RestaurantCatalogModel(
  schemaVersion: AppConstants.catalogSchemaVersion,
  restaurants: <RestaurantModel>[sampleCatalog().restaurants.first],
  events: const <EventRadarModel>[],
);

/// Cache frais : synchronisé il y a une heure.
FakeLocalDataSource _freshCache() => FakeLocalDataSource(
  restaurants: sampleCatalog().restaurants,
  events: sampleCatalog().events,
  lastSyncAt: testNow.subtract(const Duration(hours: 1)),
);

/// Point d'entrée des tests.
void main() {
  group('Stratégie offline-first', () {
    test('un cache frais répond sans réseau ni seed', () async {
      // Le cache est frais : aucune autre source n'est sollicitée.
      final _Rig rig = _rig(
        local: _freshCache(),
        remoteCatalog: _remoteCatalog(),
        remoteSyncEnabled: true,
      );

      final List<Restaurant> restaurants = _ok(
        await rig.repository.getRestaurants(),
      );

      expect(restaurants, hasLength(2));
      expect(rig.remote.fetchCalls, 0);
      expect(rig.seed.loadCalls, 0);
      expect(rig.local.writeRestaurantCalls, 0);
    });

    test('forceRefresh interroge l’API et met le cache à jour', () async {
      // Même avec un cache frais, le rafraîchissement forcé passe par l'API.
      final _Rig rig = _rig(
        local: _freshCache(),
        remoteCatalog: _remoteCatalog(),
        remoteSyncEnabled: true,
      );

      final List<Restaurant> restaurants = _ok(
        await rig.repository.getRestaurants(forceRefresh: true),
      );

      // Le catalogue distant ne contient qu'une fiche.
      expect(restaurants, hasLength(1));
      expect(rig.remote.fetchCalls, 1);
      expect(rig.local.writeRestaurantCalls, 1);
      expect(rig.local.writeEventCalls, 1);
      expect(rig.local.lastSyncAt, testNow);
    });

    test('sans cache, charge le seed et le persiste', () async {
      // Premier lancement hors ligne : le seed prend le relais.
      final _Rig rig = _rig(seedCatalog: sampleCatalog());

      final List<Restaurant> restaurants = _ok(
        await rig.repository.getRestaurants(),
      );

      expect(restaurants, hasLength(2));
      expect(rig.seed.loadCalls, 1);
      expect(rig.local.writeRestaurantCalls, 1);
      expect(rig.local.lastSyncAt, testNow);
    });

    test('sans cache et hors ligne, le seed est utilisé sans réseau', () async {
      // La connectivité absente court-circuite la tentative réseau.
      final _Rig rig = _rig(
        remoteCatalog: _remoteCatalog(),
        remoteSyncEnabled: true,
        connected: false,
        seedCatalog: sampleCatalog(),
      );

      final List<Restaurant> restaurants = _ok(
        await rig.repository.getRestaurants(),
      );

      expect(restaurants, hasLength(2));
      expect(rig.remote.fetchCalls, 0);
      expect(rig.seed.loadCalls, 1);
    });

    test('un cache périmé reste utilisable si l’API échoue', () async {
      // Mode dégradé : les données anciennes valent mieux que rien.
      final _Rig rig = _rig(
        local: FakeLocalDataSource(
          restaurants: sampleCatalog().restaurants,
          events: sampleCatalog().events,
          lastSyncAt: testNow.subtract(const Duration(days: 2)),
        ),
        remoteError: const NetworkException('coupure'),
        remoteSyncEnabled: true,
      );

      final List<Restaurant> restaurants = _ok(
        await rig.repository.getRestaurants(),
      );

      expect(restaurants, hasLength(2));
      expect(rig.remote.fetchCalls, 1);
      expect(rig.seed.loadCalls, 0);
    });

    test('sans cache, si l’API échoue, le seed prend le relais', () async {
      // L'API est indisponible mais le seed embarqué sauve l'expérience.
      final _Rig rig = _rig(
        remoteError: const NetworkException('coupure'),
        remoteSyncEnabled: true,
        seedCatalog: sampleCatalog(),
      );

      final List<Restaurant> restaurants = _ok(
        await rig.repository.getRestaurants(),
      );

      expect(restaurants, hasLength(2));
      expect(rig.seed.loadCalls, 1);
    });

    test('préfère l’erreur réseau quand seed et API échouent', () async {
      // L'erreur réseau est plus actionnable pour l'utilisateur.
      final _Rig rig = _rig(
        remoteError: const NetworkException('coupure'),
        remoteSyncEnabled: true,
        seedError: const CacheException('seed absent'),
      );

      final Failure failure = _failure(await rig.repository.getRestaurants());
      expect(failure, isA<NetworkFailure>());
    });

    test('renvoie CacheFailure si seul le seed échoue', () async {
      // Aucune API configurée et seed illisible : échec local.
      final _Rig rig = _rig(seedError: const CacheException('seed absent'));

      final Failure failure = _failure(await rig.repository.getRestaurants());
      expect(failure, isA<CacheFailure>());
    });

    test('purge un cache corrompu puis retombe sur le seed', () async {
      // Une lecture impossible déclenche une purge propre.
      final _Rig rig = _rig(
        local: FakeLocalDataSource(failReads: true),
        seedCatalog: sampleCatalog(),
      );

      final List<Restaurant> restaurants = _ok(
        await rig.repository.getRestaurants(),
      );

      expect(restaurants, hasLength(2));
      expect(rig.local.clearCatalogCalls, 1);
      expect(rig.seed.loadCalls, 1);
    });
  });

  group('getRestaurantById', () {
    test('renvoie la fiche demandée', () async {
      // L'identifiant existe dans le cache frais.
      final _Rig rig = _rig(local: _freshCache());

      final Restaurant restaurant = _ok(
        await rig.repository.getRestaurantById('r2'),
      );
      expect(restaurant.id, 'r2');
      expect(restaurant.name, 'Le Baobab');
    });

    test('renvoie NotFoundFailure pour un identifiant inconnu', () async {
      // La fiche n'existe pas : erreur métier, pas exception.
      final _Rig rig = _rig(local: _freshCache());

      final Failure failure = _failure(
        await rig.repository.getRestaurantById('r999'),
      );
      expect(failure, isA<NotFoundFailure>());
    });

    test('renvoie ValidationFailure pour un identifiant invalide', () async {
      // Un identifiant non conforme est refusé avant toute lecture.
      final _Rig rig = _rig(local: _freshCache());

      final Failure failure = _failure(
        await rig.repository.getRestaurantById('!!!'),
      );
      expect(failure, isA<ValidationFailure>());
    });
  });

  group('getEventRadar', () {
    test('convertit les événements mis en cache', () async {
      // Le cache contient un événement rattaché à r1.
      final _Rig rig = _rig(local: _freshCache());

      final List<EventRadar> events = _ok(await rig.repository.getEventRadar());
      expect(events, hasLength(1));
      expect(events.single.restaurantId, 'r1');
    });
  });

  group('Favoris', () {
    test('lit les favoris existants', () async {
      // Le cache expose un favori déjà enregistré.
      final _Rig rig = _rig(
        local: FakeLocalDataSource(favoriteIds: <String>{'r1'}),
      );

      expect(_ok(await rig.repository.getFavoriteIds()), <String>{'r1'});
    });

    test('bascule un favori dans les deux sens', () async {
      // Sans valeur explicite, l'état courant est inversé.
      final _Rig rig = _rig(local: _freshCache());

      expect(_ok(await rig.repository.toggleFavorite('r1')), isTrue);
      expect(_ok(await rig.repository.toggleFavorite('r1')), isFalse);
      expect(rig.local.favoriteIds, isEmpty);
    });

    test('respecte une valeur explicite', () async {
      // L'écriture est idempotente quand l'état est fourni.
      final _Rig rig = _rig(local: _freshCache());

      expect(
        _ok(await rig.repository.toggleFavorite('r1', isFavorite: true)),
        isTrue,
      );
      expect(
        _ok(await rig.repository.toggleFavorite('r1', isFavorite: true)),
        isTrue,
      );
      expect(rig.local.favoriteIds, <String>{'r1'});
    });

    test('refuse de mettre en favori un restaurant inconnu', () async {
      // Aucun lien mort ne doit être créé dans les favoris.
      final _Rig rig = _rig(local: _freshCache());

      final Failure failure = _failure(
        await rig.repository.toggleFavorite('r999'),
      );
      expect(failure, isA<NotFoundFailure>());
    });

    test('refuse un identifiant de favori invalide', () async {
      // La clé de stockage est validée avant écriture.
      final _Rig rig = _rig(local: _freshCache());

      final Failure failure = _failure(
        await rig.repository.toggleFavorite('!!!'),
      );
      expect(failure, isA<ValidationFailure>());
    });
  });

  group('getLastSyncAt', () {
    test('renvoie la date de synchronisation du cache', () async {
      // La date fraîche est exposée telle quelle.
      final DateTime instant = testNow.subtract(const Duration(hours: 1));
      final _Rig rig = _rig(local: FakeLocalDataSource(lastSyncAt: instant));

      expect(_ok(await rig.repository.getLastSyncAt()), instant);
    });

    test('renvoie null quand aucune synchronisation n’a eu lieu', () async {
      // Un cache vierge n'a pas de date.
      final _Rig rig = _rig(local: FakeLocalDataSource());

      expect(_ok(await rig.repository.getLastSyncAt()), isNull);
    });
  });
}
