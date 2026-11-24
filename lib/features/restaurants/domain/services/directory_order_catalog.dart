// =============================================================================
// Catalogue de commande pour une fiche de l'annuaire sourcé.
// -----------------------------------------------------------------------------
// L'annuaire réel ne publie AUCUN menu : ce service construit donc un MENU
// D'EXEMPLE, explicitement marqué « démonstration – à confirmer ». Il ne
// prétend jamais décrire la carte réelle d'un établissement.
//
// Il transforme une `KoudougouListing` (données sourcées) en `Restaurant`
// commandable afin de réutiliser les calculs existants (`CartSummary`,
// `buildOrderMessage`) sans dupliquer la logique de prix. Les champs du
// `Restaurant` qui ne proviennent pas de la source sont neutres et ne sont
// JAMAIS affichés : l'interface lit uniquement la `KoudougouListing`.
// =============================================================================

// Coordonnées publiées (champ `position` ou paire dans `area`).
import '../../../../core/location/geo_point.dart';

// Validation des coordonnées avant construction d'un `GeoPoint`.
import '../../../../core/security/input_sanitizer.dart';

// Entités de l'annuaire et du catalogue.
import '../entities/koudougou_listing.dart';
import '../entities/menu_item.dart';
import '../entities/opening_hours.dart';
import '../entities/restaurant.dart';
import '../entities/restaurant_category.dart';

/// Fabrique pure d'une fiche commandable à partir de l'annuaire sourcé.
final class DirectoryOrderCatalog {
  // Constructeur privé : espace de noms statique.
  const DirectoryOrderCatalog._();

  /// Avertissement affiché au-dessus du menu, en toutes circonstances.
  static const String demonstrationNotice =
      'Exemple de menu — démonstration. Les plats et les prix ne sont pas '
      'ceux de l’établissement : à confirmer par téléphone avant de commander.';

  /// Libellé court des badges apposés sur les plats d'exemple.
  static const String demonstrationBadge = 'Démo';

  /// Coordonnées `(latitude ; longitude)` publiées dans le champ `area`.
  ///
  /// Les sources locales écrivent les décimales avec une virgule, par exemple
  /// `Koudougou (12,25174 ; -2,34815)` pour Vivalto. Aucune coordonnée n'est
  /// inventée : sans donnée publiée, la méthode renvoie `null`.
  static final RegExp _areaCoordinates = RegExp(
    r'\(\s*([-+]?\d+(?:[.,]\d+)?)\s*;\s*([-+]?\d+(?:[.,]\d+)?)\s*\)',
  );

  /// Point GPS publié par la source, ou `null` si elle n'en donne pas.
  ///
  /// Le champ typé `position` est prioritaire (fiche Snack Time). Pour les
  /// autres fiches, on lit UNIQUEMENT les coordonnées déjà présentes dans
  /// `area` : aucune adresse ni position n'est déduite du nom du lieu.
  static GeoPoint? coordinatesOf(KoudougouListing listing) {
    // 1. Coordonnées structurées, déjà validées par la couche Data.
    final GeoPoint? published = listing.position;
    if (published != null) {
      return published;
    }

    // 2. Coordonnées textuelles publiées dans `area`.
    final RegExpMatch? match = _areaCoordinates.firstMatch(listing.area);
    if (match == null) {
      return null;
    }

    // Les décimales locales utilisent la virgule : normalisation avant parsing.
    final double? latitude = double.tryParse(
      (match.group(1) ?? '').replaceAll(',', '.'),
    );
    final double? longitude = double.tryParse(
      (match.group(2) ?? '').replaceAll(',', '.'),
    );
    if (latitude == null || longitude == null) {
      return null;
    }

    // Garde-fou avant la construction (les assertions sont désactivées en release).
    if (!InputSanitizer.isValidCoordinate(latitude, longitude)) {
      return null;
    }
    return GeoPoint(latitude: latitude, longitude: longitude);
  }

  /// Famille d'établissement déduite du libellé sourcé, pour choisir un menu
  /// d'exemple cohérent. Valeur par défaut : [RestaurantCategory.other].
  static RestaurantCategory categoryOf(KoudougouListing listing) {
    final String label = listing.category.toLowerCase();

    if (label.contains('café') ||
        label.contains('cafe') ||
        label.contains('glacier')) {
      return RestaurantCategory.cafe;
    }
    if (label.contains('fast') || label.contains('snack')) {
      return RestaurantCategory.fastFood;
    }
    if (label.contains('maquis')) {
      return RestaurantCategory.maquis;
    }
    // Les anciennes catégories « grillades » sont désormais rangées parmi les
    // restaurants : la fiche reste commandable sans filtre dédié.
    if (label.contains('grill') || label.contains('barbecue')) {
      return RestaurantCategory.restaurant;
    }
    if (label.contains('restaurant')) {
      return RestaurantCategory.restaurant;
    }
    return RestaurantCategory.other;
  }

  /// Menu d'exemple, avec des identifiants préfixés par l'identifiant de la
  /// fiche : le panier étant partagé, deux établissements ne peuvent pas
  /// mélanger leurs plats.
  static List<MenuItem> exampleMenu(KoudougouListing listing) {
    final RestaurantCategory category = categoryOf(listing);
    final List<_DemoDish> dishes = switch (category) {
      RestaurantCategory.cafe => const <_DemoDish>[
        _DemoDish('cafe', 'Café expresso', MenuSection.drinks, 500),
        _DemoDish('the-glace', 'Thé glacé maison', MenuSection.drinks, 700),
        _DemoDish('croissant', 'Croissant', MenuSection.desserts, 800),
        _DemoDish(
          'sandwich',
          'Sandwich jambon-fromage',
          MenuSection.mainDishes,
          1500,
        ),
        _DemoDish('jus', 'Jus de fruits frais', MenuSection.drinks, 1000),
      ],
      RestaurantCategory.fastFood => const <_DemoDish>[
        _DemoDish('sandwich', 'Sandwich viande', MenuSection.mainDishes, 1400),
        _DemoDish('brochette', 'Brochette de poulet', MenuSection.grills, 1200),
        _DemoDish('frites', 'Frites', MenuSection.sides, 800),
        _DemoDish('soda', 'Boisson fraîche', MenuSection.drinks, 500),
      ],
      _ => const <_DemoDish>[
        _DemoDish('riz-gras', 'Riz gras', MenuSection.mainDishes, 1200),
        _DemoDish(
          'to-arachide',
          'Tô sauce arachide',
          MenuSection.mainDishes,
          1000,
        ),
        _DemoDish('poulet-braise', 'Poulet braisé', MenuSection.grills, 2500),
        _DemoDish('alloco', 'Allococos', MenuSection.sides, 700),
        _DemoDish('boisson', 'Boisson locale', MenuSection.drinks, 500),
      ],
    };

    return List<MenuItem>.unmodifiable(
      dishes
          .map(
            (_DemoDish dish) => MenuItem(
              id: 'demo/${listing.id}/${dish.slug}',
              name: dish.name,
              description:
                  'Plat d’exemple — à confirmer auprès de l’établissement.',
              section: dish.section,
              priceFcfa: dish.priceFcfa,
              isAvailable: true,
              isSignature: false,
              portionLabel: '1 personne',
              preparationMinutes: 10,
              photoAsset: null,
              allergens: const <Allergen>{},
            ),
          )
          .toList(growable: false),
    );
  }

  /// Construit la fiche commandable utilisée par le panier et le message
  /// WhatsApp. Seuls [id], [name], [phone], [whatsappPhone], le menu et
  /// [deliveryAvailable] proviennent de données exploitables ; le reste est
  /// neutre et non affiché.
  static Restaurant toRestaurant(KoudougouListing listing) {
    // Menu d'exemple, jamais une carte réelle publiée.
    final List<MenuItem> menu = exampleMenu(listing);

    // Prix moyen purement dérivé du menu d'exemple (utilisé par les calculs).
    final int averageFcfa = menu.isEmpty
        ? 0
        : menu.fold<int>(0, (int sum, MenuItem item) => sum + item.priceFcfa) ~/
              menu.length;

    // Coordonnées publiées, ou sentinelle 0/0 pour une fiche sans position.
    // La page n'UTILISE jamais cette sentinelle pour un itinéraire : elle
    // appelle [coordinatesOf] et masque le bouton quand le résultat est `null`.
    final GeoPoint? point = coordinatesOf(listing);

    // Horaires neutres : les horaires affichés sont ceux de la fiche sourcée.
    final OpeningHours neutralHours = OpeningHours(
      weekly: <int, DaySchedule?>{
        for (int weekday = 1; weekday <= 7; weekday++)
          weekday: const DaySchedule(opensAtMinute: 0, closesAtMinute: 1440),
      },
    );

    return Restaurant(
      id: listing.id,
      name: listing.name,
      tagline: '',
      description: '',
      category: categoryOf(listing),
      sector: '',
      landmark: '',
      address: listing.area,
      latitude: point?.latitude ?? 0,
      longitude: point?.longitude ?? 0,
      phone: listing.phone,
      whatsappPhone: listing.phone,
      rating: 0,
      reviewCount: 0,
      priceRange: PriceRange.fromAveragePrice(averageFcfa),
      averagePriceFcfa: averageFcfa,
      ambiance: const AmbianceInfo(score: 0, musicGenre: '', note: ''),
      openingHours: neutralHours,
      menu: menu,
      // Une fiche construite localement n'est JAMAIS une vérification sur place.
      isVerified: false,
      verifiedAt: null,
      updatedAt: DateTime.fromMillisecondsSinceEpoch(0, isUtc: true),
      paymentMethods: const <PaymentMethod>{PaymentMethod.cash},
      amenities: <RestaurantAmenity>{
        if (listing.deliveryAvailable) RestaurantAmenity.delivery,
      },
      photoAsset: null,
      liveBraise: null,
      deliveryAvailable: listing.deliveryAvailable,
    );
  }
}

/// Plat d'exemple en écriture compacte ( usage interne au catalogue ).
final class _DemoDish {
  // Constructeur constant.
  const _DemoDish(this.slug, this.name, this.section, this.priceFcfa);

  // Données du plat.
  final String slug;
  final String name;
  final MenuSection section;
  final int priceFcfa;
}
