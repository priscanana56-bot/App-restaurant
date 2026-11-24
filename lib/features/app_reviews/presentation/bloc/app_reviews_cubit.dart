// =============================================================================
// Cubit de l'espace « avis sur l'application ».
// -----------------------------------------------------------------------------
// La page ne manipule ni Hive ni `share_plus` : elle observe cet état et envoie
// des intentions simples (note, commentaire, enregistrement, partage).
// =============================================================================

// Cubit.
import 'package:flutter_bloc/flutter_bloc.dart';

// Domaine.
import '../../domain/entities/app_review.dart';
import '../../domain/usecases/get_app_reviews.dart';
import '../../domain/usecases/share_app_review.dart';
import '../../domain/usecases/submit_app_review.dart';

// État.
import 'app_reviews_state.dart';

/// Pilote l'écran des avis.
final class AppReviewsCubit extends Cubit<AppReviewsState> {
  /// Injection des trois use cases.
  AppReviewsCubit(this._getReviews, this._submitReview, this._shareReview)
    : super(const AppReviewsState());

  // Dépendances uniques.
  final GetAppReviews _getReviews;
  final SubmitAppReview _submitReview;
  final ShareAppReview _shareReview;

  /// Charge les avis déjà enregistrés.
  Future<void> load() async {
    emit(state.copyWith(status: AppReviewsStatus.loading, failure: null));
    final result = await _getReviews();
    result.fold(
      (failure) => emit(
        state.copyWith(status: AppReviewsStatus.failure, failure: failure),
      ),
      (reviews) => emit(
        state.copyWith(status: AppReviewsStatus.ready, reviews: reviews),
      ),
    );
  }

  /// Met à jour la note choisie.
  void ratingChanged(int rating) {
    // Bornage défensif : un widget ne peut pas publier une note invalide.
    final int safeRating = rating.clamp(1, 5);
    emit(state.copyWith(rating: safeRating, failure: null));
  }

  /// Met à jour le commentaire saisi.
  void commentChanged(String comment) {
    emit(state.copyWith(comment: comment, failure: null));
  }

  /// Enregistre l'avis courant puis le place en tête de liste.
  Future<void> submit() async {
    if (state.isBusy) {
      return;
    }
    emit(state.copyWith(isBusy: true, failure: null, infoMessage: null));

    final result = await _submitReview(
      SubmitAppReviewParams(rating: state.rating, comment: state.comment),
    );
    result.fold(
      (failure) => emit(state.copyWith(isBusy: false, failure: failure)),
      (review) {
        final List<AppReview> next = <AppReview>[
          review,
          ...state.reviews.where(
            (AppReview existing) => existing.id != review.id,
          ),
        ];
        emit(
          state.copyWith(
            isBusy: false,
            status: AppReviewsStatus.ready,
            reviews: List<AppReview>.unmodifiable(next),
            comment: '',
            infoMessage: 'Merci ! Votre avis est enregistré sur cet appareil.',
          ),
        );
      },
    );
  }

  /// Ouvre la feuille de partage système pour un avis.
  Future<void> share(AppReview review) async {
    if (state.isBusy) {
      return;
    }
    emit(state.copyWith(isBusy: true, failure: null, infoMessage: null));

    final result = await _shareReview(review);
    result.fold(
      (failure) => emit(state.copyWith(isBusy: false, failure: failure)),
      (_) => emit(
        state.copyWith(
          isBusy: false,
          infoMessage: 'Votre avis est prêt à être partagé.',
        ),
      ),
    );
  }
}
