// =============================================================================
// Tests de widgets de la Présentation.
// -----------------------------------------------------------------------------
// Ces tests montent de VRAIS widgets avec de VRAIS use cases, mais un FAUX
// repository et une horloge FIGÉE. Ils vérifient le rendu et le câblage
// BLoC -> widgets sans dépendre de Hive, de GetIt, du réseau ou du GPS.
// =============================================================================

// Widgets, Material et thème.
import 'package:flutter/material.dart';

// Framework de test Flutter.
import 'package:flutter_test/flutter_test.dart';

// Fournisseurs de BLoC.
import 'package:flutter_bloc/flutter_bloc.dart';

// Routes nommées (cible du raccourci vers l'annuaire).
import 'package:koudougou_gourmet/core/constants/app_routes.dart';

// Horloge figée (déterminisme).
import 'package:koudougou_gourmet/core/utils/app_clock.dart';

// Thème clair complet (palette sémantique incluse).
import 'package:koudougou_gourmet/core/theme/app_theme.dart';

// BLoC du catalogue, du radar et de l'annuaire.
import 'package:koudougou_gourmet/features/restaurants/presentation/bloc/ambiance_radar_bloc.dart';
import 'package:koudougou_gourmet/features/restaurants/presentation/bloc/ambiance_radar_event.dart';
import 'package:koudougou_gourmet/features/restaurants/presentation/bloc/directory_cubit.dart';
import 'package:koudougou_gourmet/features/restaurants/presentation/bloc/restaurant_list_bloc.dart';
import 'package:koudougou_gourmet/features/restaurants/presentation/bloc/restaurant_list_event.dart';

// Use cases réels consommés par les BLoC.
import 'package:koudougou_gourmet/features/restaurants/domain/usecases/filter_restaurants.dart';
import 'package:koudougou_gourmet/features/restaurants/domain/usecases/get_koudougou_directory.dart';
import 'package:koudougou_gourmet/features/restaurants/domain/usecases/get_event_radar.dart';
import 'package:koudougou_gourmet/features/restaurants/domain/usecases/get_favorite_ids.dart';
import 'package:koudougou_gourmet/features/restaurants/domain/usecases/get_live_braise.dart';
import 'package:koudougou_gourmet/features/restaurants/domain/usecases/get_restaurants.dart';
import 'package:koudougou_gourmet/features/restaurants/domain/usecases/toggle_favorite.dart';

// Entités utilisées dans les données de test.
import 'package:koudougou_gourmet/features/restaurants/domain/entities/event_radar.dart';
import 'package:koudougou_gourmet/features/restaurants/domain/entities/restaurant.dart';

// Page testée.
import 'package:koudougou_gourmet/features/restaurants/presentation/pages/home_page.dart';

// Carte de restaurant (périmètre de recherche des assertions).
import 'package:koudougou_gourmet/features/restaurants/presentation/widgets/restaurant_card.dart';

// Doublures et constructeurs partagés.
import 'features/restaurants/support/fixtures.dart';

/// Point d'entrée des tests de widgets.
void main() {
  /// Construit le catalogue de test.
  FakeRestaurantRepository buildRepository() {
    return FakeRestaurantRepository(
      restaurants: <Restaurant>[
        buildRestaurant(id: 'r1', name: 'Chez Awa'),
        buildRestaurant(id: 'r2', name: 'Le Baobab'),
      ],
      events: <EventRadar>[buildEvent(id: 'evt-1', restaurantId: 'r1')],
    );
  }

  /// Monte l'accueil avec ses deux BLoC et l'horloge figée.
  Future<void> pumpHome(
    WidgetTester tester,
    FakeRestaurantRepository repository, {
    Map<String, WidgetBuilder> routes = const <String, WidgetBuilder>{},
  }) async {
    // Surface haute : la liste est paresseuse, on veut que toutes les cartes
    // soient construites pour pouvoir les rechercher dans l'arbre.
    tester.view.physicalSize = const Size(1200, 2400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    // Horloge figée : lundi 16 novembre 2026, 19 h à Koudougou.
    final FixedClock clock = FixedClock(testNow);

    // BLoC du catalogue, démarré immédiatement.
    final RestaurantListBloc listBloc = RestaurantListBloc(
      getRestaurants: GetRestaurants(repository),
      filterRestaurants: FilterRestaurants(clock),
      getLiveBraise: GetLiveBraise(repository, clock),
      getFavoriteIds: GetFavoriteIds(repository),
      toggleFavorite: ToggleFavorite(repository),
      clock: clock,
    )..add(const RestaurantListStarted());

    // BLoC du radar, démarré immédiatement.
    final AmbianceRadarBloc radarBloc = AmbianceRadarBloc(
      getEventRadar: GetEventRadar(repository, clock),
      clock: clock,
    )..add(const AmbianceRadarStarted());

    // Cubit de l'annuaire sourcé (fixture vide, aucun réseau).
    final DirectoryCubit directoryCubit = DirectoryCubit(
      GetKoudougouDirectory(FakeDirectoryRepository()),
    );
    await directoryCubit.load();

    // Nettoyage automatique en fin de test.
    addTearDown(listBloc.close);
    addTearDown(radarBloc.close);
    addTearDown(directoryCubit.close);

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        routes: routes,
        home: MultiBlocProvider(
          providers: [
            BlocProvider<RestaurantListBloc>.value(value: listBloc),
            BlocProvider<AmbianceRadarBloc>.value(value: radarBloc),
            BlocProvider<DirectoryCubit>.value(value: directoryCubit),
          ],
          child: const HomePage(),
        ),
      ),
    );

    // Laisse les chargements asynchrones se terminer.
    await tester.pumpAndSettle();
  }

  testWidgets('garde le sur-titre puis pose la question du soir', (
    WidgetTester tester,
  ) async {
    await pumpHome(tester, buildRepository());

    // Le sur-titre reste affiché, la question suit immédiatement sa carte et
    // n'est pas dupliquée sous la recherche.
    expect(find.text('KOUGOUGOU · BURKINA FASO'), findsOneWidget);
    expect(find.text('Où mangez-vous ce soir ?'), findsOneWidget);

    final List<Text> texts = tester
        .widgetList<Text>(find.byType(Text))
        .toList();
    final int surTitleIndex = texts.indexWhere(
      (Text text) => text.data == 'KOUGOUGOU · BURKINA FASO',
    );
    expect(surTitleIndex, greaterThanOrEqualTo(0));
    expect(surTitleIndex + 1, lessThan(texts.length));
    expect(texts[surTitleIndex + 1].data, 'Où mangez-vous ce soir ?');

    // Les catégories/filtres supprimés ne sont plus proposés.
    expect(find.text('Grillades'), findsNothing);
    expect(find.text('Live Braise'), findsNothing);
  });

  testWidgets('vide la carte du sur-titre de ses anciens éléments', (
    WidgetTester tester,
  ) async {
    await pumpHome(tester, buildRepository());

    // Ni le titre/ sous-titre centraux, ni les deux boutons du bas.
    expect(find.text('Le goût de la ville,\nà portée de main.'), findsNothing);
    expect(
      find.text(
        'Maquis, grillades et cafés à Koudougou : trouvez votre '
        'prochaine table en quelques secondes.',
      ),
      findsNothing,
    );
    expect(find.textContaining('braise(s) en cours'), findsNothing);
    expect(find.text('Annuaire réel'), findsNothing);
  });

  testWidgets('affiche les restaurants chargés', (WidgetTester tester) async {
    // Catalogue non vide.
    await pumpHome(tester, buildRepository());

    // Les deux fiches sont visibles. Le nom peut aussi apparaître dans le
    // radar d'ambiance : on restreint la recherche aux cartes de restaurant.
    expect(
      find.descendant(
        of: find.byType(RestaurantCard),
        matching: find.text('Chez Awa'),
      ),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: find.byType(RestaurantCard),
        matching: find.text('Le Baobab'),
      ),
      findsOneWidget,
    );

    // Le compteur de résultats reflète le catalogue.
    expect(find.text('2 établissements trouvés'), findsOneWidget);
  });

  testWidgets('ouvre l’annuaire depuis le compteur de résultats', (
    WidgetTester tester,
  ) async {
    await pumpHome(
      tester,
      buildRepository(),
      routes: <String, WidgetBuilder>{
        AppRoutes.directory: (_) => const SizedBox(key: Key('directory-route')),
      },
    );

    // Le raccourci est unique et l'aperçu existant reste disponible.
    expect(find.text('Consulter l’annuaire'), findsOneWidget);
    expect(find.text('Explorer l’annuaire'), findsOneWidget);

    // L'appui ouvre la route nommée de l'annuaire.
    await tester.tap(find.text('Consulter l’annuaire'));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('directory-route')), findsOneWidget);
  });

  testWidgets('affiche l’état vide quand aucun restaurant ne correspond', (
    WidgetTester tester,
  ) async {
    // Catalogue volontairement vide.
    await pumpHome(tester, FakeRestaurantRepository());

    // Le message d'aide et le bouton de réinitialisation sont affichés.
    expect(find.text('Aucun résultat'), findsOneWidget);
    expect(find.text('Réinitialiser les filtres'), findsOneWidget);
  });
}
