// =============================================================================
// Tests du portail créatrice.
// -----------------------------------------------------------------------------
// Ils vérifient la sécurité du PIN local, l'ordre d'écriture (code gérant avant
// la fiche) et l'absence de certification inventée sur les fiches créées.
// =============================================================================

// Type fonctionnel.
import 'package:fpdart/fpdart.dart';

// Widgets et thème pour le test de page.
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';

// Erreurs, sécurité, thème et horloge.
import 'package:koudougou_gourmet/core/error/error_mapper.dart';
import 'package:koudougou_gourmet/core/error/failures.dart';
import 'package:koudougou_gourmet/core/security/pin_auth.dart';
import 'package:koudougou_gourmet/core/theme/app_theme.dart';
import 'package:koudougou_gourmet/core/utils/app_clock.dart';

// Portail testé.
import 'package:koudougou_gourmet/features/creator_portal/domain/usecases/assign_owner_code.dart';
import 'package:koudougou_gourmet/features/creator_portal/domain/usecases/create_establishment.dart';
import 'package:koudougou_gourmet/features/creator_portal/domain/usecases/has_creator_pin.dart';
import 'package:koudougou_gourmet/features/creator_portal/domain/usecases/set_creator_pin.dart';
import 'package:koudougou_gourmet/features/creator_portal/domain/usecases/verify_creator_pin.dart';
import 'package:koudougou_gourmet/features/creator_portal/presentation/bloc/creator_portal_cubit.dart';
import 'package:koudougou_gourmet/features/creator_portal/presentation/bloc/creator_portal_state.dart';
import 'package:koudougou_gourmet/features/creator_portal/presentation/pages/creator_portal_page.dart';

// Catalogue.
import 'package:koudougou_gourmet/features/restaurants/data/models/event_radar_model.dart';
import 'package:koudougou_gourmet/features/restaurants/data/repositories/restaurant_repository_impl.dart';
import 'package:koudougou_gourmet/features/restaurants/domain/entities/opening_hours.dart';
import 'package:koudougou_gourmet/features/restaurants/domain/entities/restaurant.dart';
import 'package:koudougou_gourmet/features/restaurants/domain/entities/restaurant_category.dart';
import 'package:koudougou_gourmet/features/restaurants/domain/repositories/restaurant_repository.dart';
import 'package:koudougou_gourmet/features/restaurants/domain/usecases/get_restaurants.dart';

// Doublures partagées.
import '../../support/fake_secure_key_store.dart';
import '../restaurants/support/fixtures.dart';

/// Extrait la valeur de droite, ou échoue le test.
T _ok<T>(Either<Failure, T> result) => result.fold(
  (Failure failure) => throw StateError('Échec inattendu : ${failure.message}'),
  (T value) => value,
);

/// Extrait la `Failure` de gauche, ou échoue le test.
Failure _failure<T>(Either<Failure, T> result) => result.fold(
  (Failure failure) => failure,
  (T _) => throw StateError('Succès inattendu.'),
);

/// Paramètres de création valides par défaut.
CreateEstablishmentParams _params({
  String pin = '1234',
  String name = 'Maquis du Marché',
  String sector = 'Secteur 4',
  String landmark = 'Grand marché',
  String phone = '+22670123456',
  String ownerCode = '5678',
}) {
  return CreateEstablishmentParams(
    creatorPin: pin,
    name: name,
    category: RestaurantCategory.maquis,
    sector: sector,
    landmark: landmark,
    phone: phone,
    address: 'Près du grand marché',
    ownerCode: ownerCode,
  );
}

/// Banc de test complet du portail.
final class _Rig {
  /// Construit le banc avec un PIN créateur déjà enregistré.
  _Rig() {
    local = FakeLocalDataSource(
      restaurants: sampleCatalog().restaurants,
      events: <EventRadarModel>[...sampleCatalog().events],
      lastSyncAt: testNow,
    );
    store = FakeSecureKeyStore();
    // Coût PBKDF2 réduit : le test vérifie la logique, pas la résistance brute.
    auth = PinAuthService(store, iterations: 1000);
    repository = RestaurantRepositoryImpl(
      localDataSource: local,
      seedDataSource: FakeSeedDataSource(catalog: sampleCatalog()),
      networkInfo: FakeNetworkInfo(),
      clock: FixedClock(testNow),
    );
    verifyPin = VerifyCreatorPin(auth);
    create = CreateEstablishment(
      repository,
      verifyPin,
      auth,
      FixedClock(testNow),
    );
    hasPin = HasCreatorPin(auth, const ErrorMapper());
    setPin = SetCreatorPin(auth);
    assignCode = AssignOwnerCode(repository, verifyPin, auth);
    getRestaurants = GetRestaurants(repository);
    cubit = CreatorPortalCubit(
      hasPin,
      setPin,
      verifyPin,
      create,
      assignCode,
      getRestaurants,
    );
  }

  /// Construit un banc dont le repository refuse toutes les écritures.
  _Rig.withFailingRepository() {
    local = FakeLocalDataSource();
    store = FakeSecureKeyStore();
    auth = PinAuthService(store, iterations: 1000);
    repository = FakeRestaurantRepository(
      failure: const CacheFailure(message: 'Écriture refusée.'),
    );
    verifyPin = VerifyCreatorPin(auth);
    create = CreateEstablishment(
      repository,
      verifyPin,
      auth,
      FixedClock(testNow),
    );
    hasPin = HasCreatorPin(auth, const ErrorMapper());
    setPin = SetCreatorPin(auth);
    assignCode = AssignOwnerCode(repository, verifyPin, auth);
    getRestaurants = GetRestaurants(repository);
    cubit = CreatorPortalCubit(
      hasPin,
      setPin,
      verifyPin,
      create,
      assignCode,
      getRestaurants,
    );
  }

  /// Cache en mémoire.
  late final FakeLocalDataSource local;

  /// Coffre en mémoire.
  late final FakeSecureKeyStore store;

  /// Service d'authentification.
  late final PinAuthService auth;

  /// Repository sous test (réel ou en échec).
  late final RestaurantRepository repository;

  /// Use cases du portail.
  late final HasCreatorPin hasPin;
  late final SetCreatorPin setPin;
  late final VerifyCreatorPin verifyPin;
  late final CreateEstablishment create;
  late final AssignOwnerCode assignCode;
  late final GetRestaurants getRestaurants;

  /// Cubit sous test.
  late final CreatorPortalCubit cubit;

  /// Enregistre le PIN créateur.
  Future<void> registerPin() async {
    _ok(await setPin('1234'));
  }
}

void main() {
  group('Use cases du portail créatrice', () {
    test('le PIN doit être créé avant d’être vérifié', () async {
      final _Rig rig = _Rig();

      expect(_ok(await rig.hasPin()), isFalse);
      expect(_failure(await rig.verifyPin('1234')), isA<SecurityFailure>());

      _ok(await rig.setPin('1234'));
      expect(_ok(await rig.hasPin()), isTrue);
      expect(_ok(await rig.verifyPin('1234')), isTrue);
      expect(_ok(await rig.verifyPin('9999')), isFalse);
    });

    test('un mauvais PIN empêche toute création', () async {
      final _Rig rig = _Rig();
      await rig.registerPin();

      // Le PIN administrateur existe déjà : on vérifie qu'aucun NOUVEAU code
      // gérant n'est enregistré et qu'aucune fiche n'est écrite. Le service
      // peut en revanche enregistrer un compteur d'échecs : c'est attendu.
      final int writesBefore = rig.local.writeRestaurantCalls;
      final Failure failure = _failure(await rig.create(_params(pin: '0000')));

      expect(failure, isA<SecurityFailure>());
      expect(rig.local.writeRestaurantCalls, writesBefore);
      expect(
        rig.store.secrets.keys.any(
          (String key) => key.startsWith('owner_pin_v1_local_'),
        ),
        isFalse,
      );
    });

    test(
      'une fiche créée n’est ni vérifiée ni notée, sans horaires inventés',
      () async {
        final _Rig rig = _Rig();
        await rig.registerPin();

        final Restaurant created = _ok(await rig.create(_params()));

        expect(created.id, startsWith('local_'));
        expect(created.name, 'Maquis du Marché');
        expect(created.isVerified, isFalse);
        expect(created.verifiedAt, isNull);
        expect(created.rating, 0);
        expect(created.reviewCount, 0);
        expect(created.menu, isEmpty);
        expect(created.liveBraise, isNull);
        expect(
          created.openingHours.weekly.values.every(
            (DaySchedule? day) => day == null,
          ),
          isTrue,
        );
        // GPS volontairement approximatif : centre-ville, pas une fausse précision.
        expect(created.latitude, isA<double>());
        expect(created.longitude, isA<double>());
        expect(rig.local.writeRestaurantCalls, 1);
      },
    );

    test('le code gérant est enregistré avant la fiche', () async {
      final _Rig rig = _Rig();
      await rig.registerPin();
      rig.store.writeOrder.clear();

      await rig.create(_params());

      expect(rig.store.writeOrder.first, startsWith('owner_pin_v1_local_'));
      expect(rig.store.containsPlainText('5678'), isFalse);
      expect(
        _ok(
          await rig.auth.verifyOwnerCode(
            restaurantId: rig.local.restaurants.last.id,
            code: '5678',
          ),
        ),
        isTrue,
      );
    });

    test('si le catalogue échoue, le code gérant reste enregistré', () async {
      final _Rig rig = _Rig.withFailingRepository();
      await rig.registerPin();

      final Failure failure = _failure(await rig.create(_params()));

      expect(failure, isA<CacheFailure>());
      expect(
        rig.store.secrets.keys.any(
          (String key) => key.startsWith('owner_pin_v1_local_'),
        ),
        isTrue,
      );
    });

    test('les champs invalides sont refusés avant toute écriture', () async {
      final _Rig rig = _Rig();
      await rig.registerPin();

      expect(
        _failure(await rig.create(_params(name: '<script></script>'))),
        isA<ValidationFailure>(),
      );
      expect(
        _failure(await rig.create(_params(sector: 'Village fictif'))),
        isA<ValidationFailure>(),
      );
      expect(
        _failure(await rig.create(_params(phone: '06 12 34'))),
        isA<ValidationFailure>(),
      );
      expect(rig.local.writeRestaurantCalls, 0);
    });
  });

  group('Attribution d’un code gérant', () {
    test('une fiche existante reçoit un code sans créer de fiche', () async {
      final _Rig rig = _Rig();
      await rig.registerPin();

      final Unit result = _ok(
        await rig.assignCode(
          const AssignOwnerCodeParams(
            adminPin: '1234',
            restaurantId: 'r1',
            code: '9876',
          ),
        ),
      );

      expect(result, unit);
      expect(rig.local.writeRestaurantCalls, 0);
      expect(rig.store.containsPlainText('9876'), isFalse);
      expect(
        _ok(await rig.auth.verifyOwnerCode(restaurantId: 'r1', code: '9876')),
        isTrue,
      );
    });

    test('un mauvais PIN administrateur interdit l’attribution', () async {
      final _Rig rig = _Rig();
      await rig.registerPin();

      final Failure failure = _failure(
        await rig.assignCode(
          const AssignOwnerCodeParams(
            adminPin: '0000',
            restaurantId: 'r1',
            code: '9876',
          ),
        ),
      );

      expect(failure, isA<SecurityFailure>());
      expect(await rig.auth.hasOwnerCode('r1'), isFalse);
    });

    test('une fiche absente du catalogue est refusée', () async {
      final _Rig rig = _Rig();
      await rig.registerPin();

      final Failure failure = _failure(
        await rig.assignCode(
          const AssignOwnerCodeParams(
            adminPin: '1234',
            restaurantId: 'inconnu',
            code: '9876',
          ),
        ),
      );

      expect(failure, isA<NotFoundFailure>());
      expect(rig.store.secrets.keys, isNot(contains('owner_pin_v1_inconnu')));
    });
  });

  group('CreatorPortalCubit', () {
    test('premier lancement : création du PIN puis connexion', () async {
      final _Rig rig = _Rig();
      addTearDown(rig.cubit.close);

      await rig.cubit.load();
      expect(rig.cubit.state.phase, CreatorPortalPhase.setupPin);

      await rig.cubit.setPin(pin: '1234', confirmation: '9999');
      expect(rig.cubit.state.failure, isA<ValidationFailure>());
      expect(rig.cubit.state.phase, CreatorPortalPhase.setupPin);

      await rig.cubit.setPin(pin: '1234', confirmation: '1234');
      expect(rig.cubit.state.phase, CreatorPortalPhase.login);

      await rig.cubit.login('9999');
      expect(rig.cubit.state.failure, isA<SecurityFailure>());

      await rig.cubit.login('1234');
      expect(rig.cubit.state.phase, CreatorPortalPhase.unlocked);

      await rig.cubit.create(
        creatorPin: '1234',
        name: 'Café du Centre',
        category: RestaurantCategory.cafe,
        sector: 'Secteur 4',
        landmark: 'Centre-ville',
        phone: '+22670123456',
        address: '',
        ownerCode: '5678',
      );
      expect(rig.cubit.state.failure, isNull);
      expect(rig.cubit.state.createdRestaurant?.name, 'Café du Centre');

      // L'attribution fonctionne aussi sur une fiche du catalogue embarqué.
      await rig.cubit.assignCode(
        adminPin: '1234',
        restaurantId: 'r1',
        code: '9876',
      );
      expect(rig.cubit.state.failure, isNull);
      expect(rig.cubit.state.infoMessage, contains('Code gérant attribué'));
      expect(
        _ok(await rig.auth.verifyOwnerCode(restaurantId: 'r1', code: '9876')),
        isTrue,
      );

      rig.cubit.lock();
      expect(rig.cubit.state.phase, CreatorPortalPhase.login);
    });
  });

  testWidgets('la page demande d’abord le PIN créateur', (
    WidgetTester tester,
  ) async {
    final _Rig rig = _Rig();
    addTearDown(rig.cubit.close);

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: BlocProvider<CreatorPortalCubit>.value(
          value: rig.cubit,
          child: const CreatorPortalPage(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Administration'), findsOneWidget);
    expect(find.text('Créer le code administrateur'), findsOneWidget);
    expect(find.text('Confirmer le code'), findsOneWidget);
  });
}
