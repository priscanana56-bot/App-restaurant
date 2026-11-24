// =============================================================================
// État du portail gérant.
// =============================================================================

// Égalité de valeur.
import 'package:equatable/equatable.dart';

// Failure éventuelle.
import '../../../../core/error/failures.dart';

// Entité affichée.
import '../../../restaurants/domain/entities/restaurant.dart';

/// Cycle de vie du portail.
enum OwnerPortalStatus {
  /// Chargement non lancé.
  initial,

  /// Chargement du catalogue.
  loading,

  /// Catalogue disponible.
  ready,

  /// Échec de chargement.
  failure,
}

/// État immuable du portail gérant.
final class OwnerPortalState extends Equatable {
  /// Construit un état sûr par défaut.
  const OwnerPortalState({
    this.status = OwnerPortalStatus.initial,
    this.restaurants = const <Restaurant>[],
    this.selectedRestaurantId,
    this.selectedHasCode,
    this.isUnlocked = false,
    this.isBusy = false,
    this.failure,
    this.infoMessage,
  });

  /// Étape courante.
  final OwnerPortalStatus status;

  /// Établissements du catalogue local.
  final List<Restaurant> restaurants;

  /// Identifiant de l'établissement sélectionné.
  final String? selectedRestaurantId;

  /// `true` si un code gérant existe, `false` s'il manque, `null` si inconnu.
  /// Aucun code n'est exposé : ce drapeau sert seulement à guider l'utilisateur.
  final bool? selectedHasCode;

  /// `true` après vérification réussie du code.
  final bool isUnlocked;

  /// `true` pendant une écriture.
  final bool isBusy;

  /// Dernière erreur affichable.
  final Failure? failure;

  /// Message de confirmation.
  final String? infoMessage;

  /// Fiche sélectionnée, ou `null` si aucune sélection valide.
  Restaurant? get selectedRestaurant {
    final String? id = selectedRestaurantId;
    if (id == null) {
      return null;
    }
    for (final Restaurant restaurant in restaurants) {
      if (restaurant.id == id) {
        return restaurant;
      }
    }
    return null;
  }

  /// Copie modifiée de l'état.
  OwnerPortalState copyWith({
    OwnerPortalStatus? status,
    List<Restaurant>? restaurants,
    Object? selectedRestaurantId = _unset,
    Object? selectedHasCode = _unset,
    bool? isUnlocked,
    bool? isBusy,
    Object? failure = _unset,
    Object? infoMessage = _unset,
  }) {
    return OwnerPortalState(
      status: status ?? this.status,
      restaurants: restaurants ?? this.restaurants,
      selectedRestaurantId: identical(selectedRestaurantId, _unset)
          ? this.selectedRestaurantId
          : selectedRestaurantId as String?,
      selectedHasCode: identical(selectedHasCode, _unset)
          ? this.selectedHasCode
          : selectedHasCode as bool?,
      isUnlocked: isUnlocked ?? this.isUnlocked,
      isBusy: isBusy ?? this.isBusy,
      failure: identical(failure, _unset) ? this.failure : failure as Failure?,
      infoMessage: identical(infoMessage, _unset)
          ? this.infoMessage
          : infoMessage as String?,
    );
  }

  // Sentinelles pour distinguer « inchangé » de « remettre à null ».
  static const Object _unset = Object();

  /// Propriétés comparées par Equatable.
  @override
  List<Object?> get props => <Object?>[
    status,
    restaurants,
    selectedRestaurantId,
    selectedHasCode,
    isUnlocked,
    isBusy,
    failure,
    infoMessage,
  ];
}
