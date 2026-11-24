// =============================================================================
// Conversion des heures `HH:mm` utilisées par les données JSON.
// -----------------------------------------------------------------------------
// Le Domain travaille en minutes depuis minuit ; le seed et l'API utilisent
// des chaînes lisibles. Cette classe centrale évite de dupliquer le motif de
// validation dans chaque modèle.
// =============================================================================

/// Utilitaires d'horloge pour la couche Data.
final class ClockTime {
  // Constructeur privé : espace de noms statique.
  const ClockTime._();

  // Format strict 24 h : 00:00 à 23:59.
  static final RegExp _pattern = RegExp(r'^([01]\d|2[0-3]):([0-5]\d)$');

  /// Convertit `HH:mm` en minutes depuis minuit.
  /// [allowEndOfDay] autorise la valeur spéciale `24:00` (1440 minutes),
  /// utile uniquement pour une heure de fermeture.
  static int parseMinutes(String raw, {bool allowEndOfDay = false}) {
    final String value = raw.trim();

    // Cas spécial de fin de journée.
    if (allowEndOfDay && value == '24:00') {
      return 1440;
    }

    final RegExpMatch? match = _pattern.firstMatch(value);
    if (match == null) {
      throw const FormatException('Horaire invalide (format attendu HH:mm).');
    }

    // Les groupes 1 et 2 existent forcément si le motif correspond.
    final int hour = int.parse(match.group(1)!);
    final int minute = int.parse(match.group(2)!);
    return hour * 60 + minute;
  }

  /// Formate des minutes depuis minuit en `HH:mm`.
  /// 1440 est affiché `24:00` pour rester sérialisable en entrée.
  static String formatMinutes(int minutes) {
    // Bornage défensif.
    if (minutes < 0 || minutes > 1440) {
      throw const FormatException('Minutes hors plage.');
    }
    if (minutes == 1440) {
      return '24:00';
    }
    final String hour = (minutes ~/ 60).toString().padLeft(2, '0');
    final String minute = (minutes % 60).toString().padLeft(2, '0');
    return '$hour:$minute';
  }
}
