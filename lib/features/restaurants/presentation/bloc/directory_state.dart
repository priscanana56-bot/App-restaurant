// =============================================================================
// État de l'annuaire réel de Koudougou.
// =============================================================================

// Equatable pour des états comparables.
import 'package:equatable/equatable.dart';

// Failure éventuelle.
import '../../../../core/error/failures.dart';

// Entité affichée.
import '../../domain/entities/koudougou_listing.dart';

/// Cycle de vie du chargement de l'annuaire.
enum DirectoryStatus {
  /// Chargement pas encore lancé.
  initial,

  /// Chargement en cours.
  loading,

  /// Données disponibles.
  ready,

  /// Échec de lecture de l'asset.
  failure,
}

/// État immuable de l'annuaire.
final class DirectoryState extends Equatable {
  /// Construit un état sûr par défaut.
  const DirectoryState({
    this.status = DirectoryStatus.initial,
    this.listings = const <KoudougouListing>[],
    this.query = '',
    this.verification,
    this.failure,
  });

  /// Étape courante.
  final DirectoryStatus status;

  /// Toutes les fiches sourcées.
  final List<KoudougouListing> listings;

  /// Recherche locale (nom, quartier, spécialité).
  final String query;

  /// Filtre optionnel sur le niveau de vérification.
  final DirectoryVerification? verification;

  /// Erreur éventuelle.
  final Failure? failure;

  /// `true` pendant le chargement initial.
  bool get isLoading => status == DirectoryStatus.loading && listings.isEmpty;

  /// `true` si le chargement a échoué.
  bool get hasError => status == DirectoryStatus.failure;

  /// Fiches correspondant aux filtres actifs.
  List<KoudougouListing> get visibleListings {
    // Recherche normalisée une seule fois.
    final String needle = query.trim().toLowerCase();

    return List<KoudougouListing>.unmodifiable(
      listings.where((KoudougouListing listing) {
        // Filtre de vérification.
        final DirectoryVerification? wanted = verification;
        if (wanted != null && listing.verification != wanted) {
          return false;
        }

        // Sans recherche, toutes les fiches sont conservées.
        if (needle.isEmpty) {
          return true;
        }

        // Recherche sur les champs publics pertinents.
        return listing.name.toLowerCase().contains(needle) ||
            listing.category.toLowerCase().contains(needle) ||
            listing.area.toLowerCase().contains(needle) ||
            listing.specialties.toLowerCase().contains(needle);
      }),
    );
  }

  /// Copie modifiée de l'état.
  DirectoryState copyWith({
    DirectoryStatus? status,
    List<KoudougouListing>? listings,
    String? query,
    Object? verification = _unset,
    Object? failure = _unset,
  }) {
    return DirectoryState(
      status: status ?? this.status,
      listings: listings ?? this.listings,
      query: query ?? this.query,
      verification: identical(verification, _unset)
          ? this.verification
          : verification as DirectoryVerification?,
      failure: identical(failure, _unset) ? this.failure : failure as Failure?,
    );
  }

  // Sentinelles pour distinguer « inchangé » de « remettre à null ».
  static const Object _unset = Object();

  /// Propriétés comparées par Equatable.
  @override
  List<Object?> get props => <Object?>[
    status,
    listings,
    query,
    verification,
    failure,
  ];
}
