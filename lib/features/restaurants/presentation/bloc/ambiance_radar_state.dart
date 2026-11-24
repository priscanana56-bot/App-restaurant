// =============================================================================
// État du radar d'ambiance.
// =============================================================================

// Equatable pour comparer deux états.
import 'package:equatable/equatable.dart';

// Erreur métier éventuelle.
import '../../../../core/error/failures.dart';

// Entité affichée.
import '../../domain/entities/event_radar.dart';

/// Cycle de vie du chargement du radar.
enum AmbianceRadarStatus {
  /// Aucune demande effectuée.
  initial,

  /// Chargement en cours.
  loading,

  /// Événements disponibles.
  ready,

  /// Échec.
  failure,
}

/// État du radar d'ambiance.
final class AmbianceRadarState extends Equatable {
  /// Construit un état sûr par défaut.
  const AmbianceRadarState({
    this.status = AmbianceRadarStatus.initial,
    this.events = const <EventRadar>[],
    this.onlyLive = false,
    this.now,
    this.failure,
  });

  /// Étape courante.
  final AmbianceRadarStatus status;

  /// Événements à afficher (déjà filtrés et triés par le use case).
  final List<EventRadar> events;

  /// N'afficher que les événements en cours.
  final bool onlyLive;

  /// Instant de référence pour le badge « en direct ».
  final DateTime? now;

  /// Erreur éventuelle.
  final Failure? failure;

  /// `true` pendant le chargement.
  bool get isLoading => status == AmbianceRadarStatus.loading;

  /// `true` si le chargement a échoué.
  bool get hasError => status == AmbianceRadarStatus.failure;

  /// `true` si le radar est vide.
  bool get isEmpty => status == AmbianceRadarStatus.ready && events.isEmpty;

  /// Copie modifiée de l'état.
  AmbianceRadarState copyWith({
    AmbianceRadarStatus? status,
    List<EventRadar>? events,
    bool? onlyLive,
    DateTime? now,
    Object? failure = _unset,
  }) {
    return AmbianceRadarState(
      status: status ?? this.status,
      events: events ?? this.events,
      onlyLive: onlyLive ?? this.onlyLive,
      now: now ?? this.now,
      failure: identical(failure, _unset) ? this.failure : failure as Failure?,
    );
  }

  /// Sentinelle interne.
  static const Object _unset = Object();

  /// Propriétés comparées par Equatable.
  @override
  List<Object?> get props => <Object?>[status, events, onlyLive, now, failure];
}
