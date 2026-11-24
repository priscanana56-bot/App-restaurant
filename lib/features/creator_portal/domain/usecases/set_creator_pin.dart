// =============================================================================
// Use case : définir ou remplacer le code créateur.
// =============================================================================

// Either.
import 'package:fpdart/fpdart.dart';

// Erreurs, contrat et service PIN.
import '../../../../core/error/failures.dart';
import '../../../../core/security/pin_auth.dart';
import '../../../../core/usecases/usecase.dart';

/// Enregistre l'empreinte du code créateur (jamais le code en clair).
final class SetCreatorPin implements UseCase<Unit, String> {
  /// Injection du service.
  const SetCreatorPin(this._auth);

  // Dépendance unique.
  final PinAuthService _auth;

  /// Écrit le code après validation par le service.
  @override
  Future<Either<Failure, Unit>> call(String pin) => _auth.setCreatorPin(pin);
}
