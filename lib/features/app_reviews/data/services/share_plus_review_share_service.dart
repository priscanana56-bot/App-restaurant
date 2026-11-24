// =============================================================================
// Partage d'avis via la feuille native du système (`share_plus`).
// -----------------------------------------------------------------------------
// Aucun fichier n'est écrit et aucun texte n'est envoyé par l'application :
// c'est l'utilisateur qui choisit la destination (messagerie, réseaux, copie).
// =============================================================================

// Either.
import 'package:fpdart/fpdart.dart';

// Plugin de partage.
import 'package:share_plus/share_plus.dart';

// Failures métier.
import '../../../../core/error/failures.dart';

// Service abstrait et entité.
import '../../domain/entities/app_review.dart';
import '../../domain/services/review_share_service.dart';

/// Implémentation concrète du partage.
final class SharePlusReviewShareService implements ReviewShareService {
  /// Injection du client (permet un faux dans les tests si nécessaire).
  const SharePlusReviewShareService(this._sharePlus);

  /// Fabrique pour l'application : instance unique du plugin.
  factory SharePlusReviewShareService.create() =>
      SharePlusReviewShareService(SharePlus.instance);

  // Client de partage injecté.
  final SharePlus _sharePlus;

  /// Construit un message lisible puis ouvre la feuille de partage.
  @override
  Future<Either<Failure, Unit>> share(AppReview review) async {
    try {
      // Étoiles pleines/vides : immédiatement compréhensible sans image.
      final String stars = '${'★' * review.rating}${'☆' * (5 - review.rating)}';
      final String message =
          'Mon avis sur Koudougou Gourmet : $stars\n'
          '${review.comment}\n\n'
          'Guide local des restaurants et maquis de Koudougou.';

      await _sharePlus.share(
        ShareParams(text: message, subject: 'Avis sur Koudougou Gourmet'),
      );
      return right<Failure, Unit>(unit);
    } on Object {
      // Un partage annulé n'est PAS une erreur applicative : `share_plus`
      // renvoie un statut, aucune exception n'est levée dans ce cas.
      // Le détail technique n'est jamais affiché à l'utilisateur.
      return left<Failure, Unit>(
        const ExternalLinkFailure(
          message: 'Le partage n’a pas pu être ouvert sur cet appareil.',
        ),
      );
    }
  }
}
