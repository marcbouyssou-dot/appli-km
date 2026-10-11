import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mes_km/app/providers.dart';
import 'package:mes_km/data/local/app_database.dart';
import 'package:mes_km/data/local/sembast_settings_repository.dart';
import 'package:mes_km/domain/models/vehicle.dart';
import 'package:mes_km/features/vehicles/vehicles_controller.dart';
import 'package:sembast/sembast_memory.dart' hide Finder;

void main() {
  late MesKmDatabase database;
  late ProviderContainer container;

  setUp(() async {
    database =
        await MesKmDatabase.open(newDatabaseFactoryMemory(), name: 'veh.db');
    container = ProviderContainer(overrides: [
      databaseProvider.overrideWithValue(database),
    ]);
    addTearDown(container.dispose);
  });

  tearDown(() => database.close());

  VehiclesController controller() =>
      container.read(vehiclesControllerProvider.notifier);

  Future<VehiclesState> state() =>
      container.read(vehiclesControllerProvider.future);

  test('premier véhicule créé devient automatiquement principal', () async {
    await controller().create(
        name: 'Peugeot 3008',
        category: VehicleCategory.car,
        fiscalPowerCv: 6);

    final s = await state();
    expect(s.active.single.name, 'Peugeot 3008');
    expect(s.mainVehicleId, s.active.single.id);
    expect(
      (await SembastSettingsRepository(database.db).get()).mainVehicleId,
      s.active.single.id,
    );
  });

  test('changer de principal ne touche que le réglage', () async {
    await controller()
        .create(name: 'Peugeot', category: VehicleCategory.car);
    await controller()
        .create(name: 'Renault', category: VehicleCategory.car);
    var s = await state();
    final peugeot = s.vehicles.firstWhere((v) => v.name == 'Peugeot');
    final renault = s.vehicles.firstWhere((v) => v.name == 'Renault');
    expect(s.mainVehicleId, peugeot.id, reason: 'premier = principal');

    await controller().setMain(renault.id);

    s = await state();
    expect(s.mainVehicleId, renault.id);
    expect(s.vehicles, hasLength(2), reason: 'aucun véhicule modifié');
  });

  test('modification : même id, archivage conservé', () async {
    await controller().create(
        name: 'Peugeot', category: VehicleCategory.car, fiscalPowerCv: 6);
    final original = (await state()).active.single;

    await controller().updateVehicle(
      original,
      name: 'Peugeot 3008',
      category: VehicleCategory.car,
      fiscalPowerCv: 7,
      registration: 'AB-123-CD',
    );

    final updated = (await state()).active.single;
    expect(updated.id, original.id);
    expect(updated.name, 'Peugeot 3008');
    expect(updated.fiscalPowerCv, 7);
    expect(updated.registration, 'AB-123-CD');
  });

  test('archiver le principal : plus de principal, véhicule conservé',
      () async {
    await controller()
        .create(name: 'Peugeot', category: VehicleCategory.car);
    final peugeot = (await state()).active.single;

    await controller().archive(peugeot.id);

    final s = await state();
    expect(s.active, isEmpty);
    expect(s.archived.single.id, peugeot.id);
    expect(s.mainVehicleId, isNull);
  });

  test('réactiver un véhicule archivé', () async {
    await controller()
        .create(name: 'Peugeot', category: VehicleCategory.car);
    final peugeot = (await state()).active.single;
    await controller().archive(peugeot.id);

    await controller().unarchive(peugeot.id);

    final s = await state();
    expect(s.active.single.id, peugeot.id);
    expect(s.archived, isEmpty);
  });
}
