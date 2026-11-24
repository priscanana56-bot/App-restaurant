// =============================================================================
// Tests du portail gérant.
// -----------------------------------------------------------------------------
// Ils couvrent la chaîne complète : code haché -> use case -> repository ->
// cache Hive simulé -> Cubit -> page. Le point clé est que CHAQUE écriture
// revérifie le code, même après déverrouillage de la page.
// =============================================================================

// Type fonctionnel.
import 'package:fpdart/fpdart.dart';

// Widgets et thème pour le test de page.
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';

// Failures et horloge.
import 'package:koudougou_gourmet/core/error/failures.dart';
import 'package:koudougou_gourmet/core/security/pin_auth.dart';
import 'package:koudougou_gourmet/core/theme/app_theme.dart';
import 'package:koudougou_gourmet/core/utils/app_clock.dart';

// Portail testé.
import 'package:koudougou_gourmet/features/owner_portal/domain/usecases/add_menu_item.dart';
import 'package:koudougou_gourmet/features/owner_portal/domain/usecases/get_owner_restaurants.dart';
import 'package:koudougou_gourmet/features/owner_portal/domain/usecases/has_owner_code.dart';
import 'package:koudougou_gourmet/features/owner_portal/domain/usecases/remove_menu_item.dart';
import 'package:koudougou_gourmet/features/owner_portal/domain/usecases/verify_owner_code.dart';
import 'package:koudougou_gourmet/features/owner_portal/presentation/bloc/owner_portal_cubit.dart';
import 'package:koudougou_gourmet/features/owner_portal/presentation/bloc/owner_portal_state.dart';
import 'package:koudougou_gourmet/features/owner_portal/presentation/pages/owner_portal_page.dart';

// Catalogue : repository, entités et use case.
import 'package:koudougou_gourmet/features/restaurants/data/models/event_radar_model.dart';
import 'package:koudougou_gourmet/features/restaurants/data/repositories/restaurant_repository_impl.dart';
import 'package:koudougou_gourmet/features/restaurants/domain/entities/menu_item.dart';
import 'package:koudougou_gourmet/features/restaurants/domain/entities/restaurant.dart';
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

/// Banc de test complet du portail.
final class _Rig {
  /// Construit le banc avec un code gérant déjà défini pour `r1`.
  _Rig() {
    local = FakeLocalDataSource(
      restaurants: sampleCatalog().restaurants,
      events: <EventRadarModel>[...sampleCatalog().events],
      lastSyncAt: testNow,
    );
    store = FakeSecureKeyStore();
    auth = PinAuthService(store, iterations: 1000);
    repository = RestaurantRepositoryImpl(
      localDataSource: local,
      seedDataSource: FakeSeedDataSource(catalog: sampleCatalog()),
      networkInfo: FakeNetworkInfo(),
      clock: FixedClock(testNow),
    );
    verifyCode = VerifyOwnerCode(auth);
    addItem = AddMenuItem(repository, verifyCode, FixedClock(testNow));
    removeItem = RemoveMenuItem(repository, verifyCode);
    cubit = OwnerPortalCubit(
      GetOwnerRestaurants(GetRestaurants(repository)),
      verifyCode,
      addItem,
      removeItem,
      HasOwnerCode(auth),
    );
  }

  /// Cache en mémoire.
  late final FakeLocalDataSource local;

  /// Coffre en mémoire.
  late final FakeSecureKeyStore store;

  /// Service d'authentification.
  late final PinAuthService auth;

  /// Repository réel sur cache simulé.
  late final RestaurantRepositoryImpl repository;

  /// Use cases du portail.
  late final VerifyOwnerCode verifyCode;
  late final AddMenuItem addItem;
  late final RemoveMenuItem removeItem;

  /// Cubit sous test.
  late final OwnerPortalCubit cubit;

  /// Enregistre le code de `r1`.
  Future<void> setCode(String code) async {
    _ok(await auth.setOwnerCode(restaurantId: 'r1', code: code));
  }
}

void main() {
  group('Use cases du portail gérant', () {
    test('sans code défini, aucun plat n’est ajouté', () async {
      final _Rig rig = _Rig();
      const AddMenuItemParams params = AddMenuItemParams(
        restaurantId: 'r1',
        code: '1234',
        name: 'Nouveau plat',
        description: '',
        section: MenuSection.mainDishes,
        priceFcfa: 1000,
        portionLabel: '1 portion',
        preparationMinutes: 15,
      );

      final Failure failure = _failure(await rig.addItem(params));

      expect(failure, isA<SecurityFailure>());
      expect(rig.local.writeRestaurantCalls, 0);
    });

    test('un mauvais code est refusé à chaque écriture', () async {
      final _Rig rig = _Rig();
      await rig.setCode('1234');
      const AddMenuItemParams params = AddMenuItemParams(
        restaurantId: 'r1',
        code: '9999',
        name: 'Nouveau plat',
        description: '',
        section: MenuSection.mainDishes,
        priceFcfa: 1000,
        portionLabel: '1 portion',
        preparationMinutes: 15,
      );

      final Failure failure = _failure(await rig.addItem(params));

      expect(failure, isA<SecurityFailure>());
      expect(rig.local.writeRestaurantCalls, 0);
      expect(
        _failure(
          await rig.removeItem(
            const RemoveMenuItemParams(
              restaurantId: 'r1',
              code: '9999',
              itemId: 'r1-to',
            ),
          ),
        ),
        isA<SecurityFailure>(),
      );
      expect(rig.local.writeRestaurantCalls, 0);
    });

    test('un code valide permet d’ajouter un plat nettoyé', () async {
      final _Rig rig = _Rig();
      await rig.setCode('1234');

      final Restaurant updated = _ok(
        await rig.addItem(
          const AddMenuItemParams(
            restaurantId: 'r1',
            code: '1234',
            name: '<b>Attiéké poisson</b>',
            description: 'Poisson braisé\nservi avec alloco',
            section: MenuSection.grills,
            priceFcfa: 2500,
            portionLabel: '1 personne',
            preparationMinutes: 20,
            isSignature: true,
          ),
        ),
      );

      final MenuItem added = updated.menu.last;
      expect(added.name, 'Attiéké poisson');
      expect(added.description, isNot(contains('<b>')));
      expect(added.description, isNot(contains('\n')));
      expect(added.priceFcfa, 2500);
      expect(added.isSignature, isTrue);
      expect(added.id, startsWith('dish_r1_'));
      expect(rig.local.writeRestaurantCalls, 1);
    });

    test('un code valide permet de retirer un plat', () async {
      final _Rig rig = _Rig();
      await rig.setCode('1234');

      final Restaurant updated = _ok(
        await rig.removeItem(
          const RemoveMenuItemParams(
            restaurantId: 'r1',
            code: '1234',
            itemId: 'r1-to',
          ),
        ),
      );

      expect(
        updated.menu.map((MenuItem item) => item.id),
        isNot(contains('r1-to')),
      );
      expect(rig.local.writeRestaurantCalls, 1);
    });

    test('un prix invalide est refusé même avec un bon code', () async {
      final _Rig rig = _Rig();
      await rig.setCode('1234');

      final Failure failure = _failure(
        await rig.addItem(
          const AddMenuItemParams(
            restaurantId: 'r1',
            code: '1234',
            name: 'Plat gratuit',
            description: '',
            section: MenuSection.mainDishes,
            priceFcfa: 0,
            portionLabel: '',
            preparationMinutes: 10,
          ),
        ),
      );

      expect(failure, isA<ValidationFailure>());
      expect(rig.local.writeRestaurantCalls, 0);
    });
  });

  group('OwnerPortalCubit', () {
    test('charge, vérifie le code puis modifie le menu affiché', () async {
      final _Rig rig = _Rig();
      await rig.setCode('1234');
      addTearDown(rig.cubit.close);

      await rig.cubit.load();
      expect(rig.cubit.state.status, OwnerPortalStatus.ready);
      expect(rig.cubit.state.selectedRestaurantId, 'r1');

      await rig.cubit.unlock('9999');
      expect(rig.cubit.state.isUnlocked, isFalse);
      expect(rig.cubit.state.failure, isA<SecurityFailure>());

      await rig.cubit.unlock('1234');
      expect(rig.cubit.state.isUnlocked, isTrue);

      await rig.cubit.addDish(
        code: '1234',
        name: 'Fufu sauce arachide',
        description: '',
        section: MenuSection.mainDishes,
        priceFcfa: 1200,
        portionLabel: '1 portion',
        preparationMinutes: 15,
      );
      expect(rig.cubit.state.failure, isNull);
      expect(
        rig.cubit.state.selectedRestaurant!.menu.map(
          (MenuItem item) => item.name,
        ),
        contains('Fufu sauce arachide'),
      );

      final String dishId = rig.cubit.state.selectedRestaurant!.menu.last.id;
      await rig.cubit.removeDish(code: '1234', itemId: dishId);
      expect(rig.cubit.state.failure, isNull);
      expect(
        rig.cubit.state.selectedRestaurant!.menu.map(
          (MenuItem item) => item.id,
        ),
        isNot(contains(dishId)),
      );
    });

    test('changer d’établissement relock l’accès', () async {
      final _Rig rig = _Rig();
      await rig.setCode('1234');
      addTearDown(rig.cubit.close);

      await rig.cubit.load();
      await rig.cubit.unlock('1234');
      expect(rig.cubit.state.isUnlocked, isTrue);

      rig.cubit.selectRestaurant('r2');
      expect(rig.cubit.state.selectedRestaurantId, 'r2');
      expect(rig.cubit.state.isUnlocked, isFalse);
    });

    test(
      'une fiche peut être présélectionnée depuis la fiche détaillée',
      () async {
        final _Rig rig = _Rig();
        addTearDown(rig.cubit.close);

        await rig.cubit.load(initialRestaurantId: 'r2');

        expect(rig.cubit.state.status, OwnerPortalStatus.ready);
        expect(rig.cubit.state.selectedRestaurantId, 'r2');
      },
    );

    test('un identifiant inconnu retombe sur la première fiche', () async {
      final _Rig rig = _Rig();
      addTearDown(rig.cubit.close);

      await rig.cubit.load(initialRestaurantId: 'inexistant');

      expect(rig.cubit.state.selectedRestaurantId, 'r1');
    });

    test('le verrouillage explicite bloque toute écriture suivante', () async {
      final _Rig rig = _Rig();
      await rig.setCode('1234');
      addTearDown(rig.cubit.close);

      await rig.cubit.load();
      await rig.cubit.unlock('1234');
      expect(rig.cubit.state.isUnlocked, isTrue);

      rig.cubit.lock();
      expect(rig.cubit.state.isUnlocked, isFalse);

      await rig.cubit.addDish(
        code: '1234',
        name: 'Plat après verrouillage',
        description: '',
        section: MenuSection.mainDishes,
        priceFcfa: 1000,
        portionLabel: '1 portion',
        preparationMinutes: 10,
      );
      expect(rig.local.writeRestaurantCalls, 0);
    });
  });

  testWidgets('la page affiche l’avertissement et le sélecteur', (
    WidgetTester tester,
  ) async {
    final _Rig rig = _Rig();
    addTearDown(rig.cubit.close);

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: BlocProvider<OwnerPortalCubit>.value(
          value: rig.cubit,
          child: const OwnerPortalPage(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Portail gérant'), findsOneWidget);
    expect(find.text('Établissement à gérer'), findsOneWidget);
    expect(find.text('Code gérant'), findsOneWidget);
  });
}
