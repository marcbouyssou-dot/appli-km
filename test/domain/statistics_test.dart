import 'package:flutter_test/flutter_test.dart';
import 'package:mes_km/domain/logic/statistics.dart';
import 'package:mes_km/domain/models/civil_date.dart';
import 'package:mes_km/domain/models/day_extra.dart';

import 'helpers.dart';

void main() {
  group('totaux jour / mois / année', () {
    test('mois vide => 0', () {
      expect(totalForMonth(2026, 7, trips: const []), 0);
    });

    test('plusieurs trajets le même jour', () {
      final day = CivilDate(2026, 10, 11);
      final trips = [
        makeTrip(id: 'a', date: day, km: 24),
        makeTrip(id: 'b', date: day, km: 18),
        makeTrip(id: 'c', date: CivilDate(2026, 10, 12), km: 7),
      ];

      expect(totalForDay(day, trips: trips), 42);
      expect(totalForMonth(2026, 10, trips: trips), 49);
    });

    test('DayExtra + Trips cumulés dans les totaux', () {
      final day = CivilDate(2026, 10, 11);
      final trips = [makeTrip(id: 'a', date: day, km: 42)];
      final extras = [DayExtra(date: day, extraKm: 45)];

      expect(totalForDay(day, trips: trips, extras: extras), 87);
      expect(totalForMonth(2026, 10, trips: trips, extras: extras), 87);
      expect(totalForYear(2026, trips: trips, extras: extras), 87);
    });

    test('changement d’année : chaque année compte ses kilomètres', () {
      final trips = [
        makeTrip(id: 'a', date: CivilDate(2025, 12, 31), km: 30),
        makeTrip(id: 'b', date: CivilDate(2026, 1, 1), km: 20),
      ];

      expect(totalForYear(2025, trips: trips), 30);
      expect(totalForYear(2026, trips: trips), 20);
      expect(totalForMonth(2025, 12, trips: trips), 30);
      expect(totalForMonth(2026, 1, trips: trips), 20);
    });

    test('un aller-retour n’est pas doublé dans les totaux', () {
      final trips = [
        makeTrip(id: 'ar', date: CivilDate(2026, 5, 4), km: 48, isRoundTrip: true),
      ];
      expect(totalForYear(2026, trips: trips), 48);
    });
  });

  group('jours actifs et moyenne', () {
    test('nombre de jours avec > 0 km', () {
      final trips = [
        makeTrip(id: 'a', date: CivilDate(2026, 10, 11), km: 24),
        makeTrip(id: 'b', date: CivilDate(2026, 10, 11), km: 18),
        makeTrip(id: 'c', date: CivilDate(2026, 10, 13), km: 10),
      ];
      final extras = [
        DayExtra(date: CivilDate(2026, 10, 14), extraKm: 5),
        // Un extra à 0 ne rend pas un jour actif.
        DayExtra(date: CivilDate(2026, 10, 15), extraKm: 0),
      ];

      expect(activeDayCount(trips: trips, extras: extras), 3);
    });

    test('moyenne par jour actif', () {
      final trips = [
        makeTrip(id: 'a', date: CivilDate(2026, 10, 11), km: 40),
        makeTrip(id: 'b', date: CivilDate(2026, 10, 12), km: 20),
      ];

      expect(averageKmPerActiveDay(trips: trips), 30);
    });

    test('moyenne sans aucun jour actif => 0', () {
      expect(averageKmPerActiveDay(trips: const []), 0);
    });
  });

  group('répartition par véhicule', () {
    test('plusieurs véhicules + trip sans vehicleId', () {
      final trips = [
        makeTrip(id: 'a', km: 24, vehicleId: 'clio'),
        makeTrip(id: 'b', km: 18, vehicleId: 'clio'),
        makeTrip(id: 'c', km: 50, vehicleId: 'moto'),
        makeTrip(id: 'd', km: 7),
      ];

      final byVehicle = detailedTotalByVehicle(trips);

      expect(byVehicle['clio'], 42);
      expect(byVehicle['moto'], 50);
      expect(byVehicle[null], 7);
      expect(byVehicle, hasLength(3));
    });

    test('vide => map vide', () {
      expect(detailedTotalByVehicle(const []), isEmpty);
    });
  });
}
