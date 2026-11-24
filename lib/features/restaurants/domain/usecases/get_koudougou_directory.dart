// =============================================================================
// Use case : charger l'annuaire réel de Koudougou.
// =============================================================================

// Either et Unit.
import 'package:fpdart/fpdart.dart';

// Erreurs métier.
import '../../../../core/error/failures.dart';

// Contrat UseCase.
import '../../../../core/usecases/usecase.dart';

// Entité.
import '../entities/koudougou_listing.dart';

// Repository.
import '../repositories/koudougou_directory_repository.dart';

/// Paramètres : aucun. Le type [NoParams] garantit l'absence d'entrée libre.
final class GetKoudougouDirectory
    implements UseCase<List<KoudougouListing>, NoParams> {
  /// Injection du repository.
  const GetKoudougouDirectory(this._repository);

  // Dépendance unique.
  final KoudougouDirectoryRepository _repository;

  /// Charge les fiches sourcées.
  @override
  Future<Either<Failure, List<KoudougouListing>>> call(NoParams params) {
    return _repository.getListings();
  }
}
