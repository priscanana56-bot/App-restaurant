// =============================================================================
// Modèle JSON complet d'un restaurant.
// -----------------------------------------------------------------------------
// Frontière de confiance : ce fichier transforme des données non fiables
// (asset seed ou API) en valeurs typées, nettoyées et bornées. Il vérifie
// notamment que les coordonnées restent dans la zone de Koudougou et que les
// téléphones sont normalisés en E.164 avant de créer l'entité Domain.
// =============================================================================

// Décodage JSON (une seule conversion dynamique, immédiatement typée).
import 'dart:convert';

// Bornes métier.
import '../../../../core/constants/app_constants.dart';

// Référentiel des secteurs de Koudougou.
import '../../../../core/constants/koudougou_reference.dart';

// Nettoyage des textes, téléphones et coordonnées.
import '../../../../core/security/input_sanitizer.dart';

// Entités Domain produites.
import '../../domain/entities/restaurant.dart';
import '../../domain/entities/restaurant_category.dart';

// Modèles imbriqués.
import 'asset_path_validator.dart';
import 'json_reader.dart';
import 'live_braise_model.dart';
import 'menu_item_model.dart';
import 'opening_hours_model.dart';

/// Représentation de transport d'un restaurant.
final class RestaurantModel {
  // Constructeur privé : seuls `fromJson` et le catalogue créent des modèles.
  const RestaurantModel({
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
    required this.ambianceScore,
    required this.musicGenre,
    required this.ambianceNote,
    required this.openingHours,
    required this.menu,
    required this.isVerified,
    required this.verifiedAt,
    required this.updatedAt,
    required this.paymentMethods,
    required this.amenities,
    required this.photoAsset,
    required this.liveBraise,
    this.deliveryAvailable = false,
  });

  /// Identifiant stable.
  final String id;

  /// Nom commercial.
  final String name;

  /// Accroche courte.
  final String tagline;

  /// Description longue.
  final String description;

  /// Catégorie d'établissement.
  final RestaurantCategory category;

  /// Secteur de Koudougou.
  final String sector;

  /// Repère de proximité.
  final String landmark;

  /// Adresse descriptive.
  final String address;

  /// Latitude GPS.
  final double latitude;

  /// Longitude GPS.
  final double longitude;

  /// Téléphone E.164.
  final String phone;

  /// WhatsApp E.164.
  final String whatsappPhone;

  /// Note moyenne (0-5).
  final double rating;

  /// Nombre d'avis.
  final int reviewCount;

  /// Tranche de prix.
  final PriceRange priceRange;

  /// Prix moyen d'un repas.
  final int averagePriceFcfa;

  /// Score d'ambiance (0-100).
  final int ambianceScore;

  /// Style musical.
  final String musicGenre;

  /// Note d'ambiance.
  final String ambianceNote;

  /// Horaires d'ouverture.
  final OpeningHoursModel openingHours;

  /// Carte du restaurant.
  final List<MenuItemModel> menu;

  /// Fiche vérifiée sur place.
  final bool isVerified;

  /// Date de vérification.
  final DateTime? verifiedAt;

  /// Dernière mise à jour.
  final DateTime updatedAt;

  /// Moyens de paiement.
  final Set<PaymentMethod> paymentMethods;

  /// Équipements.
  final Set<RestaurantAmenity> amenities;

  /// Photo locale éventuelle.
  final String? photoAsset;

  /// Braise éventuelle.
  final LiveBraiseModel? liveBraise;

  /// Livraison proposée par cet établissement (champ pilote de l'indicateur).
  final bool deliveryAvailable;

  /// Construit le modèle depuis un objet JSON.
  factory RestaurantModel.fromJson(Map<String, Object?> json) {
    final JsonReader reader = JsonReader(json);

    // -------------------------------------------------------------------------
    // Identité et textes
    // -------------------------------------------------------------------------
    final String id = InputSanitizer.sanitizeIdentifier(
      reader.requireString('id', maxLength: 64),
    );
    if (id.isEmpty) {
      throw const FormatException('Identifiant de restaurant invalide.');
    }

    final String name = InputSanitizer.sanitizeShortLabel(
      reader.requireString('name', maxLength: AppConstants.shortTextMaxLength),
      maxLength: AppConstants.shortTextMaxLength,
    );
    if (name.isEmpty) {
      throw const FormatException('Nom de restaurant invalide.');
    }

    final String tagline = InputSanitizer.sanitizeShortLabel(
      reader.optionalString('tagline', maxLength: 120),
      maxLength: 120,
    );
    final String description = InputSanitizer.sanitizePlainText(
      reader.optionalString('description', maxLength: 1200),
      maxLength: 1200,
    );

    // Catégorie inconnue : repli explicite, jamais de crash.
    final RestaurantCategory category =
        RestaurantCategory.tryParse(
          reader.requireString('category', maxLength: 40),
        ) ??
        RestaurantCategory.other;

    // -------------------------------------------------------------------------
    // Localisation
    // -------------------------------------------------------------------------
    final String sector = InputSanitizer.sanitizeShortLabel(
      reader.requireString('sector', maxLength: 40),
      maxLength: 40,
    );
    if (!KoudougouReference.sectors.contains(sector)) {
      throw const FormatException('Secteur inconnu pour Koudougou.');
    }

    final String landmark = InputSanitizer.sanitizeShortLabel(
      reader.requireString('landmark', maxLength: 80),
      maxLength: 80,
    );
    final String address = InputSanitizer.sanitizeShortLabel(
      reader.optionalString('address', maxLength: 200),
      maxLength: 200,
    );

    final double latitude = reader.requireDouble('latitude', min: -90, max: 90);
    final double longitude = reader.requireDouble(
      'longitude',
      min: -180,
      max: 180,
    );
    _validateKoudougouCoordinates(latitude, longitude);

    // -------------------------------------------------------------------------
    // Contacts
    // -------------------------------------------------------------------------
    final String phone = _requirePhone(reader.requireString('phone'));
    final String rawWhatsApp = reader.optionalString('whatsappPhone');
    final String whatsappPhone = rawWhatsApp.isEmpty
        ? phone
        : _requirePhone(rawWhatsApp);

    // -------------------------------------------------------------------------
    // Notation et prix
    // -------------------------------------------------------------------------
    final double rating = reader.requireDouble('rating', min: 0, max: 5);
    final int reviewCount =
        reader.optionalInt('reviewCount', min: 0, max: 10000000) ?? 0;

    // Le menu est lu avant le prix moyen : il peut servir de repli.
    final List<MenuItemModel> menu = <MenuItemModel>[];
    for (final Object? item in reader.optionalList('menu', maxLength: 200)) {
      menu.add(
        MenuItemModel.fromJson(
          JsonReader.mapFrom(item, context: 'menu du restaurant « $id »'),
        ),
      );
    }

    // Identifiants de plats uniques : une clé de panier ne peut pas être double.
    final Set<String> menuIds = <String>{};
    for (final MenuItemModel item in menu) {
      if (!menuIds.add(item.id)) {
        throw FormatException('Plat en double dans le restaurant « $id ».');
      }
    }

    final int averagePriceFcfa =
        reader.optionalInt(
          'averagePriceFcfa',
          min: 0,
          max: AppConstants.maxPriceFcfa,
        ) ??
        _averageMenuPrice(menu);

    final PriceRange priceRange =
        PriceRange.tryParse(
          reader.optionalString('priceRange', maxLength: 20),
        ) ??
        PriceRange.fromAveragePrice(averagePriceFcfa);

    // -------------------------------------------------------------------------
    // Ambiance, équipements et paiement
    // -------------------------------------------------------------------------
    final int ambianceScore =
        reader.optionalInt('ambianceScore', min: 0, max: 100) ?? 0;
    final String musicGenre = InputSanitizer.sanitizeShortLabel(
      reader.optionalString('musicGenre', maxLength: 60),
      maxLength: 60,
    );
    final String ambianceNote = InputSanitizer.sanitizeShortLabel(
      reader.optionalString('ambianceNote', maxLength: 120),
      maxLength: 120,
    );

    // Valeurs inconnues ignorées : compatibilité ascendante avec l'API.
    final Set<RestaurantAmenity> amenities = <RestaurantAmenity>{};
    for (final String raw in reader.stringList('amenities', maxItems: 30)) {
      final RestaurantAmenity? amenity = RestaurantAmenity.tryParse(raw);
      if (amenity != null) {
        amenities.add(amenity);
      }
    }

    final Set<PaymentMethod> paymentMethods = <PaymentMethod>{};
    for (final String raw in reader.stringList(
      'paymentMethods',
      maxItems: 10,
    )) {
      final PaymentMethod? method = PaymentMethod.tryParse(raw);
      if (method != null) {
        paymentMethods.add(method);
      }
    }

    // Le champ explicite pilote l'indicateur. Pour les anciennes fiches qui ne
    // le déclarent pas encore, on conserve le repli sur l'équipement « livraison ».
    final bool deliveryAvailable = reader.has('deliveryAvailable')
        ? reader.optionalBool('deliveryAvailable')
        : amenities.contains(RestaurantAmenity.delivery);

    // -------------------------------------------------------------------------
    // Horaires, vérification et braise
    // -------------------------------------------------------------------------
    final OpeningHoursModel openingHours = OpeningHoursModel.fromJson(
      reader.requireObject('openingHours'),
    );

    final bool isVerified = reader.optionalBool('isVerified');
    final DateTime? verifiedAt = reader.optionalDateTime('verifiedAt');
    if (isVerified && verifiedAt == null) {
      throw const FormatException(
        'Un restaurant vérifié doit avoir une date de vérification.',
      );
    }

    final DateTime updatedAt = reader.requireDateTime('updatedAt');

    final Map<String, Object?>? rawLiveBraise = reader.optionalObject(
      'liveBraise',
    );
    final LiveBraiseModel? liveBraise = rawLiveBraise == null
        ? null
        : LiveBraiseModel.fromJson(rawLiveBraise);

    return RestaurantModel(
      id: id,
      name: name,
      tagline: tagline,
      description: description,
      category: category,
      sector: sector,
      landmark: landmark,
      address: address,
      latitude: latitude,
      longitude: longitude,
      phone: phone,
      whatsappPhone: whatsappPhone,
      rating: rating,
      reviewCount: reviewCount,
      priceRange: priceRange,
      averagePriceFcfa: averagePriceFcfa,
      ambianceScore: ambianceScore,
      musicGenre: musicGenre,
      ambianceNote: ambianceNote,
      openingHours: openingHours,
      menu: List<MenuItemModel>.unmodifiable(menu),
      isVerified: isVerified,
      verifiedAt: verifiedAt,
      updatedAt: updatedAt,
      paymentMethods: Set<PaymentMethod>.unmodifiable(
        paymentMethods.isEmpty
            ? <PaymentMethod>{PaymentMethod.cash}
            : paymentMethods,
      ),
      amenities: Set<RestaurantAmenity>.unmodifiable(amenities),
      photoAsset: AssetPathValidator.sanitize(
        reader.nullableString('photoAsset', maxLength: 200),
      ),
      liveBraise: liveBraise,
      deliveryAvailable: deliveryAvailable,
    );
  }

  /// Construit le modèle depuis une entité Domain (écritures locales).
  /// Les portails créent des fiches ou modifient un menu : ils repassent par
  /// ce factory avant d'écrire le cache Hive, afin de conserver un format
  /// strictement identique à celui du seed et de l'API.
  factory RestaurantModel.fromEntity(Restaurant entity) => RestaurantModel(
    id: entity.id,
    name: entity.name,
    tagline: entity.tagline,
    description: entity.description,
    category: entity.category,
    sector: entity.sector,
    landmark: entity.landmark,
    address: entity.address,
    latitude: entity.latitude,
    longitude: entity.longitude,
    phone: entity.phone,
    whatsappPhone: entity.whatsappPhone,
    rating: entity.rating,
    reviewCount: entity.reviewCount,
    priceRange: entity.priceRange,
    averagePriceFcfa: entity.averagePriceFcfa,
    ambianceScore: entity.ambiance.score,
    musicGenre: entity.ambiance.musicGenre,
    ambianceNote: entity.ambiance.note,
    openingHours: OpeningHoursModel.fromEntity(entity.openingHours),
    menu: entity.menu.map(MenuItemModel.fromEntity).toList(growable: false),
    isVerified: entity.isVerified,
    verifiedAt: entity.verifiedAt,
    updatedAt: entity.updatedAt,
    paymentMethods: entity.paymentMethods,
    amenities: entity.amenities,
    photoAsset: entity.photoAsset,
    liveBraise: entity.liveBraise == null
        ? null
        : LiveBraiseModel.fromEntity(entity.liveBraise!),
    deliveryAvailable: entity.deliveryAvailable,
  );

  /// Construit le modèle depuis une chaîne JSON mise en cache.
  factory RestaurantModel.fromJsonString(String raw) {
    // `jsonDecode` est dynamique : conversion explicite et unique.
    final Object? decoded = jsonDecode(raw) as Object?;
    return RestaurantModel.fromJson(
      JsonReader.mapFrom(decoded, context: 'restaurant'),
    );
  }

  /// Convertit le modèle en entité Domain pour l'instant [now].
  Restaurant toEntity(DateTime now) => Restaurant(
    id: id,
    name: name,
    tagline: tagline,
    description: description,
    category: category,
    sector: sector,
    landmark: landmark,
    address: address,
    latitude: latitude,
    longitude: longitude,
    phone: phone,
    whatsappPhone: whatsappPhone,
    rating: rating,
    reviewCount: reviewCount,
    priceRange: priceRange,
    averagePriceFcfa: averagePriceFcfa,
    ambiance: AmbianceInfo(
      score: ambianceScore,
      musicGenre: musicGenre,
      note: ambianceNote,
    ),
    openingHours: openingHours.toEntity(),
    menu: menu
        .map((MenuItemModel item) => item.toEntity())
        .toList(growable: false),
    isVerified: isVerified,
    verifiedAt: verifiedAt,
    updatedAt: updatedAt,
    paymentMethods: paymentMethods,
    amenities: amenities,
    photoAsset: photoAsset,
    liveBraise: liveBraise?.toEntity(
      restaurantId: id,
      restaurantName: name,
      now: now,
    ),
    deliveryAvailable: deliveryAvailable,
  );

  /// Sérialise le modèle pour le cache Hive.
  Map<String, Object?> toJson() => <String, Object?>{
    'id': id,
    'name': name,
    'tagline': tagline,
    'description': description,
    'category': category.wireValue,
    'sector': sector,
    'landmark': landmark,
    'address': address,
    'latitude': latitude,
    'longitude': longitude,
    'phone': phone,
    'whatsappPhone': whatsappPhone,
    'rating': rating,
    'reviewCount': reviewCount,
    'priceRange': priceRange.wireValue,
    'averagePriceFcfa': averagePriceFcfa,
    'ambianceScore': ambianceScore,
    'musicGenre': musicGenre,
    'ambianceNote': ambianceNote,
    'openingHours': openingHours.toJson(),
    'menu': menu
        .map((MenuItemModel item) => item.toJson())
        .toList(growable: false),
    'isVerified': isVerified,
    'verifiedAt': verifiedAt?.toIso8601String(),
    'updatedAt': updatedAt.toIso8601String(),
    'paymentMethods': paymentMethods
        .map((PaymentMethod method) => method.name)
        .toList(growable: false),
    'amenities': amenities
        .map((RestaurantAmenity amenity) => amenity.name)
        .toList(growable: false),
    'photoAsset': photoAsset,
    'liveBraise': liveBraise?.toJson(),
    'deliveryAvailable': deliveryAvailable,
  };

  /// Valide un numéro de téléphone et le normalise en E.164.
  static String _requirePhone(String raw) {
    final String? phone = InputSanitizer.sanitizePhoneNumber(raw);
    if (phone == null) {
      throw const FormatException('Numéro de téléphone invalide.');
    }
    return phone;
  }

  /// Vérifie que le point est réellement dans la zone couverte.
  static void _validateKoudougouCoordinates(double latitude, double longitude) {
    // Bornes géographiques standard d'abord.
    if (!InputSanitizer.isValidCoordinate(latitude, longitude)) {
      throw const FormatException('Coordonnées GPS invalides.');
    }

    // Puis cadre local : évite un lien GPS vers un autre pays.
    final double latitudeDelta = (latitude - AppConstants.cityLatitude).abs();
    final double longitudeDelta = (longitude - AppConstants.cityLongitude)
        .abs();
    if (latitudeDelta > AppConstants.koudougouCoordinateTolerance ||
        longitudeDelta > AppConstants.koudougouCoordinateTolerance) {
      throw const FormatException('Coordonnées hors de la zone de Koudougou.');
    }
  }

  /// Calcule un prix moyen de repli à partir des plats.
  static int _averageMenuPrice(List<MenuItemModel> menu) {
    // Seuls les plats avec un prix positif entrent dans la moyenne.
    final List<int> prices = menu
        .map((MenuItemModel item) => item.priceFcfa)
        .where((int price) => price > 0)
        .toList(growable: false);
    if (prices.isEmpty) {
      return 0;
    }

    // Moyenne entière (la devise n'a pas de sous-unité).
    final int sum = prices.fold<int>(
      0,
      (int total, int price) => total + price,
    );
    return sum ~/ prices.length;
  }
}
