import 'package:sembast/sembast.dart';

import '../../domain/models/civil_date.dart';
import '../repositories/day_clear_repository.dart';
import 'app_database.dart';

class SembastDayClearRepository implements DayClearRepository {
  SembastDayClearRepository(this._db);

  final Database _db;

  @override
  Future<void> clearDay(CivilDate date) {
    final iso = date.toIso8601();
    // Une transaction sembast couvre les deux stores de la même base :
    // la suppression trajets + extra est tout-ou-rien.
    return _db.transaction((txn) async {
      await tripsStore.delete(
        txn,
        finder: Finder(filter: Filter.equals('date', iso)),
      );
      await dayExtrasStore.record(iso).delete(txn);
    });
  }
}
