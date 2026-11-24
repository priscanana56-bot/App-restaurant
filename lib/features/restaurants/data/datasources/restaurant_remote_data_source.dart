// =============================================================================
// Contrat de la source distante.
// -----------------------------------------------------------------------------
// L'implémentation HTTP est isolée derrière cette interface : les tests du
// repository injectent un fake et aucun appel réseau réel n'est effectué.
// =============================================================================

// Modèle de catalogue échangé.
import '../models/restaurant_catalog_model.dart';

/// Téléchargement du catalogue depuis une API HTTPS.
abstract interface class RestaurantRemoteDataSource {
  /// Récupère et valide le catalogue complet.
  Future<RestaurantCatalogModel> fetchCatalog();
}
