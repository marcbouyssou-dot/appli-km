import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:mes_km/data/backup/backup_codec.dart';
import 'package:mes_km/data/backup/backup_service.dart';
import 'package:mes_km/data/local/app_database.dart';
import 'package:mes_km/data/local/codecs.dart';
import 'package:mes_km/data/local/sembast_settings_repository.dart';
import 'package:mes_km/domain/models/accountant_contact.dart';
import 'package:mes_km/domain/models/app_settings.dart';
import 'package:sembast/sembast_memory.dart';

void main() {
  AccountantContact cabinet([String name = 'Cabinet Équilibre']) =>
      AccountantContact(
        name: name,
        contact: 'Élodie Noël',
        address: '12 rue des Écoles',
        addressExtra: 'Bâtiment B',
        postalCode: '19700',
        city: 'Seilhac',
        phone: '+33 (0)5 55 00 00 00',
        email: 'contact@example.fr',
      );
  String backup(AppSettings settings) => encodeBackup(
    exportedAt: DateTime(2026),
    trips: [],
    dayExtras: [],
    favorites: [],
    vehicles: [],
    vacationPeriods: [],
    settings: settings,
  );

  test('cabinet complet : codec sans perte, formats téléphone libres', () {
    final a = cabinet();
    expect(
      accountantToDb(accountantFromDb(accountantToDb(a))),
      accountantToDb(a),
    );
    expect(() => cabinet(' '), throwsArgumentError);
    expect(AccountantContact.validEmail('contact+km@example.fr'), isTrue);
    expect(AccountantContact.validEmail('pas un email'), isFalse);
  });
  test(
    'ancienne base v1 : ouverture additive, création/modification/suppression et réouverture',
    () async {
      final factory = newDatabaseFactoryMemory();
      final legacy = await factory.openDatabase('legacy', version: 1);
      await settingsStore.record(settingsRecordKey).put(legacy, {
        'displayName': 'Profil existant',
        'themePreference': 'dark',
      });
      await legacy.close();
      var db = await MesKmDatabase.open(factory, name: 'legacy');
      var repo = SembastSettingsRepository(db.db);
      final old = await repo.get();
      expect(old.accountant, isNull);
      expect(old.displayName, 'Profil existant');
      await repo.save(old.copyWith(accountant: cabinet()));
      await db.close();
      db = await MesKmDatabase.open(factory, name: 'legacy');
      repo = SembastSettingsRepository(db.db);
      expect((await repo.get()).accountant!.city, 'Seilhac');
      await repo.save(
        (await repo.get()).copyWith(accountant: cabinet('Nouveau cabinet')),
      );
      expect((await repo.get()).accountant!.name, 'Nouveau cabinet');
      await repo.save((await repo.get()).copyWith(clearAccountant: true));
      expect((await repo.get()).accountant, isNull);
      expect((await repo.get()).displayName, 'Profil existant');
      await db.close();
    },
  );
  test(
    'backup v4 : cabinet complet exporté et restauré atomiquement',
    () async {
      final raw = backup(
        AppSettings(displayName: 'Marc', accountant: cabinet()),
      );
      final content = decodeBackup(raw);
      expect(content.settings.accountant!.contact, 'Élodie Noël');
      final db = await MesKmDatabase.open(newDatabaseFactoryMemory());
      addTearDown(db.close);
      await BackupService(db.db).restore(content);
      expect(
        accountantToDb(
          (await SembastSettingsRepository(db.db).get()).accountant!,
        ),
        accountantToDb(cabinet()),
      );
    },
  );
  test(
    'anciennes sauvegardes v1/v2/v3 sans cabinet restaurables sans valeur inventée',
    () {
      for (final version in [1, 2, 3]) {
        final map =
            jsonDecode(backup(AppSettings(displayName: 'Ancien profil')))
                as Map<String, dynamic>;
        map['schemaVersion'] = version;
        final decoded = decodeBackup(jsonEncode(map));
        expect(decoded.settings.accountant, isNull);
        expect(decoded.settings.displayName, 'Ancien profil');
      }
    },
  );
  test('cabinet corrompu dans backup : refus avant toute restauration', () {
    final map =
        jsonDecode(backup(AppSettings(accountant: cabinet())))
            as Map<String, dynamic>;
    map['data']['settings']['accountant']['name'] = '';
    expect(
      () => decodeBackup(jsonEncode(map)),
      throwsA(isA<BackupFormatException>()),
    );
  });
}
