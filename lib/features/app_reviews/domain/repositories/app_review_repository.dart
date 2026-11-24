// =============================================================================
// Contrat du repository des avis sur l'application.
// =============================================================================

// Either pour une frontière sans exception.
import 'package:fpdart/fpdart.dart';

// Failures métier.
import '../../../../core/error/failures.dart';

// Entité manipulée.
import '../entities/app_review.dart';

/// Accès local aux avis sur l'application.
abstract interface class AppReviewRepository {
  /// Liste des avis enregistrés sur cet appareil.
  Future<Either<Failure, List<AppReview>>> getReviews();

  /// Enregistre un avis et le renvoie tel qu'il a été persisté.
  Future<Either<Failure, AppReview>> saveReview(AppReview review);
}
