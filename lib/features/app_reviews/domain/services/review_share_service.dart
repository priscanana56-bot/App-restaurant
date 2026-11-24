// =============================================================================
// Abstraction du partage d'un avis.
// -----------------------------------------------------------------------------
// Le Domain ne doit pas connaître `share_plus` : il déclare seulement le service
// dont il a besoin. L'implémentation concrète vit dans la couche Data, ce qui
// rend le use case testable avec un faux sans plugin natif.
// =============================================================================

// Either.
import 'package:fpdart/fpdart.dart';

// Failures et Unit.
import '../../../../core/error/failures.dart';

// Avis à partager.
import '../entities/app_review.dart';

/// Service de partage externe d'un avis.
abstract interface class ReviewShareService {
  /// Ouvre la feuille de partage du système avec un message lisible.
  Future<Either<Failure, Unit>> share(AppReview review);
}
