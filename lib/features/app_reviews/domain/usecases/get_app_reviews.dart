// =============================================================================
// Use case : lister les avis enregistrés sur l'appareil.
// =============================================================================

// Either.
import 'package:fpdart/fpdart.dart';

// Erreurs et contrat.
import '../../../../core/error/failures.dart';
import '../../../../core/usecases/usecase.dart';

// Entité et repository.
import '../entities/app_review.dart';
import '../repositories/app_review_repository.dart';

/// Charge les avis locaux.
final class GetAppReviews implements UseCaseNoParams<List<AppReview>> {
  /// Injection du repository.
  const GetAppReviews(this._repository);

  // Dépendance unique.
  final AppReviewRepository _repository;

  /// Exécute la lecture.
  @override
  Future<Either<Failure, List<AppReview>>> call() {
    return _repository.getReviews();
  }
}
