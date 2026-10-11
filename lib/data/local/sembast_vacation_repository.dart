import 'package:sembast/sembast.dart';

import '../../domain/models/vacation_period.dart';
import '../repositories/vacation_repository.dart';
import 'app_database.dart';
import 'codecs.dart';

class SembastVacationRepository implements VacationRepository {
  SembastVacationRepository(this._db);

  final Database _db;

  @override
  Future<List<VacationPeriod>> getAll() async {
    final snapshots = await vacationPeriodsStore.find(
      _db,
      finder: Finder(sortOrders: [SortOrder('startDate')]),
    );
    return [for (final s in snapshots) vacationPeriodFromDb(s.key, s.value)];
  }

  @override
  Future<void> put(VacationPeriod period) => vacationPeriodsStore
      .record(period.id)
      .put(_db, vacationPeriodToDb(period));

  @override
  Future<void> delete(String id) async {
    await vacationPeriodsStore.record(id).delete(_db);
  }

  @override
  Future<void> replaceAll(List<VacationPeriod> periods) {
    // Transaction : tout ou rien (résultat de fusion, effacement global…).
    return _db.transaction((txn) async {
      await vacationPeriodsStore.delete(txn);
      for (final period in periods) {
        await vacationPeriodsStore
            .record(period.id)
            .put(txn, vacationPeriodToDb(period));
      }
    });
  }
}
