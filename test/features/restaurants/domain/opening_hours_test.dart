// =============================================================================
// Tests des horaires d'ouverture.
// -----------------------------------------------------------------------------
// Le cas critique est le maquis qui ferme après minuit : à 01 h du matin, le
// service appartient encore à la veille. Ces tests verrouillent cette règle.
// =============================================================================

// Framework de test.
import 'package:flutter_test/flutter_test.dart';

// Entités testées.
import 'package:koudougou_gourmet/features/restaurants/domain/entities/opening_hours.dart';

/// Construit une semaine où seul le lundi ouvre de 18 h à 02 h.
OpeningHours _overnightMonday() {
  return OpeningHours(
    weekly: const <int, DaySchedule?>{
      1: DaySchedule(opensAtMinute: 1080, closesAtMinute: 120),
      2: null,
      3: null,
      4: null,
      5: null,
      6: null,
      7: null,
    },
  );
}

/// Point d'entrée des tests.
void main() {
  // La date de référence est un lundi.
  final DateTime monday = DateTime.utc(2026, 11, 16);
  final DateTime tuesday = DateTime.utc(2026, 11, 17);

  group('DaySchedule', () {
    test('formate les heures et détecte le passage de minuit', () {
      // 18:00 -> 02:00 traverse bien minuit.
      const DaySchedule overnight = DaySchedule(
        opensAtMinute: 1080,
        closesAtMinute: 120,
      );
      expect(overnight.crossesMidnight, isTrue);
      expect(overnight.opensAtLabel, '18:00');
      expect(overnight.closesAtLabel, '02:00');
      expect(overnight.label, '18:00 – 02:00');
    });

    test('gère un créneau classique en intervalle semi-ouvert', () {
      // 10:00 -> 23:00 : 22:59 ouvert, 23:00 fermé.
      const DaySchedule daytime = DaySchedule(
        opensAtMinute: 600,
        closesAtMinute: 1380,
      );
      expect(daytime.containsMinute(600), isTrue);
      expect(daytime.containsMinute(1379), isTrue);
      expect(daytime.containsMinute(1380), isFalse);
      expect(daytime.containsMinute(599), isFalse);
    });

    test('ignore une minute hors de la journée', () {
      // Une valeur corrompue ne doit pas être interprétée comme une ouverture.
      const DaySchedule schedule = DaySchedule(
        opensAtMinute: 600,
        closesAtMinute: 1380,
      );
      expect(schedule.containsMinute(-1), isFalse);
      expect(schedule.containsMinute(1440), isFalse);
    });
  });

  group('OpeningHours.isOpenAt', () {
    test('ouvre le lundi soir', () {
      // 19:00 le lundi : le service vient de commencer.
      expect(
        _overnightMonday().isOpenAt(DateTime.utc(2026, 11, 16, 19)),
        isTrue,
      );
    });

    test('reste ouvert après minuit pour le service de la veille', () {
      // 01:00 le mardi appartient au service du lundi soir.
      expect(
        _overnightMonday().isOpenAt(DateTime.utc(2026, 11, 17, 1)),
        isTrue,
      );
    });

    test('ferme à l’heure exacte de fin', () {
      // 02:00 le mardi : la fenêtre est terminée.
      expect(
        _overnightMonday().isOpenAt(DateTime.utc(2026, 11, 17, 2)),
        isFalse,
      );
    });

    test('est fermé avant l’ouverture et le mardi soir', () {
      // 17:59 puis 20:00 le mardi, jour sans service.
      expect(
        _overnightMonday().isOpenAt(DateTime.utc(2026, 11, 16, 17, 59)),
        isFalse,
      );
      expect(
        _overnightMonday().isOpenAt(DateTime.utc(2026, 11, 17, 20)),
        isFalse,
      );
    });

    test('détecte une semaine entièrement fermée', () {
      // Aucun créneau : le libellé du jour est explicite.
      final OpeningHours closed = OpeningHours(
        weekly: <int, DaySchedule?>{
          for (var weekday = 1; weekday <= 7; weekday++) weekday: null,
        },
      );
      expect(closed.isClosedAllWeek, isTrue);
      expect(closed.todayLabel(monday), 'Fermé aujourd’hui');
    });

    test('affiche les horaires du jour demandé', () {
      // Le lundi doit afficher le créneau, pas celui d'un autre jour.
      expect(_overnightMonday().todayLabel(monday), '18:00 – 02:00');
      expect(_overnightMonday().todayLabel(tuesday), 'Fermé aujourd’hui');
    });
  });
}
