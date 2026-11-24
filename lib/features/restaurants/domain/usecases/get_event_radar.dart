// =============================================================================
// Use case : radar d'ambiance.
// -----------------------------------------------------------------------------
// Filtre les événements passés, met en avant ceux qui sont en cours, puis
// classe les autres par date de début. L'horloge est injectée pour que les
// tests soient totalement déterministes.
// =============================================================================

// Contrat UseCase et Either.
import 'package:fpdart/fpdart.dart';

// Equatable pour les paramètres.
import 'package:equatable/equatable.dart';

// Erreurs métier.
import '../../../../core/error/failures.dart';

// Horloge injectable.
import '../../../../core/utils/app_clock.dart';

// Contrat de base du use case.
import '../../../../core/usecases/usecase.dart';

// Entité retournée.
import '../entities/event_radar.dart';

// Repository consommé.
import '../repositories/restaurant_repository.dart';

/// Paramètres du radar.
final class GetEventRadarParams extends Equatable {
  /// Construit les paramètres.
  const GetEventRadarParams({
    this.forceRefresh = false,
    this.includeFinished = false,
    this.onlyLive = false,
  });

  /// Force une synchronisation avant lecture.
  final bool forceRefresh;

  /// Conserve les événements déjà terminés (historique).
  final bool includeFinished;

  /// Ne garde que les événements en cours.
  final bool onlyLive;

  /// Propriétés comparées par Equatable.
  @override
  List<Object?> get props => <Object?>[forceRefresh, includeFinished, onlyLive];
}

/// Use case du radar d'ambiance.
final class GetEventRadar
    implements UseCase<List<EventRadar>, GetEventRadarParams> {
  /// Injection du repository et de l'horloge.
  const GetEventRadar(this._repository, this._clock);

  // Dépendance métier.
  final RestaurantRepository _repository;

  // Horloge métier de Koudougou.
  final AppClock _clock;

  /// Charge puis filtre les événements.
  @override
  Future<Either<Failure, List<EventRadar>>> call(
    GetEventRadarParams params,
  ) async {
    // Chargement offline-first.
    final Either<Failure, List<EventRadar>> result = await _repository
        .getEventRadar(forceRefresh: params.forceRefresh);

    // Transformation uniquement en cas de succès.
    return result.fold(left, (List<EventRadar> events) {
      // Instant de référence unique.
      final DateTime now = _clock.now();

      // Filtrage métier.
      final List<EventRadar> filtered = events
          .where((EventRadar event) {
            // Les événements terminés sont masqués par défaut.
            if (!params.includeFinished && event.isFinishedAt(now)) {
              return false;
            }

            // Mode « en direct » strict.
            if (params.onlyLive && !event.isLiveAt(now)) {
              return false;
            }

            // Événement retenu.
            return true;
          })
          .toList(growable: true);

      // En cours d'abord, puis début le plus proche.
      filtered.sort((EventRadar leftEvent, EventRadar rightEvent) {
        final bool leftLive = leftEvent.isLiveAt(now);
        final bool rightLive = rightEvent.isLiveAt(now);
        if (leftLive != rightLive) {
          return leftLive ? -1 : 1;
        }
        return leftEvent.startsAt.compareTo(rightEvent.startsAt);
      });

      // Résultat immuable.
      return right<Failure, List<EventRadar>>(
        List<EventRadar>.unmodifiable(filtered),
      );
    });
  }
}
