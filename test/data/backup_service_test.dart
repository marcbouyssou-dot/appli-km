import 'package:flutter_test/flutter_test.dart';
import 'package:mes_km/data/backup/backup_codec.dart';
import 'package:mes_km/data/backup/backup_service.dart';
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
import 'package:sembast/sembast_memory.dart' hide Finder;

void main() {
  late MesKmDatabase database;
  late BackupService service;

  setUp(() async {
    database =
        await MesKmDatabase.open(newDatabaseFactoryMemory(), name: 'bs.db');
    service = BackupService(database.db);
  });

  tearDown(() => database.close());

  Future<void> seedEverything() async {
    await SembastVehicleRepository(database.db).put(Vehicle(
      id: 'v-1',
      name: 'Clio',
      category: VehicleCategory.car,
      archivedAt: DateTime.utc(2026, 6, 1), // archivé : inclus quand même
    ));
    await SembastTripRepository(database.db).put(Trip(
      id: 't-1',
      date: CivilDate(2026, 10, 11),
      distanceKm: 42,
      vehicleId: 'v-1',
      createdAt: DateTime.utc(2026, 10, 11, 9),
    ));
    await SembastDayExtraRepository(database.db)
        .set(DayExtra(date: CivilDate(2026, 10, 5), extraKm: 87));
    await SembastFavoriteTripRepository(database.db).put(FavoriteTrip(
        id: 'f-1', label: 'TEST BACKUP', distanceKm: 24, sortOrder: 0));
    await SembastVacationRepository(database.db).put(VacationPeriod(
        id: 'p-1',
        startDate: CivilDate(2026, 8, 3),
        endDate: CivilDate(2026, 8, 10)));
    await SembastSettingsRepository(database.db)
        .save(AppSettings(displayName: 'Marc', mainVehicleId: 'v-1'));
  }

  BackupContent contentFromSnapshot(BackupSnapshot snapshot) =>
      decodeBackup(encodeBackup(
        exportedAt: DateTime.utc(2026, 10, 11, 14),
        trips: snapshot.trips,
        dayExtras: snapshot.dayExtras,
        favorites: snapshot.favorites,
        vehicles: snapshot.vehicles,
        vacationPeriods: snapshot.vacationPeriods,
        settings: snapshot.settings,
      ));

  test('snapshot : toutes les collections, véhicule archivé inclus,'
      ' rien de dérivé', () async {
    await seedEverything();

    final snapshot = await service.snapshot();

    expect(snapshot.trips.single.id, 't-1');
    expect(snapshot.dayExtras.single.extraKm, 87);
    expect(snapshot.favorites.single.label, 'TEST BACKUP');
    expect(snapshot.vehicles.single.isArchived, isTrue);
    expect(snapshot.vacationPeriods.single.id, 'p-1');
    expect(snapshot.settings.displayName, 'Marc');

    // L'enveloppe ne contient que les 6 sections de données attendues.
    final json = encodeBackup(
      exportedAt: DateTime.utc(2026, 1, 1),
      trips: snapshot.trips,
      dayExtras: snapshot.dayExtras,
      favorites: snapshot.favorites,
      vehicles: snapshot.vehicles,
      vacationPeriods: snapshot.vacationPeriods,
      settings: snapshot.settings,
    );
    expect(json, isNot(contains('totalKm')));
    expect(json, isNot(contains('statistics')));
  });

  test('restore : remplace TOUTES les données, anciennes supprimées, '
      'métadonnées techniques préservées', () async {
    await seedEverything();
    final content = contentFromSnapshot(await service.snapshot());

    // Métadonnée technique locale (hors backup) posée avant restauration.
    final meta = BackupMetaRepository(database.db);
    await meta.setLastExportAt(DateTime.utc(2026, 10, 11, 15));

    // Données « parasites » qui doivent disparaître.
    await SembastTripRepository(database.db).put(Trip(
      id: 'parasite',
      date: CivilDate(2026, 1, 1),
      distanceKm: 999,
      createdAt: DateTime.utc(2026, 1, 1),
    ));
    await SembastFavoriteTripRepository(database.db).put(FavoriteTrip(
        id: 'parasite', label: 'Parasite', distanceKm: 1, sortOrder: 9));

    await service.restore(content);

    final trips = await SembastTripRepository(database.db).getAll();
    expect(trips.map((t) => t.id).toList(), ['t-1']);
    final favorites =
        await SembastFavoriteTripRepository(database.db).getAllOrdered();
    expect(favorites.single.label, 'TEST BACKUP');
    expect(
      (await SembastDayExtraRepository(database.db)
              .getForDate(CivilDate(2026, 10, 5)))
          ?.extraKm,
      87,
    );
    expect(
        (await SembastVacationRepository(database.db).getAll()).single.id,
        'p-1');
    expect(
        (await SembastVehicleRepository(database.db).getById('v-1'))
            ?.isArchived,
        isTrue);
    expect(
        (await SembastSettingsRepository(database.db).get()).displayName,
        'Marc');
    // Le store technique n'est pas concerné par la restauration.
    expect(await meta.lastExportAt(), DateTime.utc(2026, 10, 11, 15));
  });

  test('ROLLBACK : échec en cours de restauration => base intacte',
      () async {
    await seedEverything();
    final content = contentFromSnapshot(await service.snapshot());

    // État courant DIFFÉRENT de la sauvegarde.
    await SembastTripRepository(database.db).delete('t-1');
    await SembastTripRepository(database.db).put(Trip(
      id: 'actuel',
      date: CivilDate(2026, 3, 1),
      distanceKm: 55,
      createdAt: DateTime.utc(2026, 3, 1),
    ));

    await expectLater(
      service.restore(
        content,
        beforeCommitForTest: () async =>
            throw StateError('panne simulée avant commit'),
      ),
      throwsStateError,
    );

    // AUCUN état intermédiaire : la base précédente est intacte.
    final trips = await SembastTripRepository(database.db).getAll();
    expect(trips.single.id, 'actuel');
    expect(trips.single.distanceKm, 55);
    expect(
        await SembastFavoriteTripRepository(database.db).getAllOrdered(),
        hasLength(1)); // TEST BACKUP de seedEverything toujours là
  });
}
