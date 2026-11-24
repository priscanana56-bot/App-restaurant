// =============================================================================
// Modèle JSON des horaires d'ouverture.
// -----------------------------------------------------------------------------
// La Data accepte un objet `{ "monday": { "open": "10:30", "close": "23:00" },
// ... }`. Une journée absente ou `null` signifie « fermé ». Les horaires sont
// ensuite convertis en entités Domain immuables.
// =============================================================================

// Entités Domain produites.
import '../../domain/entities/opening_hours.dart';

// Lecteur JSON strict.
import 'json_reader.dart';

/// Représentation de transport des horaires.
final class OpeningHoursModel {
  // Constructeur privé : la map est déjà validée.
  const OpeningHoursModel._(this.weekly);

  /// Créneaux par jour (1 = lundi ... 7 = dimanche, `null` = fermé).
  final Map<int, DaySchedule?> weekly;

  // Noms de clés JSON, dans l'ordre de `DateTime.weekday`.
  static const List<String> _dayKeys = <String>[
    'monday',
    'tuesday',
    'wednesday',
    'thursday',
    'friday',
    'saturday',
    'sunday',
  ];

  // Format d'heure 24 h accepté : 00:00 à 23:59.
  static final RegExp _clockPattern = RegExp(r'^([01]\d|2[0-3]):([0-5]\d)$');

  /// Construit le modèle depuis un objet JSON.
  factory OpeningHoursModel.fromJson(Map<String, Object?> json) {
    final JsonReader reader = JsonReader(json);
    final Map<int, DaySchedule?> weekly = <int, DaySchedule?>{};

    // Parcours des sept jours : une clé absente vaut « fermé ».
    for (var index = 0; index < _dayKeys.length; index++) {
      final Map<String, Object?>? day = reader.optionalObject(_dayKeys[index]);
      if (day == null) {
        weekly[index + 1] = null;
        continue;
      }

      final JsonReader dayReader = JsonReader(day);
      final int opensAt = _parseClockMinutes(
        dayReader.requireString('open', maxLength: 5),
        allowEndOfDay: false,
      );
      int closesAt = _parseClockMinutes(
        dayReader.requireString('close', maxLength: 5),
        allowEndOfDay: true,
      );

      // 00:00 en fermeture signifie minuit en fin de journée (1440 minutes).
      if (closesAt == 0) {
        closesAt = 1440;
      }

      // Un créneau vide est une donnée incohérente.
      if (opensAt == closesAt) {
        throw FormatException(
          'Horaires invalides pour « ${_dayKeys[index]} » : ouverture = fermeture.',
        );
      }

      weekly[index + 1] = DaySchedule(
        opensAtMinute: opensAt,
        closesAtMinute: closesAt,
      );
    }

    return OpeningHoursModel._(weekly);
  }

  /// Construit le modèle depuis une entité Domain déjà validée.
  /// Les horaires créés localement n'ont pas de représentation JSON d'entrée :
  /// ce factory garantit néanmoins le même format de cache que `fromJson`.
  factory OpeningHoursModel.fromEntity(OpeningHours entity) =>
      OpeningHoursModel._(Map<int, DaySchedule?>.unmodifiable(entity.weekly));

  /// Convertit le modèle en entité Domain.
  OpeningHours toEntity() => OpeningHours(weekly: weekly);

  /// Sérialise le modèle pour le cache Hive.
  Map<String, Object?> toJson() {
    final Map<String, Object?> result = <String, Object?>{};
    for (var index = 0; index < _dayKeys.length; index++) {
      final DaySchedule? schedule = weekly[index + 1];
      result[_dayKeys[index]] = schedule == null
          ? null
          : <String, Object?>{
              'open': schedule.opensAtLabel,
              'close': schedule.closesAtMinute == 1440
                  ? '24:00'
                  : schedule.closesAtLabel,
            };
    }
    return result;
  }

  /// Convertit `HH:mm` en minutes depuis minuit.
  static int _parseClockMinutes(String raw, {required bool allowEndOfDay}) {
    final String value = raw.trim();

    // Seule la fermeture peut valoir exactement 24:00.
    if (allowEndOfDay && value == '24:00') {
      return 1440;
    }

    final RegExpMatch? match = _clockPattern.firstMatch(value);
    if (match == null) {
      throw const FormatException('Horaire invalide (format attendu HH:mm).');
    }

    // Les groupes sont garantis non nuls par le motif.
    final int hour = int.parse(match.group(1)!);
    final int minute = int.parse(match.group(2)!);
    return hour * 60 + minute;
  }
}
