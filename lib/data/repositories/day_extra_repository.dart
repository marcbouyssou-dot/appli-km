import '../../domain/models/civil_date.dart';
import '../../domain/models/day_extra.dart';

/// Accès aux kilomètres non détaillés (au plus un enregistrement par date).
abstract interface class DayExtraRepository {
  Future<DayExtra?> getForDate(CivilDate date);

  /// DayExtra d'une plage de dates, bornes incluses, triés par date.
  Future<List<DayExtra>> getBetween(CivilDate start, CivilDate end);

  Future<List<DayExtra>> getAll();

  /// Applique la valeur du jour : un extra à 0 ([DayExtra.isNone]) est
  /// l'absence logique et SUPPRIME l'enregistrement au lieu de le stocker.
  Future<void> set(DayExtra extra);

  Future<void> deleteForDate(CivilDate date);
}
