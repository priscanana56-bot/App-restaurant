// =============================================================================
// Implémentation du repository des avis.
// -----------------------------------------------------------------------------
// Le stockage est exclusivement local : aucun avis n'est envoyé sur un serveur.
// Les erreurs Hive sont converties en `Failure` avant d'atteindre la Présentation.
// =============================================================================

// Either.
import 'package:fpdart/fpdart.dart';

// Mapping exception -> failure.
import '../../../../core/error/error_mapper.dart';
import '../../../../core/error/failures.dart';

// Contrat implémenté.
import '../../domain/repositories/app_review_repository.dart';

// Entité.
import '../../domain/entities/app_review.dart';

// Source locale et modèle.
import '../datasources/app_review_local_data_source.dart';
import '../models/app_review_model.dart';

/// Repository concret des avis.
final class AppReviewRepositoryImpl implements AppReviewRepository {
  /// Injection de la source et du traducteur d'erreurs.
  const AppReviewRepositoryImpl({
    required this.localDataSource,
    this.errorMapper = const ErrorMapper(),
  });

  /// Source locale chiffrée.
  final AppReviewLocalDataSource localDataSource;

  /// Traduction des exceptions techniques.
  final ErrorMapper errorMapper;

  /// Lit les avis stockés.
  @override
  Future<Either<Failure, List<AppReview>>> getReviews() => _run(
    () async => (await localDataSource.readReviews())
        .map((AppReviewModel model) => model.toEntity())
        .toList(growable: false),
  );

  /// Enregistre un avis.
  @override
  Future<Either<Failure, AppReview>> saveReview(AppReview review) =>
      _run(() async {
        final AppReviewModel model = AppReviewModel.fromEntity(review);
        await localDataSource.writeReview(model);
        return model.toEntity();
      });

  /// Convertit toute exception en Failure stable.
  Future<Either<Failure, T>> _run<T>(Future<T> Function() action) async {
    try {
      return right<Failure, T>(await action());
    } on Object catch (error, stackTrace) {
      return left<Failure, T>(errorMapper.mapWithStack(error, stackTrace));
    }
  }
}
