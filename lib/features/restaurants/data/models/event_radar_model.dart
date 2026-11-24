// =============================================================================
// Modèle JSON d'un événement du radar.
// -----------------------------------------------------------------------------
// Deux formats sont acceptés :
//   1. ABSOLU (API) : `startsAt` / `endsAt` en ISO-8601 ;
//   2. RELATIF (seed de démonstration) : `dayOffset`, `startTime`,
//      `durationHours`. Il est résolu au chargement pour que le radar reste
//      vivant lors des démonstrations.
// =============================================================================

// Décodage JSON pour la lecture du cache.
import 'dart:convert';

// Bornes métier.
import '../../../../core/constants/app_constants.dart';

// Nettoyage des textes et des prix.
import '../../../../core/security/input_sanitizer.dart';

// Horloge de Koudougou.
import '../../../../core/utils/app_clock.dart';

// Entité Domain produite.
import '../../domain/entities/event_radar.dart';

// Conversion des heures.
import 'clock_time.dart';

// Lecteur JSON strict.
import 'json_reader.dart';

/// Représentation de transport d'un événement.
final class EventRadarModel {
  // Constructeur privé : les invariants sont vérifiés par `fromJson`.
  const EventRadarModel._({
    required this.id,
    required this.title,
    required this.type,
    required this.restaurantId,
    required this.restaurantName,
    required this.description,
    required this.entryPriceFcfa,
    required this.crowdLevel,
    required this.startsAt,
    required this.endsAt,
    required this.dayOffset,
    required this.startMinute,
    required this.durationHours,
  });

  /// Identifiant stable de l'événement.
  final String id;

  /// Titre affiché.
  final String title;

  /// Type d'événement.
  final RadarEventType type;

  /// Restaurant organisateur.
  final String restaurantId;

  /// Nom du restaurant organisateur.
  final String restaurantName;

  /// Description courte.
  final String description;

  /// Tarif d'entrée en FCFA.
  final int entryPriceFcfa;

  /// Affluence attendue (0-100).
  final int crowdLevel;

  /// Début absolu (mode API), sinon `null`.
  final DateTime? startsAt;

  /// Fin absolue (mode API), sinon `null`.
  final DateTime? endsAt;

  /// Décalage en jours (mode seed), sinon `null`.
  final int? dayOffset;

  /// Minute de début (mode seed), sinon `null`.
  final int? startMinute;

  /// Durée en heures (mode seed), sinon `null`.
  final int? durationHours;

  /// Construit le modèle depuis un objet JSON.
  factory EventRadarModel.fromJson(Map<String, Object?> json) {
    final JsonReader reader = JsonReader(json);

    // Identifiant de l'événement.
    final String id = InputSanitizer.sanitizeIdentifier(
      reader.requireString('id', maxLength: 64),
    );
    if (id.isEmpty) {
      throw const FormatException('Identifiant d’événement invalide.');
    }

    // Identifiant du restaurant organisateur.
    final String restaurantId = InputSanitizer.sanitizeIdentifier(
      reader.requireString('restaurantId', maxLength: 64),
    );
    if (restaurantId.isEmpty) {
      throw const FormatException('Restaurant d’événement invalide.');
    }

    // Titre nettoyé.
    final String title = InputSanitizer.sanitizeShortLabel(
      reader.requireString('title', maxLength: 100),
      maxLength: 100,
    );
    if (title.isEmpty) {
      throw const FormatException('Titre d’événement invalide.');
    }

    // Nom du restaurant, nettoyé.
    final String restaurantName = InputSanitizer.sanitizeShortLabel(
      reader.requireString('restaurantName', maxLength: 80),
      maxLength: 80,
    );

    // Mode absolu.
    final DateTime? startsAt = reader.optionalDateTime('startsAt');
    final DateTime? endsAt = reader.optionalDateTime('endsAt');
    final bool hasAbsolute = startsAt != null && endsAt != null;

    // Mode relatif.
    final int? dayOffset = reader.optionalInt('dayOffset', min: 0, max: 30);
    final String startTime = reader.optionalString('startTime', maxLength: 5);
    final int? durationHours = reader.optionalInt(
      'durationHours',
      min: 1,
      max: 24,
    );
    final bool hasRelative =
        dayOffset != null && startTime.isNotEmpty && durationHours != null;

    // Les deux modes sont exclusifs et l'un des deux est obligatoire.
    if (hasAbsolute == hasRelative) {
      throw const FormatException(
        'Événement : fournir soit startsAt/endsAt, soit dayOffset/startTime/durationHours.',
      );
    }

    // Validation du mode absolu.
    if (hasAbsolute && !endsAt.isAfter(startsAt)) {
      throw const FormatException('Événement : fin antérieure au début.');
    }

    // Conversion du mode relatif.
    final int? startMinute = hasRelative
        ? ClockTime.parseMinutes(startTime)
        : null;

    // Tarif et affluence.
    final int price =
        reader.optionalInt(
          'entryPriceFcfa',
          min: 0,
          max: AppConstants.maxPriceFcfa,
        ) ??
        0;
    final int crowd = reader.optionalInt('crowdLevel', min: 0, max: 100) ?? 0;

    return EventRadarModel._(
      id: id,
      title: title,
      type:
          RadarEventType.tryParse(
            reader.optionalString('type', maxLength: 40),
          ) ??
          RadarEventType.other,
      restaurantId: restaurantId,
      restaurantName: restaurantName,
      description: InputSanitizer.sanitizePlainText(
        reader.optionalString('description', maxLength: 400),
        maxLength: 400,
        allowNewlines: false,
      ),
      entryPriceFcfa: price,
      crowdLevel: crowd,
      startsAt: startsAt,
      endsAt: endsAt,
      dayOffset: dayOffset,
      startMinute: startMinute,
      durationHours: durationHours,
    );
  }

  /// Construit le modèle depuis une chaîne JSON mise en cache.
  factory EventRadarModel.fromJsonString(String raw) {
    // `jsonDecode` est dynamique : conversion explicite et unique.
    final Object? decoded = jsonDecode(raw) as Object?;
    return EventRadarModel.fromJson(
      JsonReader.mapFrom(decoded, context: 'événement'),
    );
  }

  /// Matérialise l'événement à l'instant de référence [now].
  EventRadar toEntity(DateTime now) {
    // Mode absolu : les dates de l'API font foi.
    if (startsAt != null && endsAt != null) {
      return EventRadar(
        id: id,
        title: title,
        type: type,
        restaurantId: restaurantId,
        restaurantName: restaurantName,
        description: description,
        startsAt: startsAt!,
        endsAt: endsAt!,
        entryPriceFcfa: entryPriceFcfa,
        crowdLevel: crowdLevel,
      );
    }

    // Mode relatif : la date est calculée à partir du jour courant.
    final DateTime start = KoudougouTime.atTime(
      now.add(Duration(days: dayOffset ?? 0)),
      (startMinute ?? 0) ~/ 60,
      (startMinute ?? 0) % 60,
    );
    final DateTime end = start.add(Duration(hours: durationHours ?? 1));

    return EventRadar(
      id: id,
      title: title,
      type: type,
      restaurantId: restaurantId,
      restaurantName: restaurantName,
      description: description,
      startsAt: start,
      endsAt: end,
      entryPriceFcfa: entryPriceFcfa,
      crowdLevel: crowdLevel,
    );
  }

  /// Sérialise le modèle en conservant son mode d'origine.
  Map<String, Object?> toJson() => <String, Object?>{
    'id': id,
    'title': title,
    'type': type.name,
    'restaurantId': restaurantId,
    'restaurantName': restaurantName,
    'description': description,
    'entryPriceFcfa': entryPriceFcfa,
    'crowdLevel': crowdLevel,
    if (startsAt != null) 'startsAt': startsAt!.toIso8601String(),
    if (endsAt != null) 'endsAt': endsAt!.toIso8601String(),
    if (dayOffset != null) 'dayOffset': dayOffset,
    if (startMinute != null) 'startTime': ClockTime.formatMinutes(startMinute!),
    if (durationHours != null) 'durationHours': durationHours,
  };
}
