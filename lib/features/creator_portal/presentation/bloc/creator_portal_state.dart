// =============================================================================
// État de l'espace administration.
// =============================================================================

// Égalité de valeur.
import 'package:equatable/equatable.dart';

// Failure éventuelle.
import '../../../../core/error/failures.dart';

// Entité créée.
import '../../../restaurants/domain/entities/restaurant.dart';

/// Étape de l'espace administration.
enum CreatorPortalPhase {
  /// Vérification de l'existence du PIN en cours.
  initial,

  /// Aucun PIN : premier réglage demandé.
  setupPin,

  /// PIN existant : connexion demandée.
  login,

  /// PIN vérifié : formulaire de création accessible.
  unlocked,
}

/// État immuable de l'espace administration.
final class CreatorPortalState extends Equatable {
  /// Construit un état sûr par défaut.
  const CreatorPortalState({
    this.phase = CreatorPortalPhase.initial,
    this.isBusy = false,
    this.failure,
    this.infoMessage,
    this.createdRestaurant,
    this.restaurants = const <Restaurant>[],
    this.selectedRestaurantId,
  });

  /// Étape courante.
  final CreatorPortalPhase phase;

  /// `true` pendant une opération sensible.
  final bool isBusy;

  /// Dernière erreur affichable.
  final Failure? failure;

  /// Message de confirmation.
  final String? infoMessage;

  /// Dernier établissement créé (pour afficher son code gérant).
  final Restaurant? createdRestaurant;

  /// Fiches du catalogue auxquelles un code gérant peut être attribué.
  final List<Restaurant> restaurants;

  /// Fiche actuellement sélectionnée pour l'attribution du code.
  final String? selectedRestaurantId;

  /// Copie modifiée de l'état.
  CreatorPortalState copyWith({
    CreatorPortalPhase? phase,
    bool? isBusy,
    Object? failure = _unset,
    Object? infoMessage = _unset,
    Object? createdRestaurant = _unset,
    List<Restaurant>? restaurants,
    Object? selectedRestaurantId = _unset,
  }) {
    return CreatorPortalState(
      phase: phase ?? this.phase,
      isBusy: isBusy ?? this.isBusy,
      failure: identical(failure, _unset) ? this.failure : failure as Failure?,
      infoMessage: identical(infoMessage, _unset)
          ? this.infoMessage
          : infoMessage as String?,
      createdRestaurant: identical(createdRestaurant, _unset)
          ? this.createdRestaurant
          : createdRestaurant as Restaurant?,
      restaurants: restaurants ?? this.restaurants,
      selectedRestaurantId: identical(selectedRestaurantId, _unset)
          ? this.selectedRestaurantId
          : selectedRestaurantId as String?,
    );
  }

  // Sentinelles pour distinguer « inchangé » de « remettre à null ».
  static const Object _unset = Object();

  /// Propriétés comparées par Equatable.
  @override
  List<Object?> get props => <Object?>[
    phase,
    isBusy,
    failure,
    infoMessage,
    createdRestaurant,
    restaurants,
    selectedRestaurantId,
  ];
}
