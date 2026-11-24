// =============================================================================
// Tests des écritures locales du repository (portails gérant et créatrice).
// -----------------------------------------------------------------------------
// Ces écritures modifient le cache chiffré. Les tests utilisent un cache en
// mémoire et une horloge figée pour vérifier l'immutabilité des fiches, le
// refus des doublons et l'horodatage de chaque modification.
// =============================================================================

// Type fonctionnel.
import 'package:fpdart/fpdart.dart';

// Framework de test.
import 'package:flutter_test/flutter_test.dart';

// Failures métier.
import 'package:koudougou_gourmet/core/error/failures.dart';

// Horloge figée.
import 'package:koudougou_gourmet/core/utils/app_clock.dart';

// Modèles.
import 'package:koudougou_gourmet/features/restaurants/data/models/event_radar_model.dart';
import 'package:koudougou_gourmet/features/restaurants/data/models/restaurant_model.dart';

// Repository testé.
import 'package:koudougou_gourmet/features/restaurants/data/repositories/restaurant_repository_impl.dart';

// Entités.
import 'package:koudougou_gourmet/features/restaurants/domain/entities/menu_item.dart';
import 'package:koudougou_gourmet/features/restaurants/domain/entities/restaurant.dart';

// Doublures.
import '../support/fixtures.dart';

/// Extrait la valeur de droite, ou échoue le test.
T _ok<T>(Either<Failure, T> result) => result.fold(
  (Failure failure) => throw StateError(
    'Échec inattendu : ${failure.code} — ${failure.message}',
  ),
  (T value) => value,
);

/// Extrait la `Failure` de gauche, ou échoue le test.
Failure _failure<T>(Either<Failure, T> result) => result.fold(
  (Failure failure) => failure,
  (T _) => throw StateError('Succès inattendu.'),
);

/// Banc de test avec un cache déjà rempli.
final class _Rig {
  /// Construit le banc.
  _Rig(this.local, this.seed, this.repository);

  /// Cache en mémoire.
  final FakeLocalDataSource local;

  /// Seed de secours.
  final FakeSeedDataSource seed;

  /// Repository sous test.
  final RestaurantRepositoryImpl repository;
}

/// Construit un repository dont le cache contient le catalogue d'exemple.
_Rig _rig({List<RestaurantModel>? restaurants}) {
  final FakeLocalDataSource local = FakeLocalDataSource(
    restaurants: restaurants ?? sampleCatalog().restaurants,
    events: <EventRadarModel>[...sampleCatalog().events],
    lastSyncAt: testNow,
  );
  final FakeSeedDataSource seed = FakeSeedDataSource(catalog: sampleCatalog());

  return _Rig(
    local,
    seed,
    RestaurantRepositoryImpl(
      localDataSource: local,
      seedDataSource: seed,
      networkInfo: FakeNetworkInfo(),
      clock: FixedClock(testNow),
    ),
  );
}

void main() {
  group('addRestaurant', () {
    test('persiste une nouvelle fiche et horodate l’écriture', () async {
      final _Rig rig = _rig();
      final Restaurant created = buildRestaurant(
        id: 'local_1',
        name: 'Maquis Baye',
        isVerified: false,
      );

      final Restaurant result = _ok(
        await rig.repository.addRestaurant(created),
      );

      expect(result, created);
      expect(rig.local.restaurants, hasLength(3));
      expect(rig.local.restaurants.last.id, 'local_1');
      expect(rig.local.writeRestaurantCalls, 1);
      expect(rig.local.lastSyncAt, testNow);
      expect(rig.seed.loadCalls, 0);
    });

    test('refuse un identifiant déjà présent sans écraser la fiche', () async {
      final _Rig rig = _rig();
      final Restaurant duplicate = buildRestaurant(
        id: 'r1',
        name: 'Usurpateur',
      );

      final Failure failure = _failure(
        await rig.repository.addRestaurant(duplicate),
      );

      expect(failure, isA<ValidationFailure>());
      expect(rig.local.writeRestaurantCalls, 0);
      expect(rig.local.restaurants.first.name, 'Chez Awa');
    });

    test('refuse un identifiant non conforme', () async {
      final _Rig rig = _rig();
      final Restaurant invalid = buildRestaurant(id: '../r2');

      expect(
        _failure(await rig.repository.addRestaurant(invalid)),
        isA<ValidationFailure>(),
      );
      expect(rig.local.writeRestaurantCalls, 0);
    });

    test(
      'sans cache, ajoute la fiche au seed sans le persister deux fois',
      () async {
        final FakeLocalDataSource empty = FakeLocalDataSource();
        final FakeSeedDataSource seed = FakeSeedDataSource(
          catalog: sampleCatalog(),
        );
        final RestaurantRepositoryImpl repository = RestaurantRepositoryImpl(
          localDataSource: empty,
          seedDataSource: seed,
          networkInfo: FakeNetworkInfo(),
          clock: FixedClock(testNow),
        );

        final Restaurant created = buildRestaurant(
          id: 'local_2',
          isVerified: false,
        );
        _ok(await repository.addRestaurant(created));

        expect(seed.loadCalls, 1);
        expect(empty.restaurants, hasLength(3));
      },
    );
  });

  group('addMenuItem', () {
    test(
      'ajoute un plat sans modifier les autres champs de la fiche',
      () async {
        final _Rig rig = _rig();
        final Restaurant before = rig.local.restaurants.first.toEntity(testNow);
        final MenuItem item = buildMenuItem(
          id: 'new-dish',
          name: 'Attiéké poisson braisé',
          priceFcfa: 2500,
        );

        final Restaurant updated = _ok(
          await rig.repository.addMenuItem(restaurantId: 'r1', item: item),
        );

        expect(updated.id, before.id);
        expect(updated.name, before.name);
        expect(updated.sector, before.sector);
        expect(updated.isVerified, before.isVerified);
        expect(updated.menu, hasLength(before.menu.length + 1));
        expect(updated.menu.last.id, 'new-dish');
        expect(updated.updatedAt, testNow);

        // Le cache contient bien la version enrichie.
        final Restaurant cached = rig.local.restaurants.first.toEntity(testNow);
        expect(cached.menu.map((MenuItem e) => e.id), contains('new-dish'));
      },
    );

    test('refuse un plat déjà présent', () async {
      final _Rig rig = _rig();
      final MenuItem duplicate = buildMenuItem(id: 'r1-to');

      expect(
        _failure(
          await rig.repository.addMenuItem(restaurantId: 'r1', item: duplicate),
        ),
        isA<ValidationFailure>(),
      );
      expect(rig.local.writeRestaurantCalls, 0);
    });

    test('refuse un identifiant de plat invalide', () async {
      final _Rig rig = _rig();
      final MenuItem invalid = buildMenuItem(id: '../intrus');

      expect(
        _failure(
          await rig.repository.addMenuItem(restaurantId: 'r1', item: invalid),
        ),
        isA<ValidationFailure>(),
      );
    });

    test('signale un établissement inexistant', () async {
      final _Rig rig = _rig();
      final MenuItem item = buildMenuItem(id: 'dish-orphan');

      expect(
        _failure(
          await rig.repository.addMenuItem(restaurantId: 'r999', item: item),
        ),
        isA<NotFoundFailure>(),
      );
    });
  });

  group('removeMenuItem', () {
    test('retire uniquement le plat demandé', () async {
      final _Rig rig = _rig();

      final Restaurant updated = _ok(
        await rig.repository.removeMenuItem(
          restaurantId: 'r1',
          itemId: 'r1-to',
        ),
      );

      expect(updated.menu.map((MenuItem e) => e.id), isNot(contains('r1-to')));
      expect(updated.menu.map((MenuItem e) => e.id), contains('r1-poulet'));
      expect(updated.updatedAt, testNow);
      expect(rig.local.writeRestaurantCalls, 1);
    });

    test('signale un plat qui n’existe plus', () async {
      final _Rig rig = _rig();

      expect(
        _failure(
          await rig.repository.removeMenuItem(
            restaurantId: 'r1',
            itemId: 'dish-absent',
          ),
        ),
        isA<NotFoundFailure>(),
      );
      expect(rig.local.writeRestaurantCalls, 0);
    });

    test('refuse un identifiant invalide avant toute lecture', () async {
      final _Rig rig = _rig();

      expect(
        _failure(
          await rig.repository.removeMenuItem(
            restaurantId: 'r1',
            itemId: '!bad!',
          ),
        ),
        isA<ValidationFailure>(),
      );
      expect(rig.local.readRestaurantCalls, 0);
    });
  });
}
