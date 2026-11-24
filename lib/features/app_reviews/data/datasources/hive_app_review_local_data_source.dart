// =============================================================================
// Implémentation Hive du stockage des avis.
// -----------------------------------------------------------------------------
// La boîte est déjà ouverte avec le chiffrement AES par `HiveRestaurantCache` :
// aucune clé n'est manipulée ici. Les avis sont stockés sous forme de chaînes
// JSON, exactement comme le catalogue, ce qui évite tout adaptateur généré.
// =============================================================================

// Hive typé.
import 'package:hive_ce/hive.dart';

// Erreurs stables de la couche Data.
import '../../../../core/error/exceptions.dart';

// Contrat implémenté.
import 'app_review_local_data_source.dart';

// Modèle échangé.
import '../models/app_review_model.dart';

/// Stockage Hive des avis locaux.
final class HiveAppReviewLocalDataSource implements AppReviewLocalDataSource {
  /// Injection de la boîte ouverte par le bootstrap du cache.
  const HiveAppReviewLocalDataSource(this._box);

  // Boîte chiffrée (fournie, jamais ouverte ici).
  final Box<String> _box;

  /// Lit tous les avis valides, triés du plus récent au plus ancien.
  @override
  Future<List<AppReviewModel>> readReviews() async {
    try {
      final List<AppReviewModel> reviews = <AppReviewModel>[];
      for (final String raw in _box.values) {
        try {
          reviews.add(AppReviewModel.fromJsonString(raw));
        } on FormatException {
          // Une entrée corrompue est ignorée : elle ne bloque pas les autres.
        }
      }
      reviews.sort(
        (AppReviewModel left, AppReviewModel right) =>
            right.createdAt.compareTo(left.createdAt),
      );
      return List<AppReviewModel>.unmodifiable(reviews);
    } on Object catch (error) {
      throw CacheException('Lecture des avis impossible.', cause: error);
    }
  }

  /// Persiste un avis sous sa clé stable.
  @override
  Future<void> writeReview(AppReviewModel review) async {
    try {
      await _box.put(review.id, review.toJsonString());
    } on Object catch (error) {
      throw CacheException(
        'Enregistrement de l’avis impossible.',
        cause: error,
      );
    }
  }
}
