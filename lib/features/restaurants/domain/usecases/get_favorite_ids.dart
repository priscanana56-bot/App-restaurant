// =============================================================================
// Use case : lire les identifiants favoris.
// -----------------------------------------------------------------------------
// Utilisé au démarrage pour colorer les cœurs sans recharger tout le catalogue.
// =============================================================================

// Contrat UseCase et Either.
import 'package:fpdart/fpdart.dart';

// Erreurs métier.
import '../../../../core/error/failures.dart';

// Contrat de base sans paramètre.
import '../../../../core/usecases/usecase.dart';

// Repository consommé.
import '../repositories/restaurant_repository.dart';

/// Use case de lecture des favoris.
final class GetFavoriteIds implements UseCaseNoParams<Set<String>> {
  /// Injection du repository.
  const GetFavoriteIds(this._repository);

  // Dépendance métier.
  final RestaurantRepository _repository;

  /// Délègue la lecture au repository.
  @override
  Future<Either<Failure, Set<String>>> call() => _repository.getFavoriteIds();
}
