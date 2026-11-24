// =============================================================================
// Use case : Live Braise du moment.
// -----------------------------------------------------------------------------
// Le repository fournit le catalogue complet ; ce use case ne garde que les
// braises réellement actives à l'heure de Koudougou, puis les classe par fin
// imminente. Les braises terminées ou épuisées ne sont jamais affichées.
// =============================================================================

// Contrat UseCase et Either.
import 'package:fpdart/fpdart.dart';

// Equatable pour les paramètres.
import 'package:equatable/equatable.dart';

// Nombre maximal de braises affichées par défaut.
import '../../../../core/constants/app_constants.dart';

// Erreurs métier.
import '../../../../core/error/failures.dart';

// Horloge injectable.
import '../../../../core/utils/app_clock.dart';

// Contrat de base du use case.
import '../../../../core/usecases/usecase.dart';

// Entités.
import '../entities/live_braise_status.dart';
import '../entities/restaurant.dart';

// Repository consommé.
import '../repositories/restaurant_repository.dart';

/// Paramètres du bandeau Live Braise.
final class GetLiveBraiseParams extends Equatable {
  /// Construit les paramètres.
  const GetLiveBraiseParams({
    this.forceRefresh = false,
    this.limit = AppConstants.liveBraiseMaxItems,
  }) : assert(limit > 0, 'La limite doit être strictement positive.');

  /// Force une synchronisation du catalogue avant lecture.
  final bool forceRefresh;

  /// Nombre maximal de braises retournées.
  final int limit;

  /// Propriétés comparées par Equatable.
  @override
  List<Object?> get props => <Object?>[forceRefresh, limit];
}

/// Use case du bandeau Live Braise.
final class GetLiveBraise
    implements UseCase<List<LiveBraiseStatus>, GetLiveBraiseParams> {
  /// Injection du repository et de l'horloge.
  const GetLiveBraise(this._repository, this._clock);

  // Dépendance métier.
  final RestaurantRepository _repository;

  // Horloge métier de Koudougou.
  final AppClock _clock;

  /// Charge, filtre et trie les braises actives.
  @override
  Future<Either<Failure, List<LiveBraiseStatus>>> call(
    GetLiveBraiseParams params,
  ) async {
    // Chargement offline-first du catalogue.
    final Either<Failure, List<Restaurant>> result = await _repository
        .getRestaurants(forceRefresh: params.forceRefresh);

    // Propagation de l'erreur éventuelle sans la transformer.
    return result.fold(left, (List<Restaurant> restaurants) {
      // Instant de référence unique.
      final DateTime now = _clock.now();

      // Collecte des braises actives uniquement.
      final List<LiveBraiseStatus> active = <LiveBraiseStatus>[];
      for (final Restaurant restaurant in restaurants) {
        final LiveBraiseStatus? braise = restaurant.activeLiveBraiseAt(now);
        if (braise != null) {
          active.add(braise);
        }
      }

      // Fin la plus proche d'abord : l'utilisateur doit se dépêcher.
      active.sort(
        (LiveBraiseStatus leftBraise, LiveBraiseStatus rightBraise) =>
            leftBraise.endsAt.compareTo(rightBraise.endsAt),
      );

      // Limitation du bandeau pour ne pas saturer l'écran.
      final List<LiveBraiseStatus> limited = active
          .take(params.limit)
          .toList(growable: false);

      // Retour fonctionnel immuable.
      return right<Failure, List<LiveBraiseStatus>>(limited);
    });
  }
}
