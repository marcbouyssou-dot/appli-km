@TestOn('browser')
library;

// Test navigateur réel : persistance IndexedDB via sembast_web.
// Exécution explicite : flutter test --platform chrome test/web
// (ignoré par la suite VM standard grâce à @TestOn('browser')).

import 'package:flutter_test/flutter_test.dart';
import 'package:mes_km/data/local/app_database.dart';
import 'package:mes_km/data/local/sembast_settings_repository.dart';
import 'package:mes_km/data/local/sembast_trip_repository.dart';
import 'package:mes_km/data/local/web_database.dart';
import 'package:mes_km/domain/models/app_settings.dart';
import 'package:mes_km/domain/models/civil_date.dart';
import 'package:mes_km/domain/models/trip.dart';

void main() {
  test('IndexedDB réel : écriture, fermeture, réouverture, lecture', () async {
    const dbName = 'mes_km_browser_test.db';

    var database = await openMesKmDatabaseWeb(name: dbName);
    expect(database.version, MesKmDatabase.schemaVersion);

    await SembastTripRepository(database.db).put(Trip(
      id: 'bt-1',
      date: CivilDate(2026, 10, 11),
      distanceKm: 42.5,
      origin: 'Maison',
      createdAt: DateTime.utc(2026, 10, 11, 9),
    ));
    await SembastSettingsRepository(database.db)
        .save(AppSettings(displayName: 'Test Navigateur'));
    await database.close();

    // Réouverture : les données doivent avoir survécu dans IndexedDB.
    database = await openMesKmDatabaseWeb(name: dbName);
    final trips = await SembastTripRepository(database.db).getAll();
    expect(trips.single.id, 'bt-1');
    expect(trips.single.distanceKm, 42.5);
    expect(trips.single.origin, 'Maison');

    final settings = await SembastSettingsRepository(database.db).get();
    expect(settings.displayName, 'Test Navigateur');
    await database.close();
  });
}
