// =============================================================================
// Événements du radar d'ambiance.
// =============================================================================

// Equatable pour comparer les événements.
import 'package:equatable/equatable.dart';

/// Base scellée des événements du radar.
sealed class AmbianceRadarEvent extends Equatable {
  /// Constructeur constant.
  const AmbianceRadarEvent();

  /// Aucune propriété par défaut.
  @override
  List<Object?> get props => const <Object?>[];
}

/// Chargement initial du radar.
final class AmbianceRadarStarted extends AmbianceRadarEvent {
  /// Aucun paramètre.
  const AmbianceRadarStarted();
}

/// Rafraîchissement explicite.
final class AmbianceRadarRefreshRequested extends AmbianceRadarEvent {
  /// Aucun paramètre.
  const AmbianceRadarRefreshRequested();
}

/// Bascule du filtre « uniquement en direct ».
final class AmbianceRadarOnlyLiveToggled extends AmbianceRadarEvent {
  /// Aucun paramètre.
  const AmbianceRadarOnlyLiveToggled();
}
