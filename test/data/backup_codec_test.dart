import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:mes_km/data/backup/backup_codec.dart';
import 'package:mes_km/domain/models/app_settings.dart';
import 'package:mes_km/domain/models/civil_date.dart';
import 'package:mes_km/domain/models/day_extra.dart';
import 'package:mes_km/domain/models/favorite_trip.dart';
import 'package:mes_km/domain/models/trip.dart';
import 'package:mes_km/domain/models/vacation_period.dart';
import 'package:mes_km/domain/models/vehicle.dart';

void main() {
  final fullTrips = [
    Trip(
      id: 't-1',
      date: CivilDate(2025, 12, 31),
      distanceKm: 48.3,
      isRoundTrip: true,
      origin: 'Café Évry', // accents / UTF-8
      destination: 'EHPAD « Les Chênes »',
      purpose: 'Tournée d’été',
      vehicleId: 'v-1',
      createdAt: DateTime.utc(2026, 1, 2, 10, 30),
    ),
    Trip(
      id: 't-2',
      date: CivilDate(2026, 2, 29 - 1), // 28 fév (2026 non bissextile)
      distanceKm: 12.3,
      createdAt: DateTime.utc(2026, 2, 28, 8),
    ),
  ];
  final fullExtras = [
    DayExtra(date: CivilDate(2026, 10, 5), extraKm: 45, note: 'tournée'),
  ];
  final fullFavorites = [
    FavoriteTrip(
      id: 'f-1',
      label: 'Cabinet ↔ EHPAD',
      distanceKm: 24,
      defaultRoundTrip: true,
      vehicleId: 'v-1',
      sortOrder: 0,
    ),
  ];
  final fullVehicles = [
    Vehicle(
      id: 'v-1',
      name: 'Clio',
      category: VehicleCategory.car,
      fiscalPowerCv: 5,
      registration: 'AA-123-BB',
      archivedAt: DateTime.utc(2026, 6, 1),
    ),
  ];
  final fullVacations = [
    VacationPeriod(
      id: 'p-1',
      startDate: CivilDate(2026, 8, 3),
      endDate: CivilDate(2026, 8, 15),
      label: 'Été',
    ),
  ];
  final fullSettings = AppSettings(
    displayName: 'Marc B',
    address: '1 rue Haute',
    city: 'Toulouse',
    mainVehicleId: 'v-1',
    themePreference: ThemePreference.dark,
  );

  String encodeFull() => encodeBackup(
        exportedAt: DateTime.utc(2026, 10, 11, 14, 30),
        trips: fullTrips,
        dayExtras: fullExtras,
        favorites: fullFavorites,
        vehicles: fullVehicles,
        vacationPeriods: fullVacations,
        settings: fullSettings,
      );

  group('round-trip', () {
    test('complet : tous les modèles, accents, champs optionnels', () {
      final content = decodeBackup(encodeFull());

      expect(content.exportedAt, DateTime.utc(2026, 10, 11, 14, 30));

      final trip = content.trips.firstWhere((t) => t.id == 't-1');
      expect(trip.date, CivilDate(2025, 12, 31));
      expect(trip.distanceKm, 48.3);
      expect(trip.isRoundTrip, isTrue);
      expect(trip.origin, 'Café Évry');
      expect(trip.destination, 'EHPAD « Les Chênes »');
      expect(trip.purpose, 'Tournée d’été');
      expect(trip.vehicleId, 'v-1');

      final bare = content.trips.firstWhere((t) => t.id == 't-2');
      expect(bare.origin, isNull);
      expect(bare.isRoundTrip, isFalse);

      expect(content.dayExtras.single.extraKm, 45);
      expect(content.dayExtras.single.note, 'tournée');
      expect(content.favorites.single.defaultRoundTrip, isTrue);
      expect(content.vehicles.single.isArchived, isTrue);
      expect(content.vehicles.single.category, VehicleCategory.car);
      expect(content.vacationPeriods.single.label, 'Été');
      expect(content.settings.displayName, 'Marc B');
      expect(content.settings.themePreference, ThemePreference.dark);
    });

    test('minimal : collections vides, réglages par défaut', () {
      final json = encodeBackup(
        exportedAt: DateTime.utc(2026, 1, 1),
        trips: const [],
        dayExtras: const [],
        favorites: const [],
        vehicles: const [],
        vacationPeriods: const [],
        settings: AppSettings(),
      );
      final content = decodeBackup(json);

      expect(content.trips, isEmpty);
      expect(content.daysWithKm, 0);
      expect(content.totalKm, 0);
      expect(content.yearRange, isNull);
      expect(content.settings.themePreference, ThemePreference.system);
    });

    test('aperçu : totaux et bornes d’années dérivés', () {
      final content = decodeBackup(encodeFull());
      expect(content.daysWithKm, 3); // 31/12/25, 28/02/26, 05/10/26
      expect(content.totalKm, 48.3 + 12.3 + 45);
      expect(content.yearRange, (2025, 2026));
    });
  });

  group('migration backup v1 -> v2 (fixture synthétique KM-008)', () {
    // Enveloppe EXACTEMENT au format v1 : dayExtras SANS vehicleId.
    // Les .kmbackup déjà exportés doivent rester restaurables à jamais.
    const fixtureV1 = '''
{
  "schemaVersion": 1,
  "appVersion": "1.0.0",
  "exportedAt": "2026-10-11T14:00:00.000Z",
  "counts": {"trips": 1, "dayExtras": 1, "favoriteTrips": 1,
              "vehicles": 1, "vacationPeriods": 1},
  "data": {
    "trips": [
      {"id": "t-1", "date": "2026-10-11", "distanceKm": 42.0,
       "isRoundTrip": false, "vehicleId": "v-1",
       "createdAt": "2026-10-11T09:00:00.000Z"}
    ],
    "dayExtras": [
      {"date": "2026-10-05", "extraKm": 87.0, "note": "tournée"}
    ],
    "favoriteTrips": [
      {"id": "f-1", "label": "TEST BACKUP", "distanceKm": 24.0,
       "defaultRoundTrip": false, "sortOrder": 0}
    ],
    "vehicles": [
      {"id": "v-1", "name": "Clio", "category": "car"}
    ],
    "vacationPeriods": [
      {"id": "p-1", "startDate": "2026-08-03", "endDate": "2026-08-10"}
    ],
    "settings": {"themePreference": "system"}
  }
}
''';

    test('v1 accepté et migré : DayExtra.vehicleId = null, tout restauré',
        () {
      final content = decodeBackup(fixtureV1);

      expect(content.trips.single.distanceKm, 42);
      expect(content.dayExtras.single.extraKm, 87);
      expect(content.dayExtras.single.vehicleId, isNull,
          reason: 'v1 ne portait pas d’attribution : null');
      expect(content.dayExtras.single.note, 'tournée');
      expect(content.favorites.single.label, 'TEST BACKUP');
      expect(content.vehicles.single.name, 'Clio');
      expect(content.vacationPeriods, hasLength(1));
    });

    test('v2 round-trip : vehicleId des DayExtra exporté et relu', () {
      final json = encodeBackup(
        exportedAt: DateTime.utc(2026, 10, 11),
        trips: const [],
        dayExtras: [
          DayExtra(
              date: CivilDate(2026, 10, 5),
              extraKm: 33,
              vehicleId: 'v-1'),
        ],
        favorites: const [],
        vehicles: fullVehicles,
        vacationPeriods: const [],
        settings: AppSettings(),
      );
      expect(json, contains('"schemaVersion": 4'));

      final content = decodeBackup(json);
      expect(content.dayExtras.single.vehicleId, 'v-1');
    });
  });

  group('validation / refus', () {
    test('JSON invalide', () {
      expect(() => decodeBackup('pas du json'),
          throwsA(isA<BackupFormatException>()));
    });

    test('structure invalide', () {
      expect(() => decodeBackup('{"schemaVersion":1}'),
          throwsA(isA<BackupFormatException>()));
      expect(() => decodeBackup('[]'),
          throwsA(isA<BackupFormatException>()));
    });

    test('version future : refus explicite, jamais partiel', () {
      final json = encodeFull().replaceFirst(
          '"schemaVersion": 4', '"schemaVersion": 99');
      expect(() => decodeBackup(json),
          throwsA(isA<BackupTooRecentException>()));
      expect(BackupTooRecentException().toString(),
          contains('version plus récente'));
    });

    Map<String, Object?> fullMap() =>
        jsonDecode(encodeFull()) as Map<String, Object?>;

    void expectRefused(Map<String, Object?> envelope, String fragment) {
      expect(
        () => decodeBackup(jsonEncode(envelope)),
        throwsA(isA<BackupFormatException>().having(
            (e) => e.message, 'message', contains(fragment))),
      );
    }

    test('distance négative refusée (revalidation domaine)', () {
      final map = fullMap();
      (((map['data'] as Map)['trips'] as List)[0]
          as Map)['distanceKm'] = -5.0;
      expectRefused(map, 'trajets');
    });

    test('extra négatif refusé', () {
      final map = fullMap();
      (((map['data'] as Map)['dayExtras'] as List)[0]
          as Map)['extraKm'] = -1.0;
      expectRefused(map, 'kilomètres non détaillés');
    });

    test('date invalide refusée', () {
      final map = fullMap();
      (((map['data'] as Map)['trips'] as List)[0]
          as Map)['date'] = '2026-02-30';
      expectRefused(map, 'trajets');
    });

    test('enum inconnu refusé', () {
      final map = fullMap();
      (((map['data'] as Map)['vehicles'] as List)[0]
          as Map)['category'] = 'avion';
      expectRefused(map, 'véhicules');
    });

    test('référence véhicule inconnue refusée', () {
      final map = fullMap();
      (((map['data'] as Map)['trips'] as List)[0]
          as Map)['vehicleId'] = 'v-fantôme';
      expectRefused(map, 'véhicule inconnu');
    });

    test('duplication d’ids refusée', () {
      final map = fullMap();
      final trips = (map['data'] as Map)['trips'] as List;
      trips.add(Map<String, Object?>.from(trips[0] as Map));
      expectRefused(map, 'doublon');
    });

    test('duplication de dates dayExtras refusée', () {
      final map = fullMap();
      final extras = (map['data'] as Map)['dayExtras'] as List;
      extras.add(Map<String, Object?>.from(extras[0] as Map));
      expectRefused(map, 'doublon');
    });

    test('référence véhicule inconnue dans dayExtras refusée (v2)', () {
      final map = fullMap();
      (((map['data'] as Map)['dayExtras'] as List)[0]
          as Map)['vehicleId'] = 'v-fantôme';
      expectRefused(map, 'véhicule inconnu');
    });

    test('vehicleId null accepté (politique nullable explicite)', () {
      final map = fullMap();
      (((map['data'] as Map)['trips'] as List)[0] as Map)
          .remove('vehicleId');
      final content = decodeBackup(jsonEncode(map));
      expect(content.trips.first.vehicleId, isNull);
    });
  });
}
