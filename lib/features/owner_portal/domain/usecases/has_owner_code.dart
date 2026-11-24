// =============================================================================
// Use case : indiquer si un établissement possède déjà un code gérant.
// -----------------------------------------------------------------------------
// Purement descriptif : aucun code n'est lu ni renvoyé, seulement un booléen.
// Permet à l'UI d'expliquer qu'une fiche du catalogue doit d'abord recevoir un
// code de la part de l'administration avant d'être gérable.
// =============================================================================

// Either.
import 'package:fpdart/fpdart.dart';

// Erreurs, contrat et service.
import '../../../../core/error/failures.dart';
import '../../../../core/security/pin_auth.dart';
import '../../../../core/usecases/usecase.dart';

/// Vérifie l'existence d'un code gérant pour un établissement.
final class HasOwnerCode implements UseCase<bool, String> {
  /// Injection du service de codes.
  const HasOwnerCode(this._auth);

  // Dépendance unique.
  final PinAuthService _auth;

  @override
  Future<Either<Failure, bool>> call(String restaurantId) async =>
      right<Failure, bool>(await _auth.hasOwnerCode(restaurantId));
}
