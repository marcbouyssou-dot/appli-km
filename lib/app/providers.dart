import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/backup/backup_file_gateway.dart';
import '../data/backup/backup_service.dart';
import '../data/fiscal/fiscal_reference_store.dart';
import '../data/backup/platform_backup_file_gateway.dart';
import '../data/ids.dart';
import '../data/local/app_database.dart';
import '../data/local/favorite_batch_service.dart';
import '../data/local/trip_batch_service.dart';
import '../data/network/osm_route_service.dart';
import '../data/network/route_distance_service.dart';
import '../data/local/sembast_day_clear_repository.dart';
import '../data/local/sembast_day_extra_repository.dart';
import '../data/local/sembast_favorite_trip_repository.dart';
import '../data/local/sembast_settings_repository.dart';
import '../data/local/sembast_trip_repository.dart';
import '../data/local/sembast_vacation_repository.dart';
import '../data/local/sembast_vehicle_repository.dart';
import '../data/repositories/day_clear_repository.dart';
import '../data/repositories/day_extra_repository.dart';
import '../data/repositories/favorite_trip_repository.dart';
import '../data/repositories/settings_repository.dart';
import '../data/repositories/trip_repository.dart';
import '../data/repositories/vacation_repository.dart';
import '../data/repositories/vehicle_repository.dart';
import '../domain/models/civil_date.dart';

/// Base locale, fournie par le bootstrap (main) via un override :
/// l'UI et les contrôleurs ne savent pas comment elle a été ouverte.
final databaseProvider = Provider<MesKmDatabase>(
  (ref) => throw UnimplementedError(
    'databaseProvider doit être surchargé au démarrage de l’application.',
  ),
);

final tripRepositoryProvider = Provider<TripRepository>(
  (ref) => SembastTripRepository(ref.watch(databaseProvider).db),
);

final tripBatchServiceProvider = Provider<TripBatchService>(
  (ref) => TripBatchService(
    ref.watch(databaseProvider).db,
    newId: ref.watch(idGeneratorProvider).newId,
  ),
);
final favoriteBatchServiceProvider = Provider<FavoriteBatchService>(
  (ref) => FavoriteBatchService.using(ref.watch(tripBatchServiceProvider)),
);

final dayExtraRepositoryProvider = Provider<DayExtraRepository>(
  (ref) => SembastDayExtraRepository(ref.watch(databaseProvider).db),
);

final dayClearRepositoryProvider = Provider<DayClearRepository>(
  (ref) => SembastDayClearRepository(ref.watch(databaseProvider).db),
);

final favoriteTripRepositoryProvider = Provider<FavoriteTripRepository>(
  (ref) => SembastFavoriteTripRepository(ref.watch(databaseProvider).db),
);

final vehicleRepositoryProvider = Provider<VehicleRepository>(
  (ref) => SembastVehicleRepository(ref.watch(databaseProvider).db),
);

final vacationRepositoryProvider = Provider<VacationRepository>(
  (ref) => SembastVacationRepository(ref.watch(databaseProvider).db),
);

final settingsRepositoryProvider = Provider<SettingsRepository>(
  (ref) => SembastSettingsRepository(ref.watch(databaseProvider).db),
);

final idGeneratorProvider = Provider<IdGenerator>((ref) => const IdGenerator());

final backupServiceProvider = Provider<BackupService>(
  (ref) => BackupService(ref.watch(databaseProvider).db),
);

final backupMetaRepositoryProvider = Provider<BackupMetaRepository>(
  (ref) => BackupMetaRepository(ref.watch(databaseProvider).db),
);

final backupFileGatewayProvider = Provider<BackupFileGateway>(
  (ref) => createBackupFileGateway(),
);

/// Calcul d'itinéraire : CONFORT optionnel, invoqué uniquement sur action
/// explicite de l'utilisateur — jamais en arrière-plan.
final routeDistanceServiceProvider = Provider<RouteDistanceService>(
  (ref) => OsmRouteService(),
);

/// Référentiels fiscaux embarqués (assets locaux, jamais téléchargés).
/// Chargés UNE fois au bootstrap (en parallèle de la base) et injectés en
/// valeur synchrone — comme [databaseProvider]. Les tests surchargent avec
/// des fixtures ; sans surcharge : magasin vide (aucun barème appliqué).
final fiscalReferenceStoreProvider = Provider<FiscalReferenceStore>(
  (ref) => FiscalReferenceStore(const []),
);

/// Date civile « aujourd'hui », surchargeable en test.
final todayDateProvider = Provider<CivilDate Function()>(
  (ref) => CivilDate.today,
);

/// Version des données kilométriques : incrémentée après chaque mutation
/// d'une journée, pour que les vues agrégées (calendrier…) se rechargent.
class DayDataVersion extends Notifier<int> {
  @override
  int build() => 0;

  void bump() => state++;
}

final dayDataVersionProvider = NotifierProvider<DayDataVersion, int>(
  DayDataVersion.new,
);
