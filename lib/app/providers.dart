import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/ids.dart';
import '../data/local/app_database.dart';
import '../data/local/sembast_day_extra_repository.dart';
import '../data/local/sembast_favorite_trip_repository.dart';
import '../data/local/sembast_settings_repository.dart';
import '../data/local/sembast_trip_repository.dart';
import '../data/local/sembast_vacation_repository.dart';
import '../data/local/sembast_vehicle_repository.dart';
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

final dayExtraRepositoryProvider = Provider<DayExtraRepository>(
  (ref) => SembastDayExtraRepository(ref.watch(databaseProvider).db),
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

final idGeneratorProvider = Provider<IdGenerator>(
  (ref) => const IdGenerator(),
);

/// Date civile « aujourd'hui », surchargeable en test.
final todayDateProvider = Provider<CivilDate Function()>(
  (ref) => CivilDate.today,
);
