// =============================================================================
// Restaurant proche : association immuable entre une fiche et une distance.
// -----------------------------------------------------------------------------
// Utilisé pour la redirection hors zone de livraison : on propose les fast-foods
// déjà présents dans l'annuaire, triés du plus proche au plus loin. Aucune
// nouvelle adresse n'est fabriquée par l'application.
// =============================================================================

// Égalité de valeur.
import 'package:equatable/equatable.dart';

// Fiche affichée.
import 'restaurant.dart';

/// Fiche d'annuaire associée à sa distance depuis l'utilisateur.
final class NearbyRestaurant extends Equatable {
  /// Construit une entrée déjà calculée.
  const NearbyRestaurant({required this.restaurant, required this.distanceKm});

  /// Établissement proposé.
  final Restaurant restaurant;

  /// Distance depuis la position de l'utilisateur, en kilomètres.
  final double distanceKm;

  @override
  List<Object?> get props => <Object?>[restaurant, distanceKm];
}
