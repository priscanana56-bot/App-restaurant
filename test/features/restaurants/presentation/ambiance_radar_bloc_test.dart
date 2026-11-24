// =============================================================================
// Tests du BLoC du radar d'ambiance.
// -----------------------------------------------------------------------------
// Le filtrage temporel est assuré par le use case ; ces tests vérifient le
// pilotage du BLoC : chargement, échec, masquage des événements terminés et
// bascule du filtre « uniquement en direct ».
// =============================================================================

// Framework de test.
import 'package:flutter_test/flutter_test.dart';

// Erreurs métier.
import 'package:koudougou_gourmet/core/error/failures.dart';

// Horloge figée.
import 'package:koudougou_gourmet/core/utils/app_clock.dart';

// Entité.
import 'package:koudougou_gourmet/features/restaurants/domain/entities/event_radar.dart';

// Use case réel.
import 'package:koudougou_gourmet/features/restaurants/domain/usecases/get_event_radar.dart';

// BLoC testé.
import 'package:koudougou_gourmet/features/restaurants/presentation/bloc/ambiance_radar_bloc.dart';
import 'package:koudougou_gourmet/features/restaurants/presentation/bloc/ambiance_radar_event.dart';
import 'package:koudougou_gourmet/features/restaurants/presentation/bloc/ambiance_radar_state.dart';

// Fixtures et doublures.
import '../support/fixtures.dart';

/// Construit le BLoC sur un faux repository et une horloge figée.
AmbianceRadarBloc _buildBloc(FakeRestaurantRepository repository) {
  final FixedClock clock = FixedClock(testNow);
  return AmbianceRadarBloc(
    getEventRadar: GetEventRadar(repository, clock),
    clock: clock,
  );
}

/// Matcher d'un état au statut [status] donné.
Matcher _stateWith(AmbianceRadarStatus status) => isA<AmbianceRadarState>()
    .having((AmbianceRadarState state) => state.status, 'status', status);

/// Point d'entrée des tests.
void main() {
  group('AmbianceRadarBloc', () {
    test('charge les événements à venir', () async {
      final FakeRestaurantRepository repository = FakeRestaurantRepository(
        events: <EventRadar>[
          buildEvent(
            id: 'e1',
            startsAt: testNow.add(const Duration(hours: 1)),
            endsAt: testNow.add(const Duration(hours: 4)),
          ),
        ],
      );
      final AmbianceRadarBloc bloc = _buildBloc(repository);
      addTearDown(bloc.close);

      final Future<void> expected = expectLater(
        bloc.stream,
        emitsInOrder(<Matcher>[
          _stateWith(AmbianceRadarStatus.loading),
          _stateWith(AmbianceRadarStatus.ready),
        ]),
      );

      bloc.add(const AmbianceRadarStarted());
      await expected;

      expect(bloc.state.events, hasLength(1));
      expect(bloc.state.now, testNow);
    });

    test('publie une Failure quand le repository échoue', () async {
      final FakeRestaurantRepository repository = FakeRestaurantRepository(
        failure: const NetworkFailure(),
      );
      final AmbianceRadarBloc bloc = _buildBloc(repository);
      addTearDown(bloc.close);

      final Future<void> expected = expectLater(
        bloc.stream,
        emitsInOrder(<Matcher>[
          _stateWith(AmbianceRadarStatus.loading),
          isA<AmbianceRadarState>()
              .having(
                (AmbianceRadarState state) => state.status,
                'status',
                AmbianceRadarStatus.failure,
              )
              .having(
                (AmbianceRadarState state) => state.failure,
                'failure',
                isA<NetworkFailure>(),
              ),
        ]),
      );

      bloc.add(const AmbianceRadarStarted());
      await expected;
    });

    test('masque les événements déjà terminés', () async {
      final FakeRestaurantRepository repository = FakeRestaurantRepository(
        events: <EventRadar>[
          // Terminé avant l'instant de référence.
          buildEvent(
            id: 'fini',
            startsAt: testNow.subtract(const Duration(hours: 4)),
            endsAt: testNow.subtract(const Duration(hours: 1)),
          ),
          // À venir.
          buildEvent(
            id: 'avenir',
            startsAt: testNow.add(const Duration(hours: 2)),
            endsAt: testNow.add(const Duration(hours: 5)),
          ),
        ],
      );
      final AmbianceRadarBloc bloc = _buildBloc(repository);
      addTearDown(bloc.close);

      bloc.add(const AmbianceRadarStarted());
      final AmbianceRadarState state = await bloc.stream.firstWhere(
        (AmbianceRadarState value) => value.status == AmbianceRadarStatus.ready,
      );

      expect(state.events, hasLength(1));
      expect(state.events.single.id, 'avenir');
    });

    test('le filtre « en direct » ne garde que l’événement en cours', () async {
      final FakeRestaurantRepository repository = FakeRestaurantRepository(
        events: <EventRadar>[
          // En cours à l'instant de référence.
          buildEvent(
            id: 'en-cours',
            startsAt: testNow.subtract(const Duration(hours: 1)),
            endsAt: testNow.add(const Duration(hours: 1)),
          ),
          // À venir.
          buildEvent(
            id: 'a-venir',
            startsAt: testNow.add(const Duration(hours: 2)),
            endsAt: testNow.add(const Duration(hours: 5)),
          ),
        ],
      );
      final AmbianceRadarBloc bloc = _buildBloc(repository);
      addTearDown(bloc.close);

      bloc.add(const AmbianceRadarStarted());
      await bloc.stream.firstWhere(
        (AmbianceRadarState state) => state.status == AmbianceRadarStatus.ready,
      );

      // Après bascule : uniquement l'événement en direct.
      final Future<AmbianceRadarState> next = bloc.stream.firstWhere(
        (AmbianceRadarState state) =>
            state.status == AmbianceRadarStatus.ready &&
            state.onlyLive &&
            state.events.length == 1,
      );
      bloc.add(const AmbianceRadarOnlyLiveToggled());
      final AmbianceRadarState state = await next;

      expect(state.onlyLive, isTrue);
      expect(state.events.single.id, 'en-cours');
    });
  });
}
