// =============================================================================
// Tests de l'espace « avis sur l'application ».
// -----------------------------------------------------------------------------
// Les avis restent sur l'appareil : ces tests vérifient le nettoyage du
// commentaire, le bornage de la note, la persistance locale et le partage
// explicite via un service simulé (aucun plugin natif impliqué).
// =============================================================================

// Type fonctionnel.
import 'package:fpdart/fpdart.dart';

// Widgets et thème pour le test de page.
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';

// Erreurs, horloge et thème.
import 'package:koudougou_gourmet/core/error/failures.dart';
import 'package:koudougou_gourmet/core/theme/app_theme.dart';
import 'package:koudougou_gourmet/core/utils/app_clock.dart';

// Avis : Domain, Data et Présentation.
import 'package:koudougou_gourmet/features/app_reviews/data/datasources/app_review_local_data_source.dart';
import 'package:koudougou_gourmet/features/app_reviews/data/models/app_review_model.dart';
import 'package:koudougou_gourmet/features/app_reviews/data/repositories/app_review_repository_impl.dart';
import 'package:koudougou_gourmet/features/app_reviews/domain/entities/app_review.dart';
import 'package:koudougou_gourmet/features/app_reviews/domain/services/review_share_service.dart';
import 'package:koudougou_gourmet/features/app_reviews/domain/usecases/get_app_reviews.dart';
import 'package:koudougou_gourmet/features/app_reviews/domain/usecases/share_app_review.dart';
import 'package:koudougou_gourmet/features/app_reviews/domain/usecases/submit_app_review.dart';
import 'package:koudougou_gourmet/features/app_reviews/presentation/bloc/app_reviews_cubit.dart';
import 'package:koudougou_gourmet/features/app_reviews/presentation/bloc/app_reviews_state.dart';
import 'package:koudougou_gourmet/features/app_reviews/presentation/pages/app_reviews_page.dart';

// Fixture d'horloge.
import '../restaurants/support/fixtures.dart';

/// Extrait la valeur de droite, ou échoue le test.
T _ok<T>(Either<Failure, T> result) => result.fold(
  (Failure failure) => throw StateError('Échec inattendu : ${failure.message}'),
  (T value) => value,
);

/// Extrait la `Failure` de gauche, ou échoue le test.
Failure _failure<T>(Either<Failure, T> result) => result.fold(
  (Failure failure) => failure,
  (T _) => throw StateError('Succès inattendu.'),
);

/// Stockage d'avis en mémoire.
final class FakeReviewDataSource implements AppReviewLocalDataSource {
  /// Avis indexés par identifiant.
  final Map<String, AppReviewModel> stored = <String, AppReviewModel>{};

  @override
  Future<List<AppReviewModel>> readReviews() async {
    final List<AppReviewModel> reviews = stored.values.toList();
    reviews.sort(
      (AppReviewModel left, AppReviewModel right) =>
          right.createdAt.compareTo(left.createdAt),
    );
    return List<AppReviewModel>.unmodifiable(reviews);
  }

  @override
  Future<void> writeReview(AppReviewModel review) async {
    stored[review.id] = review;
  }
}

/// Service de partage simulé.
final class FakeReviewShareService implements ReviewShareService {
  /// Dernier avis partagé.
  AppReview? shared;

  @override
  Future<Either<Failure, Unit>> share(AppReview review) async {
    shared = review;
    return right<Failure, Unit>(unit);
  }
}

/// Banc de test des avis.
final class _Rig {
  /// Construit le banc avec une horloge figée.
  _Rig() {
    source = FakeReviewDataSource();
    shareService = FakeReviewShareService();
    repository = AppReviewRepositoryImpl(localDataSource: source);
    submit = SubmitAppReview(repository, FixedClock(testNow));
    cubit = AppReviewsCubit(
      GetAppReviews(repository),
      submit,
      ShareAppReview(shareService),
    );
  }

  /// Stockage simulé.
  late final FakeReviewDataSource source;

  /// Partage simulé.
  late final FakeReviewShareService shareService;

  /// Repository réel.
  late final AppReviewRepositoryImpl repository;

  /// Use case d'écriture.
  late final SubmitAppReview submit;

  /// Cubit sous test.
  late final AppReviewsCubit cubit;
}

void main() {
  group('Modèle et repository', () {
    test('un avis JSON est nettoyé et sa note bornée', () {
      final AppReviewModel model = AppReviewModel.fromJson(<String, Object?>{
        'id': 'review-1',
        'rating': 4,
        'comment': '<b>Très pratique !</b>',
        'createdAt': testNow.toIso8601String(),
      });

      expect(model.comment, 'Très pratique !');
      expect(model.toEntity().rating, 4);
      expect(
        () => AppReviewModel.fromJson(<String, Object?>{
          'id': 'review-2',
          'rating': 9,
          'comment': '',
          'createdAt': testNow.toIso8601String(),
        }),
        throwsA(isA<FormatException>()),
      );
    });

    test(
      'les avis sont persistés puis relus du plus récent au plus ancien',
      () async {
        final _Rig rig = _Rig();
        final AppReview first = AppReview(
          id: 'review-1',
          rating: 5,
          comment: 'Super',
          createdAt: testNow.subtract(const Duration(days: 1)),
        );
        final AppReview last = AppReview(
          id: 'review-2',
          rating: 3,
          comment: 'Correct',
          createdAt: testNow,
        );

        _ok(await rig.repository.saveReview(first));
        _ok(await rig.repository.saveReview(last));

        final List<AppReview> reviews = _ok(await rig.repository.getReviews());
        expect(reviews.map((AppReview review) => review.id), <String>[
          'review-2',
          'review-1',
        ]);
      },
    );
  });

  group('Use cases', () {
    test('une note hors bornes est refusée', () async {
      final _Rig rig = _Rig();

      expect(
        _failure(
          await rig.submit(const SubmitAppReviewParams(rating: 0, comment: '')),
        ),
        isA<ValidationFailure>(),
      );
      expect(
        _failure(
          await rig.submit(const SubmitAppReviewParams(rating: 6, comment: '')),
        ),
        isA<ValidationFailure>(),
      );
      expect(rig.source.stored, isEmpty);
    });

    test(
      'le commentaire est nettoyé et l’identifiant est déterministe',
      () async {
        final _Rig rig = _Rig();

        final AppReview review = _ok(
          await rig.submit(
            const SubmitAppReviewParams(
              rating: 5,
              comment: '<i>Excellent</i> guide local !',
            ),
          ),
        );

        expect(review.comment, 'Excellent guide local !');
        expect(review.id, 'review_${testNow.microsecondsSinceEpoch}');
        expect(review.createdAt, testNow);
      },
    );

    test('le partage est délégué au service abstrait', () async {
      final _Rig rig = _Rig();
      final AppReview review = AppReview(
        id: 'review-1',
        rating: 4,
        comment: 'Bon guide',
        createdAt: testNow,
      );

      expect(_ok(await ShareAppReview(rig.shareService)(review)), unit);
      expect(rig.shareService.shared, review);
    });
  });

  group('AppReviewsCubit', () {
    test('charge, note, enregistre et partage', () async {
      final _Rig rig = _Rig();
      addTearDown(rig.cubit.close);

      await rig.cubit.load();
      expect(rig.cubit.state.status, AppReviewsStatus.ready);
      expect(rig.cubit.state.reviews, isEmpty);

      rig.cubit.ratingChanged(12);
      expect(rig.cubit.state.rating, 5);
      rig.cubit.ratingChanged(0);
      expect(rig.cubit.state.rating, 1);

      rig.cubit.commentChanged('Très utile');
      await rig.cubit.submit();
      expect(rig.cubit.state.reviews, hasLength(1));
      expect(rig.cubit.state.comment, isEmpty);
      expect(rig.cubit.state.infoMessage, isNotNull);
      expect(rig.cubit.state.averageRating, 1);

      await rig.cubit.share(rig.cubit.state.reviews.first);
      expect(rig.shareService.shared, rig.cubit.state.reviews.first);
      expect(rig.cubit.state.isBusy, isFalse);
    });
  });

  testWidgets('la page affiche la synthèse et le sélecteur de note', (
    WidgetTester tester,
  ) async {
    final _Rig rig = _Rig();
    addTearDown(rig.cubit.close);

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: BlocProvider<AppReviewsCubit>.value(
          value: rig.cubit,
          child: const AppReviewsPage(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Votre avis sur l’application'), findsOneWidget);
    expect(find.text('Votre note'), findsOneWidget);
    expect(find.text('Enregistrer mon avis'), findsOneWidget);
    expect(find.byIcon(Icons.star_rounded), findsWidgets);
  });
}
