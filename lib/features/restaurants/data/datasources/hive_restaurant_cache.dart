// =============================================================================
// Bootstrap du cache Hive chiffré.
// -----------------------------------------------------------------------------
// La clé AES-256 est lue (ou créée) dans le Keychain iOS / Keystore Android.
// Elle n'est jamais écrite dans le code, dans un asset ou dans un fichier en
// clair. Sur le web, Hive ne prend pas en charge le chiffrement AES : l'appelant
// doit passer `encrypt: false` et assumer un stockage local non chiffré (ou
// désactiver le cache web).
// =============================================================================

// Type de la clé AES.
import 'dart:typed_data';

// Hive + extension Flutter (initFlutter).
import 'package:hive_ce_flutter/hive_flutter.dart';

// Noms des boîtes.
import '../../../../core/constants/app_constants.dart';

// Exceptions stables.
import '../../../../core/error/exceptions.dart';

// Coffre-fort de la clé.
import '../../../../core/security/secure_key_store.dart';

// Avis locaux sur l'application (boîte séparée, même chiffrement AES).
import '../../../app_reviews/data/datasources/app_review_local_data_source.dart';
import '../../../app_reviews/data/datasources/hive_app_review_local_data_source.dart';

// Implémentation locale.
import 'hive_restaurant_local_data_source.dart';
import 'restaurant_local_data_source.dart';

/// Ensemble des boîtes Hive du catalogue, prêt pour l'injection.
final class HiveRestaurantCache {
  // Constructeur privé : passer par `open`.
  HiveRestaurantCache._(
    this._restaurantsBox,
    this._eventsBox,
    this._favoritesBox,
    this._settingsBox,
    this._reviewsBox,
  ) {
    // DataSources construites une seule fois avec les boîtes ouvertes.
    dataSource = HiveRestaurantLocalDataSource(
      _restaurantsBox,
      _eventsBox,
      _favoritesBox,
      _settingsBox,
    );
    reviewDataSource = HiveAppReviewLocalDataSource(_reviewsBox);
  }

  // Boîtes ouvertes.
  final Box<String> _restaurantsBox;
  final Box<String> _eventsBox;
  final Box<String> _favoritesBox;
  final Box<String> _settingsBox;
  final Box<String> _reviewsBox;

  /// Source locale consommée par le repository du catalogue.
  late final RestaurantLocalDataSource dataSource;

  /// Source locale consommée par le repository des avis.
  late final AppReviewLocalDataSource reviewDataSource;

  /// Ouvre (ou récupère) les quatre boîtes, avec chiffrement par défaut.
  static Future<HiveRestaurantCache> open({
    required SecureKeyStore keyStore,
    bool encrypt = true,
  }) async {
    try {
      // Initialisation du répertoire applicatif (idempotente).
      await Hive.initFlutter();

      // Construction du chiffrement uniquement si demandé.
      HiveAesCipher? cipher;
      if (encrypt) {
        final Uint8List key = await keyStore.getOrCreateHiveKey();
        cipher = HiveAesCipher(key);
      }

      // Ouverture des cinq boîtes : catalogue + avis sur l'application.
      final Box<String> restaurantsBox = await _openBox(
        AppConstants.restaurantsBoxName,
        cipher,
      );
      final Box<String> eventsBox = await _openBox(
        AppConstants.eventsBoxName,
        cipher,
      );
      final Box<String> favoritesBox = await _openBox(
        AppConstants.favoritesBoxName,
        cipher,
      );
      final Box<String> settingsBox = await _openBox(
        AppConstants.settingsBoxName,
        cipher,
      );
      final Box<String> reviewsBox = await _openBox(
        AppConstants.appReviewsBoxName,
        cipher,
      );

      return HiveRestaurantCache._(
        restaurantsBox,
        eventsBox,
        favoritesBox,
        settingsBox,
        reviewsBox,
      );
    } on AppException {
      // Une erreur de coffre-fort ou de cache déjà typée est conservée.
      rethrow;
    } on Object catch (error) {
      throw CacheException(
        'Ouverture du cache local impossible.',
        cause: error,
      );
    }
  }

  /// Ouvre une boîte ou récupère une boîte déjà ouverte.
  static Future<Box<String>> _openBox(
    String name,
    HiveAesCipher? cipher,
  ) async {
    // Hive interdit d'ouvrir deux fois la même boîte avec des options
    // différentes : on réutilise l'instance existante.
    if (Hive.isBoxOpen(name)) {
      return Hive.box<String>(name);
    }
    return Hive.openBox<String>(name, encryptionCipher: cipher);
  }

  /// Ferme proprement les boîtes (tests, réinitialisation, fin de session).
  Future<void> close() async {
    await Future.wait<void>(<Future<void>>[
      _restaurantsBox.close(),
      _eventsBox.close(),
      _favoritesBox.close(),
      _settingsBox.close(),
      _reviewsBox.close(),
    ]);
  }
}
