// =============================================================================
// Contrat de persistance des avis locaux.
// -----------------------------------------------------------------------------
// Le repository ne connaît ni Hive ni JSON : il manipule des modèles. Ce contrat
// permet de remplacer le stockage par un faux en mémoire dans les tests.
// =============================================================================

// Modèle stocké.
import '../models/app_review_model.dart';

/// Stockage local des avis sur l'application.
abstract interface class AppReviewLocalDataSource {
  /// Lit tous les avis, du plus récent au plus ancien.
  Future<List<AppReviewModel>> readReviews();

  /// Ajoute ou remplace un avis par son identifiant.
  Future<void> writeReview(AppReviewModel review);
}
