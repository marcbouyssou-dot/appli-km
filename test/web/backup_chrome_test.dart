@TestOn('browser')
library;

// Cycle sauvegarde/restauration sur IndexedDB RÉEL (Chrome).
// Le partage/sélecteur de fichier natif ne peut pas être automatisé en
// headless : il reste couvert par la recette humaine iPhone.

import 'dart:js_interop';
import 'dart:js_interop_unsafe';

import 'package:flutter_test/flutter_test.dart';
import 'package:mes_km/data/backup/backup_codec.dart';
import 'package:mes_km/data/backup/backup_file_gateway.dart';
import 'package:mes_km/data/backup/backup_file_gateway_web.dart';
import 'package:mes_km/data/backup/backup_service.dart';
import 'package:mes_km/data/local/sembast_favorite_trip_repository.dart';
import 'package:mes_km/data/local/sembast_trip_repository.dart';
import 'package:mes_km/data/local/web_database.dart';
import 'package:mes_km/domain/models/civil_date.dart';
import 'package:mes_km/domain/models/favorite_trip.dart';
import 'package:mes_km/domain/models/trip.dart';
import 'package:web/web.dart' as web;

void main() {
  test(
      'fichier utilisateur : nom .kmbackup EXACT, MIME octet-stream '
      '(pas de prévisualisation JSON Safari), contenu JSON importable',
      () async {
    const fileName = 'MesKm-Sauvegarde-2026-10-11.kmbackup';
    final json = encodeBackup(
      exportedAt: DateTime.utc(2026, 10, 11),
      trips: const [],
      dayExtras: const [],
      favorites: const [],
      vehicles: const [],
      vacationPeriods: const [],
      settings: (await (() async {
        final db =
            await openMesKmDatabaseWeb(name: 'mime_test.db');
        final s = (await BackupService(db.db).snapshot()).settings;
        await db.close();
        return s;
      })()),
    );

    final file = WebBackupFileGateway.buildBackupFile(
      fileName: fileName,
      content: json,
    );

    expect(file.name, fileName);
    expect(file.name, endsWith('.kmbackup'));
    expect(file.name, isNot(contains('.kmbackup.json')));
    expect(file.type, 'application/octet-stream',
        reason: 'application/json déclenche la prévisualisation Safari '
            'et l’ajout de .json au nom');

    // Round-trip : le contenu relu reste du JSON de sauvegarde valide,
    // indépendamment du MIME et de l'extension.
    final text = (await file.text().toDart).toDart;
    final content = decodeBackup(text);
    expect(content.trips, isEmpty);
  });

  test(
      'passerelle réelle : saveBackupFile n’échoue JAMAIS, même sans '
      'Web Share API (cas iPhone « canShare undefined »)', () async {
    // Sur Chrome desktop (comme sur certains contextes Safari/PWA),
    // navigator.share / canShare peuvent être absents : l’ancienne
    // implémentation levait « canShare is not a function » ici même.
    final navigator = web.window.navigator;
    final hasShare = navigator.has('share');
    final hasCanShare = navigator.has('canShare');
    // Trace du contexte réel pour le rapport (les deux chemins sont sûrs).
    // ignore: avoid_print
    print('[chrome] navigator.share=$hasShare canShare=$hasCanShare');

    const gateway = WebBackupFileGateway();
    final outcome = await gateway.saveBackupFile(
      fileName: 'MesKm-Sauvegarde-2026-10-11.kmbackup',
      content: '{"schemaVersion": 1}',
    );
    expect(outcome, BackupSaveOutcome.completed);
  });

  test('IndexedDB réel : export -> mutation -> restauration atomique',
      () async {
    final database = await openMesKmDatabaseWeb(name: 'backup_test.db');
    final service = BackupService(database.db);

    // Nettoyage (la base IndexedDB survit entre exécutions de tests).
    await service.restore(decodeBackup(encodeBackup(
      exportedAt: DateTime.utc(2026, 1, 1),
      trips: const [],
      dayExtras: const [],
      favorites: const [],
      vehicles: const [],
      vacationPeriods: const [],
      settings: (await service.snapshot()).settings,
    )));

    await SembastTripRepository(database.db).put(Trip(
      id: 't-1',
      date: CivilDate(2026, 10, 11),
      distanceKm: 42,
      createdAt: DateTime.utc(2026, 10, 11, 9),
    ));
    await SembastFavoriteTripRepository(database.db).put(FavoriteTrip(
        id: 'f-1', label: 'TEST BACKUP', distanceKm: 24, sortOrder: 0));

    // Export.
    final snapshot = await service.snapshot();
    final json = encodeBackup(
      exportedAt: DateTime.now(),
      trips: snapshot.trips,
      dayExtras: snapshot.dayExtras,
      favorites: snapshot.favorites,
      vehicles: snapshot.vehicles,
      vacationPeriods: snapshot.vacationPeriods,
      settings: snapshot.settings,
    );

    // Mutation puis restauration.
    await SembastTripRepository(database.db).delete('t-1');
    await SembastFavoriteTripRepository(database.db).delete('f-1');
    expect(await SembastTripRepository(database.db).getAll(), isEmpty);

    await service.restore(decodeBackup(json));

    expect(
        (await SembastTripRepository(database.db).getAll()).single.distanceKm,
        42);
    expect(
        (await SembastFavoriteTripRepository(database.db).getAllOrdered())
            .single
            .label,
        'TEST BACKUP');

    // Rollback réel : échec avant commit => rien ne bouge.
    await expectLater(
      service.restore(
        decodeBackup(json),
        beforeCommitForTest: () async => throw StateError('panne'),
      ),
      throwsStateError,
    );
    expect(await SembastTripRepository(database.db).getAll(), hasLength(1));

    await database.close();
  });
}
