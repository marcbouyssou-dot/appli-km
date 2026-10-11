import 'package:flutter_test/flutter_test.dart';
import 'package:mes_km/data/local/app_database.dart';
import 'package:mes_km/data/local/sembast_day_extra_repository.dart';
import 'package:mes_km/data/local/sembast_favorite_trip_repository.dart';
import 'package:mes_km/data/local/sembast_settings_repository.dart';
import 'package:mes_km/data/local/sembast_trip_repository.dart';
import 'package:mes_km/data/local/sembast_vacation_repository.dart';
import 'package:mes_km/data/local/sembast_vehicle_repository.dart';
import 'package:mes_km/domain/models/app_settings.dart';
import 'package:mes_km/domain/models/civil_date.dart';
import 'package:mes_km/domain/models/day_extra.dart';
import 'package:mes_km/domain/models/favorite_trip.dart';
import 'package:mes_km/domain/models/trip.dart';
import 'package:mes_km/domain/models/vacation_period.dart';
import 'package:mes_km/domain/models/vehicle.dart';
import 'package:sembast/sembast_memory.dart';

void main() {
  late MesKmDatabase database;

  setUp(() async {
    database =
        await MesKmDatabase.open(newDatabaseFactoryMemory(), name: 'test.db');
  });

  tearDown(() => database.close());

  Trip makeTrip(String id, CivilDate date, double km,
          {String? vehicleId, DateTime? createdAt}) =>
      Trip(
        id: id,
        date: date,
        distanceKm: km,
        vehicleId: vehicleId,
        createdAt: createdAt ?? DateTime.utc(2026, 1, 1, 8),
      );

  group('TripRepository', () {
    test('CRUD complet', () async {
      final repo = SembastTripRepository(database.db);
      final day = CivilDate(2026, 10, 11);

      await repo.put(makeTrip('t-1', day, 24));
      expect((await repo.getById('t-1'))?.distanceKm, 24);

      // Remplacement par id.
      await repo.put(makeTrip('t-1', day, 30));
      expect((await repo.getById('t-1'))?.distanceKm, 30);
      expect(await repo.getAll(), hasLength(1));

      await repo.delete('t-1');
      expect(await repo.getById('t-1'), isNull);
      expect(await repo.getAll(), isEmpty);
    });

    test('plusieurs trips le même jour, triés par création', () async {
      final repo = SembastTripRepository(database.db);
      final day = CivilDate(2026, 10, 11);

      await repo.put(
          makeTrip('t-2', day, 18, createdAt: DateTime.utc(2026, 10, 11, 14)));
      await repo.put(
          makeTrip('t-1', day, 24, createdAt: DateTime.utc(2026, 10, 11, 9)));

      final trips = await repo.getByDate(day);
      expect(trips.map((t) => t.id).toList(), ['t-1', 't-2']);
      expect(trips.map((t) => t.distanceKm).toList(), [24, 18]);
    });

    test('lecture par plage, bornes incluses, traverse l’année',
        () async {
      final repo = SembastTripRepository(database.db);
      await repo.put(makeTrip('a', CivilDate(2025, 12, 30), 10));
      await repo.put(makeTrip('b', CivilDate(2025, 12, 31), 20));
      await repo.put(makeTrip('c', CivilDate(2026, 1, 1), 30));
      await repo.put(makeTrip('d', CivilDate(2026, 1, 5), 40));

      final trips = await repo.getBetween(
        CivilDate(2025, 12, 31),
        CivilDate(2026, 1, 1),
      );
      expect(trips.map((t) => t.id).toList(), ['b', 'c']);
    });
  });

  group('DayExtraRepository', () {
    test('create / update / suppression logique via extra 0', () async {
      final repo = SembastDayExtraRepository(database.db);
      final day = CivilDate(2026, 10, 11);

      await repo.set(DayExtra(date: day, extraKm: 45));
      expect((await repo.getForDate(day))?.extraKm, 45);

      await repo.set(DayExtra(date: day, extraKm: 12.5));
      expect((await repo.getForDate(day))?.extraKm, 12.5);

      // extra 0 = absence logique => suppression de l'enregistrement.
      await repo.set(DayExtra(date: day, extraKm: 0));
      expect(await repo.getForDate(day), isNull);
      expect(await repo.getAll(), isEmpty);
    });

    test('deleteForDate et lecture par plage', () async {
      final repo = SembastDayExtraRepository(database.db);
      await repo.set(DayExtra(date: CivilDate(2026, 10, 10), extraKm: 5));
      await repo.set(DayExtra(date: CivilDate(2026, 10, 11), extraKm: 7));
      await repo.set(DayExtra(date: CivilDate(2026, 10, 20), extraKm: 9));

      final extras = await repo.getBetween(
        CivilDate(2026, 10, 10),
        CivilDate(2026, 10, 11),
      );
      expect(extras.map((e) => e.extraKm).toList(), [5, 7]);

      await repo.deleteForDate(CivilDate(2026, 10, 10));
      expect(await repo.getForDate(CivilDate(2026, 10, 10)), isNull);
      expect(await repo.getAll(), hasLength(2));
    });
  });

  group('FavoriteTripRepository', () {
    FavoriteTrip favorite(String id, String label, int sortOrder) =>
        FavoriteTrip(id: id, label: label, distanceKm: 10, sortOrder: sortOrder);

    test('CRUD + ordre par sortOrder', () async {
      final repo = SembastFavoriteTripRepository(database.db);
      await repo.put(favorite('f-b', 'Client B', 1));
      await repo.put(favorite('f-a', 'Bureau', 0));
      await repo.put(favorite('f-c', 'Dépôt', 2));

      expect(
        (await repo.getAllOrdered()).map((f) => f.label).toList(),
        ['Bureau', 'Client B', 'Dépôt'],
      );

      await repo.delete('f-b');
      expect(
        (await repo.getAllOrdered()).map((f) => f.id).toList(),
        ['f-a', 'f-c'],
      );
    });

    test('reorder réécrit les positions atomiquement', () async {
      final repo = SembastFavoriteTripRepository(database.db);
      await repo.put(favorite('f-a', 'Bureau', 0));
      await repo.put(favorite('f-b', 'Client B', 1));
      await repo.put(favorite('f-c', 'Dépôt', 2));

      await repo.reorder(['f-c', 'f-a', 'f-b']);

      final ordered = await repo.getAllOrdered();
      expect(ordered.map((f) => f.id).toList(), ['f-c', 'f-a', 'f-b']);
      expect(ordered.map((f) => f.sortOrder).toList(), [0, 1, 2]);
    });

    test('reorder avec id inconnu refuse et ne change rien', () async {
      final repo = SembastFavoriteTripRepository(database.db);
      await repo.put(favorite('f-a', 'Bureau', 0));
      await repo.put(favorite('f-b', 'Client B', 1));

      await expectLater(
        repo.reorder(['f-b', 'f-inconnu']),
        throwsArgumentError,
      );

      // La transaction est annulée : ordre initial intact.
      expect(
        (await repo.getAllOrdered()).map((f) => f.id).toList(),
        ['f-a', 'f-b'],
      );
    });
  });

  group('VehicleRepository', () {
    test('CRUD + archivage', () async {
      final repo = SembastVehicleRepository(database.db);
      final clio = Vehicle(
        id: 'v-1',
        name: 'Clio',
        category: VehicleCategory.car,
        fiscalPowerCv: 5,
      );
      final moto = Vehicle(
        id: 'v-2',
        name: 'Ténéré',
        category: VehicleCategory.twoWheeler,
      );

      await repo.put(clio);
      await repo.put(moto);
      expect(await repo.getAll(), hasLength(2));

      await repo.put(clio.archived(DateTime.utc(2026, 6, 1)));

      expect((await repo.getById('v-1'))?.isArchived, isTrue);
      expect(await repo.getAll(), hasLength(2));
      final active = await repo.getAll(includeArchived: false);
      expect(active.single.id, 'v-2');
    });
  });

  group('VacationRepository', () {
    VacationPeriod period(String id, CivilDate start, CivilDate end) =>
        VacationPeriod(id: id, startDate: start, endDate: end);

    test('put / getAll triés / delete / replaceAll', () async {
      final repo = SembastVacationRepository(database.db);
      await repo.put(period('p-2', CivilDate(2026, 8, 10), CivilDate(2026, 8, 12)));
      await repo.put(period('p-1', CivilDate(2026, 8, 1), CivilDate(2026, 8, 5)));

      expect(
        (await repo.getAll()).map((p) => p.id).toList(),
        ['p-1', 'p-2'],
      );

      await repo.delete('p-2');
      expect(await repo.getAll(), hasLength(1));

      await repo.replaceAll([
        period('m-1', CivilDate(2026, 8, 1), CivilDate(2026, 8, 12)),
      ]);
      final all = await repo.getAll();
      expect(all.single.id, 'm-1');
      expect(all.single.endDate, CivilDate(2026, 8, 12));
    });
  });

  group('SettingsRepository', () {
    test('valeurs par défaut puis sauvegarde', () async {
      final repo = SembastSettingsRepository(database.db);

      final defaults = await repo.get();
      expect(defaults.displayName, isNull);
      expect(defaults.themePreference, ThemePreference.system);

      await repo.save(AppSettings(
        displayName: 'Marc',
        mainVehicleId: 'v-1',
        themePreference: ThemePreference.dark,
      ));

      final saved = await repo.get();
      expect(saved.displayName, 'Marc');
      expect(saved.mainVehicleId, 'v-1');
      expect(saved.themePreference, ThemePreference.dark);
    });
  });
}
