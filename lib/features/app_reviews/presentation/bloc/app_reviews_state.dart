// =============================================================================
// État de l'espace « avis sur l'application ».
// =============================================================================

// Égalité de valeur.
import 'package:equatable/equatable.dart';

// Failure éventuelle.
import '../../../../core/error/failures.dart';

// Entité affichée.
import '../../domain/entities/app_review.dart';

/// Cycle de vie de l'écran des avis.
enum AppReviewsStatus {
  /// Pas encore chargé.
  initial,

  /// Chargement en cours.
  loading,

  /// Avis disponibles.
  ready,

  /// Lecture impossible.
  failure,
}

/// État immuable de l'écran des avis.
final class AppReviewsState extends Equatable {
  /// Construit un état sûr par défaut.
  const AppReviewsState({
    this.status = AppReviewsStatus.initial,
    this.reviews = const <AppReview>[],
    this.rating = 5,
    this.comment = '',
    this.isBusy = false,
    this.failure,
    this.infoMessage,
  });

  /// Étape courante.
  final AppReviewsStatus status;

  /// Avis enregistrés sur l'appareil.
  final List<AppReview> reviews;

  /// Note en cours de saisie (1 à 5).
  final int rating;

  /// Commentaire en cours de saisie.
  final String comment;

  /// `true` pendant une écriture ou un partage.
  final bool isBusy;

  /// Dernière erreur affichable.
  final Failure? failure;

  /// Message de confirmation (partage réussi, avis enregistré...).
  final String? infoMessage;

  /// Note moyenne arrondie à une décimale, ou `0` sans avis.
  double get averageRating {
    if (reviews.isEmpty) {
      return 0;
    }
    final int total = reviews.fold<int>(
      0,
      (int sum, AppReview review) => sum + review.rating,
    );
    return (total / reviews.length * 10).round() / 10;
  }

  /// Copie modifiée de l'état.
  AppReviewsState copyWith({
    AppReviewsStatus? status,
    List<AppReview>? reviews,
    int? rating,
    String? comment,
    bool? isBusy,
    Object? failure = _unset,
    Object? infoMessage = _unset,
  }) {
    return AppReviewsState(
      status: status ?? this.status,
      reviews: reviews ?? this.reviews,
      rating: rating ?? this.rating,
      comment: comment ?? this.comment,
      isBusy: isBusy ?? this.isBusy,
      failure: identical(failure, _unset) ? this.failure : failure as Failure?,
      infoMessage: identical(infoMessage, _unset)
          ? this.infoMessage
          : infoMessage as String?,
    );
  }

  // Sentinelles : `null` est une valeur légitime pour effacer un message.
  static const Object _unset = Object();

  /// Propriétés comparées par Equatable.
  @override
  List<Object?> get props => <Object?>[
    status,
    reviews,
    rating,
    comment,
    isBusy,
    failure,
    infoMessage,
  ];
}
