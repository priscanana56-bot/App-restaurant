// =============================================================================
// Use case : partager un avis avec l'entourage.
// =============================================================================

// Either.
import 'package:fpdart/fpdart.dart';

// Erreurs et contrat.
import '../../../../core/error/failures.dart';
import '../../../../core/usecases/usecase.dart';

// Entité et service abstrait.
import '../entities/app_review.dart';
import '../services/review_share_service.dart';

/// Ouvre la feuille de partage système pour un avis donné.
final class ShareAppReview implements UseCase<Unit, AppReview> {
  /// Injection du service de partage.
  const ShareAppReview(this._shareService);

  // Dépendance unique.
  final ReviewShareService _shareService;

  /// Délègue au service, sans jamais lever d'exception.
  @override
  Future<Either<Failure, Unit>> call(AppReview review) {
    return _shareService.share(review);
  }
}
