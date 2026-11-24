// =============================================================================
// BLoC du radar d'ambiance.
// -----------------------------------------------------------------------------
// Le radar met en avant les concerts, matchs et soirées des maquis. Le filtrage
// temporel (événements passés masqués, en cours d'abord) est réalisé par le use
// case `GetEventRadar` : ce BLoC ne fait que piloter le chargement et l'option
// « uniquement en direct ».
// =============================================================================

// BLoC et émetteur.
import 'package:flutter_bloc/flutter_bloc.dart';

// Type fonctionnel.
import 'package:fpdart/fpdart.dart';

// Erreur métier.
import '../../../../core/error/failures.dart';

// Horloge injectable.
import '../../../../core/utils/app_clock.dart';

// Entité.
import '../../domain/entities/event_radar.dart';

// Use case consommé.
import '../../domain/usecases/get_event_radar.dart';

// Contrat d'événements et d'état.
import 'ambiance_radar_event.dart';
import 'ambiance_radar_state.dart';

/// BLoC du radar d'ambiance.
final class AmbianceRadarBloc
    extends Bloc<AmbianceRadarEvent, AmbianceRadarState> {
  /// Injection du use case et de l'horloge.
  AmbianceRadarBloc({required this._getEventRadar, required this._clock})
    : super(const AmbianceRadarState()) {
    // Handlers.
    on<AmbianceRadarStarted>(_onStarted);
    on<AmbianceRadarRefreshRequested>(_onRefreshRequested);
    on<AmbianceRadarOnlyLiveToggled>(_onOnlyLiveToggled);
  }

  // Dépendances métier.
  final GetEventRadar _getEventRadar;
  final AppClock _clock;

  /// Chargement initial.
  Future<void> _onStarted(
    AmbianceRadarStarted event,
    Emitter<AmbianceRadarState> emit,
  ) => _load(emit: emit, forceRefresh: false);

  /// Rafraîchissement explicite.
  Future<void> _onRefreshRequested(
    AmbianceRadarRefreshRequested event,
    Emitter<AmbianceRadarState> emit,
  ) => _load(emit: emit, forceRefresh: true);

  /// Bascule du filtre « en direct » puis rechargement.
  Future<void> _onOnlyLiveToggled(
    AmbianceRadarOnlyLiveToggled event,
    Emitter<AmbianceRadarState> emit,
  ) async {
    // Nouvelle valeur du filtre.
    final bool onlyLive = !state.onlyLive;

    // Publication immédiate de l'intention.
    emit(state.copyWith(onlyLive: onlyLive));

    // Rechargement avec le nouveau critère.
    await _load(emit: emit, forceRefresh: false);
  }

  /// Charge les événements puis publie l'état.
  Future<void> _load({
    required Emitter<AmbianceRadarState> emit,
    required bool forceRefresh,
  }) async {
    // État de chargement (le filtre courant est conservé).
    emit(state.copyWith(status: AmbianceRadarStatus.loading, failure: null));

    // Appel du use case (filtrage temporel inclus).
    final Either<Failure, List<EventRadar>> result = await _getEventRadar(
      GetEventRadarParams(forceRefresh: forceRefresh, onlyLive: state.onlyLive),
    );

    // Traitement fonctionnel.
    result.fold(
      (Failure failure) => emit(
        state.copyWith(status: AmbianceRadarStatus.failure, failure: failure),
      ),
      (List<EventRadar> events) => emit(
        state.copyWith(
          status: AmbianceRadarStatus.ready,
          events: events,
          now: _clock.now(),
          failure: null,
        ),
      ),
    );
  }
}
