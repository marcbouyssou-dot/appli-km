import 'package:sembast/sembast.dart';

import '../../domain/models/civil_date.dart';
import '../../domain/models/day_extra.dart';
import '../repositories/day_extra_repository.dart';
import 'app_database.dart';
import 'codecs.dart';

class SembastDayExtraRepository implements DayExtraRepository {
  SembastDayExtraRepository(this._db);

  final Database _db;

  @override
  Future<DayExtra?> getForDate(CivilDate date) async {
    final key = date.toIso8601();
    final map = await dayExtrasStore.record(key).get(_db);
    return map == null ? null : dayExtraFromDb(key, map);
  }

  @override
  Future<List<DayExtra>> getBetween(CivilDate start, CivilDate end) async {
    final snapshots = await dayExtrasStore.find(
      _db,
      finder: Finder(
        filter: Filter.and([
          Filter.greaterThanOrEquals(Field.key, start.toIso8601()),
          Filter.lessThanOrEquals(Field.key, end.toIso8601()),
        ]),
        sortOrders: [SortOrder(Field.key)],
      ),
    );
    return [for (final s in snapshots) dayExtraFromDb(s.key, s.value)];
  }

  @override
  Future<List<DayExtra>> getAll() async {
    final snapshots = await dayExtrasStore.find(
      _db,
      finder: Finder(sortOrders: [SortOrder(Field.key)]),
    );
    return [for (final s in snapshots) dayExtraFromDb(s.key, s.value)];
  }

  @override
  Future<void> set(DayExtra extra) async {
    final record = dayExtrasStore.record(extra.date.toIso8601());
    if (extra.isNone) {
      // 0 = absence logique : on ne stocke pas d'enregistrement à zéro.
      await record.delete(_db);
    } else {
      await record.put(_db, dayExtraToDb(extra));
    }
  }

  @override
  Future<void> deleteForDate(CivilDate date) async {
    await dayExtrasStore.record(date.toIso8601()).delete(_db);
  }
}
