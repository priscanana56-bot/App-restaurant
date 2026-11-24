// =============================================================================
// État de la fiche détaillée d'un restaurant.
// =============================================================================

// Equatable pour comparer deux états.
import 'package:equatable/equatable.dart';

// Erreur métier éventuelle.
import '../../../../core/error/failures.dart';

// Entité affichée.
import '../../domain/entities/restaurant.dart';

/// Cycle de vie du chargement d'une fiche.
enum RestaurantDetailStatus {
  /// Aucune demande effectuée.
  initial,

  /// Chargement en cours.
  loading,

  /// Fiche disponible.
  ready,

  /// Échec (restaurant absent, cache illisible...).
  failure,
}

/// État de la fiche détaillée.
final class RestaurantDetailState extends Equatable {
  /// Construit un état sûr par défaut.
  const RestaurantDetailState({
    this.status = RestaurantDetailStatus.initial,
    this.restaurantId = '',
    this.restaurant,
    this.isFavorite = false,
    this.failure,
  });

  /// Étape courante.
  final RestaurantDetailStatus status;

  /// Identifiant demandé (utile pour réessayer).
  final String restaurantId;

  /// Fiche chargée, ou `null` tant que le chargement n'a pas abouti.
  final Restaurant? restaurant;

  /// Indique si le restaurant est en favori.
  final bool isFavorite;

  /// Erreur éventuelle.
  final Failure? failure;

  /// `true` pendant le chargement.
  bool get isLoading => status == RestaurantDetailStatus.loading;

  /// `true` si le chargement a échoué.
  bool get hasError => status == RestaurantDetailStatus.failure;

  /// `true` si la fiche est prête.
  bool get isReady => status == RestaurantDetailStatus.ready;

  /// Copie modifiée de l'état.
  RestaurantDetailState copyWith({
    RestaurantDetailStatus? status,
    String? restaurantId,
    Restaurant? restaurant,
    bool? isFavorite,
    Object? failure = _unset,
  }) {
    return RestaurantDetailState(
      status: status ?? this.status,
      restaurantId: restaurantId ?? this.restaurantId,
      restaurant: restaurant ?? this.restaurant,
      isFavorite: isFavorite ?? this.isFavorite,
      failure: identical(failure, _unset) ? this.failure : failure as Failure?,
    );
  }

  /// Sentinelle interne.
  static const Object _unset = Object();

  /// Propriétés comparées par Equatable.
  @override
  List<Object?> get props => <Object?>[
    status,
    restaurantId,
    restaurant,
    isFavorite,
    failure,
  ];
}
