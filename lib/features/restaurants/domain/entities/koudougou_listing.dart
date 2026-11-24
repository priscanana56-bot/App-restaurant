// =============================================================================
// Établissement de l'annuaire réel de Koudougou.
// -----------------------------------------------------------------------------
// Contrairement aux fiches « menu » (démonstration), chaque entrée de cet
// annuaire provient d'une source publique datée et est accompagnée de son
// niveau de vérification. Aucune information n'est présentée comme certifiée :
// une recherche en ligne ne prouve jamais qu'un lieu est encore ouvert.
// =============================================================================

// Égalité de valeur.
import 'package:equatable/equatable.dart';

// Point GPS optionnel (uniquement quand la source publie des coordonnées).
import '../../../../core/location/geo_point.dart';

/// Degré de fiabilité d'une fiche d'annuaire.
enum DirectoryVerification {
  /// Fiche détaillée récente (2026) avec un avis client récent : indice fort.
  recentOnlineSignal('Indice récent'),

  /// Fiche d'annuaire active mais derniers avis anciens.
  onlineListing('Fiche en ligne'),

  /// Presse locale uniquement : présence attestée à une date donnée.
  pressReport('Presse locale'),

  /// Informations partielles ou divergentes à confirmer sur place.
  toConfirm('À confirmer');

  /// Libellé français affiché dans l'interface.
  final String label;

  /// Constructeur constant.
  const DirectoryVerification(this.label);
}

/// Établissement réel recensé à Koudougou.
final class KoudougouListing extends Equatable {
  /// Construit une fiche d'annuaire immuable.
  const KoudougouListing({
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

  /// Identifiant stable dérivé du nom.
  final String id;

  /// Nom exact tel que publié par la source.
  final String name;

  /// Catégorie lisible (maquis, restaurant, café, bar...).
  final String category;

  /// Quartier ou repère géographique.
  final String area;

  /// Téléphone public (chaîne vide si non renseigné).
  final String phone;

  /// Horaires publics (chaîne vide si non renseignés).
  final String hours;

  /// Prix publiés (chaîne vide si non renseignés).
  final String priceInfo;

  /// Plats ou services cités par les sources.
  final String specialties;

  /// Nom de la source (Google Maps, Petit Futé...).
  final String sourceName;

  /// URL de la source, validée HTTPS.
  final String sourceUrl;

  /// Niveau de vérification, jamais masqué à l'utilisateur.
  final DirectoryVerification verification;

  /// Réserve ou avertissement affiché sous la fiche.
  final String note;

  /// Coordonnées publiées par la source, ou `null` si elle n'en donne pas.
  /// Elles permettent d'afficher un devis de livraison sans inventer d'adresse.
  final GeoPoint? position;

  /// Indique si un devis de livraison peut être simulé autour de ce point.
  /// Valeur par défaut `false` : aucune fiche sourcée ne certifie un service.
  final bool deliveryAvailable;

  /// Indique si des coordonnées exploitables ont été publiées.
  bool get hasPosition => position != null;

  /// Indique si un numéro téléphonique exploitable est publié.
  bool get hasPhone => phone.isNotEmpty;

  /// Indique si un lien source exploitable existe.
  bool get hasSource => sourceUrl.isNotEmpty;

  /// Sentinelle pour distinguer « ne pas modifier » de « mettre à null ».
  static const Object _copyUnset = Object();

  /// Copie immuable de la fiche, sans jamais muter l'instance d'origine.
  KoudougouListing copyWith({
    String? id,
    String? name,
    String? category,
    String? area,
    String? phone,
    String? hours,
    String? priceInfo,
    String? specialties,
    String? sourceName,
    String? sourceUrl,
    DirectoryVerification? verification,
    String? note,
    Object? position = _copyUnset,
    bool? deliveryAvailable,
  }) {
    return KoudougouListing(
      id: id ?? this.id,
      name: name ?? this.name,
      category: category ?? this.category,
      area: area ?? this.area,
      phone: phone ?? this.phone,
      hours: hours ?? this.hours,
      priceInfo: priceInfo ?? this.priceInfo,
      specialties: specialties ?? this.specialties,
      sourceName: sourceName ?? this.sourceName,
      sourceUrl: sourceUrl ?? this.sourceUrl,
      verification: verification ?? this.verification,
      note: note ?? this.note,
      position: identical(position, _copyUnset)
          ? this.position
          : position as GeoPoint?,
      deliveryAvailable: deliveryAvailable ?? this.deliveryAvailable,
    );
  }

  /// Propriétés comparées par Equatable.
  @override
  List<Object?> get props => <Object?>[
    id,
    name,
    category,
    area,
    phone,
    hours,
    priceInfo,
    specialties,
    sourceName,
    sourceUrl,
    verification,
    note,
    position,
    deliveryAvailable,
  ];
}
