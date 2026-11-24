// =============================================================================
// Use case : filtrer et trier une liste déjà chargée.
// -----------------------------------------------------------------------------
// La recherche est LOCALE et pure : aucun appel réseau. Elle est insensible
// aux accents et à la casse (« tô » trouve « Tô »), et tous les critères sont
// évalués avec l'horloge injectée (ouvert maintenant, Live Braise active).
// =============================================================================

// Contrat UseCase et Either.
import 'package:fpdart/fpdart.dart';

// Equatable pour les paramètres.
import 'package:equatable/equatable.dart';

// Erreurs métier.
import '../../../../core/error/failures.dart';

// Nettoyage/normalisation du texte de recherche.
import '../../../../core/security/input_sanitizer.dart';

// Horloge injectable (tests déterministes).
import '../../../../core/utils/app_clock.dart';

// Contrat de base du use case.
import '../../../../core/usecases/usecase.dart';

// Entités et filtre.
import '../entities/restaurant.dart';
import '../entities/restaurant_filter.dart';

/// Entrée du filtrage : la liste source et l'intention utilisateur.
final class FilterRestaurantsParams extends Equatable {
  /// Construit les paramètres.
  const FilterRestaurantsParams({
    required this.restaurants,
    required this.filter,
  });

  /// Catalogue déjà chargé par `GetRestaurants`.
  final List<Restaurant> restaurants;

  /// Critères et tri choisis par l'utilisateur.
  final RestaurantFilter filter;

  /// Propriétés comparées par Equatable.
  @override
  List<Object?> get props => <Object?>[restaurants, filter];
}

/// Use case de filtrage local.
final class FilterRestaurants
    implements UseCase<List<Restaurant>, FilterRestaurantsParams> {
  /// Injection de l'horloge pour les critères « maintenant ».
  const FilterRestaurants(this._clock);

  // Horloge métier de Koudougou.
  final AppClock _clock;

  /// Applique les critères, puis trie le résultat.
  @override
  Future<Either<Failure, List<Restaurant>>> call(
    FilterRestaurantsParams params,
  ) {
    // Instant de référence unique pour toute l'opération.
    final DateTime now = _clock.now();

    // Nettoyage de la requête brute (balises, contrôles, caractères bidi...).
    final String safeQuery = InputSanitizer.sanitizeSearchQuery(
      params.filter.query,
    );

    // Normalisation pour la recherche locale (minuscules, sans accents).
    final String normalizedQuery = InputSanitizer.normalizeForSearch(safeQuery);

    // Découpage en mots : chaque mot doit être présent (ET logique).
    final List<String> tokens = normalizedQuery.isEmpty
        ? const <String>[]
        : normalizedQuery.split(' ');

    // Normalisation du secteur demandé, s'il existe.
    final String normalizedSector = params.filter.sector == null
        ? ''
        : InputSanitizer.normalizeForSearch(params.filter.sector!);

    // Construction de la liste filtrée.
    final List<Restaurant> filtered = params.restaurants
        .where((Restaurant restaurant) {
          // 1. Recherche plein texte sur les champs utiles.
          if (tokens.isNotEmpty) {
            final String haystack = _searchText(restaurant);
            for (final String token in tokens) {
              if (!haystack.contains(token)) {
                return false;
              }
            }
          }

          // 2. Catégorie exacte.
          if (params.filter.category != null &&
              restaurant.category != params.filter.category) {
            return false;
          }

          // 3. Secteur exact (comparaison normalisée).
          if (normalizedSector.isNotEmpty &&
              InputSanitizer.normalizeForSearch(restaurant.sector) !=
                  normalizedSector) {
            return false;
          }

          // 4. Tranche de prix exacte.
          if (params.filter.priceRange != null &&
              restaurant.priceRange != params.filter.priceRange) {
            return false;
          }

          // 5. Ouvert maintenant, selon l'heure de Koudougou.
          if (params.filter.onlyOpenNow && !restaurant.isOpenAt(now)) {
            return false;
          }

          // 6. Braise réellement active à cet instant.
          if (params.filter.onlyLiveBraise &&
              !restaurant.hasLiveBraiseAt(now)) {
            return false;
          }

          // 7. Fiches vérifiées sur place uniquement.
          if (params.filter.onlyVerified && !restaurant.isVerified) {
            return false;
          }

          // 8. Note minimale.
          if (restaurant.rating < params.filter.minRating) {
            return false;
          }

          // Tous les critères sont satisfaits.
          return true;
        })
        .toList(growable: true);

    // Tri selon l'option choisie.
    filtered.sort(
      (Restaurant left, Restaurant right) =>
          _compare(left, right, params.filter.sort, now),
    );

    // Le filtrage local ne peut pas échouer : il renvoie toujours un succès.
    return Future<Either<Failure, List<Restaurant>>>.value(
      right<Failure, List<Restaurant>>(List<Restaurant>.unmodifiable(filtered)),
    );
  }

  /// Construit l'index de recherche texte d'un restaurant.
  String _searchText(Restaurant restaurant) {
    // Tampon pour éviter les concaténations répétées.
    final StringBuffer buffer = StringBuffer()
      ..write(restaurant.name)
      ..write(' ')
      ..write(restaurant.tagline)
      ..write(' ')
      ..write(restaurant.description)
      ..write(' ')
      ..write(restaurant.sector)
      ..write(' ')
      ..write(restaurant.landmark)
      ..write(' ')
      ..write(restaurant.address)
      ..write(' ')
      ..write(restaurant.category.label);

    // Les noms de plats permettent de chercher « poulet » ou « tô ».
    for (final item in restaurant.menu) {
      buffer
        ..write(' ')
        ..write(item.name);
    }

    // Normalisation finale (minuscules, sans accents ni ponctuation).
    return InputSanitizer.normalizeForSearch(buffer.toString());
  }

  /// Compare deux restaurants selon l'ordre demandé.
  int _compare(
    Restaurant left,
    Restaurant right,
    RestaurantSort sort,
    DateTime now,
  ) {
    // Dispatch exhaustif sur l'énumération de tri.
    switch (sort) {
      case RestaurantSort.recommended:
        // Une braise active passe devant tout le reste.
        final bool leftLive = left.hasLiveBraiseAt(now);
        final bool rightLive = right.hasLiveBraiseAt(now);
        if (leftLive != rightLive) {
          return leftLive ? -1 : 1;
        }

        // Puis l'ambiance, la note et le volume d'avis.
        final int byAmbiance = right.ambiance.score.compareTo(
          left.ambiance.score,
        );
        if (byAmbiance != 0) {
          return byAmbiance;
        }
        final int byRating = right.rating.compareTo(left.rating);
        if (byRating != 0) {
          return byRating;
        }
        final int byReviews = right.reviewCount.compareTo(left.reviewCount);
        if (byReviews != 0) {
          return byReviews;
        }
        return _byName(left, right);

      case RestaurantSort.ratingDesc:
        final int byRating = right.rating.compareTo(left.rating);
        if (byRating != 0) {
          return byRating;
        }
        final int byReviews = right.reviewCount.compareTo(left.reviewCount);
        return byReviews != 0 ? byReviews : _byName(left, right);

      case RestaurantSort.priceAsc:
        final int byPrice = left.averagePriceFcfa.compareTo(
          right.averagePriceFcfa,
        );
        return byPrice != 0 ? byPrice : _byName(left, right);

      case RestaurantSort.priceDesc:
        final int byPrice = right.averagePriceFcfa.compareTo(
          left.averagePriceFcfa,
        );
        return byPrice != 0 ? byPrice : _byName(left, right);

      case RestaurantSort.nameAsc:
        return _byName(left, right);
    }
  }

  /// Comparaison alphabétique insensible à la casse.
  int _byName(Restaurant left, Restaurant right) =>
      left.name.toLowerCase().compareTo(right.name.toLowerCase());
}
