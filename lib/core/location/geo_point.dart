// =============================================================================
// Point géographique et calcul de distance.
// -----------------------------------------------------------------------------
// Objet-valeur pur (aucune dépendance Flutter) utilisé par la Présentation pour
// trier les restaurants par proximité. La distance est calculée localement avec
// la formule de haversine : aucune API externe n'est appelée pour l'afficher.
// =============================================================================

// `dart:math` fournit sin, cos, atan2, sqrt et pi.
import 'dart:math' as math;

// Equatable pour comparer deux points sans écrire == / hashCode.
import 'package:equatable/equatable.dart';

/// Coordonnées GPS immuables.
final class GeoPoint extends Equatable {
  /// Construit un point. Les bornes sont garanties par l'appelant
  /// (`InputSanitizer.isValidCoordinate`) et par les assertions ci-dessous.
  const GeoPoint({required this.latitude, required this.longitude})
    : assert(
        latitude >= -90 && latitude <= 90,
        'La latitude doit être comprise entre -90 et 90.',
      ),
      assert(
        longitude >= -180 && longitude <= 180,
        'La longitude doit être comprise entre -180 et 180.',
      );

  /// Latitude en degrés décimaux.
  final double latitude;

  /// Longitude en degrés décimaux.
  final double longitude;

  /// Distance approximative jusqu'à [other], en kilomètres.
  /// Formule de haversine : précision amplement suffisante à l'échelle d'une ville.
  double distanceToKm(GeoPoint other) {
    // Rayon moyen de la Terre, en kilomètres.
    const double earthRadiusKm = 6371.0088;

    // Écarts angulaires convertis en radians.
    final double deltaLatitude = _toRadians(other.latitude - latitude);
    final double deltaLongitude = _toRadians(other.longitude - longitude);

    // Latitudes converties une seule fois.
    final double latitude1 = _toRadians(latitude);
    final double latitude2 = _toRadians(other.latitude);

    // Termes intermédiaires de la haversine (tous typés `double`).
    final double sinLatitude = math.sin(deltaLatitude / 2);
    final double sinLongitude = math.sin(deltaLongitude / 2);

    // Carré de la moitié de la corde.
    final double a =
        sinLatitude * sinLatitude +
        math.cos(latitude1) * math.cos(latitude2) * sinLongitude * sinLongitude;

    // Angle central, borné par la racine pour éviter toute erreur numérique.
    final double c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));

    // Distance finale.
    return earthRadiusKm * c;
  }

  /// Convertit des degrés en radians.
  static double _toRadians(double degrees) => degrees * math.pi / 180;

  /// Propriétés comparées par Equatable.
  @override
  List<Object?> get props => <Object?>[latitude, longitude];
}
