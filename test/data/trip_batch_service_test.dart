import 'package:flutter_test/flutter_test.dart';
import 'package:mes_km/data/backup/backup_codec.dart';
import 'package:mes_km/data/backup/backup_service.dart';
import 'package:mes_km/data/local/app_database.dart';
import 'package:mes_km/data/local/codecs.dart';
import 'package:mes_km/data/local/trip_batch_service.dart';
import 'package:mes_km/domain/logic/day_total.dart';
import 'package:mes_km/domain/models/civil_date.dart';
import 'package:mes_km/domain/models/day_extra.dart';
import 'package:mes_km/domain/models/trip.dart';
import 'package:mes_km/domain/models/trip_template.dart';
import 'package:mes_km/domain/models/vacation_period.dart';
import 'package:mes_km/domain/models/vehicle.dart';
import 'package:sembast/sembast_memory.dart';

void main() {
  late MesKmDatabase db;
  late TripBatchService engine;
  final today = CivilDate(2026, 10, 23),
      first = CivilDate(2026, 9, 7),
      second = CivilDate(2026, 9, 14);
  final source = Trip(
    id: 'source',
    date: CivilDate(2026, 9, 1),
    distanceKm: 70,
    isRoundTrip: true,
    origin: 'Cabinet',
    destination: 'Clinique',
    purpose: 'Tournée',
    vehicleId: 'old',
    createdAt: DateTime.utc(2026, 9, 1, 8),
  );
  final draft = TripTemplate(
    distanceKm: 70,
    isRoundTrip: true,
    origin: 'Cabinet',
    destination: 'Clinique',
    purpose: 'Tournée',
    vehicleId: 'old',
  );
  final copy = const TripBatchSource.existingTrip('source');
  setUp(() async {
    db = await MesKmDatabase.open(newDatabaseFactoryMemory());
    var id = 0;
    engine = TripBatchService(db.db, newId: () => 'copy-${id++}');
    await tripsStore.record(source.id).put(db.db, tripToDb(source));
    for (final v in [
      Vehicle(
        id: 'old',
        name: 'Voiture historique',
        category: VehicleCategory.car,
        archivedAt: DateTime(2026, 10, 1),
      ),
      Vehicle(
        id: 'current',
        name: 'Principal actuel',
        category: VehicleCategory.car,
      ),
    ]) {
      await vehiclesStore.record(v.id).put(db.db, vehicleToDb(v));
    }
    await settingsStore.record(settingsRecordKey).put(db.db, {
      'mainVehicleId': 'current',
    });
  });
  tearDown(() => db.close());
  Future<TripBatchPlan> plan(
    TripBatchSource from,
    List<CivilDate> days, {
    String? vehicle = 'old',
    bool confirmed = true,
  }) => engine.preview(
    source: from,
    dates: days,
    vehicleId: vehicle,
    today: today,
    vehicleConfirmed: confirmed,
  );
  Future<List<Trip>> all() async => [
    for (final s in await tripsStore.find(db.db)) tripFromDb(s.key, s.value),
  ];
  Future<void> put(Trip t) => tripsStore.record(t.id).put(db.db, tripToDb(t));

  test(
    'saisie multi-jours : aperçu sans ajout initial ni favori puis seules dates choisies',
    () async {
      final p = await plan(TripBatchSource.draft(draft), [
        second,
        first,
        first,
      ]);
      expect(await tripsStore.count(db.db), 1);
      expect(await favoriteTripsStore.count(db.db), 0);
      expect(p.additions, [first, second]);
      expect(await engine.apply(p), 2);
      expect(
        (await all()).where((t) => t.id != 'source').map((t) => t.date).toSet(),
        {first, second},
      );
      expect((await all()).where((t) => t.date == today), isEmpty);
    },
  );
  test(
    'saisie sur aujourd’hui sans véhicule autorisée, sans confirmation passée',
    () async {
      final p = await plan(
        TripBatchSource.draft(draft),
        [today],
        vehicle: null,
        confirmed: false,
      );
      await engine.apply(p);
      expect(
        (await all()).lastWhere((t) => t.id != 'source').vehicleId,
        isNull,
      );
    },
  );
  test('mélange passé et aujourd’hui avec véhicule choisi', () async {
    final p = await plan(TripBatchSource.draft(draft), [
      first,
      today,
    ], vehicle: 'current');
    await engine.apply(p);
    expect(
      (await all())
          .where((t) => t.id != 'source')
          .every((t) => t.vehicleId == 'current'),
      isTrue,
    );
  });
  test('dates futures, sélection vide et passé non confirmé refusés', () async {
    await expectLater(plan(copy, [today.addDays(1)]), throwsArgumentError);
    await expectLater(plan(copy, []), throwsArgumentError);
    await expectLater(
      plan(copy, [first], confirmed: false),
      throwsArgumentError,
    );
    expect(await tripsStore.count(db.db), 1);
  });
  test(
    'report : tous les champs métier, A/R non doublé, IDs/dates/métadonnées propres',
    () async {
      final original = await tripsStore.record('source').get(db.db);
      await engine.apply(await plan(copy, [first, second]));
      final added = (await all()).where((t) => t.id != 'source').toList();
      expect(added.map((t) => t.id).toSet().length, 2);
      for (final t in added) {
        expect(t.distanceKm, 70);
        expect(t.isRoundTrip, isTrue);
        expect(t.origin, 'Cabinet');
        expect(t.destination, 'Clinique');
        expect(t.purpose, 'Tournée');
        expect(t.vehicleId, 'old');
        expect(t.createdAt, isNot(source.createdAt));
      }
      expect(await tripsStore.record('source').get(db.db), original);
    },
  );
  test(
    'date source exclue même après choix explicite d’un autre véhicule',
    () async {
      final p = await plan(copy, [source.date, first], vehicle: 'current');
      expect(p.duplicates, [source.date]);
      expect(p.additions, [first]);
      await engine.apply(p);
      expect((await all()).where((t) => t.date == source.date).length, 1);
    },
  );
  test(
    'doublon partiel normalisé puis doublon total, aucune copie silencieuse',
    () async {
      await put(
        Trip(
          id: 'existing',
          date: first,
          distanceKm: 70,
          isRoundTrip: true,
          origin: '  CABINET  ',
          destination: 'clinique',
          purpose: 'tournée',
          vehicleId: 'old',
          createdAt: DateTime.utc(2026),
        ),
      );
      final p = await plan(copy, [first, second]);
      expect(p.duplicates, [first]);
      expect(await engine.apply(p), 1);
      final full = await plan(copy, [first, second]);
      expect(full.additions, isEmpty);
      expect(await engine.apply(full), 0);
      expect(await tripsStore.count(db.db), 3);
    },
  );
  test(
    'véhicule ou type aller-retour différent ne constitue pas un doublon',
    () async {
      await put(
        Trip(
          id: 'other',
          date: first,
          distanceKm: 70,
          isRoundTrip: false,
          origin: 'Cabinet',
          destination: 'Clinique',
          purpose: 'Tournée',
          vehicleId: 'old',
          createdAt: DateTime.utc(2026),
        ),
      );
      expect((await plan(copy, [first])).additions, [first]);
      await put(sourceToDate(first, 'other', vehicle: 'current'));
      expect((await plan(copy, [first])).additions, [first]);
    },
  );
  test('historique préservé malgré un principal actuel différent', () async {
    await engine.apply(await plan(copy, [first]));
    expect((await all()).singleWhere((t) => t.id != 'source').vehicleId, 'old');
    expect(
      (await settingsStore
          .record(settingsRecordKey)
          .get(db.db))!['mainVehicleId'],
      'current',
    );
  });
  test(
    'source sans véhicule : null explicite conservé, aucun principal inféré',
    () async {
      await put(sourceToDate(source.date, 'source', vehicle: null));
      await engine.apply(await plan(copy, [first], vehicle: null));
      expect((await all()).every((t) => t.vehicleId == null), isTrue);
    },
  );
  test(
    'véhicule archivé seulement avant sa date ; véhicule disparu refusé',
    () async {
      await expectLater(plan(copy, [today]), throwsStateError);
      await expectLater(
        plan(copy, [first], vehicle: 'missing'),
        throwsStateError,
      );
      expect(await engine.apply(await plan(copy, [first])), 1);
    },
  );
  test('congé exclu et période conservée à l’identique', () async {
    final v = vacationPeriodToDb(
      VacationPeriod(id: 'holiday', startDate: first, endDate: first),
    );
    await vacationPeriodsStore.record('holiday').put(db.db, v);
    final p = await plan(copy, [first, second]);
    expect(p.vacations, [first]);
    await engine.apply(p);
    expect(await vacationPeriodsStore.record('holiday').get(db.db), v);
    expect((await all()).where((t) => t.date == first), isEmpty);
  });
  test(
    'DayExtra, note, attribution, trajets existants préservés ; total strictement additif',
    () async {
      final extra = DayExtra(
        date: first,
        extraKm: 33,
        vehicleId: 'old',
        note: 'Total saisi conservé',
      );
      final extraMap = dayExtraToDb(extra);
      await dayExtrasStore.record(first.toIso8601()).put(db.db, extraMap);
      await put(
        Trip(
          id: 'other',
          date: first,
          distanceKm: 12,
          createdAt: DateTime.utc(2026),
        ),
      );
      final before = await tripsStore.record('other').get(db.db);
      await engine.apply(await plan(copy, [first]));
      expect(
        await dayExtrasStore.record(first.toIso8601()).get(db.db),
        extraMap,
      );
      expect(await tripsStore.record('other').get(db.db), before);
      expect(
        dayTotalKm((await all()).where((t) => t.date == first), extra),
        115,
      );
    },
  );
  test('échec à la deuxième écriture : rollback du lot entier', () async {
    final p = await plan(copy, [first, second]);
    final failing = TripBatchService(db.db, newId: () => 'collision');
    await expectLater(failing.apply(p), throwsStateError);
    expect(await tripsStore.count(db.db), 1);
    expect(await tripsStore.record('source').get(db.db), tripToDb(source));
  });
  test(
    'source modifiée entre aperçu et confirmation : reconfirmation obligatoire',
    () async {
      final p = await plan(copy, [first]);
      await put(
        Trip(
          id: 'source',
          date: source.date,
          distanceKm: 71,
          createdAt: source.createdAt,
        ),
      );
      await expectLater(engine.apply(p), throwsStateError);
      expect(await tripsStore.count(db.db), 1);
    },
  );
  test('source supprimée après aperçu : aucune copie créée', () async {
    final p = await plan(copy, [first]);
    await tripsStore.record('source').delete(db.db);
    await expectLater(engine.apply(p), throwsStateError);
    expect(await tripsStore.count(db.db), 0);
  });
  test(
    'doublon créé après aperçu : arrêt atomique, double confirmation impossible',
    () async {
      final p = await plan(copy, [first, second]);
      await put(sourceToDate(first, 'concurrent'));
      await expectLater(engine.apply(p), throwsStateError);
      expect(await tripsStore.count(db.db), 2);
      final fresh = await plan(copy, [first, second]);
      await engine.apply(fresh);
      await expectLater(engine.apply(fresh), throwsStateError);
      expect(await tripsStore.count(db.db), 3);
    },
  );
  test(
    'congé ajouté entre aperçu et validation : aucune écriture du lot',
    () async {
      final p = await plan(copy, [first, second]);
      await vacationPeriodsStore
          .record('late')
          .put(
            db.db,
            vacationPeriodToDb(
              VacationPeriod(id: 'late', startDate: first, endDate: first),
            ),
          );
      await expectLater(engine.apply(p), throwsStateError);
      expect(await tripsStore.count(db.db), 1);
    },
  );
  test(
    'modifier puis supprimer une copie ne touche ni la source ni les autres copies',
    () async {
      await engine.apply(await plan(copy, [first, second]));
      final copies = (await all()).where((t) => t.id != 'source').toList();
      final untouched = await tripsStore.record(copies[1].id).get(db.db);
      await put(
        Trip(
          id: copies[0].id,
          date: first,
          distanceKm: 2,
          createdAt: copies[0].createdAt,
        ),
      );
      await tripsStore.record(copies[0].id).delete(db.db);
      expect(await tripsStore.record(copies[1].id).get(db.db), untouched);
      expect(await tripsStore.record('source').get(db.db), tripToDb(source));
    },
  );
  test(
    'copies ordinaires dans backup/restore v4, sans nouvelle migration',
    () async {
      await engine.apply(await plan(copy, [first, second]));
      final backup = BackupService(db.db);
      final s = await backup.snapshot();
      final encoded = encodeBackup(
        exportedAt: DateTime.utc(2026, 10, 23),
        trips: s.trips,
        dayExtras: s.dayExtras,
        favorites: s.favorites,
        vehicles: s.vehicles,
        vacationPeriods: s.vacationPeriods,
        settings: s.settings,
      );
      final other = await MesKmDatabase.open(newDatabaseFactoryMemory());
      try {
        await BackupService(other.db).restore(decodeBackup(encoded));
        final restored = await BackupService(other.db).snapshot();
        expect(restored.trips.length, 3);
        expect(restored.favorites, isEmpty);
        expect(
          restored.trips.map((t) => tripToDb(t)),
          s.trips.map((t) => tripToDb(t)),
        );
        expect(backupSchemaVersion, 4);
        expect(other.version, 1);
      } finally {
        await other.close();
      }
    },
  );
}

Trip sourceToDate(CivilDate d, String id, {String? vehicle = 'old'}) => Trip(
  id: id,
  date: d,
  distanceKm: 70,
  isRoundTrip: true,
  origin: 'Cabinet',
  destination: 'Clinique',
  purpose: 'Tournée',
  vehicleId: vehicle,
  createdAt: DateTime.utc(2026, 9, 1, 8),
);
