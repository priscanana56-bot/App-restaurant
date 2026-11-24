// =============================================================================
// Événements du catalogue de restaurants.
// -----------------------------------------------------------------------------
// Un événement = une INTENTION de l'utilisateur ou du système (« charger »,
// « rechercher », « filtrer », « trier », « mettre en favori »). Les événements
// sont immuables et comparables (Equatable), ce qui rend les tests de BLoC
// lisibles et déterministes.
// =============================================================================

// Equatable pour comparer les événements (et leurs paramètres).
import 'package:equatable/equatable.dart';

// Objets-valeurs de filtrage et de tri.
import '../../domain/entities/restaurant_category.dart';
import '../../domain/entities/restaurant_filter.dart';

/// Base scellée : le compilateur vérifie que tous les cas sont traités.
sealed class RestaurantListEvent extends Equatable {
  /// Constructeur constant pour les sous-classes sans paramètre.
  const RestaurantListEvent();

  /// Aucune propriété par défaut : chaque sous-classe déclare les siennes.
  @override
  List<Object?> get props => const <Object?>[];
}

/// Chargement initial du catalogue (cache -> réseau -> seed).
final class RestaurantListStarted extends RestaurantListEvent {
  /// Aucun paramètre : la stratégie offline-first est interne à la Data.
  const RestaurantListStarted();
}

/// Demande de rafraîchissement explicite (tirer pour actualiser).
final class RestaurantListRefreshRequested extends RestaurantListEvent {
  /// Aucun paramètre.
  const RestaurantListRefreshRequested();
}

/// Modification du texte de recherche.
final class RestaurantListSearchChanged extends RestaurantListEvent {
  /// Construit l'événement avec le texte brut saisi.
  const RestaurantListSearchChanged(this.query);

  /// Texte brut : il sera nettoyé par le use case de filtrage.
  final String query;

  /// Propriétés comparées par Equatable.
  @override
  List<Object?> get props => <Object?>[query];
}

/// Sélection d'une catégorie (re-taper la même catégorie la désactive).
final class RestaurantListCategoryToggled extends RestaurantListEvent {
  /// Construit l'événement avec la catégorie ciblée (jamais `null`).
  const RestaurantListCategoryToggled(this.category);

  /// Catégorie à activer ou désactiver.
  final RestaurantCategory category;

  /// Propriétés comparées par Equatable.
  @override
  List<Object?> get props => <Object?>[category];
}

/// Changement de l'ordre d'affichage.
final class RestaurantListSortChanged extends RestaurantListEvent {
  /// Construit l'événement avec le nouvel ordre.
  const RestaurantListSortChanged(this.sort);

  /// Ordre demandé.
  final RestaurantSort sort;

  /// Propriétés comparées par Equatable.
  @override
  List<Object?> get props => <Object?>[sort];
}

/// Activation/désactivation du filtre « ouvert maintenant ».
final class RestaurantListOpenNowToggled extends RestaurantListEvent {
  /// Aucun paramètre : l'état courant est inversé par le BLoC.
  const RestaurantListOpenNowToggled();
}

/// Activation/désactivation du filtre « Live Braise active ».
final class RestaurantListLiveBraiseToggled extends RestaurantListEvent {
  /// Aucun paramètre.
  const RestaurantListLiveBraiseToggled();
}

/// Activation/désactivation du filtre « vérifié sur place ».
final class RestaurantListVerifiedToggled extends RestaurantListEvent {
  /// Aucun paramètre.
  const RestaurantListVerifiedToggled();
}

/// Réinitialisation complète des critères (hors tri).
final class RestaurantListFiltersCleared extends RestaurantListEvent {
  /// Aucun paramètre.
  const RestaurantListFiltersCleared();
}

/// Bascule du favori d'un restaurant.
final class RestaurantListFavoriteToggled extends RestaurantListEvent {
  /// Construit l'événement avec l'identifiant ciblé.
  const RestaurantListFavoriteToggled(this.restaurantId);

  /// Identifiant du restaurant (revalidé par le use case).
  final String restaurantId;

  /// Propriétés comparées par Equatable.
  @override
  List<Object?> get props => <Object?>[restaurantId];
}
