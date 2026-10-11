import 'package:sembast/sembast.dart';

import '../../domain/models/app_settings.dart';
import '../repositories/settings_repository.dart';
import 'app_database.dart';
import 'codecs.dart';

class SembastSettingsRepository implements SettingsRepository {
  SembastSettingsRepository(this._db);

  final Database _db;

  @override
  Future<AppSettings> get() async {
    final map = await settingsStore.record(settingsRecordKey).get(_db);
    return map == null ? AppSettings() : appSettingsFromDb(map);
  }

  @override
  Future<void> save(AppSettings settings) => settingsStore
      .record(settingsRecordKey)
      .put(_db, appSettingsToDb(settings));
}
