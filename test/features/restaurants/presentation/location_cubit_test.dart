// =============================================================================
// Tests du Cubit de localisation GPS.
// -----------------------------------------------------------------------------
// Le service est remplacé par un fake : on vérifie le cycle de vie
// (au repos -> chargement -> position ou échec) sans dépendre de `geolocator`.
// =============================================================================

// Framework de test.
import 'package:flutter_test/flutter_test.dart';

// Erreurs métier.
import 'package:koudougou_gourmet/core/error/failures.dart';

// Objet-valeur géographique.
import 'package:koudougou_gourmet/core/location/geo_point.dart';

// Cubit testé.
import 'package:koudougou_gourmet/features/restaurants/presentation/bloc/location_cubit.dart';

// Fixtures et doublures.
import '../support/fixtures.dart';

/// Point d'entrée des tests.
void main() {
  group('LocationCubit', () {
    test('démarre au repos', () {
      final LocationCubit cubit = LocationCubit(FakeLocationService());
      addTearDown(cubit.close);

      expect(cubit.state.status, LocationStatus.initial);
      expect(cubit.state.hasPosition, isFalse);
    });

    test('request publie la position obtenue', () async {
      // Position fixe au centre de Koudougou.
      final FakeLocationService service = FakeLocationService(
        position: const GeoPoint(latitude: 12.2528, longitude: -2.3669),
      );
      final LocationCubit cubit = LocationCubit(service);
      addTearDown(cubit.close);

      final Future<void> expected = expectLater(
        cubit.stream,
        emitsInOrder(<Matcher>[
          isA<LocationState>().having(
            (LocationState state) => state.status,
            'status',
            LocationStatus.loading,
          ),
          isA<LocationState>()
              .having(
                (LocationState state) => state.status,
                'status',
                LocationStatus.ready,
              )
              .having(
                (LocationState state) => state.hasPosition,
                'hasPosition',
                isTrue,
              ),
        ]),
      );

      await cubit.request();
      await expected;

      expect(cubit.state.position?.latitude, 12.2528);
      expect(cubit.state.position?.longitude, -2.3669);
      expect(service.calls, 1);
    });

    test('request publie la Failure du service', () async {
      final FakeLocationService service = FakeLocationService(
        failure: const PermissionFailure(message: 'Accès refusé.'),
      );
      final LocationCubit cubit = LocationCubit(service);
      addTearDown(cubit.close);

      final Future<void> expected = expectLater(
        cubit.stream,
        emitsInOrder(<Matcher>[
          isA<LocationState>().having(
            (LocationState state) => state.status,
            'status',
            LocationStatus.loading,
          ),
          isA<LocationState>()
              .having(
                (LocationState state) => state.status,
                'status',
                LocationStatus.failure,
              )
              .having(
                (LocationState state) => state.failure,
                'failure',
                isA<PermissionFailure>(),
              ),
        ]),
      );

      await cubit.request();
      await expected;

      expect(cubit.state.hasPosition, isFalse);
    });
  });
}
