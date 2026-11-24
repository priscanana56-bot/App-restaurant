// =============================================================================
// Critères de filtrage et de tri de la liste des restaurants.
// -----------------------------------------------------------------------------
// Objet-valeur pur, construit par la Présentation (recherche, puces, tri) puis
// consommé par le use case `FilterRestaurants`. Aucune logique ici : le filtre
// décrit seulement l'intention de l'utilisateur.
// =============================================================================

// Equatable pour comparer deux filtres.
import 'package:equatable/equatable.dart';

// Types de classement.
import 'restaurant_category.dart';

/// Ordre d'affichage de la liste filtrée.
enum RestaurantSort {
  /// Recommandation : braise active, ambiance, note puis nombre d'avis.
  recommended('Pertinence'),

  /// Meilleures notes d'abord.
  ratingDesc('Mieux notés'),

  /// Prix moyen croissant.
  priceAsc('Prix croissant'),

  /// Prix moyen décroissant.
  priceDesc('Prix décroissant'),

  /// Ordre alphabétique français simplifié.
  nameAsc('Nom (A-Z)');

  /// Constructeur enrichi avec le libellé affiché.
  const RestaurantSort(this.label);

  /// Libellé français du menu de tri.
  final String label;
}

/// Ensemble des critères actifs sur la liste.
final class RestaurantFilter extends Equatable {
  /// Construit un filtre. Tous les critères sont optionnels sauf le tri.
  const RestaurantFilter({
    this.query = '',
    this.category,
    this.sector,
    this.priceRange,
    this.onlyOpenNow = false,
    this.onlyLiveBraise = false,
    this.onlyVerified = false,
    this.minRating = 0,
    this.sort = RestaurantSort.recommended,
  }) : assert(
         minRating >= 0 && minRating <= 5,
         'La note minimale doit être entre 0 et 5.',
       );

  /// Texte brut saisi par l'utilisateur. Il sera nettoyé par le use case.
  final String query;

  /// Catégorie exacte, ou `null` pour toutes les catégories.
  final RestaurantCategory? category;

  /// Secteur exact, ou `null` pour tous les secteurs.
  final String? sector;

  /// Tranche de prix exacte, ou `null` pour toutes les tranches.
  final PriceRange? priceRange;

  /// N'afficher que les établissements ouverts maintenant.
  final bool onlyOpenNow;

  /// N'afficher que les établissements avec une braise active.
  final bool onlyLiveBraise;

  /// N'afficher que les fiches vérifiées sur place.
  final bool onlyVerified;

  /// Note minimale (0 = aucun filtre).
  final double minRating;

  /// Ordre d'affichage.
  final RestaurantSort sort;

  /// Indique si au moins un critère restrictif est actif.
  bool get hasActiveCriteria =>
      query.trim().isNotEmpty ||
      category != null ||
      sector != null ||
      priceRange != null ||
      onlyOpenNow ||
      onlyLiveBraise ||
      onlyVerified ||
      minRating > 0;

  /// Copie modifiée du filtre.
  /// Le sentinelle permet de distinguer « ne pas changer » de « mettre à null »
  /// pour les champs nullables (catégorie, secteur, tranche de prix).
  RestaurantFilter copyWith({
    String? query,
    Object? category = _unset,
    Object? sector = _unset,
    Object? priceRange = _unset,
    bool? onlyOpenNow,
    bool? onlyLiveBraise,
    bool? onlyVerified,
    double? minRating,
    RestaurantSort? sort,
  }) {
    return RestaurantFilter(
      query: query ?? this.query,
      category: identical(category, _unset)
          ? this.category
          : category as RestaurantCategory?,
      sector: identical(sector, _unset) ? this.sector : sector as String?,
      priceRange: identical(priceRange, _unset)
          ? this.priceRange
          : priceRange as PriceRange?,
      onlyOpenNow: onlyOpenNow ?? this.onlyOpenNow,
      onlyLiveBraise: onlyLiveBraise ?? this.onlyLiveBraise,
      onlyVerified: onlyVerified ?? this.onlyVerified,
      minRating: minRating ?? this.minRating,
      sort: sort ?? this.sort,
    );
  }

  /// Sentinelle interne : aucune valeur utilisateur ne peut l'égaler.
  static const Object _unset = Object();

  /// Propriétés comparées par Equatable.
  @override
  List<Object?> get props => <Object?>[
    query,
    category,
    sector,
    priceRange,
    onlyOpenNow,
    onlyLiveBraise,
    onlyVerified,
    minRating,
    sort,
  ];
}
