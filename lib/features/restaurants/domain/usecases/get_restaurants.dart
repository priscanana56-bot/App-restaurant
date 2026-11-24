// =============================================================================
// Use case : récupérer la liste des restaurants.
// -----------------------------------------------------------------------------
// Il ne fait que déléguer au repository après avoir typé l'intention. La
// stratégie offline-first (cache, réseau, seed) appartient à la Data.
// =============================================================================

// Contrat UseCase et Either.
import 'package:fpdart/fpdart.dart';

// Equatable pour les paramètres.
import 'package:equatable/equatable.dart';

// Erreurs métier.
import '../../../../core/error/failures.dart';

// Contrat de base du use case.
import '../../../../core/usecases/usecase.dart';

// Entité retournée.
import '../entities/restaurant.dart';

// Repository consommé.
import '../repositories/restaurant_repository.dart';

/// Demande de chargement du catalogue.
final class GetRestaurantsParams extends Equatable {
  /// Construit les paramètres.
  const GetRestaurantsParams({this.forceRefresh = false});

  /// Ignore la fraîcheur du cache et force une synchronisation.
  final bool forceRefresh;

  /// Propriétés comparées par Equatable.
  @override
  List<Object?> get props => <Object?>[forceRefresh];
}

/// Use case de chargement du catalogue.
final class GetRestaurants
    implements UseCase<List<Restaurant>, GetRestaurantsParams> {
  /// Injection du repository (jamais d'instanciation directe dans le Domain).
  const GetRestaurants(this._repository);

  // Dépendance métier.
  final RestaurantRepository _repository;

  /// Exécute le chargement.
  @override
  Future<Either<Failure, List<Restaurant>>> call(GetRestaurantsParams params) {
    // Délégation directe : la Data gère cache, réseau et données de secours.
    return _repository.getRestaurants(forceRefresh: params.forceRefresh);
  }
}
