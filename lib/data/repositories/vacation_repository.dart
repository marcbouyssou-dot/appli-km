import '../../domain/models/vacation_period.dart';

/// Accès aux périodes de congés.
abstract interface class VacationRepository {
  /// Toutes les périodes, triées par date de début.
  Future<List<VacationPeriod>> getAll();

  /// Crée ou remplace (même id) une période.
  Future<void> put(VacationPeriod period);

  Future<void> delete(String id);

  /// Remplace atomiquement l'ensemble des périodes (résultat d'une fusion
  /// `mergeVacationPeriods`, effacement global, restauration).
  Future<void> replaceAll(List<VacationPeriod> periods);
}
