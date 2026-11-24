// =============================================================================
// Use case : récupérer une fiche par identifiant.
// -----------------------------------------------------------------------------
// L'identifiant vient d'une route ou d'un lien : il est revalidé AVANT de
// toucher au repository (défense en profondeur contre les injections de clés).
// =============================================================================

// Contrat UseCase et Either.
import 'package:fpdart/fpdart.dart';

// Equatable pour les paramètres.
import 'package:equatable/equatable.dart';

// Erreurs métier.
import '../../../../core/error/failures.dart';

// Nettoyage des identifiants.
import '../../../../core/security/input_sanitizer.dart';

// Contrat de base du use case.
import '../../../../core/usecases/usecase.dart';

// Entité retournée.
import '../entities/restaurant.dart';

// Repository consommé.
import '../repositories/restaurant_repository.dart';

/// Identifiant du restaurant demandé.
final class GetRestaurantByIdParams extends Equatable {
  /// Construit les paramètres avec l'identifiant brut.
  const GetRestaurantByIdParams(this.restaurantId);

  /// Identifiant tel que reçu par la Présentation.
  final String restaurantId;

  /// Propriétés comparées par Equatable.
  @override
  List<Object?> get props => <Object?>[restaurantId];
}

/// Use case de lecture d'une fiche.
final class GetRestaurantById
    implements UseCase<Restaurant, GetRestaurantByIdParams> {
  /// Injection du repository.
  const GetRestaurantById(this._repository);

  // Dépendance métier.
  final RestaurantRepository _repository;

  /// Valide l'identifiant puis interroge le repository.
  @override
  Future<Either<Failure, Restaurant>> call(GetRestaurantByIdParams params) {
    // Nettoyage strict : seuls lettres, chiffres, `_` et `-` sont acceptés.
    final String id = InputSanitizer.sanitizeIdentifier(params.restaurantId);

    // Un identifiant vide ne doit jamais atteindre une clé de stockage.
    if (id.isEmpty) {
      return Future<Either<Failure, Restaurant>>.value(
        left(
          const ValidationFailure(
            message: 'Identifiant de restaurant invalide.',
            field: 'restaurantId',
          ),
        ),
      );
    }

    // Délégation à la Data.
    return _repository.getRestaurantById(id);
  }
}
