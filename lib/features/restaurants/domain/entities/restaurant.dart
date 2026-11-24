// =============================================================================
// Entité racine du catalogue : un restaurant ou maquis de Koudougou.
// -----------------------------------------------------------------------------
// Cette classe est le contrat central du Domain. Elle est immuable, comparable
// et totalement indépendante de Flutter, de HTTP et de Hive. La couche Data
// construit ces objets uniquement après nettoyage et validation des données.
// =============================================================================

// Equatable pour l'égalité de valeur.
import 'package:equatable/equatable.dart';

// Objets-valeurs de classement (catégorie, prix, équipements, ambiance).
import 'restaurant_category.dart';

// Entité du menu.
import 'menu_item.dart';

// Horaires d'ouverture.
import 'opening_hours.dart';

// Statut Live Braise éventuel.
import 'live_braise_status.dart';

/// Fiche complète d'un établissement.
final class Restaurant extends Equatable {
  /// Construit une fiche en garantissant l'immuabilité des collections et la
  /// cohérence des bornes (note, coordonnées, vérification).
  Restaurant({
    required this.id,
    required this.name,
    required this.tagline,
    required this.description,
    required this.category,
    required this.sector,
    required this.landmark,
    required this.address,
    required this.latitude,
    required this.longitude,
    required this.phone,
    required this.whatsappPhone,
    required this.rating,
    required this.reviewCount,
    required this.priceRange,
    required this.averagePriceFcfa,
    required this.ambiance,
    required this.openingHours,
    required List<MenuItem> menu,
    required this.isVerified,
    required this.verifiedAt,
    required this.updatedAt,
    required Set<PaymentMethod> paymentMethods,
    required Set<RestaurantAmenity> amenities,
    required this.photoAsset,
    required this.liveBraise,
    this.deliveryAvailable = false,
  }) : assert(rating >= 0 && rating <= 5, 'La note doit être entre 0 et 5.'),
       assert(reviewCount >= 0, 'Le nombre d’avis ne peut pas être négatif.'),
       assert(averagePriceFcfa >= 0, 'Le prix moyen ne peut pas être négatif.'),
       assert(
         latitude >= -90 && latitude <= 90,
         'La latitude doit être entre -90 et 90.',
       ),
       assert(
         longitude >= -180 && longitude <= 180,
         'La longitude doit être entre -180 et 180.',
       ),
       assert(
         !isVerified || verifiedAt != null,
         'Un établissement vérifié doit avoir une date de vérification.',
       ),
       menu = List<MenuItem>.unmodifiable(menu),
       paymentMethods = Set<PaymentMethod>.unmodifiable(paymentMethods),
       amenities = Set<RestaurantAmenity>.unmodifiable(amenities);

  /// Identifiant stable, utilisé dans les routes et les favoris.
  final String id;

  /// Nom commercial affiché (ex. « Chez Tantie Awa »).
  final String name;

  /// Accroche courte affichée sous le nom (une ligne maximum).
  final String tagline;

  /// Description longue de l'ambiance et de la cuisine.
  final String description;

  /// Grande famille d'établissement.
  final RestaurantCategory category;

  /// Secteur administratif de Koudougou (ex. « Secteur 4 »).
  final String sector;

  /// Repère de proximité utilisé quand le GPS est imprécis.
  final String landmark;

  /// Adresse postale ou descriptive.
  final String address;

  /// Latitude GPS du restaurant.
  final double latitude;

  /// Longitude GPS du restaurant.
  final double longitude;

  /// Téléphone principal au format E.164 (`+226XXXXXXXX`).
  final String phone;

  /// Numéro WhatsApp au format E.164 (`+226XXXXXXXX`).
  final String whatsappPhone;

  /// Note moyenne de 0 à 5.
  final double rating;

  /// Nombre d'avis ayant servi à calculer la note.
  final int reviewCount;

  /// Tranche de prix déduite du prix moyen.
  final PriceRange priceRange;

  /// Prix moyen d'un repas complet, en FCFA.
  final int averagePriceFcfa;

  /// Indicateurs d'affluence et de musique.
  final AmbianceInfo ambiance;

  /// Horaires d'ouverture hebdomadaires.
  final OpeningHours openingHours;

  /// Carte du restaurant, non modifiable.
  final List<MenuItem> menu;

  /// Indique si la fiche a été contrôlée sur place par l'équipe.
  final bool isVerified;

  /// Date du dernier contrôle sur place (obligatoire si [isVerified] est vrai).
  final DateTime? verifiedAt;

  /// Date de dernière mise à jour de la fiche.
  final DateTime updatedAt;

  /// Moyens de paiement acceptés.
  final Set<PaymentMethod> paymentMethods;

  /// Équipements et services disponibles.
  final Set<RestaurantAmenity> amenities;

  /// Photo locale éventuelle (chemin d'asset), sinon `null`.
  final String? photoAsset;

  /// Braise du jour, si l'établissement en propose une.
  final LiveBraiseStatus? liveBraise;

  /// Indique si l'établissement propose réellement la livraison.
  ///
  /// Ce booléen pilote l'indicateur affiché sur les fiches. Il est distinct de
  /// l'équipement `RestaurantAmenity.delivery` : une fiche peut déclarer le
  /// service dans ses amenities sans que le tarif local soit appliqué.
  final bool deliveryAvailable;

  /// Indique si le restaurant est ouvert à l'instant [now].
  bool isOpenAt(DateTime now) => openingHours.isOpenAt(now);

  /// Braise active à l'instant [now], ou `null` si aucune braise n'est en cours.
  LiveBraiseStatus? activeLiveBraiseAt(DateTime now) {
    // Une braise peut exister mais être terminée ou épuisée.
    final LiveBraiseStatus? braise = liveBraise;
    if (braise != null && braise.isActiveAt(now)) {
      return braise;
    }
    return null;
  }

  /// Indique si une braise est active à l'instant [now].
  bool hasLiveBraiseAt(DateTime now) => activeLiveBraiseAt(now) != null;

  /// Plats réellement commandables, triés par section puis par nom.
  List<MenuItem> get orderableMenu {
    // Copie triée pour ne jamais modifier la liste d'origine.
    final List<MenuItem> items = menu
        .where((MenuItem item) => item.isOrderable)
        .toList(growable: true);
    items.sort((MenuItem left, MenuItem right) {
      // Tri principal par ordre de section dans le menu.
      final int bySection = left.section.index.compareTo(right.section.index);
      if (bySection != 0) {
        return bySection;
      }
      // Tri secondaire alphabétique, insensible à la casse.
      return left.name.toLowerCase().compareTo(right.name.toLowerCase());
    });
    return List<MenuItem>.unmodifiable(items);
  }

  /// Plats signatures disponibles.
  List<MenuItem> get signatureDishes => List<MenuItem>.unmodifiable(
    menu.where((MenuItem item) => item.isSignature && item.isOrderable),
  );

  /// Regroupe les plats par section, dans l'ordre du menu.
  Map<MenuSection, List<MenuItem>> get menuBySection {
    // Map ordonnée pour conserver l'ordre de déclaration des sections.
    final Map<MenuSection, List<MenuItem>> grouped =
        <MenuSection, List<MenuItem>>{};
    for (final MenuSection section in MenuSection.values) {
      final List<MenuItem> items = orderableMenu
          .where((MenuItem item) => item.section == section)
          .toList(growable: false);
      if (items.isNotEmpty) {
        grouped[section] = items;
      }
    }
    return Map<MenuSection, List<MenuItem>>.unmodifiable(grouped);
  }

  /// Libellé de localisation compact : `Secteur 4 · Grand marché`.
  String get locationLabel => '$sector · $landmark';

  /// Sentinelle interne pour distinguer « ne pas modifier » de « mettre à null ».
  /// Les champs nullable (photo, vérification, braise) ont besoin de cette
  /// distinction : `null` est une valeur légitime, pas l'absence de directive.
  static const Object _copyUnset = Object();

  /// Copie immuable de la fiche, utilisée par les portails quand le menu change.
  /// Aucun appelant ne peut muter l'instance d'origine : les collections sont
  /// recopiées puis à nouveau rendues non modifiables par le constructeur.
  Restaurant copyWith({
    String? id,
    String? name,
    String? tagline,
    String? description,
    RestaurantCategory? category,
    String? sector,
    String? landmark,
    String? address,
    double? latitude,
    double? longitude,
    String? phone,
    String? whatsappPhone,
    double? rating,
    int? reviewCount,
    PriceRange? priceRange,
    int? averagePriceFcfa,
    AmbianceInfo? ambiance,
    OpeningHours? openingHours,
    List<MenuItem>? menu,
    bool? isVerified,
    Object? verifiedAt = _copyUnset,
    DateTime? updatedAt,
    Set<PaymentMethod>? paymentMethods,
    Set<RestaurantAmenity>? amenities,
    Object? photoAsset = _copyUnset,
    Object? liveBraise = _copyUnset,
    bool? deliveryAvailable,
  }) {
    return Restaurant(
      id: id ?? this.id,
      name: name ?? this.name,
      tagline: tagline ?? this.tagline,
      description: description ?? this.description,
      category: category ?? this.category,
      sector: sector ?? this.sector,
      landmark: landmark ?? this.landmark,
      address: address ?? this.address,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      phone: phone ?? this.phone,
      whatsappPhone: whatsappPhone ?? this.whatsappPhone,
      rating: rating ?? this.rating,
      reviewCount: reviewCount ?? this.reviewCount,
      priceRange: priceRange ?? this.priceRange,
      averagePriceFcfa: averagePriceFcfa ?? this.averagePriceFcfa,
      ambiance: ambiance ?? this.ambiance,
      openingHours: openingHours ?? this.openingHours,
      menu: menu ?? this.menu,
      isVerified: isVerified ?? this.isVerified,
      verifiedAt: identical(verifiedAt, _copyUnset)
          ? this.verifiedAt
          : verifiedAt as DateTime?,
      updatedAt: updatedAt ?? this.updatedAt,
      paymentMethods: paymentMethods ?? this.paymentMethods,
      amenities: amenities ?? this.amenities,
      photoAsset: identical(photoAsset, _copyUnset)
          ? this.photoAsset
          : photoAsset as String?,
      liveBraise: identical(liveBraise, _copyUnset)
          ? this.liveBraise
          : liveBraise as LiveBraiseStatus?,
      deliveryAvailable: deliveryAvailable ?? this.deliveryAvailable,
    );
  }

  /// Propriétés comparées par Equatable (collections comparées en profondeur).
  @override
  List<Object?> get props => <Object?>[
    id,
    name,
    tagline,
    description,
    category,
    sector,
    landmark,
    address,
    latitude,
    longitude,
    phone,
    whatsappPhone,
    rating,
    reviewCount,
    priceRange,
    averagePriceFcfa,
    ambiance,
    openingHours,
    menu,
    isVerified,
    verifiedAt,
    updatedAt,
    paymentMethods,
    amenities,
    photoAsset,
    liveBraise,
    deliveryAvailable,
  ];
}
