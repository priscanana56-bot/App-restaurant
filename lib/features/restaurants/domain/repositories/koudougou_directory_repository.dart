// =============================================================================
// Contrat du repository de l'annuaire réel de Koudougou.
// =============================================================================

// Either fonctionnel.
import 'package:fpdart/fpdart.dart';

// Erreurs métier.
import '../../../../core/error/failures.dart';

// Entité exposée.
import '../entities/koudougou_listing.dart';

/// Accès aux fiches sourcées de l'annuaire local.
abstract interface class KoudougouDirectoryRepository {
  /// Retourne les établissements recensés, avec leur statut de vérification.
  Future<Either<Failure, List<KoudougouListing>>> getListings();
}
