import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../../domain/models/vehicle.dart';

/// État véhicules : liste complète (archivés inclus) + principal désigné.
class VehiclesState {
  VehiclesState({required this.vehicles, required this.mainVehicleId});

  final List<Vehicle> vehicles;
  final String? mainVehicleId;

  List<Vehicle> get active =>
      [for (final v in vehicles) if (!v.isArchived) v];

  List<Vehicle> get archived =>
      [for (final v in vehicles) if (v.isArchived) v];

  Vehicle? byId(String? id) {
    if (id == null) return null;
    for (final v in vehicles) {
      if (v.id == id) return v;
    }
    return null;
  }

  bool isMain(String id) => id == mainVehicleId;
}

/// Gestion des véhicules. RÈGLE FONDAMENTALE : changer le véhicule
/// principal ne réattribue JAMAIS les Trips/DayExtra existants — leurs
/// vehicleId sont figés à la saisie.
class VehiclesController extends AsyncNotifier<VehiclesState> {
  @override
  Future<VehiclesState> build() => _load();

  Future<VehiclesState> _load() async {
    final vehicles = await ref.read(vehicleRepositoryProvider).getAll();
    final settings = await ref.read(settingsRepositoryProvider).get();
    return VehiclesState(
      vehicles: vehicles,
      mainVehicleId: settings.mainVehicleId,
    );
  }

  Future<void> _refresh() async {
    state = await AsyncValue.guard(_load);
    ref.read(dayDataVersionProvider.notifier).bump();
  }

  Future<void> create({
    required String name,
    required VehicleCategory category,
    int? fiscalPowerCv,
    String? registration,
  }) async {
    final current = await future;
    final vehicle = Vehicle(
      id: ref.read(idGeneratorProvider).newId(),
      name: name,
      category: category,
      fiscalPowerCv: fiscalPowerCv,
      registration: registration,
    );
    await ref.read(vehicleRepositoryProvider).put(vehicle);

    // Premier véhicule (ou aucun principal désigné) : devient principal.
    if (current.mainVehicleId == null) {
      await _setMainInternal(vehicle.id);
    }
    await _refresh();
  }

  /// Remplace le véhicule [original] (même id, même état d'archivage).
  Future<void> updateVehicle(
    Vehicle original, {
    required String name,
    required VehicleCategory category,
    int? fiscalPowerCv,
    String? registration,
  }) async {
    await ref.read(vehicleRepositoryProvider).put(Vehicle(
          id: original.id,
          name: name,
          category: category,
          fiscalPowerCv: fiscalPowerCv,
          registration: registration,
          archivedAt: original.archivedAt,
        ));
    await _refresh();
  }

  Future<void> setMain(String vehicleId) async {
    await _setMainInternal(vehicleId);
    await _refresh();
  }

  Future<void> _setMainInternal(String vehicleId) async {
    final settingsRepo = ref.read(settingsRepositoryProvider);
    final settings = await settingsRepo.get();
    await settingsRepo.save(settings.copyWith(mainVehicleId: vehicleId));
  }

  /// Archive (jamais de suppression physique : l'historique reste intact).
  /// Si c'était le principal : plus de principal (UX la plus simple,
  /// le prochain véhicule créé ou désigné le redeviendra).
  Future<void> archive(String vehicleId) async {
    final current = await future;
    final vehicle = current.byId(vehicleId);
    if (vehicle == null || vehicle.isArchived) return;

    await ref
        .read(vehicleRepositoryProvider)
        .put(vehicle.archived(DateTime.now()));

    if (current.mainVehicleId == vehicleId) {
      final settingsRepo = ref.read(settingsRepositoryProvider);
      final settings = await settingsRepo.get();
      // copyWith ne sait pas remettre à null : on repasse par le texte vide.
      await settingsRepo.save(settings.copyWith(mainVehicleId: ''));
    }
    await _refresh();
  }

  Future<void> unarchive(String vehicleId) async {
    final current = await future;
    final vehicle = current.byId(vehicleId);
    if (vehicle == null || !vehicle.isArchived) return;

    await ref.read(vehicleRepositoryProvider).put(Vehicle(
          id: vehicle.id,
          name: vehicle.name,
          category: vehicle.category,
          fiscalPowerCv: vehicle.fiscalPowerCv,
          registration: vehicle.registration,
        ));
    await _refresh();
  }
}

final vehiclesControllerProvider =
    AsyncNotifierProvider<VehiclesController, VehiclesState>(
  VehiclesController.new,
);
