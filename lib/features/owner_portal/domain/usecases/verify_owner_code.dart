// =============================================================================
// Use case : vérifier le code d'un gérant.
// -----------------------------------------------------------------------------
// Le code n'est jamais transmis au repository ni à l'API : `PinAuthService`
// compare deux empreintes PBKDF2 salées stockées dans le coffre natif.
// =============================================================================

// Égalité des paramètres.
import 'package:equatable/equatable.dart';

// Either.
import 'package:fpdart/fpdart.dart';

// Erreurs, contrat et nettoyage d'identifiant.
import '../../../../core/error/failures.dart';
import '../../../../core/security/input_sanitizer.dart';
import '../../../../core/security/pin_auth.dart';
import '../../../../core/usecases/usecase.dart';

/// Paramètres de vérification d'un code gérant.
final class VerifyOwnerCodeParams extends Equatable {
  /// Construit des paramètres typés.
  const VerifyOwnerCodeParams({required this.restaurantId, required this.code});

  /// Établissement concerné.
  final String restaurantId;

  /// Code saisi par le gérant.
  final String code;

  // Le code saisi est exclu de l'égalité et du toString d'Equatable : un secret
  // ne doit jamais apparaître dans un journal de debug.
  @override
  List<Object?> get props => <Object?>[restaurantId];
}

/// Vérifie un code gérant local.
final class VerifyOwnerCode implements UseCase<bool, VerifyOwnerCodeParams> {
  /// Injection du service d'authentification locale.
  const VerifyOwnerCode(this._auth);

  // Dépendance unique.
  final PinAuthService _auth;

  /// Renvoie `true` uniquement si l'empreinte correspond.
  @override
  Future<Either<Failure, bool>> call(VerifyOwnerCodeParams params) async {
    // L'identifiant est revalidé avant de construire une clé de stockage.
    final String safeId = InputSanitizer.sanitizeIdentifier(
      params.restaurantId,
    );
    if (safeId.isEmpty) {
      return left(
        const ValidationFailure(
          message: 'Établissement invalide.',
          field: 'restaurantId',
        ),
      );
    }

    return _auth.verifyOwnerCode(
      restaurantId: safeId,
      code: params.code.trim(),
    );
  }
}
