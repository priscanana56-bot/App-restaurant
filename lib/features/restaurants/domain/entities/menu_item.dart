// =============================================================================
// Entités du menu d'un restaurant.
// -----------------------------------------------------------------------------
// Un `MenuItem` est immuable et déjà nettoyé par la couche Data. Le Domain
// applique seulement les invariants métier (prix positif, quantité, etc.).
// Aucun import Flutter n'est autorisé dans ce fichier.
// =============================================================================

// Equatable pour comparer deux plats sans écrire == / hashCode à la main.
import 'package:equatable/equatable.dart';

/// Section du menu dans laquelle le plat est affiché.
enum MenuSection {
  /// Entrées, salades et petites faims.
  starters('Entrées'),

  /// Plats principaux (riz, tô, attiéké, pâtes...).
  mainDishes('Plats'),

  /// Viandes et poissons braisés ou grillés.
  grills('Grillades'),

  /// Accompagnements (alloco, haricots, frites...).
  sides('Accompagnements'),

  /// Desserts et fruits.
  desserts('Desserts'),

  /// Boissons locales et rafraîchissements.
  drinks('Boissons');

  /// Constructeur enrichi avec le libellé affiché.
  const MenuSection(this.label);

  /// Libellé français de la section.
  final String label;

  /// Convertit une valeur JSON en section connue, sinon renvoie `null`.
  static MenuSection? tryParse(String? raw) {
    // Normalisation commune (casse, espaces).
    final String value = (raw ?? '').trim().toLowerCase();
    for (final MenuSection section in MenuSection.values) {
      if (section.name.toLowerCase() == value ||
          section.label.toLowerCase() == value) {
        return section;
      }
    }
    return null;
  }
}

/// Allergène déclaré dans un plat, utile pour les convives sensibles.
enum Allergen {
  /// Arachide, très présente dans la cuisine locale (sauce arachide).
  peanuts('Arachide'),

  /// Gluten (pain, pâtes, semoule).
  gluten('Gluten'),

  /// Poisson et produits de la mer.
  fish('Poisson'),

  /// Crustacés et fruits de mer.
  shellfish('Crustacés'),

  /// Œufs.
  eggs('Œufs'),

  /// Lait et produits laitiers.
  milk('Lait'),

  /// Soja et dérivés.
  soy('Soja');

  /// Constructeur enrichi avec le libellé affiché.
  const Allergen(this.label);

  /// Libellé français de l'allergène.
  final String label;

  /// Convertit une valeur JSON en allergène connu, sinon renvoie `null`.
  static Allergen? tryParse(String? raw) {
    // Normalisation commune (casse, espaces).
    final String value = (raw ?? '').trim().toLowerCase();
    for (final Allergen allergen in Allergen.values) {
      if (allergen.name.toLowerCase() == value ||
          allergen.label.toLowerCase() == value) {
        return allergen;
      }
    }
    return null;
  }
}

/// Plat ou boisson proposé par un restaurant.
final class MenuItem extends Equatable {
  /// Construit un plat en garantissant l'immuabilité de la collection
  /// d'allergènes et la cohérence des valeurs numériques.
  MenuItem({
    required this.id,
    required this.name,
    required this.description,
    required this.section,
    required this.priceFcfa,
    required this.isAvailable,
    required this.isSignature,
    required this.portionLabel,
    required this.preparationMinutes,
    required this.photoAsset,
    required Set<Allergen> allergens,
  }) : assert(priceFcfa >= 0, 'Un prix ne peut pas être négatif.'),
       assert(preparationMinutes >= 0, 'Un délai ne peut pas être négatif.'),
       allergens = Set<Allergen>.unmodifiable(allergens);

  /// Identifiant stable du plat (utilisé par le panier et les favoris).
  final String id;

  /// Nom affiché (ex. « Poulet braisé »).
  final String name;

  /// Description commerciale courte.
  final String description;

  /// Section de rattachement dans le menu.
  final MenuSection section;

  /// Prix en FCFA, toujours entier (la devise n'a pas de sous-unité).
  final int priceFcfa;

  /// Indique si le plat peut être commandé maintenant.
  final bool isAvailable;

  /// Met en avant une spécialité de la maison.
  final bool isSignature;

  /// Libellé de portion (ex. « 1 personne », « à partager »).
  final String portionLabel;

  /// Temps de préparation annoncé, en minutes (0 = inconnu).
  final int preparationMinutes;

  /// Chemin d'asset local de la photo, ou `null` si aucune photo.
  final String? photoAsset;

  /// Allergènes déclarés, dans une collection non modifiable.
  final Set<Allergen> allergens;

  /// Un plat commandable doit être disponible et avoir un prix strictement
  /// positif : un plat gratuit n'a pas de sens dans un menu de restaurant.
  bool get isOrderable => isAvailable && priceFcfa > 0;

  /// Propriétés comparées par Equatable (les collections sont comparées en
  /// profondeur par Equatable).
  @override
  List<Object?> get props => <Object?>[
    id,
    name,
    description,
    section,
    priceFcfa,
    isAvailable,
    isSignature,
    portionLabel,
    preparationMinutes,
    photoAsset,
    allergens,
  ];
}
