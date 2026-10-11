import 'package:sembast/sembast.dart';

import '../../domain/models/civil_date.dart';
import '../../domain/models/trip.dart';
import '../repositories/trip_repository.dart';
import 'app_database.dart';
import 'codecs.dart';

class SembastTripRepository implements TripRepository {
  SembastTripRepository(this._db);

  final Database _db;

  @override
  Future<Trip?> getById(String id) async {
    final map = await tripsStore.record(id).get(_db);
    return map == null ? null : tripFromDb(id, map);
  }

  @override
  Future<List<Trip>> getByDate(CivilDate date) async {
    final snapshots = await tripsStore.find(
      _db,
      finder: Finder(
        filter: Filter.equals('date', date.toIso8601()),
        sortOrders: [SortOrder('createdAt')],
      ),
    );
    return [for (final s in snapshots) tripFromDb(s.key, s.value)];
  }

  @override
  Future<List<Trip>> getBetween(CivilDate start, CivilDate end) async {
    final snapshots = await tripsStore.find(
      _db,
      finder: Finder(
        // Le format yyyy-MM-dd rend l'ordre lexicographique chronologique.
        filter: Filter.and([
          Filter.greaterThanOrEquals('date', start.toIso8601()),
          Filter.lessThanOrEquals('date', end.toIso8601()),
        ]),
        sortOrders: [SortOrder('date'), SortOrder('createdAt')],
      ),
    );
    return [for (final s in snapshots) tripFromDb(s.key, s.value)];
  }

  @override
  Future<List<Trip>> getAll() async {
    final snapshots = await tripsStore.find(
      _db,
      finder: Finder(sortOrders: [SortOrder('date'), SortOrder('createdAt')]),
    );
    return [for (final s in snapshots) tripFromDb(s.key, s.value)];
  }

  @override
  Future<void> put(Trip trip) =>
      tripsStore.record(trip.id).put(_db, tripToDb(trip));

  @override
  Future<void> delete(String id) async {
    await tripsStore.record(id).delete(_db);
  }
}
