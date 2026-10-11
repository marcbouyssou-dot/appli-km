import 'package:sembast/sembast.dart';

import '../../domain/models/vehicle.dart';
import '../repositories/vehicle_repository.dart';
import 'app_database.dart';
import 'codecs.dart';

class SembastVehicleRepository implements VehicleRepository {
  SembastVehicleRepository(this._db);

  final Database _db;

  @override
  Future<Vehicle?> getById(String id) async {
    final map = await vehiclesStore.record(id).get(_db);
    return map == null ? null : vehicleFromDb(id, map);
  }

  @override
  Future<List<Vehicle>> getAll({bool includeArchived = true}) async {
    final snapshots = await vehiclesStore.find(
      _db,
      finder: Finder(sortOrders: [SortOrder('name')]),
    );
    final vehicles = [for (final s in snapshots) vehicleFromDb(s.key, s.value)];
    return includeArchived
        ? vehicles
        : vehicles.where((v) => !v.isArchived).toList();
  }

  @override
  Future<void> put(Vehicle vehicle) =>
      vehiclesStore.record(vehicle.id).put(_db, vehicleToDb(vehicle));
}
