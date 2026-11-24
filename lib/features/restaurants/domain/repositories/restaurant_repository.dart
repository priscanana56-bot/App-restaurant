// =============================================================================
// Contrat du repository des restaurants.
// -----------------------------------------------------------------------------
// Le Domain définit CE DONT IL A BESOIN ; la Data fournit l'implémentation
// (Hive, seed embarqué ou API HTTPS). Aucune méthode n'expose d'exception :
// toutes renvoient un `Either<Failure, T>`.
// =============================================================================

// Type fonctionnel Either et Unit.
import 'package:fpdart/fpdart.dart';

// Erreurs métier.
import '../../../../core/error/failures.dart';

// Entités manipulées par le contrat.
import '../entities/event_radar.dart';
import '../entities/menu_item.dart';
import '../entities/restaurant.dart';

/// Accès au catalogue des restaurants et aux données associées.
abstract interface class RestaurantRepository {
  /// Récupère le catalogue complet selon la stratégie offline-first.
  /// [forceRefresh] ignore la fraîcheur du cache et tente une synchronisation.
  Future<Either<Failure, List<Restaurant>>> getRestaurants({
    bool forceRefresh = false,
  });

  /// Récupère une fiche précise par son identifiant.
  Future<Either<Failure, Restaurant>> getRestaurantById(String id);

  /// Récupère le radar d'événements (concerts, matchs, soirées).
  Future<Either<Failure, List<EventRadar>>> getEventRadar({
    bool forceRefresh = false,
  });

  /// Récupère les identifiants des restaurants favoris.
  Future<Either<Failure, Set<String>>> getFavoriteIds();

  /// Ajoute, retire ou inverse un favori.
  /// Si [isFavorite] est `null`, l'état courant est inversé.
  /// Retourne le nouvel état (`true` = favori).
  Future<Either<Failure, bool>> toggleFavorite(
    String restaurantId, {
    bool? isFavorite,
  });

  /// Date de la dernière synchronisation réussie du catalogue, ou `null`.
  Future<Either<Failure, DateTime?>> getLastSyncAt();

  // ---------------------------------------------------------------------------
  // Écritures locales (portail créatrice et portail gérant)
  // ---------------------------------------------------------------------------
  // Ces méthodes ne parlent PAS au serveur : elles modifient le cache chiffré
  // de l'appareil. Le Domain reste donc maître des invariants (unicité des
  // identifiants, menu cohérent, horodatage) quelle que soit la source initiale.

  /// Ajoute un établissement créé localement au catalogue.
  /// Un identifiant déjà présent est refusé (aucun écrasement silencieux).
  Future<Either<Failure, Restaurant>> addRestaurant(Restaurant restaurant);

  /// Ajoute un plat au menu d'un établissement et renvoie la fiche mise à jour.
  Future<Either<Failure, Restaurant>> addMenuItem({
    required String restaurantId,
    required MenuItem item,
  });

  /// Retire un plat du menu d'un établissement et renvoie la fiche mise à jour.
  Future<Either<Failure, Restaurant>> removeMenuItem({
    required String restaurantId,
    required String itemId,
  });
}
