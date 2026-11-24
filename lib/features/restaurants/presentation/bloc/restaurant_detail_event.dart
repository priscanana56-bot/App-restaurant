// =============================================================================
// Événements de la fiche détaillée d'un restaurant.
// =============================================================================

// Equatable pour comparer les événements.
import 'package:equatable/equatable.dart';

/// Base scellée des événements de la fiche.
sealed class RestaurantDetailEvent extends Equatable {
  /// Constructeur constant pour les sous-classes.
  const RestaurantDetailEvent();

  /// Aucune propriété par défaut.
  @override
  List<Object?> get props => const <Object?>[];
}

/// Demande de chargement de la fiche.
final class RestaurantDetailRequested extends RestaurantDetailEvent {
  /// Construit l'événement avec l'identifiant brut (revalidé par le use case).
  const RestaurantDetailRequested(this.restaurantId);

  /// Identifiant du restaurant ciblé.
  final String restaurantId;

  /// Propriétés comparées par Equatable.
  @override
  List<Object?> get props => <Object?>[restaurantId];
}

/// Bascule du favori depuis la fiche.
final class RestaurantDetailFavoriteToggled extends RestaurantDetailEvent {
  /// Aucun paramètre : l'identifiant est déjà dans l'état.
  const RestaurantDetailFavoriteToggled();
}
