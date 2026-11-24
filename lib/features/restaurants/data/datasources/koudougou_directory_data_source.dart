// =============================================================================
// Source de l'annuaire réel de Koudougou.
// -----------------------------------------------------------------------------
// Contrairement au catalogue de démonstration, cet annuaire n'est pas modifiable
// par un gérant : il cite des établissements trouvés dans des sources publiques
// et conserve leur niveau de vérification. Il est embarqué pour rester disponible
// hors ligne.
// =============================================================================

// Décodage JSON (conversion dynamique unique et immédiatement typée).
import 'dart:convert';

// Accès aux assets.
import 'package:flutter/services.dart';

// Erreurs typées.
import '../../../../core/error/exceptions.dart';

// Entité chargée.
import '../../domain/entities/koudougou_listing.dart';

// Modèle JSON.
import '../models/json_reader.dart';
import '../models/koudougou_listing_model.dart';

/// Contrat de chargement de l'annuaire.
abstract interface class KoudougouDirectoryDataSource {
  /// Charge les fiches sourcées.
  Future<List<KoudougouListing>> load();
}

/// Source basée sur l'asset JSON vérifié.
final class AssetKoudougouDirectoryDataSource
    implements KoudougouDirectoryDataSource {
  /// [bundle] est injectable pour les tests.
  AssetKoudougouDirectoryDataSource({
    AssetBundle? bundle,
    this.assetPath = 'assets/seed/koudougou_directory.json',
  }) : _bundle = bundle ?? rootBundle;

  // Bundle d'assets (rootBundle en production).
  final AssetBundle _bundle;

  /// Chemin de l'asset, surchargeable en test.
  final String assetPath;

  /// Charge, valide et nettoie l'annuaire.
  @override
  Future<List<KoudougouListing>> load() async {
    try {
      // Lecture de l'asset texte.
      final String raw = await _bundle.loadString(assetPath);

      // Conversion dynamique unique puis lecture typée.
      final Object? decoded = jsonDecode(raw) as Object?;
      final JsonReader root = JsonReader(
        JsonReader.mapFrom(decoded, context: 'annuaire de Koudougou'),
      );

      // Version de schéma : on refuse un format inconnu.
      final int version = root.requireInt('schemaVersion', min: 1, max: 100);
      if (version != 1) {
        throw const FormatException('Version d’annuaire non prise en charge.');
      }

      // Décodage de chaque fiche.
      final List<KoudougouListing> listings = <KoudougouListing>[];
      for (final Object? item in root.requireList('listings', maxLength: 500)) {
        final KoudougouListingModel model = KoudougouListingModel.fromJson(
          JsonReader.mapFrom(item, context: 'fiche d’annuaire'),
        );
        listings.add(model.toEntity());
      }

      return List<KoudougouListing>.unmodifiable(listings);
    } on AppException {
      // Une erreur déjà typée n'est pas réinterprétée.
      rethrow;
    } on Object catch (error) {
      throw CacheException(
        'L’annuaire de Koudougou est illisible.',
        cause: error,
      );
    }
  }
}
