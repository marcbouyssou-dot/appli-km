import 'package:sembast/sembast.dart';
import '../../domain/models/civil_date.dart';
import 'trip_batch_service.dart';

/// Adaptateur de compatibilité 005 : toutes les règles résident dans le moteur commun.
typedef FavoriteBatchPlan = TripBatchPlan;

class FavoriteBatchService {
  FavoriteBatchService(Database db, {required String Function() newId})
    : _engine = TripBatchService(db, newId: newId);
  FavoriteBatchService.using(this._engine);
  final TripBatchService _engine;
  Future<FavoriteBatchPlan> preview({
    required String favoriteId,
    required Iterable<CivilDate> dates,
    required String? vehicleId,
    required CivilDate today,
    required bool vehicleConfirmed,
  }) => _engine.preview(
    source: TripBatchSource.favorite(favoriteId),
    dates: dates,
    vehicleId: vehicleId,
    today: today,
    vehicleConfirmed: vehicleConfirmed,
  );
  Future<int> apply(FavoriteBatchPlan approved) => _engine.apply(approved);
}
