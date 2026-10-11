import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mes_km/app/providers.dart';
import 'package:mes_km/data/local/app_database.dart';
import 'package:mes_km/data/local/sembast_day_extra_repository.dart';
import 'package:mes_km/data/local/sembast_trip_repository.dart';
import 'package:mes_km/domain/models/civil_date.dart';
import 'package:mes_km/domain/models/favorite_trip.dart';
import 'package:mes_km/domain/models/vehicle.dart';
import 'package:mes_km/features/day/day_controller.dart';
import 'package:mes_km/features/vehicles/vehicles_controller.dart';
import 'package:sembast/sembast_memory.dart' hide Finder;

/// ATTRIBUTION FIGÉE : changer le véhicule principal ne réattribue jamais
/// les kilomètres historiques.
void main() {
  final day = CivilDate(2026, 10, 11);
  late MesKmDatabase database;
  late ProviderContainer container;

  setUp(() async {
    database =
        await MesKmDatabase.open(newDatabaseFactoryMemory(), name: 'att.db');
    container = ProviderContainer(overrides: [
      databaseProvider.overrideWithValue(database),
      todayDateProvider.overrideWithValue(() => day),
    ]);
    addTearDown(container.dispose);
  });

  tearDown(() => database.close());

  DayController dayCtrl() =>
      container.read(dayControllerProvider(day).notifier);

  VehiclesController vehCtrl() =>
      container.read(vehiclesControllerProvider.notifier);

  Future<String> createVehicle(String name) async {
    await vehCtrl().create(name: name, category: VehicleCategory.car);
    final s = await container.read(vehiclesControllerProvider.future);
    return s.vehicles.firstWhere((v) => v.name == name).id;
  }

  Future<double?> storedExtraKm() async =>
      (await SembastDayExtraRepository(database.db).getForDate(day))?.extraKm;

  Future<String?> storedExtraVehicle() async =>
      (await SembastDayExtraRepository(database.db).getForDate(day))
          ?.vehicleId;

  group('DayExtra', () {
    test('nouvel extra fige le principal ACTUEL ; aucun véhicule => null',
        () async {
      await dayCtrl().declareTotal(33);
      expect(await storedExtraVehicle(), isNull);

      await dayCtrl().clearDay();
      final peugeot = await createVehicle('Peugeot');
      await dayCtrl().declareTotal(87);
      expect(await storedExtraVehicle(), peugeot);
    });

    test(
        'SCÉNARIO LOT : extra 87 Peugeot ; principal -> Renault ; '
        '87 reste Peugeot ; 87 -> 92 conserve Peugeot', () async {
      final peugeot = await createVehicle('Peugeot');
      await dayCtrl().declareTotal(87);

      final renault = await createVehicle('Renault');
      await vehCtrl().setMain(renault);
      expect(await storedExtraVehicle(), peugeot,
          reason: 'l’historique n’est jamais réattribué');

      await dayCtrl().declareTotal(92);
      expect(await storedExtraKm(), 92);
      expect(await storedExtraVehicle(), peugeot,
          reason: 'modification du total : véhicule conservé');
    });

    test('suppression (0) puis recréation => principal du moment', () async {
      final peugeot = await createVehicle('Peugeot');
      await dayCtrl().declareTotal(87);
      expect(await storedExtraVehicle(), peugeot);

      await dayCtrl().declareTotal(0); // absence logique
      final renault = await createVehicle('Renault');
      await vehCtrl().setMain(renault);
      await dayCtrl().declareTotal(40);

      expect(await storedExtraVehicle(), renault);
    });

    test('correction manuelle : véhicule seul change, jamais le kilométrage',
        () async {
      final peugeot = await createVehicle('Peugeot');
      final renault = await createVehicle('Renault');
      await dayCtrl().declareTotal(87); // Peugeot (principal)
      expect(await storedExtraVehicle(), peugeot);

      await dayCtrl().setDayExtraVehicle(renault);
      expect(await storedExtraVehicle(), renault);
      expect(await storedExtraKm(), 87);

      await dayCtrl().setDayExtraVehicle(null);
      expect(await storedExtraVehicle(), isNull);
      expect(await storedExtraKm(), 87);
    });
  });

  group('Trips', () {
    test('vehicleId stocké tel que choisi ; modification le conserve',
        () async {
      final peugeot = await createVehicle('Peugeot');
      await dayCtrl()
          .addTrip(distanceKm: 24, isRoundTrip: false, vehicleId: peugeot);

      final renault = await createVehicle('Renault');
      await vehCtrl().setMain(renault);

      final trip =
          (await SembastTripRepository(database.db).getByDate(day)).single;
      expect(trip.vehicleId, peugeot,
          reason: 'changer de principal ne réattribue pas');

      await dayCtrl().updateTrip(trip,
          distanceKm: 30, isRoundTrip: true, vehicleId: trip.vehicleId);
      final updated =
          (await SembastTripRepository(database.db).getByDate(day)).single;
      expect(updated.vehicleId, peugeot);
      expect(updated.distanceKm, 30);
    });
  });

  group('Favoris', () {
    FavoriteTrip favorite({String? vehicleId}) => FavoriteTrip(
          id: 'fav-1',
          label: 'Travail',
          distanceKm: 70,
          vehicleId: vehicleId,
          sortOrder: 0,
        );

    test(
        'Automatique : principal résolu AU TAP et figé ; changer de '
        'principal n’affecte que les taps futurs', () async {
      final renault = await createVehicle('Renault');
      final fallback1 = await dayCtrl().addTripFromFavorite(favorite());
      expect(fallback1, isFalse);

      final peugeot = await createVehicle('Peugeot');
      await vehCtrl().setMain(peugeot);
      await dayCtrl().addTripFromFavorite(favorite());

      final trips = await SembastTripRepository(database.db).getByDate(day);
      expect(trips[0].vehicleId, renault, reason: 'figé au premier tap');
      expect(trips[1].vehicleId, peugeot, reason: 'nouveau principal');
    });

    test('véhicule explicite du favori toujours utilisé', () async {
      final peugeot = await createVehicle('Peugeot');
      final renault = await createVehicle('Renault');
      await vehCtrl().setMain(renault);

      await dayCtrl().addTripFromFavorite(favorite(vehicleId: peugeot));

      final trip =
          (await SembastTripRepository(database.db).getByDate(day)).single;
      expect(trip.vehicleId, peugeot);
    });

    test(
        'véhicule ARCHIVÉ référencé : jamais de Trip archivé silencieux — '
        'repli principal + signalement', () async {
      final peugeot = await createVehicle('Peugeot');
      final renault = await createVehicle('Renault');
      await vehCtrl().setMain(renault);
      await vehCtrl().archive(peugeot);

      final archivedFallback =
          await dayCtrl().addTripFromFavorite(favorite(vehicleId: peugeot));

      expect(archivedFallback, isTrue, reason: 'UI informée');
      final trip =
          (await SembastTripRepository(database.db).getByDate(day)).single;
      expect(trip.vehicleId, renault,
          reason: 'repli sur le principal actuel');
    });
  });
}
