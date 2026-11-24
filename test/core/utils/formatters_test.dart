// =============================================================================
// Tests des formateurs (FCFA, téléphone, dates, distances).
// =============================================================================

// Framework de test.
import 'package:flutter_test/flutter_test.dart';

// Données de locale française pour `intl`.
import 'package:intl/date_symbol_data_local.dart';

// Classe testée.
import 'package:koudougou_gourmet/core/utils/formatters.dart';

/// Point d'entrée des tests.
void main() {
  // Charge une seule fois les symboles de date français.
  setUpAll(() async {
    await initializeDateFormatting('fr_FR');
  });

  // ---------------------------------------------------------------------------
  // Monnaie
  // ---------------------------------------------------------------------------
  group('AppFormatters.fcfa', () {
    test('groupe les milliers avec une espace', () {
      // Format attendu sur tous les appareils.
      expect(AppFormatters.fcfa(12500), '12 500 FCFA');
      expect(AppFormatters.fcfa(0), '0 FCFA');
    });

    test('gère les montants négatifs', () {
      // Un remboursement ou une correction peut être négatif.
      expect(AppFormatters.fcfa(-1500), '-1 500 FCFA');
    });

    test('produit une version compacte au-delà de 10 000', () {
      // Virgule française dans le format compact.
      expect(AppFormatters.fcfaCompact(12500), '12,5 k FCFA');
      expect(AppFormatters.fcfaCompact(5000), '5 000 FCFA');
    });
  });

  // ---------------------------------------------------------------------------
  // Téléphone
  // ---------------------------------------------------------------------------
  group('AppFormatters.phoneDisplay', () {
    test('formate un numéro burkinabè en groupes de deux', () {
      // Indicatif + quatre paires.
      expect(AppFormatters.phoneDisplay('+22670123456'), '+226 70 12 34 56');
    });

    test('renvoie la valeur d’origine si le format est inconnu', () {
      // Aucune exception sur une valeur courte.
      expect(AppFormatters.phoneDisplay('17'), '17');
    });
  });

  // ---------------------------------------------------------------------------
  // Dates
  // ---------------------------------------------------------------------------
  group('AppFormatters dates', () {
    // Instant de référence : 12 mars 2026 à 19h30 UTC (heure de Koudougou).
    final DateTime instant = DateTime.utc(2026, 3, 12, 19, 30);

    test('formate la date courte', () {
      expect(AppFormatters.shortDateFr(instant), '12/03/2026');
    });

    test('formate la date longue en français', () {
      // Mois en minuscules selon la locale française.
      expect(AppFormatters.longDateFr(instant), '12 mars 2026');
    });

    test('formate l’heure sur 24 heures', () {
      expect(AppFormatters.timeFr(instant), '19:30');
    });

    test('affiche le jour de la semaine sans dépendre d’ICU', () {
      // 12 mars 2026 est un jeudi.
      expect(AppFormatters.weekdayFr(instant), 'jeudi');
    });
  });

  // ---------------------------------------------------------------------------
  // Ancienneté de vérification
  // ---------------------------------------------------------------------------
  group('AppFormatters.verificationAge', () {
    // « Maintenant » fixe pour des tests déterministes.
    final DateTime now = DateTime.utc(2026, 3, 12, 10);

    test('affiche aujourd’hui et hier', () {
      expect(
        AppFormatters.verificationAge(DateTime.utc(2026, 3, 12, 8), now),
        'Vérifié aujourd’hui',
      );
      expect(
        AppFormatters.verificationAge(DateTime.utc(2026, 3, 11, 8), now),
        'Vérifié hier',
      );
    });

    test('affiche les jours puis les semaines', () {
      expect(
        AppFormatters.verificationAge(DateTime.utc(2026, 3, 9), now),
        'Vérifié il y a 3 jours',
      );
      expect(
        AppFormatters.verificationAge(DateTime.utc(2026, 3, 1), now),
        'Vérifié il y a 1 semaine',
      );
    });

    test('affiche la date précise au-delà d’un mois', () {
      expect(
        AppFormatters.verificationAge(DateTime.utc(2026, 1, 15), now),
        'Vérifié le 15/01/2026',
      );
    });
  });

  // ---------------------------------------------------------------------------
  // Divers
  // ---------------------------------------------------------------------------
  group('AppFormatters divers', () {
    test('formate les distances en mètres ou kilomètres', () {
      // Arrondi métrique et décimale française.
      expect(AppFormatters.distanceKm(0.85), '850 m');
      expect(AppFormatters.distanceKm(1.4), '1,4 km');
    });

    test('borne le pourcentage entre 0 et 100', () {
      // Valeur normale et valeurs extrêmes.
      expect(AppFormatters.percentage(72.6), '73 %');
      expect(AppFormatters.percentage(-5), '0 %');
      expect(AppFormatters.percentage(150), '100 %');
    });
  });
}
