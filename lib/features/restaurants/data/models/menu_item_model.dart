// =============================================================================
// Modèle JSON d'un plat.
// -----------------------------------------------------------------------------
// Tous les textes sont nettoyés par `InputSanitizer` avant de rejoindre le
// Domain. Un identifiant, un prix ou une section invalide fait échouer le
// parsing : mieux vaut ignorer une fiche corrompue que d'afficher un plat
// à un prix faux.
// =============================================================================

// Bornes métier.
import '../../../../core/constants/app_constants.dart';

// Nettoyage des textes et des prix.
import '../../../../core/security/input_sanitizer.dart';

// Entité Domain produite.
import '../../domain/entities/menu_item.dart';

// Validation des chemins d'images.
import 'asset_path_validator.dart';

// Lecteur JSON strict.
import 'json_reader.dart';

/// Représentation de transport d'un plat.
final class MenuItemModel {
  // Constructeur privé : les valeurs ont déjà été validées.
  const MenuItemModel({
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
    required this.allergens,
  });

  /// Identifiant technique du plat.
  final String id;

  /// Nom affiché.
  final String name;

  /// Description courte.
  final String description;

  /// Section du menu.
  final MenuSection section;

  /// Prix en FCFA.
  final int priceFcfa;

  /// Disponibilité actuelle.
  final bool isAvailable;

  /// Plat signature de la maison.
  final bool isSignature;

  /// Libellé de portion.
  final String portionLabel;

  /// Temps de préparation en minutes.
  final int preparationMinutes;

  /// Chemin d'asset de la photo, ou `null`.
  final String? photoAsset;

  /// Allergènes déclarés.
  final Set<Allergen> allergens;

  /// Construit le modèle depuis un objet JSON.
  factory MenuItemModel.fromJson(Map<String, Object?> json) {
    final JsonReader reader = JsonReader(json);

    // Identifiant sûr, utilisable comme clé de panier.
    final String id = InputSanitizer.sanitizeIdentifier(
      reader.requireString('id', maxLength: 64),
    );
    if (id.isEmpty) {
      throw const FormatException('Identifiant de plat invalide.');
    }

    // Nom nettoyé et non vide.
    final String name = InputSanitizer.sanitizeShortLabel(
      reader.requireString('name', maxLength: AppConstants.shortTextMaxLength),
      maxLength: AppConstants.shortTextMaxLength,
    );
    if (name.isEmpty) {
      throw const FormatException('Nom de plat invalide.');
    }

    // Description facultative, sans balises ni caractères de contrôle.
    final String description = InputSanitizer.sanitizePlainText(
      reader.optionalString('description', maxLength: 400),
      maxLength: 400,
      allowNewlines: false,
    );

    // Section obligatoire et connue.
    final MenuSection? section = MenuSection.tryParse(
      reader.requireString('section', maxLength: 40),
    );
    if (section == null) {
      throw const FormatException('Section de menu inconnue.');
    }

    // Prix validé par le sanitizer (pas de décimale, pas de caractère parasite).
    final int? price = InputSanitizer.sanitizePriceFcfa(
      reader
          .requireInt('priceFcfa', min: 0, max: AppConstants.maxPriceFcfa)
          .toString(),
    );
    if (price == null) {
      throw const FormatException('Prix de plat invalide.');
    }

    // Libellé de portion facultatif.
    final String portionLabel = InputSanitizer.sanitizeShortLabel(
      reader.optionalString('portionLabel', maxLength: 40),
      maxLength: 40,
    );

    // Allergènes : les valeurs inconnues sont ignorées (compatibilité future).
    final Set<Allergen> allergens = <Allergen>{};
    for (final String raw in reader.stringList('allergens', maxItems: 20)) {
      final Allergen? allergen = Allergen.tryParse(raw);
      if (allergen != null) {
        allergens.add(allergen);
      }
    }

    return MenuItemModel(
      id: id,
      name: name,
      description: description,
      section: section,
      priceFcfa: price,
      isAvailable: reader.optionalBool('isAvailable', defaultValue: true),
      isSignature: reader.optionalBool('isSignature'),
      portionLabel: portionLabel.isEmpty ? '1 portion' : portionLabel,
      preparationMinutes:
          reader.optionalInt('preparationMinutes', min: 0, max: 240) ?? 0,
      photoAsset: AssetPathValidator.sanitize(
        reader.nullableString('photoAsset', maxLength: 200),
      ),
      allergens: Set<Allergen>.unmodifiable(allergens),
    );
  }

  /// Construit le modèle depuis une entité déjà validée par le Domain.
  /// Utilisé par les portails pour réécrire le cache local sans repasser par
  /// une source JSON externe (les valeurs de l'entité sont déjà nettoyées).
  factory MenuItemModel.fromEntity(MenuItem item) => MenuItemModel(
    id: item.id,
    name: item.name,
    description: item.description,
    section: item.section,
    priceFcfa: item.priceFcfa,
    isAvailable: item.isAvailable,
    isSignature: item.isSignature,
    portionLabel: item.portionLabel,
    preparationMinutes: item.preparationMinutes,
    photoAsset: item.photoAsset,
    allergens: item.allergens,
  );

  /// Convertit le modèle en entité Domain.
  MenuItem toEntity() => MenuItem(
    id: id,
    name: name,
    description: description,
    section: section,
    priceFcfa: priceFcfa,
    isAvailable: isAvailable,
    isSignature: isSignature,
    portionLabel: portionLabel,
    preparationMinutes: preparationMinutes,
    photoAsset: photoAsset,
    allergens: allergens,
  );

  /// Sérialise le modèle pour le cache Hive.
  Map<String, Object?> toJson() => <String, Object?>{
    'id': id,
    'name': name,
    'description': description,
    'section': section.name,
    'priceFcfa': priceFcfa,
    'isAvailable': isAvailable,
    'isSignature': isSignature,
    'portionLabel': portionLabel,
    'preparationMinutes': preparationMinutes,
    'photoAsset': photoAsset,
    'allergens': allergens
        .map((Allergen allergen) => allergen.name)
        .toList(growable: false),
  };
}
