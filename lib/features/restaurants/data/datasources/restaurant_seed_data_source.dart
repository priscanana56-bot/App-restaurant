// =============================================================================
// Source de données embarquée (seed).
// -----------------------------------------------------------------------------
// Le catalogue de démonstration est un asset JSON versionné. Il est utilisé
// UNIQUEMENT lorsque ni le cache ni l'API ne peuvent fournir de données :
// il garantit que l'application reste utilisable hors ligne dès le premier
// lancement.
// =============================================================================

// Accès aux assets Flutter.
import 'package:flutter/services.dart';

// Chemin du seed.
import '../../../../core/constants/app_constants.dart';

// Exceptions stables.
import '../../../../core/error/exceptions.dart';

// Modèle de catalogue.
import '../models/restaurant_catalog_model.dart';

/// Contrat de chargement du seed.
abstract interface class RestaurantSeedDataSource {
  /// Charge et valide le catalogue embarqué.
  Future<RestaurantCatalogModel> load();
}

/// Implémentation basée sur le bundle d'assets.
final class AssetRestaurantSeedDataSource implements RestaurantSeedDataSource {
  /// [bundle] permet d'injecter un faux bundle dans les tests.
  AssetRestaurantSeedDataSource({
    AssetBundle? bundle,
    this.assetPath = AppConstants.seedAssetPath,
  }) : _bundle = bundle ?? rootBundle;

  // Bundle source (rootBundle en production).
  final AssetBundle _bundle;

  /// Chemin de l'asset JSON (surchargeable dans les tests).
  final String assetPath;

  /// Charge le JSON embarqué et le valide comme n'importe quelle source.
  @override
  Future<RestaurantCatalogModel> load() async {
    try {
      final String raw = await _bundle.loadString(assetPath);
      return RestaurantCatalogModel.fromJsonString(raw);
    } on AppException {
      rethrow;
    } on Object catch (error) {
      throw CacheException(
        'Les données embarquées de Koudougou sont illisibles.',
        cause: error,
      );
    }
  }
}
