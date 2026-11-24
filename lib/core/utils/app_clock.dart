// =============================================================================
// Horloge applicative injectable.
// -----------------------------------------------------------------------------
// Les horaires d'ouverture, le Live Braise et les événements dépendent de
// l'heure. Pour que les tests soient déterministes, on n'appelle jamais
// `DateTime.now()` directement dans le Domain : on injecte un `AppClock`.
// =============================================================================

// Constantes de fuseau (Africa/Ouagadougou = GMT+0, sans heure d'été).
import '../constants/app_constants.dart';

/// Contrat d'horloge utilisé par les use cases.
abstract interface class AppClock {
  /// Renvoie l'heure « murale » de Koudougou, encodée en UTC.
  /// Exemple : 19h30 à Ouagadougou -> DateTime.utc(..., 19, 30).
  DateTime now();
}

/// Horloge réelle du système.
final class SystemClock implements AppClock {
  /// Constructeur constant : aucune ressource à initialiser.
  const SystemClock();

  /// Conversion de l'instant système vers l'heure de Koudougou.
  @override
  DateTime now() {
    // `toUtc()` fournit GMT, qui est exactement le fuseau de Ouagadougou.
    // Cela évite qu'un téléphone réglé sur un autre fuseau fausse les horaires.
    final DateTime utcNow = DateTime.now().toUtc();

    // Sécurité : on force le décalage configuré (0 pour le Burkina Faso).
    return utcNow.add(const Duration(hours: AppConstants.utcOffsetHours));
  }
}

/// Horloge figée, réservée aux tests et aux aperçus de design.
final class FixedClock implements AppClock {
  /// [instant] doit déjà représenter l'heure murale de Koudougou en UTC.
  const FixedClock(this.instant);

  // Instant retourné à chaque appel.
  final DateTime instant;

  /// Renvoie toujours l'instant fourni au constructeur.
  @override
  DateTime now() => instant;
}

/// Helpers de calendrier indépendants du fuseau du téléphone.
final class KoudougouTime {
  // Constructeur privé : utilitaires statiques.
  const KoudougouTime._();

  /// Lundi = 1 ... dimanche = 7, comme `DateTime.weekday`.
  static int weekday(DateTime instant) => instant.toUtc().weekday;

  /// Heure locale de Koudougou (0-23).
  static int hour(DateTime instant) => instant.toUtc().hour;

  /// Minute locale (0-59).
  static int minute(DateTime instant) => instant.toUtc().minute;

  /// Convertit un couple heure/minute en minutes depuis minuit.
  static int minutesOfDay(DateTime instant) =>
      hour(instant) * 60 + minute(instant);

  /// Construit un instant UTC du jour courant à l'heure indiquée.
  /// Utile pour comparer les horaires d'ouverture sans dérive de fuseau.
  static DateTime atTime(DateTime day, int hour, int minute) {
    // Normalisation du jour en UTC pour rester cohérent avec `now()`.
    final DateTime utcDay = day.toUtc();

    // Construction d'un instant précis, sans seconde ni milliseconde.
    return DateTime.utc(utcDay.year, utcDay.month, utcDay.day, hour, minute);
  }
}
