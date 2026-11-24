// =============================================================================
// Tests des use cases Live Braise et Radar d'ambiance.
// -----------------------------------------------------------------------------
// Ils combinent le repository et l'horloge : les tests vérifient le filtrage
// temporel, l'ordre d'affichage et la propagation des erreurs métier.
// =============================================================================

// Framework de test.
import 'package:flutter_test/flutter_test.dart';

// Failures.
import 'package:koudougou_gourmet/core/error/failures.dart';

// Horloge figée.
import 'package:koudougou_gourmet/core/utils/app_clock.dart';

// Entités.
import 'package:koudougou_gourmet/features/restaurants/domain/entities/event_radar.dart';
import 'package:koudougou_gourmet/features/restaurants/domain/entities/live_braise_status.dart';
import 'package:koudougou_gourmet/features/restaurants/domain/entities/restaurant.dart';

// Use cases testés.
import 'package:koudougou_gourmet/features/restaurants/domain/usecases/get_event_radar.dart';
import 'package:koudougou_gourmet/features/restaurants/domain/usecases/get_live_braise.dart';

// Fixtures.
import '../support/fixtures.dart';

/// Point d'entrée des tests.
void main() {
  group('LiveBraiseStatus', () {
    test('calcule la progression et le temps restant', () {
      // 4 portions servies sur 10.
      final LiveBraiseStatus braise = buildLiveBraise(
        portionsTotal: 10,
        portionsRemaining: 4,
      );
      expect(braise.servedPercentage, 60);
      expect(braise.remainingMinutesAt(testNow), 60);
      expect(braise.isSoldOut, isFalse);
    });

    test('une braise épuisée n’est jamais active', () {
      // Le stock prime sur la fenêtre horaire.
      final LiveBraiseStatus braise = buildLiveBraise(portionsRemaining: 0);
      expect(braise.isSoldOut, isTrue);
      expect(braise.isActiveAt(testNow), isFalse);
      expect(braise.servedPercentage, 100);
    });

    test('une braise terminée renvoie zéro minute restante', () {
      // Aucun nombre négatif ne doit être affiché.
      final LiveBraiseStatus braise = buildLiveBraise(
        startedAt: testNow.subtract(const Duration(hours: 4)),
        endsAt: testNow.subtract(const Duration(hours: 1)),
      );
      expect(braise.isActiveAt(testNow), isFalse);
      expect(braise.remainingMinutesAt(testNow), 0);
    });
  });

  group('EventRadar', () {
    test('distingue en cours, à venir et terminé', () {
      // Un événement en cours à l'instant de référence.
      final EventRadar live = buildEvent(
        startsAt: testNow.subtract(const Duration(hours: 1)),
        endsAt: testNow.add(const Duration(hours: 1)),
      );
      expect(live.isLiveAt(testNow), isTrue);
      expect(live.isUpcomingAt(testNow), isFalse);
      expect(live.isFinishedAt(testNow), isFalse);
      expect(live.isFree, isTrue);

      // Un événement passé.
      final EventRadar finished = buildEvent(
        startsAt: testNow.subtract(const Duration(hours: 3)),
        endsAt: testNow.subtract(const Duration(hours: 1)),
      );
      expect(finished.isFinishedAt(testNow), isTrue);
    });
  });

  group('GetLiveBraise', () {
    late List<Restaurant> restaurants;
    late GetLiveBraise useCase;

    setUp(() {
      // Trois braises actives, une épuisée et une terminée.
      restaurants = <Restaurant>[
        buildRestaurant(
          id: 'r1',
          name: 'Chez Awa',
          liveBraise: buildLiveBraise(
            restaurantId: 'r1',
            restaurantName: 'Chez Awa',
            endsAt: testNow.add(const Duration(minutes: 30)),
          ),
        ),
        buildRestaurant(
          id: 'r2',
          name: 'Le Baobab',
          liveBraise: buildLiveBraise(
            restaurantId: 'r2',
            restaurantName: 'Le Baobab',
            endsAt: testNow.add(const Duration(hours: 2)),
          ),
        ),
        buildRestaurant(
          id: 'r3',
          name: 'Braise épuisée',
          liveBraise: buildLiveBraise(
            restaurantId: 'r3',
            restaurantName: 'Braise épuisée',
            portionsRemaining: 0,
          ),
        ),
        buildRestaurant(
          id: 'r4',
          name: 'Braise terminée',
          liveBraise: buildLiveBraise(
            restaurantId: 'r4',
            restaurantName: 'Braise terminée',
            startedAt: testNow.subtract(const Duration(hours: 4)),
            endsAt: testNow.subtract(const Duration(hours: 1)),
          ),
        ),
        buildRestaurant(id: 'r5', name: 'Sans braise'),
      ];
      useCase = GetLiveBraise(
        FakeRestaurantRepository(restaurants: restaurants),
        FixedClock(testNow),
      );
    });

    test(
      'ne garde que les braises actives, triées par fin imminente',
      () async {
        // Awa termine dans 30 min, Baobab dans 2 h.
        final result = await useCase(const GetLiveBraiseParams());
        final List<LiveBraiseStatus> braises = result.fold(
          (failure) => throw StateError(failure.code),
          (value) => value,
        );
        expect(braises.map((braise) => braise.restaurantId), <String>[
          'r1',
          'r2',
        ]);
      },
    );

    test('respecte la limite demandée', () async {
      // Une seule braise pour un bandeau compact.
      final result = await useCase(const GetLiveBraiseParams(limit: 1));
      final List<LiveBraiseStatus> braises = result.fold(
        (failure) => throw StateError(failure.code),
        (value) => value,
      );
      expect(braises, hasLength(1));
      expect(braises.single.restaurantId, 'r1');
    });

    test('propage la Failure du repository', () async {
      // Une panne de cache ne doit pas devenir une exception.
      final GetLiveBraise failing = GetLiveBraise(
        FakeRestaurantRepository(failure: const CacheFailure()),
        FixedClock(testNow),
      );
      final result = await failing(const GetLiveBraiseParams());
      expect(result.isLeft(), isTrue);
      expect(
        result.fold((failure) => failure, (_) => const UnknownFailure()),
        isA<CacheFailure>(),
      );
    });
  });

  group('GetEventRadar', () {
    late List<EventRadar> events;
    late GetEventRadar useCase;

    setUp(() {
      // Un événement en cours, un à venir et un terminé.
      events = <EventRadar>[
        buildEvent(
          id: 'live',
          title: 'En cours',
          startsAt: testNow.subtract(const Duration(hours: 1)),
          endsAt: testNow.add(const Duration(hours: 1)),
        ),
        buildEvent(
          id: 'upcoming',
          title: 'À venir',
          startsAt: testNow.add(const Duration(hours: 2)),
          endsAt: testNow.add(const Duration(hours: 4)),
        ),
        buildEvent(
          id: 'finished',
          title: 'Terminé',
          startsAt: testNow.subtract(const Duration(hours: 5)),
          endsAt: testNow.subtract(const Duration(hours: 3)),
        ),
      ];
      useCase = GetEventRadar(
        FakeRestaurantRepository(events: events),
        FixedClock(testNow),
      );
    });

    test('masque les événements terminés et met le direct en tête', () async {
      // Seuls « live » et « upcoming » restent.
      final result = await useCase(const GetEventRadarParams());
      final List<EventRadar> radar = result.fold(
        (failure) => throw StateError(failure.code),
        (value) => value,
      );
      expect(radar.map((event) => event.id), <String>['live', 'upcoming']);
    });

    test('ne garde que le direct en mode onlyLive', () async {
      // Le filtre strict est utile pour le bandeau d'ambiance.
      final result = await useCase(const GetEventRadarParams(onlyLive: true));
      final List<EventRadar> radar = result.fold(
        (failure) => throw StateError(failure.code),
        (value) => value,
      );
      expect(radar, hasLength(1));
      expect(radar.single.id, 'live');
    });

    test('conserve l’historique quand includeFinished est vrai', () async {
      // Le mode historique renvoie les trois événements.
      final result = await useCase(
        const GetEventRadarParams(includeFinished: true),
      );
      final List<EventRadar> radar = result.fold(
        (failure) => throw StateError(failure.code),
        (value) => value,
      );
      expect(radar, hasLength(3));
      expect(radar.first.id, 'live');
    });

    test('propage la Failure du repository', () async {
      // Le use case ne transforme pas l'erreur métier.
      final GetEventRadar failing = GetEventRadar(
        FakeRestaurantRepository(failure: const NetworkFailure()),
        FixedClock(testNow),
      );
      final result = await failing(const GetEventRadarParams());
      expect(result.isLeft(), isTrue);
      expect(
        result.fold((failure) => failure, (_) => const UnknownFailure()),
        isA<NetworkFailure>(),
      );
    });
  });
}
