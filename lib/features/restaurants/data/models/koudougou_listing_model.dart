// =============================================================================
// Modèle JSON d'une fiche de l'annuaire réel de Koudougou.
// -----------------------------------------------------------------------------
// Le JSON de l'annuaire est une source externe : chaque champ est nettoyé par
// `InputSanitizer`, l'URL est validée en HTTPS et le statut de vérification est
// interprété explicitement. Une fiche invalide est rejetée, jamais devinée.
// =============================================================================

// Bornes et nettoyage.
import '../../../../core/constants/app_constants.dart';
import '../../../../core/location/geo_point.dart';
import '../../../../core/security/input_sanitizer.dart';

// Entité produite.
import '../../domain/entities/koudougou_listing.dart';

// Lecteur typé.
import 'json_reader.dart';

/// Représentation de transport d'une fiche d'annuaire.
final class KoudougouListingModel {
  /// Construit un modèle déjà validé.
  const KoudougouListingModel({
    required this.id,
    required this.name,
    required this.category,
    required this.area,
    required this.phone,
    required this.hours,
    required this.priceInfo,
    required this.specialties,
    required this.sourceName,
    required this.sourceUrl,
    required this.verification,
    required this.note,
    this.position,
    this.deliveryAvailable = false,
  });

  /// Identifiant stable.
  final String id;

  /// Nom publié.
  final String name;

  /// Catégorie lisible.
  final String category;

  /// Quartier ou repère.
  final String area;

  /// Téléphone E.164 ou chaîne vide.
  final String phone;

  /// Horaires publiés.
  final String hours;

  /// Prix publiés.
  final String priceInfo;

  /// Spécialités citées.
  final String specialties;

  /// Source citée.
  final String sourceName;

  /// URL HTTPS de la source.
  final String sourceUrl;

  /// Niveau de vérification.
  final DirectoryVerification verification;

  /// Réserve affichée à l'utilisateur.
  final String note;

  /// Coordonnées publiées, ou `null` si la source n'en donne pas.
  final GeoPoint? position;

  /// Autorise la simulation du devis autour de ce point (jamais par défaut).
  final bool deliveryAvailable;

  /// Décode une fiche depuis un objet JSON typé.
  factory KoudougouListingModel.fromJson(Map<String, Object?> json) {
    final JsonReader reader = JsonReader(json);

    // Identifiant technique strict.
    final String id = InputSanitizer.sanitizeIdentifier(
      reader.requireString('id', maxLength: 64),
    );
    if (id.isEmpty) {
      throw const FormatException('Identifiant d’annuaire invalide.');
    }

    // Textes : la source est publique mais peut contenir du HTML ou des contrôles.
    final String name = InputSanitizer.sanitizeShortLabel(
      reader.requireString('name', maxLength: AppConstants.shortTextMaxLength),
      maxLength: AppConstants.shortTextMaxLength,
    );
    final String category = InputSanitizer.sanitizeShortLabel(
      reader.requireString('category', maxLength: 80),
      maxLength: 80,
    );
    final String area = InputSanitizer.sanitizeShortLabel(
      reader.requireString('area', maxLength: 160),
      maxLength: 160,
    );
    final String hours = InputSanitizer.sanitizeShortLabel(
      reader.optionalString('hours', maxLength: 200),
      maxLength: 200,
    );
    final String priceInfo = InputSanitizer.sanitizeShortLabel(
      reader.optionalString('priceInfo', maxLength: 200),
      maxLength: 200,
    );
    final String specialties = InputSanitizer.sanitizePlainText(
      reader.optionalString('specialties', maxLength: 400),
      maxLength: 400,
      allowNewlines: false,
    );
    final String sourceName = InputSanitizer.sanitizeShortLabel(
      reader.requireString('sourceName', maxLength: 160),
      maxLength: 160,
    );
    final String note = InputSanitizer.sanitizePlainText(
      reader.optionalString('note', maxLength: 300),
      maxLength: 300,
      allowNewlines: false,
    );

    // Téléphone : une valeur invalide est ignorée, pas transformée en faux numéro.
    final String? phone = InputSanitizer.sanitizePhoneNumber(
      reader.optionalString('phone', maxLength: 40),
    );

    // URL : uniquement HTTPS, sans identifiants ni port exotique.
    final Uri? uri = InputSanitizer.sanitizeUrl(
      reader.optionalString('sourceUrl', maxLength: AppConstants.urlMaxLength),
    );
    final String sourceUrl = uri?.toString() ?? '';

    // Statut : une valeur inconnue est ramenée à « à confirmer ».
    final DirectoryVerification verification = _parseVerification(
      reader.requireString('verification', maxLength: 40),
    );

    if (name.isEmpty || category.isEmpty || area.isEmpty) {
      throw const FormatException('Fiche d’annuaire incomplète.');
    }

    // Coordonnées optionnelles : une valeur invalide est IGNORÉE, jamais
    // remplacée par une position inventée au centre de la ville.
    final double? latitude = reader.optionalDouble(
      'latitude',
      min: -90,
      max: 90,
    );
    final double? longitude = reader.optionalDouble(
      'longitude',
      min: -180,
      max: 180,
    );
    GeoPoint? position;
    if (latitude != null &&
        longitude != null &&
        InputSanitizer.isValidCoordinate(latitude, longitude) &&
        (latitude - AppConstants.cityLatitude).abs() <=
            AppConstants.koudougouCoordinateTolerance &&
        (longitude - AppConstants.cityLongitude).abs() <=
            AppConstants.koudougouCoordinateTolerance) {
      position = GeoPoint(latitude: latitude, longitude: longitude);
    }

    return KoudougouListingModel(
      id: id,
      name: name,
      category: category,
      area: area,
      phone: phone ?? '',
      hours: hours,
      priceInfo: priceInfo,
      specialties: specialties,
      sourceName: sourceName,
      sourceUrl: sourceUrl,
      verification: verification,
      note: note,
      position: position,
      deliveryAvailable: reader.optionalBool('deliveryAvailable'),
    );
  }

  /// Convertit le modèle en entité Domain.
  KoudougouListing toEntity() => KoudougouListing(
    id: id,
    name: name,
    category: category,
    area: area,
    phone: phone,
    hours: hours,
    priceInfo: priceInfo,
    specialties: specialties,
    sourceName: sourceName,
    sourceUrl: sourceUrl,
    verification: verification,
    note: note,
    position: position,
    deliveryAvailable: deliveryAvailable,
  );

  /// Interprète le statut de vérification publié dans le JSON.
  static DirectoryVerification _parseVerification(String raw) {
    return switch (raw) {
      'recentOnlineSignal' => DirectoryVerification.recentOnlineSignal,
      'onlineListing' => DirectoryVerification.onlineListing,
      'pressReport' => DirectoryVerification.pressReport,
      'toConfirm' => DirectoryVerification.toConfirm,
      _ => DirectoryVerification.toConfirm,
    };
  }
}
