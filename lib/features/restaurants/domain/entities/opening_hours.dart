// =============================================================================
// Horaires d'ouverture d'un restaurant.
// -----------------------------------------------------------------------------
// Le Domain raisonne en minutes depuis minuit, dans le fuseau de Koudougou
// (GMT+0). Cette représentation évite les erreurs de fuseau du téléphone et
// gère simplement les maquis qui ferment après minuit (18 h -> 02 h).
// =============================================================================

// Equatable pour comparer deux horaires sans code manuel.
import 'package:equatable/equatable.dart';

/// Créneau d'ouverture d'une journée.
final class DaySchedule extends Equatable {
  /// Construit un créneau valide.
  /// [opensAtMinute] et [closesAtMinute] sont exprimés depuis minuit.
  const DaySchedule({required this.opensAtMinute, required this.closesAtMinute})
    : assert(
        opensAtMinute >= 0 && opensAtMinute < 1440,
        'L’ouverture doit être comprise entre 00:00 et 23:59.',
      ),
      assert(
        closesAtMinute > 0 && closesAtMinute <= 1440,
        'La fermeture doit être comprise entre 00:01 et 24:00.',
      ),
      assert(
        opensAtMinute != closesAtMinute,
        'Un créneau vide n’a pas de sens.',
      );

  /// Heure d'ouverture, en minutes depuis minuit (ex. 10:30 = 630).
  final int opensAtMinute;

  /// Heure de fermeture, en minutes depuis minuit (ex. 23:00 = 1380).
  /// La valeur 1440 représente minuit en fin de journée.
  final int closesAtMinute;

  /// Indique si le créneau se termine le lendemain (ex. 18:00 -> 02:00).
  bool get crossesMidnight => closesAtMinute <= opensAtMinute;

  /// Indique si [minute] tombe dans le créneau, en considérant que le créneau
  /// a commencé le jour de [opensAtMinute].
  bool containsMinute(int minute) {
    // Bornage défensif : une minute hors [0, 1439] est invalide.
    if (minute < 0 || minute >= 1440) {
      return false;
    }

    // Créneau de nuit : ouvert après l'ouverture OU avant la fermeture.
    if (crossesMidnight) {
      return minute >= opensAtMinute || minute < closesAtMinute;
    }

    // Créneau de jour classique : intervalle semi-ouvert [ouverture, fermeture).
    return minute >= opensAtMinute && minute < closesAtMinute;
  }

  /// Indique si le service du jour a déjà commencé à [minute].
  /// Pour un créneau de nuit, seules les minutes après l'ouverture comptent :
  /// la partie « après minuit » appartient au service de la veille.
  bool hasStartedAt(int minute) {
    // Créneau de nuit : le service démarre à l'heure d'ouverture du soir.
    if (crossesMidnight) {
      return minute >= opensAtMinute;
    }

    // Créneau classique : le service a démarré dans l'intervalle.
    return containsMinute(minute);
  }

  /// Heure d'ouverture formatée en `HH:mm`.
  String get opensAtLabel => _formatMinutes(opensAtMinute);

  /// Heure de fermeture formatée en `HH:mm` (minuit affiché `00:00`).
  String get closesAtLabel => _formatMinutes(closesAtMinute);

  /// Libellé lisible : `10:30 – 23:00` ou `18:00 – 02:00`.
  String get label => '$opensAtLabel – $closesAtLabel';

  /// Convertit un nombre de minutes en `HH:mm`.
  static String _formatMinutes(int minute) {
    // Minuit de fin de journée est affiché comme 00:00.
    final int normalized = minute % 1440;
    final String hours = (normalized ~/ 60).toString().padLeft(2, '0');
    final String minutes = (normalized % 60).toString().padLeft(2, '0');
    return '$hours:$minutes';
  }

  /// Propriétés comparées par Equatable.
  @override
  List<Object?> get props => <Object?>[opensAtMinute, closesAtMinute];
}

/// Semaine d'ouverture d'un restaurant.
/// La clé de la map suit `DateTime.weekday` : 1 = lundi ... 7 = dimanche.
final class OpeningHours extends Equatable {
  /// Construit une semaine complète.
  /// Une journée sans créneau est représentée par `null` (fermé).
  OpeningHours({required Map<int, DaySchedule?> weekly})
    : assert(
        weekly.length == 7,
        'La semaine doit contenir exactement 7 jours.',
      ),
      assert(
        weekly.keys.every((int weekday) => weekday >= 1 && weekday <= 7),
        'Les clés de jour doivent aller de 1 (lundi) à 7 (dimanche).',
      ),
      weekly = Map<int, DaySchedule?>.unmodifiable(weekly);

  /// Créneaux indexés par jour de la semaine (1 = lundi, 7 = dimanche).
  final Map<int, DaySchedule?> weekly;

  /// Créneau d'un jour précis, ou `null` si fermé.
  DaySchedule? scheduleForWeekday(int weekday) => weekly[weekday];

  /// Créneau du jour de [instant], en heure de Koudougou.
  DaySchedule? scheduleFor(DateTime instant) => weekly[instant.toUtc().weekday];

  /// Indique si l'établissement est ouvert à l'instant donné.
  bool isOpenAt(DateTime instant) {
    // Conversion systématique en UTC : c'est l'heure murale de Koudougou.
    final DateTime utcInstant = instant.toUtc();

    // Minute courante depuis minuit.
    final int minute = utcInstant.hour * 60 + utcInstant.minute;

    // Service du jour même (y compris un créneau qui a commencé ce matin).
    final DaySchedule? today = weekly[utcInstant.weekday];
    if (today != null && today.hasStartedAt(minute)) {
      return true;
    }

    // Service de la veille encore actif après minuit (ex. 18:00 -> 02:00).
    final int yesterdayWeekday = utcInstant
        .subtract(const Duration(days: 1))
        .weekday;
    final DaySchedule? yesterday = weekly[yesterdayWeekday];
    if (yesterday != null &&
        yesterday.crossesMidnight &&
        minute < yesterday.closesAtMinute) {
      return true;
    }

    // Aucun service actif à cet instant.
    return false;
  }

  /// Indique si le restaurant est fermé toute la semaine.
  bool get isClosedAllWeek =>
      weekly.values.every((DaySchedule? schedule) => schedule == null);

  /// Libellé des horaires du jour de [instant] :
  /// `10:30 – 23:00` ou `Fermé aujourd’hui`.
  String todayLabel(DateTime instant) {
    final DaySchedule? schedule = scheduleFor(instant);
    return schedule?.label ?? 'Fermé aujourd’hui';
  }

  /// Propriétés comparées par Equatable (la map est comparée en profondeur).
  @override
  List<Object?> get props => <Object?>[weekly];
}
