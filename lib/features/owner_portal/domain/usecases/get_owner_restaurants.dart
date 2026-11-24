// =============================================================================
// Use case : lister les établissements gérables sur cet appareil.
// -----------------------------------------------------------------------------
// Le portail gérant travaille sur le catalogue local (offline-first). Il ne
// crée pas de sources : il réutilise le use case public `GetRestaurants`, puis
// la couche Présentation demande le code du gérant avant toute modification.
// =============================================================================

// Either.
import 'package:fpdart/fpdart.dart';

// Erreurs et contrat.
import '../../../../core/error/failures.dart';
import '../../../../core/usecases/usecase.dart';

// Entité et use case du catalogue.
import '../../../restaurants/domain/entities/restaurant.dart';
import '../../../restaurants/domain/usecases/get_restaurants.dart';

/// Charge les fiches accessibles au portail gérant.
final class GetOwnerRestaurants implements UseCaseNoParams<List<Restaurant>> {
  /// Injection du use case du catalogue.
  const GetOwnerRestaurants(this._getRestaurants);

  // Dépendance unique.
  final GetRestaurants _getRestaurants;

  /// Exécute le chargement sans forcer la synchronisation distante.
  @override
  Future<Either<Failure, List<Restaurant>>> call() {
    return _getRestaurants(const GetRestaurantsParams());
  }
}
