import 'package:flutter_test/flutter_test.dart';
import 'package:mes_km/domain/logic/vacations.dart';
import 'package:mes_km/domain/models/civil_date.dart';
import 'package:mes_km/domain/models/vacation_period.dart';

VacationPeriod period(
  String id,
  CivilDate start,
  CivilDate end, {
  String? label,
}) =>
    VacationPeriod(id: id, startDate: start, endDate: end, label: label);

void main() {
  group('mergeVacationPeriods', () {
    test('périodes disjointes restent séparées', () {
      final merged = mergeVacationPeriods([
        period('a', CivilDate(2026, 8, 1), CivilDate(2026, 8, 5)),
        period('b', CivilDate(2026, 8, 10), CivilDate(2026, 8, 12)),
      ]);

      expect(merged, hasLength(2));
      expect(merged[0].endDate, CivilDate(2026, 8, 5));
      expect(merged[1].startDate, CivilDate(2026, 8, 10));
    });

    test('chevauchement fusionné', () {
      final merged = mergeVacationPeriods([
        period('a', CivilDate(2026, 8, 1), CivilDate(2026, 8, 7)),
        period('b', CivilDate(2026, 8, 5), CivilDate(2026, 8, 10)),
      ]);

      expect(merged, hasLength(1));
      expect(merged.single.startDate, CivilDate(2026, 8, 1));
      expect(merged.single.endDate, CivilDate(2026, 8, 10));
    });

    test('cas de référence : 1–5 août + 6–10 août => 1–10 août', () {
      final merged = mergeVacationPeriods([
        period('a', CivilDate(2026, 8, 1), CivilDate(2026, 8, 5)),
        period('b', CivilDate(2026, 8, 6), CivilDate(2026, 8, 10)),
      ]);

      expect(merged, hasLength(1));
      expect(merged.single.startDate, CivilDate(2026, 8, 1));
      expect(merged.single.endDate, CivilDate(2026, 8, 10));
    });

    test('une période entièrement incluse disparaît dans l’englobante',
        () {
      final merged = mergeVacationPeriods([
        period('a', CivilDate(2026, 8, 1), CivilDate(2026, 8, 20)),
        period('b', CivilDate(2026, 8, 5), CivilDate(2026, 8, 10)),
      ]);

      expect(merged, hasLength(1));
      expect(merged.single.startDate, CivilDate(2026, 8, 1));
      expect(merged.single.endDate, CivilDate(2026, 8, 20));
    });

    test('jours uniques contigus fusionnés', () {
      final merged = mergeVacationPeriods([
        period('a', CivilDate(2026, 8, 1), CivilDate(2026, 8, 1)),
        period('b', CivilDate(2026, 8, 2), CivilDate(2026, 8, 2)),
      ]);

      expect(merged, hasLength(1));
      expect(merged.single.startDate, CivilDate(2026, 8, 1));
      expect(merged.single.endDate, CivilDate(2026, 8, 2));
    });

    test('fusion traverse le changement d’année', () {
      final merged = mergeVacationPeriods([
        period('a', CivilDate(2025, 12, 29), CivilDate(2025, 12, 31)),
        period('b', CivilDate(2026, 1, 1), CivilDate(2026, 1, 4)),
      ]);

      expect(merged, hasLength(1));
      expect(merged.single.startDate, CivilDate(2025, 12, 29));
      expect(merged.single.endDate, CivilDate(2026, 1, 4));
    });

    test('résultat indépendant de l’ordre d’entrée', () {
      final a = period('a', CivilDate(2026, 8, 1), CivilDate(2026, 8, 5));
      final b = period('b', CivilDate(2026, 8, 6), CivilDate(2026, 8, 10));
      final c = period('c', CivilDate(2026, 8, 20), CivilDate(2026, 8, 22));

      List<List<CivilDate>> ranges(List<VacationPeriod> periods) =>
          periods.map((p) => [p.startDate, p.endDate]).toList();

      final expected = ranges(mergeVacationPeriods([a, b, c]));
      expect(ranges(mergeVacationPeriods([c, b, a])), expected);
      expect(ranges(mergeVacationPeriods([b, c, a])), expected);
    });

    test('la période fusionnée garde l’id le plus ancien et son label',
        () {
      final merged = mergeVacationPeriods([
        period('late', CivilDate(2026, 8, 6), CivilDate(2026, 8, 10),
            label: 'Suite'),
        period('early', CivilDate(2026, 8, 1), CivilDate(2026, 8, 5)),
      ]);

      expect(merged.single.id, 'early');
      // Label de la plus ancienne absente => premier label rencontré.
      expect(merged.single.label, 'Suite');
    });

    test('n’altère pas la liste d’entrée (fusion)', () {
      final input = [
        period('b', CivilDate(2026, 8, 6), CivilDate(2026, 8, 10)),
        period('a', CivilDate(2026, 8, 1), CivilDate(2026, 8, 5)),
      ];
      mergeVacationPeriods(input);

      expect(input.first.id, 'b');
      expect(input, hasLength(2));
    });
  });

  group('removeDateFromPeriods', () {
    String noNewId() => fail('aucun nouvel id ne devrait être requis');

    test('période d’un seul jour => supprimée', () {
      final result = removeDateFromPeriods(
        [period('a', CivilDate(2026, 8, 5), CivilDate(2026, 8, 5))],
        CivilDate(2026, 8, 5),
        newIdForSplit: noNewId,
      );
      expect(result, isEmpty);
    });

    test('retirer le début => start + 1, id conservé', () {
      final result = removeDateFromPeriods(
        [period('a', CivilDate(2026, 8, 3), CivilDate(2026, 8, 10))],
        CivilDate(2026, 8, 3),
        newIdForSplit: noNewId,
      );
      expect(result.single.id, 'a');
      expect(result.single.startDate, CivilDate(2026, 8, 4));
      expect(result.single.endDate, CivilDate(2026, 8, 10));
    });

    test('retirer la fin => end - 1, id conservé', () {
      final result = removeDateFromPeriods(
        [period('a', CivilDate(2026, 8, 3), CivilDate(2026, 8, 10))],
        CivilDate(2026, 8, 10),
        newIdForSplit: noNewId,
      );
      expect(result.single.endDate, CivilDate(2026, 8, 9));
    });

    test('retirer le milieu => découpe : 3-10 moins le 6 => 3-5 et 7-10', () {
      final result = removeDateFromPeriods(
        [
          period('a', CivilDate(2026, 8, 3), CivilDate(2026, 8, 10),
              label: 'Été'),
        ],
        CivilDate(2026, 8, 6),
        newIdForSplit: () => 'nouveau',
      );

      expect(result, hasLength(2));
      expect(result[0].id, 'a');
      expect(result[0].startDate, CivilDate(2026, 8, 3));
      expect(result[0].endDate, CivilDate(2026, 8, 5));
      expect(result[1].id, 'nouveau');
      expect(result[1].startDate, CivilDate(2026, 8, 7));
      expect(result[1].endDate, CivilDate(2026, 8, 10));
      expect(result[1].label, 'Été', reason: 'label hérité');
    });

    test('découpe traversant le changement d’année', () {
      final result = removeDateFromPeriods(
        [period('a', CivilDate(2025, 12, 28), CivilDate(2026, 1, 3))],
        CivilDate(2025, 12, 31),
        newIdForSplit: () => 'n',
      );

      expect(result[0].endDate, CivilDate(2025, 12, 30));
      expect(result[1].startDate, CivilDate(2026, 1, 1));
      expect(result[1].endDate, CivilDate(2026, 1, 3));
    });

    test('les périodes non concernées restent intactes', () {
      final untouched =
          period('b', CivilDate(2026, 9, 1), CivilDate(2026, 9, 5));
      final result = removeDateFromPeriods(
        [
          period('a', CivilDate(2026, 8, 3), CivilDate(2026, 8, 10)),
          untouched,
        ],
        CivilDate(2026, 8, 3),
        newIdForSplit: noNewId,
      );
      expect(result, hasLength(2));
      expect(result[1].id, 'b');
      expect(result[1].startDate, CivilDate(2026, 9, 1));
    });
  });

  group('isVacationDate', () {
    test('couvert / non couvert, bornes incluses', () {
      final periods = [
        period('a', CivilDate(2026, 8, 3), CivilDate(2026, 8, 10)),
      ];
      expect(isVacationDate(periods, CivilDate(2026, 8, 3)), isTrue);
      expect(isVacationDate(periods, CivilDate(2026, 8, 10)), isTrue);
      expect(isVacationDate(periods, CivilDate(2026, 8, 2)), isFalse);
      expect(isVacationDate(periods, CivilDate(2026, 8, 11)), isFalse);
      // JOUR VIDE ≠ CONGÉ : rien n'est implicite.
      expect(isVacationDate(const [], CivilDate(2026, 8, 5)), isFalse);
    });
  });
}
