// =============================================================================
// État du catalogue de restaurants.
// -----------------------------------------------------------------------------
// L'état est IMMUABLE : chaque changement produit une nouvelle instance via
// `copyWith`. Il expose à la fois la liste complète (source de vérité) et la
// liste visible (filtrée/triée), afin que la recherche locale n'ait jamais
// besoin de rappeler la Data.
// =============================================================================

// Equatable pour comparer deux états et éviter les reconstructions inutiles.
import 'package:equatable/equatable.dart';

// Erreur métier éventuelle (jamais d'exception dans l'état).
import '../../../../core/error/failures.dart';

// Entités affichées.
import '../../domain/entities/live_braise_status.dart';
import '../../domain/entities/restaurant.dart';
import '../../domain/entities/restaurant_filter.dart';

/// Cycle de vie d'un chargement.
enum RestaurantListStatus {
  /// Aucun chargement lancé.
  initial,

  /// Chargement en cours (premier affichage ou rafraîchissement).
  loading,

  /// Données disponibles (la liste peut être vide après filtrage).
  ready,

  /// Échec : [RestaurantListState.failure] contient la cause métier.
  failure,
}

/// État complet de l'écran d'accueil.
final class RestaurantListState extends Equatable {
  /// Construit un état ; tous les champs ont une valeur par défaut sûre.
  const RestaurantListState({
    this.status = RestaurantListStatus.initial,
    this.allRestaurants = const <Restaurant>[],
    this.visibleRestaurants = const <Restaurant>[],
    this.liveBraise = const <LiveBraiseStatus>[],
    this.favoriteIds = const <String>{},
    this.filter = const RestaurantFilter(),
    this.now,
    this.failure,
  });

  /// Étape courante du chargement.
  final RestaurantListStatus status;

  /// Catalogue complet, non filtré.
  final List<Restaurant> allRestaurants;

  /// Sous-ensemble filtré et trié, affiché dans la liste.
  final List<Restaurant> visibleRestaurants;

  /// Braises réellement actives à l'instant [now].
  final List<LiveBraiseStatus> liveBraise;

  /// Identifiants des restaurants favoris.
  final Set<String> favoriteIds;

  /// Critères et tri actifs.
  final RestaurantFilter filter;

  /// Instant de référence (heure de Koudougou) pour les statuts « ouvert ».
  final DateTime? now;

  /// Erreur éventuelle à afficher.
  final Failure? failure;

  /// `true` pendant un chargement.
  bool get isLoading => status == RestaurantListStatus.loading;

  /// `true` si le chargement a échoué.
  bool get hasError => status == RestaurantListStatus.failure;

  /// `true` si le catalogue est prêt mais qu'aucun restaurant ne correspond.
  bool get isEmpty =>
      status == RestaurantListStatus.ready && visibleRestaurants.isEmpty;

  /// Restaurants favoris, dans l'ordre du catalogue.
  List<Restaurant> get favoriteRestaurants => List<Restaurant>.unmodifiable(
    allRestaurants.where(
      (Restaurant restaurant) => favoriteIds.contains(restaurant.id),
    ),
  );

  /// Indique si un restaurant est ouvert à l'instant de référence.
  bool isOpen(Restaurant restaurant) {
    final DateTime? reference = now;
    return reference != null && restaurant.isOpenAt(reference);
  }

  /// Indique si une braise est active pour un restaurant donné.
  bool hasLiveBraise(String restaurantId) => liveBraise.any(
    (LiveBraiseStatus braise) => braise.restaurantId == restaurantId,
  );

  /// Copie modifiée de l'état.
  /// Le sentinelle [_unset] distingue « ne pas changer » de « mettre à null »
  /// pour le champ `failure`, qui est nullable.
  RestaurantListState copyWith({
    RestaurantListStatus? status,
    List<Restaurant>? allRestaurants,
    List<Restaurant>? visibleRestaurants,
    List<LiveBraiseStatus>? liveBraise,
    Set<String>? favoriteIds,
    RestaurantFilter? filter,
    DateTime? now,
    Object? failure = _unset,
  }) {
    return RestaurantListState(
      status: status ?? this.status,
      allRestaurants: allRestaurants ?? this.allRestaurants,
      visibleRestaurants: visibleRestaurants ?? this.visibleRestaurants,
      liveBraise: liveBraise ?? this.liveBraise,
      favoriteIds: favoriteIds ?? this.favoriteIds,
      filter: filter ?? this.filter,
      now: now ?? this.now,
      failure: identical(failure, _unset) ? this.failure : failure as Failure?,
    );
  }

  /// Sentinelle interne : aucune valeur utilisateur ne peut l'égaler.
  static const Object _unset = Object();

  /// Propriétés comparées par Equatable (collections comparées en profondeur).
  @override
  List<Object?> get props => <Object?>[
    status,
    allRestaurants,
    visibleRestaurants,
    liveBraise,
    favoriteIds,
    filter,
    now,
    failure,
  ];
}
