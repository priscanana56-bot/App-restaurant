// =============================================================================
// Constantes globales de l'application.
// -----------------------------------------------------------------------------
// Ce fichier ne contient QUE des valeurs publiques, immuables et sans secret.
// Aucune clé API, aucun mot de passe et aucun numéro réel ne doit y figurer.
// Les valeurs propres à un environnement sont résolues par `AppConfig`.
// =============================================================================

/// Classe « espace de noms » : jamais instanciée, uniquement des membres statiques.
final class AppConstants {
  // Constructeur privé pour empêcher toute instanciation accidentelle.
  const AppConstants._();

  // ---------------------------------------------------------------------------
  // Identité de l'application
  // ---------------------------------------------------------------------------

  /// Nom commercial affiché dans l'interface et les métadonnées du store.
  static const String appName = 'Koudougou Gourmet';

  /// Signature courte utilisée sur l'écran d'accueil et les partages.
  static const String appTagline = 'Le goût de Koudougou, à portée de main';

  /// Nom de la ville couverte par cette première version.
  static const String cityName = 'Koudougou';

  /// Pays de déploiement, utile pour les formats de téléphone et d'adresse.
  static const String countryName = 'Burkina Faso';

  /// Fuseau horaire officiel : GMT toute l'année, sans heure d'été.
  /// Ce libellé documente la règle métier utilisée pour les horaires d'ouverture.
  static const String timezoneName = 'Africa/Ouagadougou';

  /// Décalage fixe avec UTC (GMT+0). Il sert à calculer l'heure « locale » de
  /// Koudougou sans dépendre du fuseau du téléphone de l'utilisateur.
  static const int utcOffsetHours = 0;

  /// Locale par défaut de l'application (français du Burkina Faso).
  static const String defaultLocale = 'fr_FR';

  // ---------------------------------------------------------------------------
  // Coordonnées de référence de Koudougou (centre-ville)
  // ---------------------------------------------------------------------------

  /// Latitude approximative du centre de Koudougou, utilisée pour cadrer la carte
  /// et pour les recherches de proximité lorsque la position est inconnue.
  static const double cityLatitude = 12.2528;

  /// Longitude approximative du centre de Koudougou.
  static const double cityLongitude = -2.3669;

  /// Niveau de zoom initial de la carte (rues et quartiers visibles).
  static const double defaultMapZoom = 14.0;

  // ---------------------------------------------------------------------------
  // Limites de saisie (défense en profondeur contre les entrées abusives)
  // ---------------------------------------------------------------------------

  /// Longueur maximale d'une requête de recherche, en caractères.
  static const int searchMaxLength = 80;

  /// Longueur maximale d'un commentaire ou d'un message WhatsApp, en caractères.
  static const int commentMaxLength = 600;

  /// Longueur maximale d'un nom de plat ou d'un libellé saisi par un gérant.
  static const int shortTextMaxLength = 120;

  /// Longueur maximale d'une URL externe acceptée par l'application.
  static const int urlMaxLength = 2048;

  /// Quantité maximale d'un même article dans le panier.
  static const int maxItemQuantity = 99;

  /// Nombre maximal de convives pour le partage d'addition.
  static const int maxPartySize = 30;

  /// Prix maximal plausible d'un article, en FCFA (garde-fou anti-saisie).
  static const int maxPriceFcfa = 10000000;

  /// Quantité maximale d'articles distincts dans un panier.
  static const int maxCartLines = 50;

  /// Taille de page par défaut pour la liste des restaurants.
  static const int defaultPageSize = 20;

  // ---------------------------------------------------------------------------
  // Cache local (offline-first)
  // ---------------------------------------------------------------------------

  /// Nom de la boîte Hive contenant la liste des restaurants et leurs menus.
  static const String restaurantsBoxName = 'restaurants_cache_v1';

  /// Nom de la boîte Hive contenant les identifiants des favoris.
  static const String favoritesBoxName = 'favorites_v1';

  /// Nom de la boîte Hive contenant les préférences (thème, dernière sync).
  static const String settingsBoxName = 'settings_v1';

  /// Nom de la boîte Hive contenant le panier en cours (résilience au kill).
  static const String cartBoxName = 'cart_v1';

  /// Nom de la boîte Hive contenant le radar d'événements (concerts, matchs).
  static const String eventsBoxName = 'events_cache_v1';

  /// Nom de la boîte Hive contenant les avis locaux sur l'application.
  /// Ces avis restent sur l'appareil : aucun serveur, aucun compte utilisateur.
  static const String appReviewsBoxName = 'app_reviews_v1';

  /// Chemin de l'asset JSON contenant le catalogue de démonstration.
  /// Il est remplacé par l'API distante dès qu'une URL HTTPS est configurée.
  static const String seedAssetPath = 'assets/seed/restaurants_koudougou.json';

  /// Version du schéma JSON acceptée pour le catalogue (seed et API).
  /// Une version inconnue est refusée plutôt que mal interprétée.
  static const int catalogSchemaVersion = 1;

  /// Durée de fraîcheur du cache avant une tentative de rafraîchissement.
  static const Duration cacheTtl = Duration(hours: 24);

  /// Durée au-delà de laquelle les données sont affichées avec un avertissement.
  static const Duration cacheStaleAfter = Duration(days: 7);

  /// Clé de version du schéma de cache (invalidation lors d'un changement majeur).
  static const String cacheSchemaKey = 'cache_schema_version';

  /// Version courante du schéma de cache, à incrémenter en cas de rupture.
  /// Version 2 : purge le catalogue mis en cache après la mise à jour du seed
  /// (retrait de la poissonnerie et ajout des fiches du cahier de projet).
  static const int cacheSchemaVersion = 2;

  // ---------------------------------------------------------------------------
  // Réseau et liens externes
  // ---------------------------------------------------------------------------

  /// Nom d'hôte officiel des liens WhatsApp (format universel, sans deep link).
  static const String whatsAppHost = 'wa.me';

  /// Schémas d'URL autorisés à quitter l'application.
  /// Cette liste est volontairement minimale : pas de `http`, `javascript`,
  /// `intent`, `file` ou `data`, qui constituent des vecteurs d'attaque connus.
  static const Set<String> allowedExternalSchemes = <String>{
    'https',
    'tel',
    'geo',
  };

  /// Numéro de support de secours, clairement fictif.
  /// Il est remplacé par `APP_SUPPORT_PHONE` en production (voir `AppConfig`).
  static const String supportPhonePlaceholder = '+22600000000';

  /// Délai maximal accordé à l'ouverture d'un lien externe.
  static const Duration externalLinkTimeout = Duration(seconds: 8);

  /// Taille maximale d'une réponse HTTP de catalogue, en octets (2 Mio).
  /// Elle protège la mémoire du téléphone contre une réponse abusive.
  static const int maxRemotePayloadBytes = 2 * 1024 * 1024;

  /// Demi-largeur de la zone couverte autour de Koudougou, en degrés.
  /// Toute coordonnée hors de ce cadre est rejetée : l'application ne doit
  /// jamais générer un lien GPS vers un point arbitraire du globe.
  static const double koudougouCoordinateTolerance = 0.6;

  // ---------------------------------------------------------------------------
  // Fonctionnalités produit (valeurs métier par défaut)
  // ---------------------------------------------------------------------------

  /// Nombre maximal de préparations affichées dans le bandeau Live Braise.
  static const int liveBraiseMaxItems = 3;

  /// Seuil d'affluence (0-100) à partir duquel le maquis est signalé « animé ».
  static const int crowdedThreshold = 70;

  /// Rayon de recherche par défaut autour de l'utilisateur, en kilomètres.
  static const double nearbyRadiusKm = 5.0;

  /// Distance maximale de livraison, en kilomètres (règle produit).
  /// Au-delà, aucun devis n'est proposé : l'utilisateur est redirigé vers les
  /// fast-foods les plus proches de l'annuaire.
  static const double deliveryMaxDistanceKm = 5.0;

  /// Montant fixe demandé dès qu'une livraison est possible, en FCFA.
  static const int deliveryBaseFeeFcfa = 500;

  /// Supplément en FCFA par kilomètre de distance (calcul proportionnel,
  /// arrondi au FCFA supérieur par le use case).
  /// Le devis est plafonné à [deliveryMaxDistanceKm].
  static const int deliveryFeePerKmFcfa = 200;

  /// Nombre maximal de fast-foods proposés en redirection hors zone.
  static const int nearbyFastFoodSuggestions = 3;
}
