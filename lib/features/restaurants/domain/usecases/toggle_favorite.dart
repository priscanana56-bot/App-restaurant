// =============================================================================
// Use case : ajouter / retirer un favori.
// -----------------------------------------------------------------------------
// Le geste utilisateur est simple, mais l'identifiant doit être validé avant
// d'être utilisé comme clé de stockage Hive.
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

// Repository consommé.
import '../repositories/restaurant_repository.dart';

/// Paramètres du basculement de favori.
final class ToggleFavoriteParams extends Equatable {
  /// Construit les paramètres.
  const ToggleFavoriteParams({required this.restaurantId, this.isFavorite});

  /// Identifiant du restaurant ciblé.
  final String restaurantId;

  /// État demandé ; `null` signifie « inverser l'état courant ».
  final bool? isFavorite;

  /// Propriétés comparées par Equatable.
  @override
  List<Object?> get props => <Object?>[restaurantId, isFavorite];
}

/// Use case de favori.
final class ToggleFavorite implements UseCase<bool, ToggleFavoriteParams> {
  /// Injection du repository.
  const ToggleFavorite(this._repository);

  // Dépendance métier.
  final RestaurantRepository _repository;

  /// Valide l'identifiant puis délègue au repository.
  @override
  Future<Either<Failure, bool>> call(ToggleFavoriteParams params) {
    // Validation stricte de la clé de stockage.
    final String id = InputSanitizer.sanitizeIdentifier(params.restaurantId);

    // Un identifiant invalide ne doit jamais devenir une clé Hive.
    if (id.isEmpty) {
      return Future<Either<Failure, bool>>.value(
        left(
          const ValidationFailure(
            message: 'Identifiant de restaurant invalide.',
            field: 'restaurantId',
          ),
        ),
      );
    }

    // Délégation à la Data (état courant lu puis écrit).
    return _repository.toggleFavorite(id, isFavorite: params.isFavorite);
  }
}
