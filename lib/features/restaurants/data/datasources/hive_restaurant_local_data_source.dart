// =============================================================================
// Implémentation Hive du cache local.
// -----------------------------------------------------------------------------
// Le catalogue est stocké sous forme de chaînes JSON (une par restaurant, une
// par événement) : les types restent explicites et Hive n'a besoin d'aucun
// adaptateur généré. Les boîtes sont ouvertes avec chiffrement AES par
// `HiveRestaurantCache`.
// =============================================================================

// Encodage JSON des modèles.
import 'dart:convert';

// Box Hive typée.
import 'package:hive_ce/hive.dart';

// Constantes (version de schéma, clés).
import '../../../../core/constants/app_constants.dart';

// Exceptions stables de la couche Data.
import '../../../../core/error/exceptions.dart';

// Nettoyage des identifiants.
import '../../../../core/security/input_sanitizer.dart';

// Modèles.
import '../models/event_radar_model.dart';
import '../models/restaurant_model.dart';

// Contrat implémenté.
import 'restaurant_local_data_source.dart';

/// Cache Hive du catalogue.
final class HiveRestaurantLocalDataSource implements RestaurantLocalDataSource {
  /// Reçoit des boîtes déjà ouvertes (et déjà chiffrées par le bootstrap).
  /// Les paramètres sont positionnels pour garder les champs privés tout en
  /// utilisant les initializing formals recommandés par le linter.
  HiveRestaurantLocalDataSource(
    this._restaurantsBox,
    this._eventsBox,
    this._favoritesBox,
    this._settingsBox,
  );

  // Boîtes Hive injectées, jamais exposées.
  final Box<String> _restaurantsBox;
  final Box<String> _eventsBox;
  final Box<String> _favoritesBox;
  final Box<String> _settingsBox;

  // Clé de la date de synchronisation dans la boîte de préférences.
  static const String _lastSyncKey = 'catalog_last_sync_at';

  // Valeur stockée pour un favori (seule la présence de la clé importe).
  static const String _favoriteValue = '1';

  /// Vérifie et applique la version du schéma de cache.
  @override
  Future<void> ensureSchemaVersion() async {
    try {
      final String? stored = _settingsBox.get(AppConstants.cacheSchemaKey);
      final int? version = int.tryParse(stored ?? '');

      // Version identique : aucune migration nécessaire.
      if (version == AppConstants.cacheSchemaVersion) {
        return;
      }

      // Rupture de schéma : le catalogue est purgé, les favoris sont conservés.
      await _restaurantsBox.clear();
      await _eventsBox.clear();
      await _settingsBox.delete(_lastSyncKey);
      await _settingsBox.put(
        AppConstants.cacheSchemaKey,
        '${AppConstants.cacheSchemaVersion}',
      );
    } on AppException {
      // Une erreur métier déjà typée n'est pas masquée.
      rethrow;
    } on Object catch (error) {
      throw CacheException(
        'Initialisation du cache local impossible.',
        cause: error,
      );
    }
  }

  /// Lit et décode les restaurants du cache.
  @override
  Future<List<RestaurantModel>> readRestaurants() async {
    try {
      return _readModels(
        _restaurantsBox,
        RestaurantModel.fromJsonString,
        'restaurants',
      );
    } on AppException {
      rethrow;
    } on Object catch (error) {
      throw CacheException(
        'Lecture du cache des restaurants impossible.',
        cause: error,
      );
    }
  }

  /// Écrit les restaurants dans le cache.
  @override
  Future<void> writeRestaurants(List<RestaurantModel> restaurants) async {
    try {
      final Map<String, String> payload = <String, String>{
        for (final RestaurantModel model in restaurants)
          model.id: jsonEncode(model.toJson()),
      };
      await _restaurantsBox.clear();
      await _restaurantsBox.putAll(payload);
    } on AppException {
      rethrow;
    } on Object catch (error) {
      throw CacheException(
        'Écriture du cache des restaurants impossible.',
        cause: error,
      );
    }
  }

  /// Lit et décode les événements du cache.
  @override
  Future<List<EventRadarModel>> readEvents() async {
    try {
      return _readModels(
        _eventsBox,
        EventRadarModel.fromJsonString,
        'événements',
      );
    } on AppException {
      rethrow;
    } on Object catch (error) {
      throw CacheException(
        'Lecture du cache des événements impossible.',
        cause: error,
      );
    }
  }

  /// Écrit les événements dans le cache.
  @override
  Future<void> writeEvents(List<EventRadarModel> events) async {
    try {
      final Map<String, String> payload = <String, String>{
        for (final EventRadarModel model in events)
          model.id: jsonEncode(model.toJson()),
      };
      await _eventsBox.clear();
      await _eventsBox.putAll(payload);
    } on AppException {
      rethrow;
    } on Object catch (error) {
      throw CacheException(
        'Écriture du cache des événements impossible.',
        cause: error,
      );
    }
  }

  /// Lit les identifiants favoris.
  @override
  Future<Set<String>> readFavoriteIds() async {
    try {
      final Set<String> favorites = <String>{};

      // Les clés Hive sont dynamiques : contrôle de type explicite.
      for (final Object? rawKey in _favoritesBox.keys) {
        if (rawKey is! String) {
          continue;
        }
        final String id = InputSanitizer.sanitizeIdentifier(rawKey);
        if (id.isNotEmpty) {
          favorites.add(id);
        }
      }

      return Set<String>.unmodifiable(favorites);
    } on AppException {
      rethrow;
    } on Object catch (error) {
      throw CacheException('Lecture des favoris impossible.', cause: error);
    }
  }

  /// Ajoute ou retire un favori.
  @override
  Future<void> writeFavorite(
    String restaurantId, {
    required bool isFavorite,
  }) async {
    // Validation de la clé avant toute écriture.
    final String id = InputSanitizer.sanitizeIdentifier(restaurantId);
    if (id.isEmpty) {
      throw const ValidationException(
        'Identifiant de favori invalide.',
        field: 'restaurantId',
      );
    }

    try {
      if (isFavorite) {
        await _favoritesBox.put(id, _favoriteValue);
      } else {
        await _favoritesBox.delete(id);
      }
    } on AppException {
      rethrow;
    } on Object catch (error) {
      throw CacheException('Écriture du favori impossible.', cause: error);
    }
  }

  /// Lit la date de dernière synchronisation.
  @override
  Future<DateTime?> readLastSyncAt() async {
    try {
      final String? raw = _settingsBox.get(_lastSyncKey);
      if (raw == null || raw.isEmpty) {
        return null;
      }

      final DateTime? parsed = DateTime.tryParse(raw);
      if (parsed == null) {
        return null;
      }

      // Normalisation UTC et refus d'une date aberrante.
      final DateTime utc = parsed.toUtc();
      if (utc.year < 2020 || utc.year > 2100) {
        return null;
      }
      return utc;
    } on AppException {
      rethrow;
    } on Object catch (error) {
      throw CacheException(
        'Lecture de la date de synchronisation impossible.',
        cause: error,
      );
    }
  }

  /// Enregistre la date de dernière synchronisation.
  @override
  Future<void> writeLastSyncAt(DateTime instant) async {
    final DateTime utc = instant.toUtc();
    if (utc.year < 2020 || utc.year > 2100) {
      throw const ValidationException(
        'Date de synchronisation invalide.',
        field: 'lastSyncAt',
      );
    }

    try {
      await _settingsBox.put(_lastSyncKey, utc.toIso8601String());
    } on AppException {
      rethrow;
    } on Object catch (error) {
      throw CacheException(
        'Écriture de la date de synchronisation impossible.',
        cause: error,
      );
    }
  }

  /// Purge le catalogue sans effacer les favoris.
  @override
  Future<void> clearCatalog() async {
    try {
      await _restaurantsBox.clear();
      await _eventsBox.clear();
      await _settingsBox.delete(_lastSyncKey);
    } on AppException {
      rethrow;
    } on Object catch (error) {
      throw CacheException('Purge du cache local impossible.', cause: error);
    }
  }

  /// Décode une boîte de modèles, en ignorant les entrées corrompues.
  List<T> _readModels<T>(
    Box<String> box,
    T Function(String raw) decode,
    String label,
  ) {
    // Résultat typé et compteur d'entrées illisibles.
    final List<T> models = <T>[];
    var corrupted = 0;

    for (final String raw in box.values) {
      try {
        models.add(decode(raw));
      } on Object {
        // Une entrée illisible ne doit pas bloquer les autres.
        corrupted++;
      }
    }

    // Toutes les entrées étaient corrompues : le cache est inutilisable.
    if (models.isEmpty && corrupted > 0) {
      throw CacheException(
        'Le cache des $label est illisible et doit être reconstruit.',
      );
    }

    return List<T>.unmodifiable(models);
  }
}
