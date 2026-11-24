// =============================================================================
// Use case : indique si un code créateur a déjà été défini.
// =============================================================================

// Either.
import 'package:fpdart/fpdart.dart';

// Erreurs, contrat, mapper et service PIN.
import '../../../../core/error/error_mapper.dart';
import '../../../../core/error/failures.dart';
import '../../../../core/security/pin_auth.dart';
import '../../../../core/usecases/usecase.dart';

/// Vérifie l'existence du code créateur dans le coffre natif.
final class HasCreatorPin implements UseCaseNoParams<bool> {
  /// Injection du service et du traducteur d'erreurs.
  const HasCreatorPin(this._auth, this._errorMapper);

  // Dépendances uniques.
  final PinAuthService _auth;
  final ErrorMapper _errorMapper;

  /// Renvoie `true` si un PIN a déjà été enregistré.
  @override
  Future<Either<Failure, bool>> call() async {
    try {
      return right<Failure, bool>(await _auth.hasCreatorPin());
    } on Object catch (error, stackTrace) {
      return left<Failure, bool>(_errorMapper.mapWithStack(error, stackTrace));
    }
  }
}
