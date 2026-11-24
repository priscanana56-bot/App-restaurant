// =============================================================================
// Use case : vérifier le code créateur.
// =============================================================================

// Either.
import 'package:fpdart/fpdart.dart';

// Erreurs, contrat et service PIN.
import '../../../../core/error/failures.dart';
import '../../../../core/security/pin_auth.dart';
import '../../../../core/usecases/usecase.dart';

/// Compare l'empreinte du code saisi avec celle du coffre natif.
final class VerifyCreatorPin implements UseCase<bool, String> {
  /// Injection du service.
  const VerifyCreatorPin(this._auth);

  // Dépendance unique.
  final PinAuthService _auth;

  /// Renvoie `true` uniquement si le code est correct.
  @override
  Future<Either<Failure, bool>> call(String pin) => _auth.verifyCreatorPin(pin);
}
