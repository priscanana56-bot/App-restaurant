// =============================================================================
// Modèle JSON du Live Braise.
// -----------------------------------------------------------------------------
// Deux formats sont acceptés :
//   1. ABSOLU (API) : `startedAt` / `endsAt` en ISO-8601 ;
//   2. QUOTIDIEN (seed de démonstration) : `startTime`, `endTime`, `days`.
// Le format quotidien est matérialisé au jour courant par `toEntity`, ce qui
// permet au bandeau Live Braise de rester pertinent chaque soir.
// =============================================================================

// Bornes métier.
import '../../../../core/constants/app_constants.dart';

// Nettoyage des textes et des prix.
import '../../../../core/security/input_sanitizer.dart';

// Horloge de Koudougou (construction d'instants UTC).
import '../../../../core/utils/app_clock.dart';

// Entité Domain produite.
import '../../domain/entities/live_braise_status.dart';

// Conversion des heures.
import 'clock_time.dart';

// Lecteur JSON strict.
import 'json_reader.dart';

/// Représentation de transport d'une braise.
final class LiveBraiseModel {
  // Constructeur privé : les invariants sont vérifiés par `fromJson`.
  const LiveBraiseModel._({
    required this.dishName,
    required this.description,
    required this.priceFcfa,
    required this.portionsTotal,
    required this.portionsRemaining,
    required this.startedAt,
    required this.endsAt,
    required this.dailyStartMinute,
    required this.dailyEndMinute,
    required this.weekdays,
  });

  /// Nom du plat braisé.
  final String dishName;

  /// Description courte.
  final String description;

  /// Prix d'une portion en FCFA.
  final int priceFcfa;

  /// Nombre total de portions.
  final int portionsTotal;

  /// Portions restantes.
  final int portionsRemaining;

  /// Début absolu (mode API), sinon `null`.
  final DateTime? startedAt;

  /// Fin absolue (mode API), sinon `null`.
  final DateTime? endsAt;

  /// Minute d'ouverture quotidienne (mode seed), sinon `null`.
  final int? dailyStartMinute;

  /// Minute de fermeture quotidienne (mode seed), sinon `null`.
  final int? dailyEndMinute;

  /// Jours actifs (1 = lundi ... 7 = dimanche).
  final Set<int> weekdays;

  /// Construit le modèle depuis un objet JSON.
  factory LiveBraiseModel.fromJson(Map<String, Object?> json) {
    final JsonReader reader = JsonReader(json);

    // Texte nettoyé.
    final String dishName = InputSanitizer.sanitizeShortLabel(
      reader.requireString('dishName', maxLength: 80),
      maxLength: 80,
    );
    if (dishName.isEmpty) {
      throw const FormatException('Nom de braise invalide.');
    }

    // Prix validé.
    final int? price = InputSanitizer.sanitizePriceFcfa(
      reader
          .requireInt('priceFcfa', min: 0, max: AppConstants.maxPriceFcfa)
          .toString(),
    );
    if (price == null) {
      throw const FormatException('Prix de braise invalide.');
    }

    // Stock cohérent.
    final int portionsTotal = reader.requireInt(
      'portionsTotal',
      min: 1,
      max: 500,
    );
    final int portionsRemaining = reader.requireInt(
      'portionsRemaining',
      min: 0,
      max: portionsTotal,
    );

    // Mode absolu (API).
    final DateTime? startedAt = reader.optionalDateTime('startedAt');
    final DateTime? endsAt = reader.optionalDateTime('endsAt');
    final bool hasAbsolute = startedAt != null && endsAt != null;

    // Mode quotidien (seed).
    final String startTime = reader.optionalString('startTime', maxLength: 5);
    final String endTime = reader.optionalString('endTime', maxLength: 5);
    final bool hasDaily = startTime.isNotEmpty && endTime.isNotEmpty;

    // Les deux modes sont exclusifs et l'un des deux est obligatoire.
    if (hasAbsolute == hasDaily) {
      throw const FormatException(
        'Live Braise : fournir soit startedAt/endsAt, soit startTime/endTime.',
      );
    }

    // Validation du mode absolu.
    if (hasAbsolute && !endsAt.isAfter(startedAt)) {
      throw const FormatException('Live Braise : fin antérieure au début.');
    }

    int? dailyStart;
    int? dailyEnd;
    Set<int> weekdays = <int>{1, 2, 3, 4, 5, 6, 7};
    if (hasDaily) {
      dailyStart = ClockTime.parseMinutes(startTime);
      dailyEnd = ClockTime.parseMinutes(endTime, allowEndOfDay: true);
      if (dailyStart == dailyEnd) {
        throw const FormatException('Live Braise : créneau vide.');
      }

      // Jours optionnels : par défaut, tous les jours.
      final List<int> rawDays = reader.intList('days', min: 1, max: 7);
      if (rawDays.isNotEmpty) {
        weekdays = Set<int>.unmodifiable(rawDays.toSet());
      }
    }

    return LiveBraiseModel._(
      dishName: dishName,
      description: InputSanitizer.sanitizePlainText(
        reader.optionalString('description', maxLength: 300),
        maxLength: 300,
        allowNewlines: false,
      ),
      priceFcfa: price,
      portionsTotal: portionsTotal,
      portionsRemaining: portionsRemaining,
      startedAt: startedAt,
      endsAt: endsAt,
      dailyStartMinute: dailyStart,
      dailyEndMinute: dailyEnd,
      weekdays: weekdays,
    );
  }

  /// Construit le modèle depuis un statut Domain matérialisé.
  /// Le mode absolu (dates ISO) est conservé : une braise créée ou modifiée
  /// localement garde exactement sa fenêtre horaire, sans réinterprétation.
  factory LiveBraiseModel.fromEntity(LiveBraiseStatus status) =>
      LiveBraiseModel._(
        dishName: status.dishName,
        description: status.description,
        priceFcfa: status.priceFcfa,
        portionsTotal: status.portionsTotal,
        portionsRemaining: status.portionsRemaining,
        startedAt: status.startedAt,
        endsAt: status.endsAt,
        dailyStartMinute: null,
        dailyEndMinute: null,
        weekdays: <int>{status.startedAt.weekday},
      );

  /// Matérialise la braise pour le restaurant et l'instant donnés.
  LiveBraiseStatus toEntity({
    required String restaurantId,
    required String restaurantName,
    required DateTime now,
  }) {
    // Mode absolu : les dates de l'API font foi.
    if (startedAt != null && endsAt != null) {
      return LiveBraiseStatus(
        restaurantId: restaurantId,
        restaurantName: restaurantName,
        dishName: dishName,
        description: description,
        priceFcfa: priceFcfa,
        portionsTotal: portionsTotal,
        portionsRemaining: portionsRemaining,
        startedAt: startedAt!,
        endsAt: endsAt!,
      );
    }

    // Mode quotidien : on cherche d'abord une session en cours.
    final ({DateTime start, DateTime end}) window = _resolveDailyWindow(now);
    return LiveBraiseStatus(
      restaurantId: restaurantId,
      restaurantName: restaurantName,
      dishName: dishName,
      description: description,
      priceFcfa: priceFcfa,
      portionsTotal: portionsTotal,
      portionsRemaining: portionsRemaining,
      startedAt: window.start,
      endsAt: window.end,
    );
  }

  /// Sérialise le modèle en conservant son mode d'origine.
  Map<String, Object?> toJson() => <String, Object?>{
    'dishName': dishName,
    'description': description,
    'priceFcfa': priceFcfa,
    'portionsTotal': portionsTotal,
    'portionsRemaining': portionsRemaining,
    if (startedAt != null) 'startedAt': startedAt!.toIso8601String(),
    if (endsAt != null) 'endsAt': endsAt!.toIso8601String(),
    if (dailyStartMinute != null)
      'startTime': ClockTime.formatMinutes(dailyStartMinute!),
    if (dailyEndMinute != null)
      'endTime': ClockTime.formatMinutes(dailyEndMinute!),
    if (dailyStartMinute != null)
      'days': weekdays.toList(growable: false)..sort(),
  };

  /// Résout la fenêtre quotidienne active, ou la prochaine à venir.
  ({DateTime start, DateTime end}) _resolveDailyWindow(DateTime now) {
    // Le constructeur garantit la présence des deux minutes en mode quotidien.
    final int startMinute = dailyStartMinute!;
    final int endMinute = dailyEndMinute!;

    // Début du service du jour, à l'heure murale de Koudougou.
    final DateTime todayStart = KoudougouTime.atTime(
      now,
      startMinute ~/ 60,
      startMinute % 60,
    );

    // Une session de la veille peut encore être active après minuit.
    final DateTime yesterdayStart = todayStart.subtract(
      const Duration(days: 1),
    );

    // Recherche d'une session en cours.
    for (final DateTime candidate in <DateTime>[yesterdayStart, todayStart]) {
      final DateTime end = _endFor(candidate, endMinute);
      if (weekdays.contains(candidate.weekday) &&
          !now.isBefore(candidate) &&
          now.isBefore(end)) {
        return (start: candidate, end: end);
      }
    }

    // Aucune session en cours : on prépare la prochaine occurrence.
    DateTime nextStart = todayStart;
    for (var offset = 0; offset < 7; offset++) {
      final DateTime candidate = todayStart.add(Duration(days: offset));
      if (weekdays.contains(candidate.weekday)) {
        nextStart = candidate;
        break;
      }
    }
    return (start: nextStart, end: _endFor(nextStart, endMinute));
  }

  /// Calcule la fin d'une session démarrée à [start].
  DateTime _endFor(DateTime start, int endMinute) {
    // 24:00 signifie minuit à la fin de la journée de début.
    if (endMinute == 1440) {
      return DateTime.utc(
        start.year,
        start.month,
        start.day,
      ).add(const Duration(days: 1));
    }

    // Même jour si l'heure de fin est postérieure au début.
    final DateTime sameDay = KoudougouTime.atTime(
      start,
      endMinute ~/ 60,
      endMinute % 60,
    );
    if (sameDay.isAfter(start)) {
      return sameDay;
    }

    // Sinon, la session se termine le lendemain (ex. 18:00 -> 02:00).
    return sameDay.add(const Duration(days: 1));
  }
}
