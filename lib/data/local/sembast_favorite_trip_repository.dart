import 'package:sembast/sembast.dart';

import '../../domain/models/favorite_trip.dart';
import '../repositories/favorite_trip_repository.dart';
import 'app_database.dart';
import 'codecs.dart';

class SembastFavoriteTripRepository implements FavoriteTripRepository {
  SembastFavoriteTripRepository(this._db);

  final Database _db;

  @override
  Future<List<FavoriteTrip>> getAllOrdered() async {
    final snapshots = await favoriteTripsStore.find(
      _db,
      finder: Finder(sortOrders: [SortOrder('sortOrder'), SortOrder('label')]),
    );
    return [for (final s in snapshots) favoriteTripFromDb(s.key, s.value)];
  }

  @override
  Future<void> put(FavoriteTrip favorite) =>
      favoriteTripsStore.record(favorite.id).put(_db, favoriteTripToDb(favorite));

  @override
  Future<void> delete(String id) async {
    await favoriteTripsStore.record(id).delete(_db);
  }

  @override
  Future<void> reorder(List<String> orderedIds) {
    // Transaction : l'ordre complet est réécrit atomiquement.
    return _db.transaction((txn) async {
      for (var index = 0; index < orderedIds.length; index++) {
        final record = favoriteTripsStore.record(orderedIds[index]);
        final existing = await record.get(txn);
        if (existing == null) {
          throw ArgumentError(
            'reorder : favori inconnu "${orderedIds[index]}".',
          );
        }
        await record.put(txn, {...existing, 'sortOrder': index});
      }
    });
  }
}
