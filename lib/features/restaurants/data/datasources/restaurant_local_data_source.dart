// =============================================================================
// Contrat de la source de données locale (cache offline-first).
// -----------------------------------------------------------------------------
// Le repository ne connaît ni Hive ni le format JSON : il manipule des modèles
// et des dates. Cette abstraction permet de remplacer Hive par un fake dans
// les tests sans toucher au Domain.
// =============================================================================

// Modèles stockés.
import '../models/event_radar_model.dart';
import '../models/restaurant_model.dart';

/// Persistance locale du catalogue, des favoris et de la date de synchronisation.
abstract interface class RestaurantLocalDataSource {
  /// Vérifie la version du schéma et purge le catalogue si nécessaire.
  Future<void> ensureSchemaVersion();

  /// Lit tous les restaurants mis en cache.
  Future<List<RestaurantModel>> readRestaurants();

  /// Remplace le cache des restaurants.
  Future<void> writeRestaurants(List<RestaurantModel> restaurants);

  /// Lit tous les événements mis en cache.
  Future<List<EventRadarModel>> readEvents();

  /// Remplace le cache des événements.
  Future<void> writeEvents(List<EventRadarModel> events);

  /// Lit les identifiants favoris.
  Future<Set<String>> readFavoriteIds();

  /// Ajoute ou retire un favori.
  Future<void> writeFavorite(String restaurantId, {required bool isFavorite});

  /// Lit la date de dernière synchronisation réussie.
  Future<DateTime?> readLastSyncAt();

  /// Enregistre la date de dernière synchronisation.
  Future<void> writeLastSyncAt(DateTime instant);

  /// Purge le catalogue et la date de synchronisation, sans toucher aux favoris.
  Future<void> clearCatalog();
}
