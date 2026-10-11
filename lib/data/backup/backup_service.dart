import 'package:flutter/foundation.dart';
import 'package:sembast/sembast.dart';

import '../../domain/models/app_settings.dart';
import '../../domain/models/day_extra.dart';
import '../../domain/models/favorite_trip.dart';
import '../../domain/models/trip.dart';
import '../../domain/models/vacation_period.dart';
import '../../domain/models/vehicle.dart';
import '../local/app_database.dart';
import '../local/codecs.dart';
import 'backup_codec.dart';

/// Instantané cohérent de toutes les données métier.
class BackupSnapshot {
  BackupSnapshot({
    required this.trips,
    required this.dayExtras,
    required this.favorites,
    required this.vehicles,
    required this.vacationPeriods,
    required this.settings,
  });

  final List<Trip> trips;
  final List<DayExtra> dayExtras;
  final List<FavoriteTrip> favorites;
  final List<Vehicle> vehicles;
  final List<VacationPeriod> vacationPeriods;
  final AppSettings settings;
}

/// Export (snapshot cohérent) et restauration ATOMIQUE de la base.
class BackupService {
  BackupService(this._db);

  final Database _db;

  /// Lit toutes les collections dans UNE transaction : impossible d'obtenir
  /// les trajets à un instant et les extras à un autre.
  Future<BackupSnapshot> snapshot() {
    return _db.transaction((txn) async {
      final trips = await tripsStore.find(txn);
      final extras = await dayExtrasStore.find(txn);
      final favorites = await favoriteTripsStore.find(txn);
      final vehicles = await vehiclesStore.find(txn);
      final vacations = await vacationPeriodsStore.find(txn);
      final settingsMap =
          await settingsStore.record(settingsRecordKey).get(txn);

      return BackupSnapshot(
        trips: [for (final s in trips) tripFromDb(s.key, s.value)],
        dayExtras: [for (final s in extras) dayExtraFromDb(s.key, s.value)],
        favorites: [
          for (final s in favorites) favoriteTripFromDb(s.key, s.value)
        ],
        vehicles: [for (final s in vehicles) vehicleFromDb(s.key, s.value)],
        vacationPeriods: [
          for (final s in vacations) vacationPeriodFromDb(s.key, s.value)
        ],
        settings:
            settingsMap == null ? AppSettings() : appSettingsFromDb(settingsMap),
      );
    });
  }

  /// Remplace TOUTES les données métier par celles de [content], dans UNE
  /// transaction sembast : la moindre erreur annule tout, la base précédente
  /// reste intacte, aucun état intermédiaire n'est observable.
  ///
  /// Le store `settings` n'est pas vidé en bloc : seul l'enregistrement
  /// applicatif est remplacé — les métadonnées techniques (ex. date du
  /// dernier export) sont préservées.
  Future<void> restore(
    BackupContent content, {
    @visibleForTesting Future<void> Function()? beforeCommitForTest,
  }) {
    return _db.transaction((txn) async {
      await tripsStore.delete(txn);
      await dayExtrasStore.delete(txn);
      await favoriteTripsStore.delete(txn);
      await vehiclesStore.delete(txn);
      await vacationPeriodsStore.delete(txn);

      for (final trip in content.trips) {
        await tripsStore.record(trip.id).put(txn, tripToDb(trip));
      }
      for (final extra in content.dayExtras) {
        await dayExtrasStore
            .record(extra.date.toIso8601())
            .put(txn, dayExtraToDb(extra));
      }
      for (final favorite in content.favorites) {
        await favoriteTripsStore
            .record(favorite.id)
            .put(txn, favoriteTripToDb(favorite));
      }
      for (final vehicle in content.vehicles) {
        await vehiclesStore.record(vehicle.id).put(txn, vehicleToDb(vehicle));
      }
      for (final period in content.vacationPeriods) {
        await vacationPeriodsStore
            .record(period.id)
            .put(txn, vacationPeriodToDb(period));
      }
      await settingsStore
          .record(settingsRecordKey)
          .put(txn, appSettingsToDb(content.settings));

      if (beforeCommitForTest != null) {
        await beforeCommitForTest();
      }
    });
  }
}

/// Métadonnées techniques locales de sauvegarde (hors enveloppe exportée) :
/// uniquement la dernière génération RÉUSSIE d'un export par Mes Km —
/// jamais une prétention sur ce qui existe dans Fichiers/iCloud.
class BackupMetaRepository {
  BackupMetaRepository(this._db);

  static const _key = 'backup_meta';

  final Database _db;

  Future<DateTime?> lastExportAt() async {
    final map = await settingsStore.record(_key).get(_db);
    final raw = map?['lastExportAt'];
    return raw is String ? DateTime.tryParse(raw) : null;
  }

  Future<void> setLastExportAt(DateTime at) => settingsStore
      .record(_key)
      .put(_db, {'lastExportAt': at.toUtc().toIso8601String()});
}
