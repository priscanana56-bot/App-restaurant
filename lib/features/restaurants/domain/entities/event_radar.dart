// =============================================================================
// Radar d'ambiance — événements ponctuels autour de Koudougou.
// -----------------------------------------------------------------------------
// Un événement est toujours rattaché à un restaurant vérifié du catalogue.
// Les dates sont exprimées en heure de Koudougou (UTC), comme les horaires.
// =============================================================================

// Equatable pour comparer deux événements.
import 'package:equatable/equatable.dart';

/// Type d'événement affiché dans le radar.
enum RadarEventType {
  /// Concert ou prestation d'artiste.
  concert('Concert'),

  /// Retransmission ou rencontre de football.
  football('Football'),

  /// Soirée DJ / coupé-décalé.
  djSet('Soirée DJ'),

  /// Animation culturelle, danse ou théâtre.
  cultural('Culture'),

  /// Marché nocturne ou foire gastronomique.
  market('Marché'),

  /// Menu spécial ou soirée dégustation.
  specialMenu('Menu spécial'),

  /// Type non encore connu de l'application (compatibilité ascendante).
  other('Autre');

  /// Constructeur enrichi avec le libellé affiché.
  const RadarEventType(this.label);

  /// Libellé français affiché dans les badges.
  final String label;

  /// Convertit une valeur JSON en type connu, sinon `null`.
  static RadarEventType? tryParse(String? raw) {
    // Normalisation commune (casse, espaces, tirets).
    final String value = (raw ?? '').trim().toLowerCase().replaceAll('-', '');
    for (final RadarEventType type in RadarEventType.values) {
      if (type.name.toLowerCase() == value ||
          type.label.toLowerCase() == value) {
        return type;
      }
    }
    return null;
  }
}

/// Événement du radar d'ambiance.
final class EventRadar extends Equatable {
  /// Construit un événement cohérent.
  const EventRadar({
    required this.id,
    required this.title,
    required this.type,
    required this.restaurantId,
    required this.restaurantName,
    required this.description,
    required this.startsAt,
    required this.endsAt,
    required this.entryPriceFcfa,
    required this.crowdLevel,
  }) : assert(entryPriceFcfa >= 0, 'Un tarif ne peut pas être négatif.'),
       assert(
         crowdLevel >= 0 && crowdLevel <= 100,
         'Le niveau d’affluence doit être entre 0 et 100.',
       );

  /// Identifiant stable de l'événement.
  final String id;

  /// Titre affiché (ex. « Soirée coupé-décalé »).
  final String title;

  /// Catégorie de l'événement.
  final RadarEventType type;

  /// Identifiant du restaurant organisateur.
  final String restaurantId;

  /// Nom du restaurant, dénormalisé pour l'affichage.
  final String restaurantName;

  /// Description courte de la soirée.
  final String description;

  /// Début de l'événement.
  final DateTime startsAt;

  /// Fin prévue de l'événement.
  final DateTime endsAt;

  /// Tarif d'entrée en FCFA (0 = entrée libre).
  final int entryPriceFcfa;

  /// Affluence attendue de 0 à 100.
  final int crowdLevel;

  /// Indique si l'événement est en cours à l'instant [now].
  bool isLiveAt(DateTime now) =>
      !now.isBefore(startsAt) && now.isBefore(endsAt);

  /// Indique si l'événement n'a pas encore commencé.
  bool isUpcomingAt(DateTime now) => now.isBefore(startsAt);

  /// Indique si l'événement est terminé.
  bool isFinishedAt(DateTime now) => !now.isBefore(endsAt);

  /// Indique si l'entrée est gratuite.
  bool get isFree => entryPriceFcfa == 0;

  /// Propriétés comparées par Equatable.
  @override
  List<Object?> get props => <Object?>[
    id,
    title,
    type,
    restaurantId,
    restaurantName,
    description,
    startsAt,
    endsAt,
    entryPriceFcfa,
    crowdLevel,
  ];
}
