// =============================================================================
// Objets-valeurs de classement des restaurants.
// -----------------------------------------------------------------------------
// Ce fichier ne dépend d'AUCUN package Flutter : il peut être testé en pur
// Dart et réutilisé par un éventuel serveur. Les libellés français sont
// centralisés ici pour éviter les chaînes dispersées dans l'interface.
// =============================================================================

// Equatable fournit l'égalité de valeur pour AmbianceInfo.
import 'package:equatable/equatable.dart';

// Seuil métier d'ambiance « animée » (70 sur 100).
import '../../../../core/constants/app_constants.dart';

/// Grande famille d'établissement, utilisée par les filtres de l'écran d'accueil.
enum RestaurantCategory {
  /// Maquis traditionnel : terrasse, grillades, ambiance musicale.
  maquis('Maquis'),

  /// Restaurant assis avec service à table.
  restaurant('Restaurant'),

  /// Restauration rapide locale (burgers, sandwichs, plats à emporter).
  fastFood('Fast-food'),

  /// Café, pâtisserie ou salon de thé.
  cafe('Café / Pâtisserie'),

  /// Catégorie de repli pour une donnée future non encore connue de l'app.
  other('Autre');

  /// Constructeur enrichi : chaque valeur porte son libellé français.
  const RestaurantCategory(this.label);

  /// Libellé affiché dans les puces de filtre et les fiches.
  final String label;

  /// Convertit une valeur textuelle (JSON) en catégorie connue.
  /// Retourne `null` si la valeur est absente ou inconnue, afin que le modèle
  /// puisse choisir explicitement entre rejet et repli.
  static RestaurantCategory? tryParse(String? raw) {
    // Normalisation : minuscules, sans espaces de bord ni tirets.
    final String value = (raw ?? '').trim().toLowerCase().replaceAll('-', '');

    // Correspondance exhaustive et lisible.
    return switch (value) {
      'maquis' => RestaurantCategory.maquis,
      'restaurant' => RestaurantCategory.restaurant,
      // Anciennes valeurs de catégorie : repli vers « Restaurant » pour
      // conserver les fiches déjà publiées sans réintroduire la catégorie.
      'grillades' || 'grill' || 'barbecue' => RestaurantCategory.restaurant,
      'fastfood' => RestaurantCategory.fastFood,
      'cafe' || 'cafepâtisserie' || 'patisserie' => RestaurantCategory.cafe,
      'other' || 'autre' => RestaurantCategory.other,
      _ => null,
    };
  }

  /// Représentation stable utilisée dans le cache JSON.
  String get wireValue => switch (this) {
    RestaurantCategory.maquis => 'maquis',
    RestaurantCategory.restaurant => 'restaurant',
    RestaurantCategory.fastFood => 'fastFood',
    RestaurantCategory.cafe => 'cafe',
    RestaurantCategory.other => 'other',
  };
}

/// Tranche de prix, déduite du prix moyen d'un repas.
enum PriceRange {
  /// Moins de 1 500 FCFA : repas populaire, tô, riz gras.
  budget('Économique', 'Moins de 1 500 FCFA'),

  /// De 1 500 à 3 000 FCFA : plat complet avec boisson.
  moderate('Modéré', '1 500 à 3 000 FCFA'),

  /// Plus de 3 000 FCFA : grillades, poisson, service renforcé.
  premium('Premium', 'Plus de 3 000 FCFA');

  /// Constructeur enrichi avec libellé court et description.
  const PriceRange(this.label, this.description);

  /// Libellé court affiché sur les badges.
  final String label;

  /// Description utilisée dans les filtres.
  final String description;

  /// Déduit la tranche à partir d'un prix moyen en FCFA.
  static PriceRange fromAveragePrice(int averagePriceFcfa) {
    // Un prix négatif est une donnée corrompue : on le classe « économique »
    // plutôt que de propager une valeur absurde dans l'interface.
    if (averagePriceFcfa < 1500) {
      return PriceRange.budget;
    }

    // La borne haute de « modéré » est inclusive.
    if (averagePriceFcfa <= 3000) {
      return PriceRange.moderate;
    }

    // Au-delà, l'établissement est considéré premium.
    return PriceRange.premium;
  }

  /// Convertit une valeur JSON en tranche connue.
  static PriceRange? tryParse(String? raw) {
    // Normalisation tolérante (casse et espaces).
    return switch ((raw ?? '').trim().toLowerCase()) {
      'budget' || 'economique' => PriceRange.budget,
      'moderate' || 'modere' => PriceRange.moderate,
      'premium' => PriceRange.premium,
      _ => null,
    };
  }

  /// Représentation stable dans le cache JSON.
  String get wireValue => switch (this) {
    PriceRange.budget => 'budget',
    PriceRange.moderate => 'moderate',
    PriceRange.premium => 'premium',
  };
}

/// Équipement ou service proposé par l'établissement.
enum RestaurantAmenity {
  /// Espace extérieur ombragé, typique des maquis.
  terrace('Terrasse'),

  /// Salle climatisée.
  airConditioning('Climatisation'),

  /// Accès Wi-Fi (gratuit ou payant selon l'établissement).
  wifi('Wi-Fi'),

  /// Parking privé ou aire de stationnement à proximité.
  parking('Parking'),

  /// Espace adapté aux familles et aux enfants.
  familyFriendly('Familial'),

  /// Musique live ou DJ sur place.
  liveMusic('Musique live'),

  /// Plats disponibles à emporter.
  takeaway('À emporter'),

  /// Livraison possible dans Koudougou.
  delivery('Livraison'),

  /// Tables de groupe et réservations pour événements.
  acceptsGroups('Groupes acceptés'),

  /// Accès facilité pour les personnes à mobilité réduite.
  wheelchairAccessible('Accès PMR'),

  /// Plats sans viande disponibles.
  vegetarianOptions('Options végétariennes');

  /// Constructeur enrichi avec le libellé affiché.
  const RestaurantAmenity(this.label);

  /// Libellé français affiché dans la fiche.
  final String label;

  /// Convertit une valeur JSON inconnue en `null` (donnée ignorée).
  static RestaurantAmenity? tryParse(String? raw) {
    // Les valeurs de cache utilisent le nom Dart ; on accepte aussi le libellé.
    final String value = (raw ?? '').trim().toLowerCase();
    for (final RestaurantAmenity amenity in RestaurantAmenity.values) {
      if (amenity.name.toLowerCase() == value ||
          amenity.label.toLowerCase() == value) {
        return amenity;
      }
    }
    return null;
  }
}

/// Moyen de paiement accepté sur place.
enum PaymentMethod {
  /// Espèces en FCFA.
  cash('Espèces'),

  /// Orange Money via code marchand.
  orangeMoney('Orange Money'),

  /// Moov Money via code marchand.
  moovMoney('Moov Money'),

  /// Carte bancaire (rare, mais présent dans les hôtels-restaurants).
  card('Carte bancaire');

  /// Constructeur enrichi avec le libellé affiché.
  const PaymentMethod(this.label);

  /// Libellé français affiché dans la fiche.
  final String label;

  /// Convertit une valeur JSON inconnue en `null` (donnée ignorée).
  static PaymentMethod? tryParse(String? raw) {
    // Normalisation commune aux valeurs de cache et aux libellés.
    final String value = (raw ?? '').trim().toLowerCase();
    for (final PaymentMethod method in PaymentMethod.values) {
      if (method.name.toLowerCase() == value ||
          method.label.toLowerCase() == value) {
        return method;
      }
    }
    return null;
  }
}

/// Indicateurs d'ambiance affichés par le « radar ».
final class AmbianceInfo extends Equatable {
  /// Construit une ambiance avec un score borné par assertion.
  const AmbianceInfo({
    required this.score,
    required this.musicGenre,
    required this.note,
  }) : assert(score >= 0 && score <= 100, 'Le score doit être entre 0 et 100.');

  /// Score d'affluence et d'animation de 0 (calme) à 100 (complet).
  final int score;

  /// Style musical dominant (ex. « Musique burkinabè », « DJ »).
  final String musicGenre;

  /// Précision courte affichée sous le score.
  final String note;

  /// Indique si l'établissement dépasse le seuil d'ambiance « animée ».
  bool get isLively => score >= AppConstants.crowdedThreshold;

  /// Propriétés comparées par Equatable.
  @override
  List<Object?> get props => <Object?>[score, musicGenre, note];
}
