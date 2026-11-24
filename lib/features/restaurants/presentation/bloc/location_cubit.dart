// =============================================================================
// Cubit de localisation GPS (écran carte).
// -----------------------------------------------------------------------------
// Il expose l'état de la demande de position : au repos, en cours, obtenue ou en
// échec. La position sert uniquement à trier les restaurants par proximité et à
// afficher une distance : aucune position n'est jamais envoyée à un serveur.
// =============================================================================

// Equatable pour comparer deux états.
import 'package:equatable/equatable.dart';

// Cubit.
import 'package:flutter_bloc/flutter_bloc.dart';

// Erreur métier éventuelle.
import '../../../../core/error/failures.dart';

// Service de localisation et objet-valeur.
import '../../../../core/location/geo_point.dart';
import '../../../../core/location/location_service.dart';

/// Cycle de vie de la demande de position.
enum LocationStatus {
  /// Aucune demande effectuée.
  initial,

  /// Demande en cours (permission + lecture GPS).
  loading,

  /// Position obtenue.
  ready,

  /// Échec (permission refusée, service désactivé...).
  failure,
}

/// État du cubit de localisation.
final class LocationState extends Equatable {
  /// Construit un état au repos.
  const LocationState({
    this.status = LocationStatus.initial,
    this.position,
    this.failure,
  });

  /// Étape courante.
  final LocationStatus status;

  /// Position obtenue, ou `null`.
  final GeoPoint? position;

  /// Erreur éventuelle.
  final Failure? failure;

  /// `true` pendant la demande.
  bool get isLoading => status == LocationStatus.loading;

  /// `true` si la position est disponible.
  bool get hasPosition => status == LocationStatus.ready && position != null;

  /// Copie modifiée de l'état.
  LocationState copyWith({
    LocationStatus? status,
    GeoPoint? position,
    Object? failure = _unset,
  }) {
    return LocationState(
      status: status ?? this.status,
      position: position ?? this.position,
      failure: identical(failure, _unset) ? this.failure : failure as Failure?,
    );
  }

  /// Sentinelle interne.
  static const Object _unset = Object();

  /// Propriétés comparées par Equatable.
  @override
  List<Object?> get props => <Object?>[status, position, failure];
}

/// Cubit pilotant la demande de position.
final class LocationCubit extends Cubit<LocationState> {
  /// Injection du service (fake en test).
  LocationCubit(this._service) : super(const LocationState());

  // Dépendance.
  final LocationService _service;

  /// Demande la position courante et publie le résultat.
  Future<void> request() async {
    // Passage en chargement, erreur précédente effacée.
    emit(state.copyWith(status: LocationStatus.loading, failure: null));

    // Appel du service (jamais d'exception : tout est converti en Failure).
    final result = await _service.currentPosition();

    // Publication de l'état final.
    result.fold(
      (Failure failure) => emit(
        state.copyWith(status: LocationStatus.failure, failure: failure),
      ),
      (GeoPoint position) => emit(
        state.copyWith(
          status: LocationStatus.ready,
          position: position,
          failure: null,
        ),
      ),
    );
  }
}
