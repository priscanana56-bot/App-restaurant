// =============================================================================
// Tests du filtrage local et du tri.
// -----------------------------------------------------------------------------
// Le filtrage doit être rapide, sans réseau, insensible aux accents, et prendre
// en compte les horaires / la braise à l'heure exacte fournie par l'horloge.
// =============================================================================

// Framework de test.
import 'package:flutter_test/flutter_test.dart';

// Horloge figée.
import 'package:koudougou_gourmet/core/utils/app_clock.dart';

// Entités et filtre.
import 'package:koudougou_gourmet/features/restaurants/domain/entities/menu_item.dart';
import 'package:koudougou_gourmet/features/restaurants/domain/entities/restaurant.dart';
import 'package:koudougou_gourmet/features/restaurants/domain/entities/restaurant_category.dart';
import 'package:koudougou_gourmet/features/restaurants/domain/entities/restaurant_filter.dart';

// Use case testé.
import 'package:koudougou_gourmet/features/restaurants/domain/usecases/filter_restaurants.dart';

// Fixtures.
import '../support/fixtures.dart';

/// Applique le use case et extrait la liste de succès.
Future<List<Restaurant>> _filter(
  FilterRestaurants useCase,
  List<Restaurant> restaurants,
  RestaurantFilter filter,
) async {
  final result = await useCase(
    FilterRestaurantsParams(restaurants: restaurants, filter: filter),
  );
  return result.fold(
    (failure) => throw StateError('Filtrage en échec : ${failure.code}'),
    (value) => value,
  );
}

/// Point d'entrée des tests.
void main() {
  late FilterRestaurants useCase;
  late List<Restaurant> restaurants;

  setUp(() {
    // Horloge déterministe : lundi 19 h.
    useCase = FilterRestaurants(FixedClock(testNow));

    restaurants = <Restaurant>[
      // Ouvert, braise active, ambiance forte, économique.
      buildRestaurant(
        id: 'r1',
        name: 'Chez Awa',
        category: RestaurantCategory.maquis,
        sector: 'Secteur 4',
        landmark: 'Grand marché',
        rating: 4.6,
        reviewCount: 10,
        averagePriceFcfa: 1000,
        ambianceScore: 80,
        liveBraise: buildLiveBraise(),
        menu: <MenuItem>[
          buildMenuItem(id: 'r1-to', name: 'Tô sauce gombo', priceFcfa: 700),
          buildMenuItem(
            id: 'r1-poulet',
            name: 'Poulet braisé',
            section: MenuSection.grills,
            priceFcfa: 3000,
          ),
        ],
      ),
      // Ouvert, sans braise, premium, peu animé, non vérifié.
      buildRestaurant(
        id: 'r2',
        name: 'Le Baobab',
        category: RestaurantCategory.cafe,
        sector: 'Secteur 5',
        landmark: 'Centre-ville',
        rating: 4.2,
        reviewCount: 20,
        priceRange: PriceRange.premium,
        averagePriceFcfa: 3500,
        ambianceScore: 40,
        isVerified: false,
        menu: <MenuItem>[
          buildMenuItem(
            id: 'r2-brochettes',
            name: 'Brochettes de bœuf',
            section: MenuSection.grills,
            priceFcfa: 1500,
          ),
        ],
      ),
      // Fermé à 19 h (service du matin), note maximale, économique.
      buildRestaurant(
        id: 'r3',
        name: 'Tô de Mariam',
        category: RestaurantCategory.restaurant,
        sector: 'Secteur 3',
        landmark: 'Gare routière',
        rating: 4.8,
        reviewCount: 30,
        averagePriceFcfa: 700,
        ambianceScore: 50,
        openingHours: standardOpeningHours(
          opensAtMinute: 390,
          closesAtMinute: 900,
        ),
        menu: <MenuItem>[
          buildMenuItem(id: 'r3-riz', name: 'Riz sauce', priceFcfa: 700),
        ],
      ),
    ];
  });

  group('Recherche plein texte', () {
    test('trouve un restaurant par son repère, sans accent', () async {
      // « marché » et « marche » doivent produire le même résultat.
      final List<Restaurant> result = await _filter(
        useCase,
        restaurants,
        const RestaurantFilter(query: 'grand marche'),
      );
      expect(result.map((restaurant) => restaurant.id), <String>['r1']);
    });

    test('trouve un restaurant par un plat de son menu', () async {
      // Le mot « poulet » n'est pas dans le nom mais dans le menu.
      final List<Restaurant> result = await _filter(
        useCase,
        restaurants,
        const RestaurantFilter(query: 'poulet'),
      );
      expect(result.map((restaurant) => restaurant.id), <String>['r1']);
    });

    test('neutralise les balises avant la recherche', () async {
      // Une tentative d'injection ne doit pas casser le filtrage.
      final List<Restaurant> result = await _filter(
        useCase,
        restaurants,
        const RestaurantFilter(query: '<b>poulet</b>'),
      );
      expect(result.map((restaurant) => restaurant.id), <String>['r1']);
    });

    test('exige la présence de tous les mots', () async {
      // « grand poulet » exige les deux mots dans le même restaurant.
      final List<Restaurant> result = await _filter(
        useCase,
        restaurants,
        const RestaurantFilter(query: 'grand poulet'),
      );
      expect(result.map((restaurant) => restaurant.id), <String>['r1']);
    });
  });

  group('Critères', () {
    test('filtre par catégorie', () async {
      // Seul Le Baobab est classé « Café / Pâtisserie ».
      final List<Restaurant> result = await _filter(
        useCase,
        restaurants,
        const RestaurantFilter(category: RestaurantCategory.cafe),
      );
      expect(result.map((restaurant) => restaurant.id), <String>['r2']);
    });

    test('filtre par secteur', () async {
      // Le secteur est comparé après normalisation.
      final List<Restaurant> result = await _filter(
        useCase,
        restaurants,
        const RestaurantFilter(sector: 'Secteur 5'),
      );
      expect(result.map((restaurant) => restaurant.id), <String>['r2']);
    });

    test('filtre par tranche de prix', () async {
      // Budget : Chez Awa et Tô de Mariam.
      final List<Restaurant> result = await _filter(
        useCase,
        restaurants,
        const RestaurantFilter(priceRange: PriceRange.budget),
      );
      expect(result.map((restaurant) => restaurant.id), <String>['r1', 'r3']);
    });

    test('ne garde que les restaurants ouverts maintenant', () async {
      // À 19 h, le service du matin de Mariam est terminé.
      final List<Restaurant> result = await _filter(
        useCase,
        restaurants,
        const RestaurantFilter(onlyOpenNow: true),
      );
      expect(result.map((restaurant) => restaurant.id), <String>['r1', 'r2']);
    });

    test('ne garde que les braises actives', () async {
      // La braise de Chez Awa est active ; les autres n'en ont pas.
      final List<Restaurant> result = await _filter(
        useCase,
        restaurants,
        const RestaurantFilter(onlyLiveBraise: true),
      );
      expect(result.map((restaurant) => restaurant.id), <String>['r1']);
    });

    test('ne garde que les fiches vérifiées', () async {
      // Le Baobab n'a pas encore été contrôlé sur place.
      final List<Restaurant> result = await _filter(
        useCase,
        restaurants,
        const RestaurantFilter(onlyVerified: true),
      );
      expect(result.map((restaurant) => restaurant.id), <String>['r1', 'r3']);
    });

    test('applique une note minimale', () async {
      // Seules les notes >= 4,6 restent.
      final List<Restaurant> result = await _filter(
        useCase,
        restaurants,
        const RestaurantFilter(minRating: 4.6),
      );
      expect(result.map((restaurant) => restaurant.id), <String>['r1', 'r3']);
    });
  });

  group('Tri', () {
    test('trie par note décroissante', () async {
      // Mariam (4,8), Awa (4,6), Baobab (4,2).
      final List<Restaurant> result = await _filter(
        useCase,
        restaurants,
        const RestaurantFilter(sort: RestaurantSort.ratingDesc),
      );
      expect(result.map((restaurant) => restaurant.id), <String>[
        'r3',
        'r1',
        'r2',
      ]);
    });

    test('trie par prix croissant puis par nom', () async {
      // Mariam et Awa sont à 1 000/700 : Mariam reste devant.
      final List<Restaurant> result = await _filter(
        useCase,
        restaurants,
        const RestaurantFilter(sort: RestaurantSort.priceAsc),
      );
      expect(result.map((restaurant) => restaurant.id), <String>[
        'r3',
        'r1',
        'r2',
      ]);
    });

    test('trie par prix décroissant', () async {
      // Baobab (3 500) puis Awa (1 000) puis Mariam (700).
      final List<Restaurant> result = await _filter(
        useCase,
        restaurants,
        const RestaurantFilter(sort: RestaurantSort.priceDesc),
      );
      expect(result.map((restaurant) => restaurant.id), <String>[
        'r2',
        'r1',
        'r3',
      ]);
    });

    test('trie par nom sans tenir compte de la casse', () async {
      // Chez Awa, Le Baobab, Tô de Mariam.
      final List<Restaurant> result = await _filter(
        useCase,
        restaurants,
        const RestaurantFilter(sort: RestaurantSort.nameAsc),
      );
      expect(result.map((restaurant) => restaurant.id), <String>[
        'r1',
        'r2',
        'r3',
      ]);
    });

    test('met une braise active en tête de la pertinence', () async {
      // Awa passe devant malgré une note inférieure à celle de Mariam.
      final List<Restaurant> result = await _filter(
        useCase,
        restaurants,
        const RestaurantFilter(),
      );
      expect(result.map((restaurant) => restaurant.id), <String>[
        'r1',
        'r3',
        'r2',
      ]);
    });
  });

  group('RestaurantFilter', () {
    test('copyWith distingue « ne pas changer » de « remettre à null »', () {
      // La catégorie est retirée explicitement.
      const RestaurantFilter initial = RestaurantFilter(
        category: RestaurantCategory.maquis,
        query: 'awa',
      );
      final RestaurantFilter cleared = initial.copyWith(category: null);
      expect(cleared.category, isNull);
      expect(cleared.query, 'awa');

      // Sans argument, la catégorie est conservée.
      expect(
        initial.copyWith(query: 'baobab').category,
        RestaurantCategory.maquis,
      );
    });

    test('détecte la présence de critères actifs', () {
      // Aucun critère restrictif.
      expect(const RestaurantFilter().hasActiveCriteria, isFalse);

      // Un simple texte suffit.
      expect(const RestaurantFilter(query: 'awa').hasActiveCriteria, isTrue);

      // Une note minimale suffit également.
      expect(const RestaurantFilter(minRating: 4).hasActiveCriteria, isTrue);
    });
  });
}
