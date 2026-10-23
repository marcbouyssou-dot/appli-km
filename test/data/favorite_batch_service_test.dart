import 'package:flutter_test/flutter_test.dart';
import 'package:mes_km/data/local/app_database.dart';
import 'package:mes_km/data/local/codecs.dart';
import 'package:mes_km/data/local/favorite_batch_service.dart';
import 'package:mes_km/domain/models/civil_date.dart';
import 'package:mes_km/domain/models/day_extra.dart';
import 'package:mes_km/domain/models/favorite_trip.dart';
import 'package:mes_km/domain/models/trip.dart';
import 'package:mes_km/domain/models/vacation_period.dart';
import 'package:mes_km/domain/models/vehicle.dart';
import 'package:sembast/sembast_memory.dart';

void main() {
  late MesKmDatabase database;
  late FavoriteBatchService service;
  final today = CivilDate(2026, 10, 22);
  final d1 = CivilDate(2026, 9, 7), d2 = CivilDate(2026, 9, 14);
  final favorite = FavoriteTrip(
    id: 'f',
    label: 'Cabinet → Clinique',
    distanceKm: 12,
    origin: 'Cabinet',
    destination: 'Clinique',
    purpose: 'Tournée',
    vehicleId: 'old',
    sortOrder: 0,
  );
  setUp(() async {
    database = await MesKmDatabase.open(newDatabaseFactoryMemory());
    var id = 0;
    service = FavoriteBatchService(database.db, newId: () => 'new-${id++}');
    await favoriteTripsStore
        .record('f')
        .put(database.db, favoriteTripToDb(favorite));
    for (final v in [
      Vehicle(
        id: 'old',
        name: 'Ancienne voiture',
        category: VehicleCategory.car,
        archivedAt: DateTime(2026, 10, 1),
      ),
      Vehicle(
        id: 'new',
        name: 'Voiture actuelle',
        category: VehicleCategory.car,
      ),
    ]) {
      await vehiclesStore.record(v.id).put(database.db, vehicleToDb(v));
    }
  });
  tearDown(() => database.close());
  Future<FavoriteBatchPlan> plan(
    List<CivilDate> days, {
    String? vehicle = 'old',
    bool confirmed = true,
  }) => service.preview(
    favoriteId: 'f',
    dates: days,
    vehicleId: vehicle,
    today: today,
    vehicleConfirmed: confirmed,
  );
  Future<void> seed(
    CivilDate d, {
    String vehicle = 'old',
    String id = 'existing',
  }) => tripsStore
      .record(id)
      .put(
        database.db,
        tripToDb(
          Trip(
            id: id,
            date: d,
            distanceKm: 12,
            origin: 'Cabinet',
            destination: 'Clinique',
            purpose: 'Tournée',
            vehicleId: vehicle,
            createdAt: DateTime(2026),
          ),
        ),
      );

  test(
    'aperçu sans écriture, dates uniques triées puis création atomique multi-jours',
    () async {
      final p = await plan([d2, d1, d1]);
      expect(p.additions, [d1, d2]);
      expect(await tripsStore.count(database.db), 0);
      expect(await service.apply(p), 2);
      final stored = await tripsStore.find(database.db);
      expect(stored.map((s) => tripFromDb(s.key, s.value).date).toSet(), {
        d1,
        d2,
      });
      expect(stored.every((s) => s.value['vehicleId'] == 'old'), isTrue);
    },
  );
  test('un jour seul et DayExtra inchangé', () async {
    await dayExtrasStore
        .record(d1.toIso8601())
        .put(database.db, dayExtraToDb(DayExtra(date: d1, extraKm: 33)));
    expect(await service.apply(await plan([d1])), 1);
    expect(
      (await dayExtrasStore
          .record(d1.toIso8601())
          .get(database.db))!['extraKm'],
      33,
    );
  });
  test('doublon partiel : une seule nouvelle écriture', () async {
    await seed(d1);
    final p = await plan([d1, d2]);
    expect(p.duplicates, [d1]);
    expect(p.additions, [d2]);
    expect(await service.apply(p), 1);
    expect(await tripsStore.count(database.db), 2);
  });
  test('tous déjà présents : zéro ajout', () async {
    await seed(d1);
    await seed(d2, id: 'second');
    final p = await plan([d1, d2]);
    expect(p.additions, isEmpty);
    expect(p.duplicates, [d1, d2]);
    expect(await service.apply(p), 0);
    expect(await tripsStore.count(database.db), 2);
  });
  test('mêmes caractéristiques mais autre véhicule : pas un doublon', () async {
    await seed(d1, vehicle: 'new');
    expect((await plan([d1])).additions, [d1]);
  });
  test('congés exclus sans modifier la période', () async {
    final vacation = VacationPeriod(id: 'holiday', startDate: d1, endDate: d1);
    await vacationPeriodsStore
        .record(vacation.id)
        .put(database.db, vacationPeriodToDb(vacation));
    final p = await plan([d1, d2]);
    expect(p.vacations, [d1]);
    expect(await service.apply(p), 1);
    expect(
      await vacationPeriodsStore.record('holiday').get(database.db),
      vacationPeriodToDb(vacation),
    );
  });
  test(
    'attribution passée explicite, jamais principal actuel deviné',
    () async {
      await expectLater(plan([d1], confirmed: false), throwsArgumentError);
      await service.apply(await plan([d1]));
      expect(
        (await tripsStore.find(database.db)).single.value['vehicleId'],
        'old',
      );
      await expectLater(
        plan([today]),
        throwsStateError,
        reason: 'archivé avant cette date',
      );
    },
  );
  test(
    'dates futures refusées et absence de véhicule explicite possible',
    () async {
      await expectLater(
        plan([today.addDays(1)], vehicle: null),
        throwsArgumentError,
      );
      final p = await plan([today], vehicle: null, confirmed: false);
      expect(await service.apply(p), 1);
      expect(
        (await tripsStore.find(
          database.db,
        )).single.value.containsKey('vehicleId'),
        isFalse,
      );
    },
  );
  test(
    'concurrence : données modifiées après résumé => reconfirmation, zéro écriture',
    () async {
      final p = await plan([d1, d2]);
      await seed(d1);
      await expectLater(service.apply(p), throwsStateError);
      expect(await tripsStore.count(database.db), 1);
    },
  );
  test('double confirmation ne crée jamais deux lots', () async {
    final p = await plan([d1]);
    await service.apply(p);
    await expectLater(service.apply(p), throwsStateError);
    expect(await tripsStore.count(database.db), 1);
  });
  test(
    'échec de deuxième écriture : rollback complet, aucune moitié de lot',
    () async {
      final failing = FavoriteBatchService(
        database.db,
        newId: () => 'collision',
      );
      await expectLater(failing.apply(await plan([d1, d2])), throwsStateError);
      expect(await tripsStore.count(database.db), 0);
    },
  );
}
