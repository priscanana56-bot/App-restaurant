// =============================================================================
// Formatage localisé (dates françaises, FCFA, téléphone, distances).
// -----------------------------------------------------------------------------
// Toutes les méthodes sont pures et déterministes. Le format monétaire est
// implémenté manuellement pour garantir l'espace de milliers et le suffixe
// « FCFA » sur tous les appareils, sans dépendre des données ICU du système.
// =============================================================================

// Formatage des dates localisées.
import 'package:intl/intl.dart';

/// Utilitaires d'affichage.
final class AppFormatters {
  // Constructeur privé : méthodes statiques uniquement.
  const AppFormatters._();

  // ---------------------------------------------------------------------------
  // Monnaie
  // ---------------------------------------------------------------------------

  /// Formate un montant entier en FCFA : `12500` -> `12 500 FCFA`.
  static String fcfa(int amount) {
    // Valeur absolue pour gérer proprement le signe négatif.
    final String digits = amount.abs().toString();

    // Tampon de construction du nombre groupé.
    final StringBuffer buffer = StringBuffer();

    // Parcours caractère par caractère, avec une espace tous les trois chiffres.
    for (var index = 0; index < digits.length; index++) {
      // Insertion d'un séparateur avant chaque groupe de trois, sauf au début.
      if (index > 0 && (digits.length - index) % 3 == 0) {
        buffer.write(' ');
      }

      // Ajout du chiffre courant.
      buffer.write(digits[index]);
    }

    // Signe négatif éventuel, puis espace insécable logique et devise.
    return '${amount < 0 ? '-' : ''}$buffer FCFA';
  }

  /// Variante compacte pour les badges : `12500` -> `12,5k FCFA`.
  static String fcfaCompact(int amount) {
    // En dessous de 10 000, le format complet reste plus lisible.
    if (amount.abs() < 10000) {
      return fcfa(amount);
    }

    // Division par mille avec une décimale, virgule française.
    final String compact = (amount / 1000)
        .toStringAsFixed(1)
        .replaceAll('.', ',');
    return '$compact k FCFA';
  }

  // ---------------------------------------------------------------------------
  // Téléphone
  // ---------------------------------------------------------------------------

  /// Affiche un numéro burkinabè E.164 de façon lisible :
  /// `+22670000000` -> `+226 70 00 00 00`.
  static String phoneDisplay(String e164) {
    // Extraction des chiffres pour absorber les formats déjà partiellement formatés.
    final String digits = e164.replaceAll(RegExp(r'[^0-9]'), '');

    // Un numéro burkinabè complet comporte 11 chiffres, dont l'indicatif 226.
    if (digits.length == 11 && digits.startsWith('226')) {
      // Partie nationale à 8 chiffres.
      final String national = digits.substring(3);

      // Groupes de deux chiffres, conformes aux habitudes locales.
      return '+226 ${national.substring(0, 2)} ${national.substring(2, 4)} '
          '${national.substring(4, 6)} ${national.substring(6, 8)}';
    }

    // Format inconnu : on renvoie la valeur d'origine (déjà nettoyée en amont).
    return e164;
  }

  // ---------------------------------------------------------------------------
  // Dates et heures (heure de Koudougou = UTC)
  // ---------------------------------------------------------------------------

  /// Format numérique court, indépendant des données de locale.
  static final DateFormat _shortDate = DateFormat('dd/MM/yyyy');

  /// Format complet français ; nécessite `initializeDateFormatting('fr_FR')`.
  static final DateFormat _longDate = DateFormat('dd MMMM yyyy', 'fr_FR');

  /// Heure sur 24 heures, sans fuseau (l'instant est déjà en heure de Koudougou).
  static final DateFormat _time = DateFormat('HH:mm');

  /// Jours de la semaine en français, utilisés en repli si ICU n'est pas chargé.
  static const List<String> _frenchWeekdays = <String>[
    'lundi',
    'mardi',
    'mercredi',
    'jeudi',
    'vendredi',
    'samedi',
    'dimanche',
  ];

  /// Date courte : `12/03/2026`.
  static String shortDateFr(DateTime instant) {
    // Conversion UTC pour rester sur l'heure murale de Koudougou.
    return _shortDate.format(instant.toUtc());
  }

  /// Date longue : `12 mars 2026`, avec repli numérique si la locale manque.
  static String longDateFr(DateTime instant) {
    // Bloc de capture : `intl` lève une erreur si les données fr ne sont pas chargées.
    try {
      return _longDate.format(instant.toUtc());
    } on Object {
      // Repli sûr : l'interface ne doit jamais planter pour un format de date.
      return _shortDate.format(instant.toUtc());
    }
  }

  /// Heure : `19:30`.
  static String timeFr(DateTime instant) {
    // Format 24 h, standard au Burkina Faso.
    return _time.format(instant.toUtc());
  }

  /// Date et heure : `12/03/2026 à 19:30`.
  static String dateTimeFr(DateTime instant) {
    // Combinaison lisible pour les reçus et confirmations de commande.
    return '${shortDateFr(instant)} à ${timeFr(instant)}';
  }

  /// Jour de la semaine en français, sans dépendre du chargement ICU.
  static String weekdayFr(DateTime instant) {
    // `weekday` renvoie 1 (lundi) à 7 (dimanche).
    return _frenchWeekdays[instant.toUtc().weekday - 1];
  }

  /// Ancienneté d'une vérification sur place, en langage naturel.
  static String verificationAge(DateTime verifiedAt, DateTime now) {
    // Écart en jours complets, dans le même référentiel UTC.
    final int days = now.toUtc().difference(verifiedAt.toUtc()).inDays;

    // Une date future (horloge déréglée) est traitée comme aujourd'hui.
    if (days <= 0) {
      return 'Vérifié aujourd’hui';
    }

    // Cas de la veille.
    if (days == 1) {
      return 'Vérifié hier';
    }

    // Moins d'une semaine : nombre de jours.
    if (days < 7) {
      return 'Vérifié il y a $days jours';
    }

    // Moins d'un mois : nombre de semaines.
    if (days < 30) {
      final int weeks = days ~/ 7;
      return 'Vérifié il y a $weeks ${weeks == 1 ? "semaine" : "semaines"}';
    }

    // Ancien : date précise plus utile qu'un décompte.
    return 'Vérifié le ${shortDateFr(verifiedAt)}';
  }

  // ---------------------------------------------------------------------------
  // Divers
  // ---------------------------------------------------------------------------

  /// Distance lisible : `1,4 km` ou `850 m`.
  static String distanceKm(double kilometers) {
    // En dessous du kilomètre, affichage en mètres arrondis.
    if (kilometers < 1) {
      final int meters = (kilometers * 1000).round();
      return '$meters m';
    }

    // Sinon, un chiffre après la virgule.
    return '${kilometers.toStringAsFixed(1).replaceAll('.', ',')} km';
  }

  /// Pourcentage borné, pour l'affluence : `72 %`.
  static String percentage(num value) {
    // Bornage défensif entre 0 et 100.
    final int bounded = value.round().clamp(0, 100);

    // Format français avec espace avant le symbole.
    return '$bounded %';
  }
}
