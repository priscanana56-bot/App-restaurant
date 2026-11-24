// =============================================================================
// Implémentation du repository de l'annuaire sourcé.
// =============================================================================

// Either fonctionnel.
import 'package:fpdart/fpdart.dart';

// Mapping d'erreurs.
import '../../../../core/error/error_mapper.dart';
import '../../../../core/error/failures.dart';

// Entité Domain.
import '../../domain/entities/koudougou_listing.dart';

// Contrat implémenté.
import '../../domain/repositories/koudougou_directory_repository.dart';

// Source de données.
import '../datasources/koudougou_directory_data_source.dart';

/// Repository concret de l'annuaire.
final class KoudougouDirectoryRepositoryImpl
    implements KoudougouDirectoryRepository {
  /// Injection de la source et du traducteur d'erreurs.
  KoudougouDirectoryRepositoryImpl(this._dataSource, {ErrorMapper? errorMapper})
    : _errorMapper = errorMapper ?? const ErrorMapper();

  // Dépendances privées.
  final KoudougouDirectoryDataSource _dataSource;
  final ErrorMapper _errorMapper;

  /// Charge les fiches sans jamais laisser fuir d'exception.
  @override
  Future<Either<Failure, List<KoudougouListing>>> getListings() async {
    try {
      return right<Failure, List<KoudougouListing>>(await _dataSource.load());
    } on Object catch (error, stackTrace) {
      return left<Failure, List<KoudougouListing>>(
        _errorMapper.mapWithStack(error, stackTrace),
      );
    }
  }
}
