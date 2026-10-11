import 'package:flutter_test/flutter_test.dart';
import 'package:mes_km/data/local/app_database.dart';
import 'package:mes_km/data/local/sembast_day_extra_repository.dart';
import 'package:mes_km/data/local/sembast_trip_repository.dart';
import 'package:mes_km/domain/models/civil_date.dart';
import 'package:mes_km/domain/models/day_extra.dart';
import 'package:mes_km/domain/models/trip.dart';
import 'package:sembast/sembast_memory.dart';

void main() {
  group('cycle de vie de la base', () {
    test('fermeture puis réouverture : données toujours présentes', () async {
      // La factory mémoire conserve les "fichiers" entre open/close : elle
      // simule le cycle fermeture/réouverture avec le vrai moteur sembast.
      final factory = newDatabaseFactoryMemory();

      var database = await MesKmDatabase.open(factory, name: 'cycle.db');
      await SembastTripRepository(database.db).put(Trip(
        id: 't-1',
        date: CivilDate(2026, 10, 11),
        distanceKm: 42,
        createdAt: DateTime.utc(2026, 10, 11, 9),
      ));
      await database.close();

      database = await MesKmDatabase.open(factory, name: 'cycle.db');
      final trips = await SembastTripRepository(database.db).getAll();
      expect(trips.single.distanceKm, 42);
      expect(database.version, MesKmDatabase.schemaVersion);
      await database.close();
    });

    test('création : version du schéma = 1', () async {
      final database =
          await MesKmDatabase.open(newDatabaseFactoryMemory(), name: 'v.db');
      expect(database.version, 1);
      await database.close();
    });

    test('schéma plus récent que l’application : ouverture refusée',
        () async {
      final factory = newDatabaseFactoryMemory();

      // Simule une base créée par une future version (schéma v2).
      final futureDb = await factory.openDatabase('future.db', version: 2);
      await futureDb.close();

      await expectLater(
        MesKmDatabase.open(factory, name: 'future.db'),
        throwsStateError,
      );
    });

    test('isolation entre stores : mêmes clés, collections distinctes',
        () async {
      final database = await MesKmDatabase.open(
        newDatabaseFactoryMemory(),
        name: 'iso.db',
      );
      final day = CivilDate(2026, 10, 11);

      // 'day_extras' utilise la date comme clé ; les autres stores ne
      // doivent pas voir ces enregistrements, et réciproquement.
      await SembastDayExtraRepository(database.db)
          .set(DayExtra(date: day, extraKm: 5));
      await SembastTripRepository(database.db).put(Trip(
        id: '2026-10-11', // clé identique à celle du DayExtra, exprès
        date: day,
        distanceKm: 10,
        createdAt: DateTime.utc(2026, 10, 11),
      ));

      expect(await SembastTripRepository(database.db).getAll(), hasLength(1));
      expect(
        await SembastDayExtraRepository(database.db).getAll(),
        hasLength(1),
      );

      await SembastTripRepository(database.db).delete('2026-10-11');
      expect(
        (await SembastDayExtraRepository(database.db).getForDate(day))?.extraKm,
        5,
      );
      await database.close();
    });

    test('enregistrement corrompu : erreur explicite à la lecture', () async {
      final database = await MesKmDatabase.open(
        newDatabaseFactoryMemory(),
        name: 'bad.db',
      );

      // Écrit une map invalide directement dans le store (hors repository).
      await tripsStore
          .record('bad')
          .put(database.db, {'date': 'pas-une-date', 'distanceKm': 10.0});

      await expectLater(
        SembastTripRepository(database.db).getAll(),
        throwsFormatException,
      );
      await database.close();
    });
  });
}
