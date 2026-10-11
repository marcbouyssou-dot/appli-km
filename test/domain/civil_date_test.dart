import 'package:flutter_test/flutter_test.dart';
import 'package:mes_km/domain/models/civil_date.dart';

void main() {
  group('CivilDate — validité', () {
    test('29 février est valide sur année bissextile', () {
      final date = CivilDate(2024, 2, 29);
      expect(date.toIso8601(), '2024-02-29');
    });

    test('29 février est refusé hors année bissextile', () {
      expect(() => CivilDate(2023, 2, 29), throwsArgumentError);
    });

    test('mois et jour hors bornes refusés', () {
      expect(() => CivilDate(2026, 13, 1), throwsArgumentError);
      expect(() => CivilDate(2026, 4, 31), throwsArgumentError);
      expect(() => CivilDate(2026, 0, 10), throwsArgumentError);
    });
  });

  group('CivilDate — égalité et tri', () {
    test('deux dates identiques sont égales (== et hashCode)', () {
      expect(CivilDate(2026, 10, 11), CivilDate(2026, 10, 11));
      expect(
        CivilDate(2026, 10, 11).hashCode,
        CivilDate(2026, 10, 11).hashCode,
      );
    });

    test('tri correct, y compris au changement d’année', () {
      final dates = [
        CivilDate(2026, 1, 1),
        CivilDate(2025, 12, 31),
        CivilDate(2026, 2, 1),
        CivilDate(2025, 1, 15),
      ]..sort();

      expect(dates.map((d) => d.toIso8601()).toList(), [
        '2025-01-15',
        '2025-12-31',
        '2026-01-01',
        '2026-02-01',
      ]);
    });

    test('isBefore / isAfter au passage 31 décembre / 1er janvier', () {
      final dec31 = CivilDate(2025, 12, 31);
      final jan1 = CivilDate(2026, 1, 1);
      expect(dec31.isBefore(jan1), isTrue);
      expect(jan1.isAfter(dec31), isTrue);
    });
  });

  group('CivilDate — conversions sans dérive', () {
    test('fromDateTime ignore l’heure, même tard le soir', () {
      final lateEvening = DateTime(2026, 3, 29, 23, 59, 59);
      expect(CivilDate.fromDateTime(lateEvening), CivilDate(2026, 3, 29));
    });

    test('toDateTime rend minuit local du même jour', () {
      final dt = CivilDate(2026, 10, 11).toDateTime();
      expect([dt.year, dt.month, dt.day, dt.hour], [2026, 10, 11, 0]);
    });

    test('aller-retour parse/toIso8601 stable', () {
      const iso = '2026-02-05';
      expect(CivilDate.parse(iso).toIso8601(), iso);
    });

    test('parse refuse les formats invalides', () {
      expect(() => CivilDate.parse('2026/02/05'), throwsFormatException);
      expect(() => CivilDate.parse('pas-une-date'), throwsFormatException);
    });

    test('addDays traverse le changement d’heure d’été sans dérive',
        () {
      // En France, le passage à l'heure d'été 2026 a lieu le 29 mars.
      var date = CivilDate(2026, 3, 28);
      date = date.addDays(1);
      expect(date, CivilDate(2026, 3, 29));
      date = date.addDays(1);
      expect(date, CivilDate(2026, 3, 30));
    });

    test('addDays traverse le changement d’année', () {
      expect(CivilDate(2025, 12, 31).addDays(1), CivilDate(2026, 1, 1));
      expect(CivilDate(2026, 1, 1).addDays(-1), CivilDate(2025, 12, 31));
    });

    test('addDays gère le 29 février', () {
      expect(CivilDate(2024, 2, 28).addDays(1), CivilDate(2024, 2, 29));
      expect(CivilDate(2024, 2, 29).addDays(1), CivilDate(2024, 3, 1));
      expect(CivilDate(2023, 2, 28).addDays(1), CivilDate(2023, 3, 1));
    });
  });
}
