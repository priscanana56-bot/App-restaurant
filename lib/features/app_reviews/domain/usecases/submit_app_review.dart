// =============================================================================
// Use case : enregistrer un avis sur l'application.
// -----------------------------------------------------------------------------
// La note est validée ici (invariant métier) et le commentaire est nettoyé par
// `InputSanitizer` avant d'atteindre le stockage : aucune balise ni caractère
// de contrôle ne peut être persisté, même si l'UI est contournée.
// =============================================================================

// Égalité des paramètres.
import 'package:equatable/equatable.dart';

// Either.
import 'package:fpdart/fpdart.dart';

// Bornes et nettoyage.
import '../../../../core/constants/app_constants.dart';
import '../../../../core/error/failures.dart';
import '../../../../core/security/input_sanitizer.dart';

// Contrat et horloge.
import '../../../../core/usecases/usecase.dart';
import '../../../../core/utils/app_clock.dart';

// Entité et repository.
import '../entities/app_review.dart';
import '../repositories/app_review_repository.dart';

/// Paramètres typés d'un nouvel avis.
final class SubmitAppReviewParams extends Equatable {
  /// Construit des paramètres validables.
  const SubmitAppReviewParams({required this.rating, required this.comment});

  /// Note de 1 à 5 étoiles.
  final int rating;

  /// Commentaire libre (éventuellement vide).
  final String comment;

  /// Propriétés comparées par Equatable.
  @override
  List<Object?> get props => <Object?>[rating, comment];
}

/// Enregistre un avis local.
final class SubmitAppReview
    implements UseCase<AppReview, SubmitAppReviewParams> {
  /// Injection du repository et de l'horloge.
  const SubmitAppReview(this._repository, this._clock);

  // Dépendances uniques.
  final AppReviewRepository _repository;
  final AppClock _clock;

  /// Valide, nettoie puis persiste l'avis.
  @override
  Future<Either<Failure, AppReview>> call(SubmitAppReviewParams params) async {
    // Invariant métier : une note hors bornes est refusée avant tout stockage.
    if (params.rating < 1 || params.rating > 5) {
      return left(
        const ValidationFailure(
          message: 'Choisissez une note entre 1 et 5 étoiles.',
          field: 'rating',
        ),
      );
    }

    // Le commentaire est facultatif mais toujours nettoyé.
    final String comment = InputSanitizer.sanitizePlainText(
      params.comment,
      maxLength: AppConstants.commentMaxLength,
    );

    // Instant unique : l'identifiant et la date désignent exactement le même
    // événement, ce qui facilite les tests déterministes.
    final DateTime now = _clock.now();

    // Identifiant local dérivé de l'horloge injectée (tests déterministes).
    final String id = InputSanitizer.sanitizeIdentifier(
      'review_${now.microsecondsSinceEpoch}',
    );
    if (id.isEmpty) {
      return left(
        const ValidationFailure(
          message: 'Impossible de créer un identifiant d’avis.',
          field: 'id',
        ),
      );
    }

    final AppReview review = AppReview(
      id: id,
      rating: params.rating,
      comment: comment,
      createdAt: now,
    );
    return _repository.saveReview(review);
  }
}
