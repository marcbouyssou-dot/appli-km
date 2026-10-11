import '../../domain/models/vehicle.dart';

/// Accès aux véhicules.
///
/// Pas de suppression physique : un véhicule référencé par l'historique
/// s'archive (`put(vehicle.archived(...))`), conformément au domaine.
abstract interface class VehicleRepository {
  Future<Vehicle?> getById(String id);

  /// Tous les véhicules, triés par nom.
  /// [includeArchived] à false pour ne garder que les véhicules actifs.
  Future<List<Vehicle>> getAll({bool includeArchived = true});

  /// Crée ou remplace (même id) un véhicule.
  Future<void> put(Vehicle vehicle);
}
