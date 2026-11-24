// =============================================================================
// Use case : retirer un plat du menu d'un établissement.
// =============================================================================

// Égalité des paramètres.
import 'package:equatable/equatable.dart';

// Either.
import 'package:fpdart/fpdart.dart';

// Erreurs, contrat et nettoyage.
import '../../../../core/error/failures.dart';
import '../../../../core/security/input_sanitizer.dart';
import '../../../../core/usecases/usecase.dart';

// Entité et repository.
import '../../../restaurants/domain/entities/restaurant.dart';
import '../../../restaurants/domain/repositories/restaurant_repository.dart';

// Vérification du code.
import 'verify_owner_code.dart';

/// Paramètres de suppression d'un plat.
final class RemoveMenuItemParams extends Equatable {
  /// Construit des paramètres typés.
  const RemoveMenuItemParams({
    required this.restaurantId,
    required this.code,
    required this.itemId,
  });

  /// Établissement concerné.
  final String restaurantId;

  /// Code gérant revérifié à chaque écriture.
  final String code;

  /// Identifiant du plat à retirer.
  final String itemId;

  /// Propriétés comparées par Equatable.
  @override
  List<Object?> get props => <Object?>[restaurantId, itemId];
}

/// Retire un plat après vérification du code gérant.
final class RemoveMenuItem
    implements UseCase<Restaurant, RemoveMenuItemParams> {
  /// Injection du repository et de la vérification.
  const RemoveMenuItem(this._repository, this._verifyCode);

  // Dépendances uniques.
  final RestaurantRepository _repository;
  final VerifyOwnerCode _verifyCode;

  /// Authentifie puis supprime.
  @override
  Future<Either<Failure, Restaurant>> call(RemoveMenuItemParams params) async {
    final String safeRestaurantId = InputSanitizer.sanitizeIdentifier(
      params.restaurantId,
    );
    final String safeItemId = InputSanitizer.sanitizeIdentifier(params.itemId);
    if (safeRestaurantId.isEmpty || safeItemId.isEmpty) {
      return Future<Either<Failure, Restaurant>>.value(
        left(
          const ValidationFailure(
            message: 'Établissement ou plat invalide.',
            field: 'itemId',
          ),
        ),
      );
    }

    final Either<Failure, bool> verification = await _verifyCode(
      VerifyOwnerCodeParams(restaurantId: safeRestaurantId, code: params.code),
    );
    return verification.fold<Future<Either<Failure, Restaurant>>>(
      (Failure failure) async => left<Failure, Restaurant>(failure),
      (bool isValid) async {
        if (!isValid) {
          return left<Failure, Restaurant>(
            const SecurityFailure(
              message: 'Code gérant incorrect. Modification refusée.',
            ),
          );
        }
        return _repository.removeMenuItem(
          restaurantId: safeRestaurantId,
          itemId: safeItemId,
        );
      },
    );
  }
}
