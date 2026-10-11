import '../../domain/models/civil_date.dart';
import '../../domain/models/trip.dart';

/// Accès aux trajets détaillés, indépendant du mécanisme de stockage.
abstract interface class TripRepository {
  Future<Trip?> getById(String id);

  /// Trajets d'une date civile, triés par date de création.
  Future<List<Trip>> getByDate(CivilDate date);

  /// Trajets d'une plage de dates, bornes incluses, triés par date.
  Future<List<Trip>> getBetween(CivilDate start, CivilDate end);

  /// Tous les trajets, triés par date (statistiques, exports futurs).
  Future<List<Trip>> getAll();

  /// Crée ou remplace (même id) un trajet.
  Future<void> put(Trip trip);

  Future<void> delete(String id);
}
