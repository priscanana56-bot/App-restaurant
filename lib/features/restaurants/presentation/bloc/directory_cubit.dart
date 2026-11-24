// =============================================================================
// Cubit de l'annuaire réel de Koudougou.
// -----------------------------------------------------------------------------
// Il charge l'asset sourcé une fois, puis applique recherche et filtres en
// mémoire : aucune écriture n'est possible depuis l'application, ce qui garantit
// que les fiches restent identiques à leurs sources citées.
// =============================================================================

// Cubit.
import 'package:flutter_bloc/flutter_bloc.dart';

// Contrat des use cases (`NoParams` n'est pas ré-exporté par le use case).
import '../../../../core/usecases/usecase.dart';

// Domaine.
import '../../domain/entities/koudougou_listing.dart';
import '../../domain/usecases/get_koudougou_directory.dart';

// État.
import 'directory_state.dart';

/// Pilote l'affichage de l'annuaire.
final class DirectoryCubit extends Cubit<DirectoryState> {
  /// Injection du use case.
  DirectoryCubit(this._getDirectory) : super(const DirectoryState());

  // Dépendance unique.
  final GetKoudougouDirectory _getDirectory;

  /// Charge les fiches sourcées.
  Future<void> load() async {
    // Évite un double chargement concurrent.
    if (state.status == DirectoryStatus.loading ||
        state.status == DirectoryStatus.ready) {
      return;
    }

    emit(state.copyWith(status: DirectoryStatus.loading, failure: null));

    // Le use case ne jette jamais : les erreurs sont dans le `Either`.
    final result = await _getDirectory(const NoParams());
    result.fold(
      (failure) => emit(
        state.copyWith(status: DirectoryStatus.failure, failure: failure),
      ),
      (listings) => emit(
        state.copyWith(status: DirectoryStatus.ready, listings: listings),
      ),
    );
  }

  /// Met à jour la recherche locale.
  void searchChanged(String query) {
    emit(state.copyWith(query: query));
  }

  /// Filtre sur un niveau de vérification (`null` = tous).
  void verificationChanged(DirectoryVerification? verification) {
    emit(state.copyWith(verification: verification));
  }

  /// Réinitialise recherche et filtres.
  void clearFilters() {
    emit(state.copyWith(query: '', verification: null));
  }
}
