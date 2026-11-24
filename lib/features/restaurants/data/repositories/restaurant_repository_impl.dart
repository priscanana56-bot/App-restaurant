// =============================================================================
// Implémentation du repository des restaurants.
// -----------------------------------------------------------------------------
// Stratégie offline-first :
//   1. cache frais et non forcé            -> cache ;
//   2. synchronisation demandée/possible   -> API, puis cache ;
//   3. API indisponible mais cache présent -> cache (mode dégradé) ;
//   4. aucun cache                         -> seed embarqué, puis cache.
// Aucune exception ne traverse cette classe : tout est converti en `Failure`.
// =============================================================================

// Type fonctionnel Either.
import 'package:fpdart/fpdart.dart';

// Configuration de l'API et constantes de cache.
import '../../../../core/constants/app_config.dart';
import '../../../../core/constants/app_constants.dart';

// Mapping exception -> failure.
import '../../../../core/error/error_mapper.dart';
import '../../../../core/error/exceptions.dart';
import '../../../../core/error/failures.dart';

// Détection de connectivité.
import '../../../../core/network/network_info.dart';

// Nettoyage des identifiants.
import '../../../../core/security/input_sanitizer.dart';

// Horloge injectable.
import '../../../../core/utils/app_clock.dart';

// Entités Domain.
import '../../domain/entities/event_radar.dart';
import '../../domain/entities/menu_item.dart';
import '../../domain/entities/restaurant.dart';

// Contrat Domain implémenté.
import '../../domain/repositories/restaurant_repository.dart';

// Sources de données.
import '../datasources/http_restaurant_remote_data_source.dart';
import '../datasources/restaurant_local_data_source.dart';
import '../datasources/restaurant_remote_data_source.dart';
import '../datasources/restaurant_seed_data_source.dart';

// Modèles échangés.
import '../models/event_radar_model.dart';
import '../models/restaurant_catalog_model.dart';
import '../models/restaurant_model.dart';

/// Repository concret consommé par les use cases.
final class RestaurantRepositoryImpl implements RestaurantRepository {
  /// Les dépendances sont injectées par GetIt (aucun singleton caché ici).
  RestaurantRepositoryImpl({
    required this.localDataSource,
    required this.seedDataSource,
    required this.networkInfo,
    required this.clock,
    RestaurantRemoteDataSource? remoteDataSource,
    bool? remoteSyncEnabled,
    Duration? cacheTtl,
    ErrorMapper? errorMapper,
  }) // Le champ privé est mutable (construction HTTP paresseuse), donc un
    // initializing formal nommé serait impossible : on garde l'initialisation.
    // ignore: prefer_initializing_formals
    : _remoteDataSource = remoteDataSource,
       _remoteSyncEnabled =
           remoteSyncEnabled ??
           (AppConfig.hasRemoteBackend && AppConfig.isRemoteSyncEnabled),
       _cacheTtl = cacheTtl ?? AppConstants.cacheTtl,
       _errorMapper = errorMapper ?? const ErrorMapper();

  /// Cache local chiffré.
  final RestaurantLocalDataSource localDataSource;

  /// Catalogue embarqué de secours.
  final RestaurantSeedDataSource seedDataSource;

  /// État du réseau (fake en test).
  final NetworkInfo networkInfo;

  /// Horloge de Koudougou.
  final AppClock clock;

  // Source distante éventuelle (fake ou HTTP construit à la demande).
  RestaurantRemoteDataSource? _remoteDataSource;

  // Active la tentative réseau.
  final bool _remoteSyncEnabled;

  // Durée de fraîcheur du cache.
  final Duration _cacheTtl;

  // Traducteur d'erreurs techniques.
  final ErrorMapper _errorMapper;

  // ---------------------------------------------------------------------------
  // API publique
  // ---------------------------------------------------------------------------

  /// Charge le catalogue selon la stratégie offline-first.
  @override
  Future<Either<Failure, List<Restaurant>>> getRestaurants({
    bool forceRefresh = false,
  }) {
    return _run<List<Restaurant>>(() async {
      // Instant unique : toutes les braises sont résolues au même moment.
      final DateTime now = clock.now();
      final RestaurantCatalogModel catalog = await _loadCatalog(
        forceRefresh: forceRefresh,
      );

      // Conversion en entités immuables.
      return catalog.restaurants
          .map((RestaurantModel model) => model.toEntity(now))
          .toList(growable: false);
    });
  }

  /// Charge une fiche précise après validation de l'identifiant.
  @override
  Future<Either<Failure, Restaurant>> getRestaurantById(String id) {
    return _run<Restaurant>(() async {
      // Validation défensive : le use case l'a déjà fait, on refait le contrôle.
      final String safeId = InputSanitizer.sanitizeIdentifier(id);
      if (safeId.isEmpty) {
        throw const ValidationException(
          'Identifiant de restaurant invalide.',
          field: 'restaurantId',
        );
      }

      // Chargement (cache prioritaire, puis réseau/seed).
      final RestaurantCatalogModel catalog = await _loadCatalog(
        forceRefresh: false,
      );
      final DateTime now = clock.now();
      for (final RestaurantModel model in catalog.restaurants) {
        if (model.id == safeId) {
          return model.toEntity(now);
        }
      }

      // Fiche absente du catalogue courant.
      throw NotFoundException(
        'Ce restaurant n’est plus disponible.',
        resourceId: safeId,
      );
    });
  }

  /// Charge le radar d'événements.
  @override
  Future<Either<Failure, List<EventRadar>>> getEventRadar({
    bool forceRefresh = false,
  }) {
    return _run<List<EventRadar>>(() async {
      // Instant unique pour la matérialisation des événements relatifs.
      final DateTime now = clock.now();
      final RestaurantCatalogModel catalog = await _loadCatalog(
        forceRefresh: forceRefresh,
      );
      return catalog.toEventEntities(now);
    });
  }

  /// Lit les favoris locaux.
  @override
  Future<Either<Failure, Set<String>>> getFavoriteIds() {
    return _run<Set<String>>(() async {
      await localDataSource.ensureSchemaVersion();
      return localDataSource.readFavoriteIds();
    });
  }

  /// Ajoute, retire ou inverse un favori.
  @override
  Future<Either<Failure, bool>> toggleFavorite(
    String restaurantId, {
    bool? isFavorite,
  }) {
    return _run<bool>(() async {
      // Validation de la clé de stockage.
      final String safeId = InputSanitizer.sanitizeIdentifier(restaurantId);
      if (safeId.isEmpty) {
        throw const ValidationException(
          'Identifiant de restaurant invalide.',
          field: 'restaurantId',
        );
      }

      // Un favori ne peut cibler qu'un restaurant réellement présent.
      final RestaurantCatalogModel catalog = await _loadCatalog(
        forceRefresh: false,
      );
      var exists = false;
      for (final RestaurantModel model in catalog.restaurants) {
        if (model.id == safeId) {
          exists = true;
          break;
        }
      }
      if (!exists) {
        throw NotFoundException(
          'Ce restaurant n’est plus disponible.',
          resourceId: safeId,
        );
      }

      // État courant lu dans Hive.
      final Set<String> favorites = await localDataSource.readFavoriteIds();
      final bool nextValue = isFavorite ?? !favorites.contains(safeId);

      // Écriture idempotente.
      await localDataSource.writeFavorite(safeId, isFavorite: nextValue);
      return nextValue;
    });
  }

  /// Lit la date de dernière synchronisation.
  @override
  Future<Either<Failure, DateTime?>> getLastSyncAt() {
    return _run<DateTime?>(() async {
      await localDataSource.ensureSchemaVersion();
      return localDataSource.readLastSyncAt();
    });
  }

  // ---------------------------------------------------------------------------
  // Écritures locales (offline-first)
  // ---------------------------------------------------------------------------

  /// Ajoute un établissement au cache chiffré.
  @override
  Future<Either<Failure, Restaurant>> addRestaurant(Restaurant restaurant) {
    return _run<Restaurant>(() async {
      // L'identifiant sert de clé de route et de clé de code gérant : il doit
      // être conforme avant toute écriture.
      final String safeId = InputSanitizer.sanitizeIdentifier(restaurant.id);
      if (safeId.isEmpty) {
        throw const ValidationException(
          'Identifiant d’établissement invalide.',
          field: 'restaurantId',
        );
      }

      final List<RestaurantModel> models = await _readWritableCatalog();
      if (models.any((RestaurantModel model) => model.id == safeId)) {
        throw const ValidationException(
          'Un établissement avec cet identifiant existe déjà.',
          field: 'restaurantId',
        );
      }

      // `fromEntity` garantit le même schéma JSON que le seed et l'API.
      models.add(RestaurantModel.fromEntity(restaurant));
      await _writeModels(models);
      return restaurant;
    });
  }

  /// Ajoute un plat au menu d'une fiche existante.
  @override
  Future<Either<Failure, Restaurant>> addMenuItem({
    required String restaurantId,
    required MenuItem item,
  }) {
    return _run<Restaurant>(() async {
      final String safeRestaurantId = InputSanitizer.sanitizeIdentifier(
        restaurantId,
      );
      final String safeItemId = InputSanitizer.sanitizeIdentifier(item.id);
      if (safeRestaurantId.isEmpty || safeItemId.isEmpty) {
        throw const ValidationException(
          'Identifiant de plat ou d’établissement invalide.',
          field: 'itemId',
        );
      }
      if (safeItemId != item.id) {
        throw const ValidationException(
          'Identifiant de plat non conforme.',
          field: 'itemId',
        );
      }

      final List<RestaurantModel> models = await _readWritableCatalog();
      final int index = models.indexWhere(
        (RestaurantModel model) => model.id == safeRestaurantId,
      );
      if (index < 0) {
        throw NotFoundException(
          'Cet établissement n’est plus disponible.',
          resourceId: safeRestaurantId,
        );
      }

      final DateTime now = clock.now();
      final Restaurant current = models[index].toEntity(now);
      if (current.menu.any((MenuItem existing) => existing.id == safeItemId)) {
        throw const ValidationException(
          'Ce plat existe déjà dans le menu.',
          field: 'itemId',
        );
      }

      // Copie immuable : les autres champs de la fiche restent strictement
      // identiques, seul le menu et la date de mise à jour évoluent.
      final Restaurant updated = current.copyWith(
        menu: <MenuItem>[...current.menu, item],
        updatedAt: now,
      );
      models[index] = RestaurantModel.fromEntity(updated);
      await _writeModels(models);
      return updated;
    });
  }

  /// Retire un plat du menu d'une fiche existante.
  @override
  Future<Either<Failure, Restaurant>> removeMenuItem({
    required String restaurantId,
    required String itemId,
  }) {
    return _run<Restaurant>(() async {
      final String safeRestaurantId = InputSanitizer.sanitizeIdentifier(
        restaurantId,
      );
      final String safeItemId = InputSanitizer.sanitizeIdentifier(itemId);
      if (safeRestaurantId.isEmpty || safeItemId.isEmpty) {
        throw const ValidationException(
          'Identifiant de plat ou d’établissement invalide.',
          field: 'itemId',
        );
      }

      final List<RestaurantModel> models = await _readWritableCatalog();
      final int index = models.indexWhere(
        (RestaurantModel model) => model.id == safeRestaurantId,
      );
      if (index < 0) {
        throw NotFoundException(
          'Cet établissement n’est plus disponible.',
          resourceId: safeRestaurantId,
        );
      }

      final DateTime now = clock.now();
      final Restaurant current = models[index].toEntity(now);
      if (!current.menu.any((MenuItem existing) => existing.id == safeItemId)) {
        throw NotFoundException(
          'Ce plat n’existe plus dans le menu.',
          resourceId: safeItemId,
        );
      }

      final Restaurant updated = current.copyWith(
        menu: current.menu
            .where((MenuItem item) => item.id != safeItemId)
            .toList(growable: false),
        updatedAt: now,
      );
      models[index] = RestaurantModel.fromEntity(updated);
      await _writeModels(models);
      return updated;
    });
  }

  /// Lit la base de travail des écritures : cache présent, sinon seed embarqué.
  /// Le seed est renvoyé sans être persisté ici : `_writeModels` écrira la
  /// version enrichie, ce qui évite de perdre les fiches de démonstration.
  Future<List<RestaurantModel>> _readWritableCatalog() async {
    await localDataSource.ensureSchemaVersion();
    try {
      final List<RestaurantModel> cached = await localDataSource
          .readRestaurants();
      if (cached.isNotEmpty) {
        // Les sources de lecture renvoient des listes NON modifiables : on
        // travaille toujours sur une copie, sinon `add`/`[]=` lèverait une
        // `UnsupportedError` (convertie en UnknownFailure) lors des écritures.
        return List<RestaurantModel>.of(cached);
      }
    } on Object {
      // Cache corrompu : on repart du seed, comme au premier lancement.
    }

    final RestaurantCatalogModel seed = await seedDataSource.load();
    return List<RestaurantModel>.of(seed.restaurants);
  }

  /// Persiste la liste et horodate l'écriture locale.
  /// La date de synchronisation est rafraîchie : les ajouts locaux ne doivent
  /// pas être écrasés par une API distante qui ignorerait ces fiches.
  Future<void> _writeModels(List<RestaurantModel> models) async {
    await localDataSource.writeRestaurants(models);
    await localDataSource.writeLastSyncAt(clock.now());
  }

  // ---------------------------------------------------------------------------
  // Chargement offline-first
  // ---------------------------------------------------------------------------

  /// Applique la stratégie cache -> API -> cache -> seed.
  Future<RestaurantCatalogModel> _loadCatalog({
    required bool forceRefresh,
  }) async {
    // Une éventuelle migration de schéma est appliquée avant toute lecture.
    await localDataSource.ensureSchemaVersion();

    // -------------------------------------------------------------------------
    // 1. Lecture du cache
    // -------------------------------------------------------------------------
    List<RestaurantModel> cachedRestaurants = const <RestaurantModel>[];
    List<EventRadarModel> cachedEvents = const <EventRadarModel>[];
    var cacheReadable = true;
    try {
      cachedRestaurants = await localDataSource.readRestaurants();
      cachedEvents = await localDataSource.readEvents();
    } on Object {
      // Un cache corrompu est purgé : les favoris restent intacts.
      cacheReadable = false;
      await localDataSource.clearCatalog();
    }

    final bool cacheFresh =
        cacheReadable && cachedRestaurants.isNotEmpty && await _isCacheFresh();

    // Cache frais et rafraîchissement non demandé : réponse immédiate.
    if (!forceRefresh && cacheFresh) {
      return _cachedCatalog(cachedRestaurants, cachedEvents);
    }

    // -------------------------------------------------------------------------
    // 2. Tentative réseau (si activée et si une interface est disponible)
    // -------------------------------------------------------------------------
    AppException? remoteError;
    final RestaurantRemoteDataSource? remote = _remote;
    if (_remoteSyncEnabled && remote != null) {
      var connected = false;
      try {
        connected = await networkInfo.isConnected;
      } on Object {
        // Une erreur de plugin équivaut à « pas de réseau ».
        connected = false;
      }

      if (connected) {
        try {
          final RestaurantCatalogModel catalog = await remote.fetchCatalog();

          // Le cache ne doit jamais masquer une réponse fraîche.
          await _persistQuietly(catalog);
          return catalog;
        } on AppException catch (error) {
          remoteError = error;
        } on Object catch (error) {
          remoteError = UnknownException(
            'La synchronisation distante a échoué.',
            cause: error,
          );
        }
      }
    }

    // -------------------------------------------------------------------------
    // 3. Cache périmé mais utilisable (mode dégradé)
    // -------------------------------------------------------------------------
    if (cachedRestaurants.isNotEmpty) {
      return _cachedCatalog(cachedRestaurants, cachedEvents);
    }

    // -------------------------------------------------------------------------
    // 4. Aucun cache : catalogue embarqué
    // -------------------------------------------------------------------------
    try {
      final RestaurantCatalogModel seed = await seedDataSource.load();
      await _persistQuietly(seed);
      return seed;
    } on AppException catch (error) {
      // On préfère l'erreur réseau, plus actionnable, si elle existe.
      throw remoteError ?? error;
    }
  }

  /// Construit un catalogue à partir des listes déjà en cache.
  RestaurantCatalogModel _cachedCatalog(
    List<RestaurantModel> restaurants,
    List<EventRadarModel> events,
  ) {
    return RestaurantCatalogModel(
      schemaVersion: AppConstants.catalogSchemaVersion,
      restaurants: restaurants,
      events: events,
    );
  }

  /// Vérifie que le cache n'a pas dépassé sa durée de fraîcheur.
  Future<bool> _isCacheFresh() async {
    try {
      final DateTime? lastSync = await localDataSource.readLastSyncAt();
      if (lastSync == null) {
        return false;
      }

      // Une date future (horloge déréglée) n'est pas considérée comme fraîche.
      final Duration age = clock.now().difference(lastSync);
      return age >= Duration.zero && age < _cacheTtl;
    } on Object {
      return false;
    }
  }

  /// Persiste le catalogue sans faire échouer la réponse en cas d'erreur disque.
  Future<void> _persistQuietly(RestaurantCatalogModel catalog) async {
    try {
      await localDataSource.writeRestaurants(catalog.restaurants);
      await localDataSource.writeEvents(catalog.events);
      await localDataSource.writeLastSyncAt(clock.now());
    } on Object {
      // Le catalogue reste utilisable en mémoire ; le cache sera retenté plus tard.
      return;
    }
  }

  /// Construit la source HTTP à la demande, si une URL sûre est configurée.
  RestaurantRemoteDataSource? get _remote {
    // Une source injectée (fake de test) est prioritaire.
    if (_remoteDataSource != null) {
      return _remoteDataSource;
    }

    // Sans activation explicite, aucun appel réseau.
    if (!_remoteSyncEnabled) {
      return null;
    }

    final String baseUrl = AppConfig.apiBaseUrl.trim();
    if (baseUrl.isEmpty) {
      return null;
    }

    try {
      final HttpRestaurantRemoteDataSource remote =
          HttpRestaurantRemoteDataSource(baseUrl: baseUrl);
      _remoteDataSource = remote;
      return remote;
    } on SecurityException {
      // URL non HTTPS : le mode local reste disponible, sans erreur bloquante.
      return null;
    }
  }

  /// Exécute une opération en convertissant toute exception en `Failure`.
  Future<Either<Failure, T>> _run<T>(Future<T> Function() action) async {
    try {
      return right<Failure, T>(await action());
    } on Object catch (error, stackTrace) {
      // Le stack trace est consommé par le mapper (futur logger), pas exposé.
      return left<Failure, T>(_errorMapper.mapWithStack(error, stackTrace));
    }
  }
}
