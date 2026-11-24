// =============================================================================
// Contrats de base des use cases.
// -----------------------------------------------------------------------------
// Un use case représente UNE intention métier (ex. « récupérer les restaurants »).
// Il reçoit des paramètres typés et renvoie toujours un `Either<Failure, T>` :
// la Présentation n'a donc jamais à attraper d'exception.
// =============================================================================

// `Either` et `Failure` forment le contrat fonctionnel du Domain.
import 'package:fpdart/fpdart.dart';

// Erreur métier exposée aux couches supérieures.
import '../error/failures.dart';

// Equatable pour comparer les paramètres sans valeur (NoParams).
import 'package:equatable/equatable.dart';

/// Use case asynchrone avec paramètres.
abstract interface class UseCase<SuccessType, Params> {
  /// Exécute l'intention métier.
  Future<Either<Failure, SuccessType>> call(Params params);
}

/// Use case asynchrone sans paramètre.
abstract interface class UseCaseNoParams<SuccessType> {
  /// Exécute l'intention métier sans argument.
  Future<Either<Failure, SuccessType>> call();
}

/// Use case réactif (flux continu), utile pour le Live Braise et le radar.
abstract interface class StreamUseCase<SuccessType, Params> {
  /// Émet des états métier successifs jusqu'à fermeture de l'abonnement.
  Stream<Either<Failure, SuccessType>> call(Params params);
}

/// Paramètres vides, à utiliser quand un use case n'a besoin d'aucune donnée.
/// `Equatable` permet de comparer deux instances et de les utiliser dans un BLoC.
final class NoParams extends Equatable {
  /// Constructeur constant : une seule instance logique.
  const NoParams();

  /// Aucune propriété : toutes les instances de NoParams sont égales.
  @override
  List<Object?> get props => const <Object?>[];
}
