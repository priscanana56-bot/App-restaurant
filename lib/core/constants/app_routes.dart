// =============================================================================
// Routes nommées de l'application.
// -----------------------------------------------------------------------------
// Centraliser les chemins évite les chaînes « magiques » dans les widgets et
// permet de construire des liens profonds de façon contrôlée.
// =============================================================================

/// Routes et constructeurs de chemins typés.
final class AppRoutes {
  // Constructeur privé : espace de noms statique uniquement.
  const AppRoutes._();

  // ---------------------------------------------------------------------------
  // Routes racines
  // ---------------------------------------------------------------------------

  /// Écran d'accueil : liste, recherche et filtres des restaurants.
  static const String home = '/';

  /// Carte des restaurants et maquis de Koudougou.
  static const String map = '/map';

  /// Liste des restaurants mis en favori.
  static const String favorites = '/favorites';

  /// Paramètres de l'application (thème, cache, support).
  static const String settings = '/settings';

  /// Portail sécurisé réservé aux gérants.
  static const String ownerPortal = '/owner';

  /// Écran de connexion du portail gérant.
  static const String ownerLogin = '/owner/login';

  /// Annuaire sourcé des établissements réels de Koudougou.
  static const String directory = '/annuaire';

  /// Motif d'une fiche commandable de l'annuaire : `/annuaire/:id`.
  static const String directoryListingPattern = '/annuaire/:id';

  /// Chemin concret vers la fiche d'une entrée de l'annuaire.
  /// L'identifiant est encodé comme pour les fiches du catalogue.
  static String directoryListing(String listingId) {
    final String safeId = Uri.encodeComponent(listingId.trim());
    return '/annuaire/$safeId';
  }

  /// Espace administration (ajout d'établissements, codes gérants).
  static const String creatorPortal = '/createur';

  /// Alias mnémonique de l'espace administration.
  static const String adminPortal = '/admin';

  /// Espace d'avis locaux sur la qualité de l'application.
  static const String appReviews = '/avis';

  // ---------------------------------------------------------------------------
  // Routes paramétrées
  // ---------------------------------------------------------------------------

  /// Fiche détaillée d'un restaurant : `/restaurants/:id`.
  static const String restaurantDetailPattern = '/restaurants/:id';

  /// Chemin concret vers la fiche d'un restaurant.
  /// [restaurantId] est encodé pour empêcher toute injection de segment d'URL.
  static String restaurantDetail(String restaurantId) {
    // Encodage strict : les « / », « ? » et caractères de contrôle sont neutralisés.
    final String safeId = Uri.encodeComponent(restaurantId.trim());
    return '/restaurants/$safeId';
  }

  /// Écran de partage d'addition pour un restaurant donné.
  static String splitBill(String restaurantId) {
    // Même principe d'encodage que pour la fiche restaurant.
    final String safeId = Uri.encodeComponent(restaurantId.trim());
    return '/restaurants/$safeId/split-bill';
  }

  /// Écran de commande / panier WhatsApp pour un restaurant donné.
  static String order(String restaurantId) {
    // Encodage systématique de l'identifiant avant construction du chemin.
    final String safeId = Uri.encodeComponent(restaurantId.trim());
    return '/restaurants/$safeId/order';
  }

  /// Récupère l'identifiant depuis les arguments d'une route ou d'un deep link.
  /// Retourne une chaîne vide si la valeur est absente ou du mauvais type.
  static String restaurantIdFromArguments(Object? arguments) {
    // Seules les chaînes non vides sont acceptées : aucun cast implicite.
    if (arguments is String) {
      return arguments.trim();
    }

    // Valeur absente ou invalide : l'appelant affichera une erreur propre.
    return '';
  }
}
