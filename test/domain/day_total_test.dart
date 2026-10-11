import 'package:flutter_test/flutter_test.dart';
import 'package:mes_km/domain/logic/day_total.dart';
import 'package:mes_km/domain/models/civil_date.dart';
import 'package:mes_km/domain/models/day_extra.dart';

import 'helpers.dart';

void main() {
  final day = CivilDate(2026, 10, 11);

  group('applyDeclaredDayTotal — invariant central', () {
    test('aucun trip + total 87 => extra 87', () {
      final result = applyDeclaredDayTotal(
        date: day,
        tripsOfDay: const [],
        declaredTotalKm: 87,
      );

      result as DailyTotalAdjusted;
      expect(result.extraKm, 87);
      expect(result.dayExtra?.extraKm, 87);
      expect(result.dayExtra?.date, day);
    });

    test('cas de référence : trips 24 + 18, total 87 => extra 45', () {
      final trips = [
        makeTrip(id: 'a', date: day, km: 24),
        makeTrip(id: 'b', date: day, km: 18),
      ];

      final result = applyDeclaredDayTotal(
        date: day,
        tripsOfDay: trips,
        declaredTotalKm: 87,
      );

      result as DailyTotalAdjusted;
      expect(result.extraKm, 45);
      expect(dayTotalKm(trips, result.dayExtra), 87);
      // Les deux trips restent strictement inchangés.
      expect(trips[0].distanceKm, 24);
      expect(trips[1].distanceKm, 18);
    });

    test('trips 24 + 18, total 42 => extra 0, absence logique de DayExtra',
        () {
      final result = applyDeclaredDayTotal(
        date: day,
        tripsOfDay: [
          makeTrip(id: 'a', date: day, km: 24),
          makeTrip(id: 'b', date: day, km: 18),
        ],
        declaredTotalKm: 42,
      );

      result as DailyTotalAdjusted;
      expect(result.extraKm, 0);
      expect(result.dayExtra, isNull);
    });

    test('trips 24 + 18, total 40 => refus métier typé, rien de modifié', () {
      final trips = [
        makeTrip(id: 'a', date: day, km: 24),
        makeTrip(id: 'b', date: day, km: 18),
      ];

      final result = applyDeclaredDayTotal(
        date: day,
        tripsOfDay: trips,
        declaredTotalKm: 40,
      );

      result as DailyTotalBelowDetailed;
      expect(result.detailedKm, 42);
      expect(result.requestedKm, 40);
      expect(trips[0].distanceKm, 24);
      expect(trips[1].distanceKm, 18);
    });

    test('la suppression conceptuelle d’un Trip ne modifie pas extraKm',
        () {
      final trips = [
        makeTrip(id: 'a', date: day, km: 24),
        makeTrip(id: 'b', date: day, km: 18),
      ];
      final adjusted = applyDeclaredDayTotal(
        date: day,
        tripsOfDay: trips,
        declaredTotalKm: 87,
      ) as DailyTotalAdjusted;
      final extra = adjusted.dayExtra!;

      // L'utilisateur supprime ensuite le trip de 24 km : l'extra reste 45,
      // le total dérivé diminue honnêtement.
      final remaining = [trips[1]];
      expect(extra.extraKm, 45);
      expect(dayTotalKm(remaining, extra), 63);
    });

    test('une distance aller-retour n’est jamais doublée deux fois', () {
      // Trip saisi comme A/R : distanceKm contient DÉJÀ le total (48).
      final roundTrip = makeTrip(id: 'ar', date: day, km: 48, isRoundTrip: true);
      expect(detailedTotalKm([roundTrip]), 48);

      final result = applyDeclaredDayTotal(
        date: day,
        tripsOfDay: [roundTrip],
        declaredTotalKm: 48,
      );
      result as DailyTotalAdjusted;
      expect(result.extraKm, 0);
    });

    test('total déclaré négatif = erreur d’appel, pas un cas métier', () {
      expect(
        () => applyDeclaredDayTotal(
          date: day,
          tripsOfDay: const [],
          declaredTotalKm: -1,
        ),
        throwsArgumentError,
      );
    });

    test('un trip d’un autre jour est refusé', () {
      expect(
        () => applyDeclaredDayTotal(
          date: day,
          tripsOfDay: [makeTrip(date: CivilDate(2026, 10, 12))],
          declaredTotalKm: 50,
        ),
        throwsArgumentError,
      );
    });

    test('décimales : trips 12.3 + 7.9, total 30.5 => extra 10.3 exact', () {
      final result = applyDeclaredDayTotal(
        date: day,
        tripsOfDay: [
          makeTrip(id: 'a', date: day, km: 12.3),
          makeTrip(id: 'b', date: day, km: 7.9),
        ],
        declaredTotalKm: 30.5,
      );

      result as DailyTotalAdjusted;
      expect(result.extraKm, 10.3);
    });
  });

  group('dayTotalKm', () {
    test('trips + extra', () {
      final extra = DayExtra(date: day, extraKm: 45);
      expect(
        dayTotalKm(
          [makeTrip(id: 'a', date: day, km: 24), makeTrip(id: 'b', date: day, km: 18)],
          extra,
        ),
        87,
      );
    });

    test('sans extra', () {
      expect(dayTotalKm([makeTrip(km: 24)], null), 24);
    });
  });
}
