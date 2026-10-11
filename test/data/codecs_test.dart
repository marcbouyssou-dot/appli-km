import 'package:flutter_test/flutter_test.dart';
import 'package:mes_km/data/local/codecs.dart';
import 'package:mes_km/domain/models/app_settings.dart';
import 'package:mes_km/domain/models/civil_date.dart';
import 'package:mes_km/domain/models/day_extra.dart';
import 'package:mes_km/domain/models/favorite_trip.dart';
import 'package:mes_km/domain/models/trip.dart';
import 'package:mes_km/domain/models/vacation_period.dart';
import 'package:mes_km/domain/models/vehicle.dart';

void main() {
  group('Trip round-trip', () {
    test('tous champs renseignés', () {
      final trip = Trip(
        id: 't-1',
        date: CivilDate(2025, 12, 31),
        distanceKm: 48.3,
        isRoundTrip: true,
        origin: 'Maison',
        destination: 'Client',
        purpose: 'RDV',
        vehicleId: 'v-1',
        createdAt: DateTime.utc(2026, 1, 2, 10, 30),
      );

      final restored = tripFromDb('t-1', tripToDb(trip));

      expect(restored.id, trip.id);
      expect(restored.date, CivilDate(2025, 12, 31));
      expect(restored.distanceKm, 48.3);
      expect(restored.isRoundTrip, isTrue);
      expect(restored.origin, 'Maison');
      expect(restored.destination, 'Client');
      expect(restored.purpose, 'RDV');
      expect(restored.vehicleId, 'v-1');
      expect(restored.createdAt, DateTime.utc(2026, 1, 2, 10, 30));
    });

    test('champs optionnels absents', () {
      final trip = Trip(
        id: 't-2',
        date: CivilDate(2024, 2, 29),
        distanceKm: 12.3,
        createdAt: DateTime.utc(2024, 2, 29, 8),
      );

      final map = tripToDb(trip);
      expect(map.containsKey('origin'), isFalse);
      expect(map.containsKey('vehicleId'), isFalse);

      final restored = tripFromDb('t-2', map);
      expect(restored.date, CivilDate(2024, 2, 29));
      expect(restored.origin, isNull);
      expect(restored.vehicleId, isNull);
      expect(restored.isRoundTrip, isFalse);
    });

    test('kilomètres sans perte vs canonicalisation domaine', () {
      for (final km in [0.1, 12.3, 99.9, 1234.5, 48.0]) {
        final trip = Trip(
          id: 't',
          date: CivilDate(2026, 6, 15),
          distanceKm: km,
          createdAt: DateTime.utc(2026),
        );
        expect(tripFromDb('t', tripToDb(trip)).distanceKm, km);
      }
    });

    test('donnée stockée invalide refusée explicitement', () {
      expect(
        () => tripFromDb('t', {'distanceKm': 10.0}),
        throwsFormatException,
      );
      expect(
        () => tripFromDb('t', {'date': '2026-01-15', 'createdAt': 'x'}),
        throwsFormatException,
      );
      // La revalidation domaine s'applique aussi aux données stockées.
      expect(
        () => tripFromDb('t', {
          'date': '2026-01-15',
          'distanceKm': -5.0,
          'createdAt': '2026-01-15T08:00:00Z',
        }),
        throwsArgumentError,
      );
    });
  });

  group('DayExtra round-trip', () {
    test('clé = date, note optionnelle', () {
      final extra = DayExtra(
        date: CivilDate(2025, 12, 31),
        extraKm: 45,
        note: 'tournée',
      );
      final restored = dayExtraFromDb('2025-12-31', dayExtraToDb(extra));
      expect(restored.date, CivilDate(2025, 12, 31));
      expect(restored.extraKm, 45);
      expect(restored.note, 'tournée');

      final bare = DayExtra(date: CivilDate(2024, 2, 29), extraKm: 7.5);
      expect(dayExtraToDb(bare).containsKey('note'), isFalse);
      expect(dayExtraFromDb('2024-02-29', dayExtraToDb(bare)).extraKm, 7.5);
    });
  });

  group('FavoriteTrip round-trip', () {
    test('complet et minimal', () {
      final favorite = FavoriteTrip(
        id: 'f-1',
        label: 'Bureau',
        distanceKm: 24,
        defaultRoundTrip: true,
        origin: 'Maison',
        destination: 'Bureau',
        purpose: 'Travail',
        vehicleId: 'v-1',
        sortOrder: 3,
      );
      final restored = favoriteTripFromDb('f-1', favoriteTripToDb(favorite));
      expect(restored.label, 'Bureau');
      expect(restored.distanceKm, 24);
      expect(restored.defaultRoundTrip, isTrue);
      expect(restored.sortOrder, 3);
      expect(restored.vehicleId, 'v-1');

      final minimal =
          FavoriteTrip(id: 'f-2', label: 'Dépôt', distanceKm: 7.5, sortOrder: 0);
      final restoredMinimal =
          favoriteTripFromDb('f-2', favoriteTripToDb(minimal));
      expect(restoredMinimal.origin, isNull);
      expect(restoredMinimal.defaultRoundTrip, isFalse);
    });
  });

  group('Vehicle round-trip + enums', () {
    test('catégories stables et versionnables', () {
      expect(vehicleCategoryToDb(VehicleCategory.car), 'car');
      expect(vehicleCategoryToDb(VehicleCategory.twoWheeler), 'twoWheeler');
      expect(vehicleCategoryFromDb('car'), VehicleCategory.car);
      expect(vehicleCategoryFromDb('twoWheeler'), VehicleCategory.twoWheeler);
      expect(() => vehicleCategoryFromDb('plane'), throwsFormatException);
    });

    test('véhicule archivé et non archivé', () {
      final vehicle = Vehicle(
        id: 'v-1',
        name: 'Clio',
        category: VehicleCategory.car,
        fiscalPowerCv: 5,
        registration: 'AA-123-BB',
      );
      final restored = vehicleFromDb('v-1', vehicleToDb(vehicle));
      expect(restored.name, 'Clio');
      expect(restored.category, VehicleCategory.car);
      expect(restored.fiscalPowerCv, 5);
      expect(restored.registration, 'AA-123-BB');
      expect(restored.isArchived, isFalse);

      final archived = vehicle.archived(DateTime.utc(2026, 6, 1, 12));
      final restoredArchived = vehicleFromDb('v-1', vehicleToDb(archived));
      expect(restoredArchived.isArchived, isTrue);
      expect(restoredArchived.archivedAt, DateTime.utc(2026, 6, 1, 12));
    });
  });

  group('VacationPeriod round-trip', () {
    test('période traversant le changement d’année', () {
      final period = VacationPeriod(
        id: 'p-1',
        startDate: CivilDate(2025, 12, 29),
        endDate: CivilDate(2026, 1, 4),
        label: 'Fêtes',
      );
      final restored = vacationPeriodFromDb('p-1', vacationPeriodToDb(period));
      expect(restored.startDate, CivilDate(2025, 12, 29));
      expect(restored.endDate, CivilDate(2026, 1, 4));
      expect(restored.label, 'Fêtes');
    });
  });

  group('AppSettings round-trip + enum thème', () {
    test('complet, minimal, thème inconnu refusé', () {
      final settings = AppSettings(
        displayName: 'Marc B',
        address: '1 rue Haute',
        city: 'Toulouse',
        documentRecipientName: 'Cabinet X',
        documentRecipientAddress: '2 rue Basse',
        mainVehicleId: 'v-1',
        themePreference: ThemePreference.dark,
      );
      final restored = appSettingsFromDb(appSettingsToDb(settings));
      expect(restored.displayName, 'Marc B');
      expect(restored.mainVehicleId, 'v-1');
      expect(restored.themePreference, ThemePreference.dark);

      final defaults = appSettingsFromDb(appSettingsToDb(AppSettings()));
      expect(defaults.displayName, isNull);
      expect(defaults.themePreference, ThemePreference.system);

      expect(() => themePreferenceFromDb('sepia'), throwsFormatException);
    });
  });
}
