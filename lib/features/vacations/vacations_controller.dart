import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../../domain/logic/vacations.dart';
import '../../domain/models/civil_date.dart';
import '../../domain/models/vacation_period.dart';

/// Contrôleur des congés (liste globale de périodes, triée).
///
/// Toute mutation passe par `replaceAll` ATOMIQUE après application de la
/// logique pure du domaine (fusion, retrait d'une date), puis incrémente la
/// version des données pour rafraîchir calendrier et journées.
class VacationsController extends AsyncNotifier<List<VacationPeriod>> {
  @override
  Future<List<VacationPeriod>> build() =>
      ref.read(vacationRepositoryProvider).getAll();

  Future<void> _applyAndRefresh(List<VacationPeriod> periods) async {
    await ref.read(vacationRepositoryProvider).replaceAll(periods);
    state = await AsyncValue.guard(
      () => ref.read(vacationRepositoryProvider).getAll(),
    );
    ref.read(dayDataVersionProvider.notifier).bump();
  }

  /// Ajoute une période (bornes incluses), fusionnée avec l'existant
  /// (chevauchements et périodes contiguës).
  Future<void> addPeriod(CivilDate start, CivilDate end) async {
    final current = await future;
    final merged = mergeVacationPeriods([
      ...current,
      VacationPeriod(
        id: ref.read(idGeneratorProvider).newId(),
        startDate: start,
        endDate: end,
      ),
    ]);
    await _applyAndRefresh(merged.toList());
  }

  /// Marque une seule journée comme congé.
  Future<void> markDay(CivilDate date) => addPeriod(date, date);

  /// Retire UNE date du statut congé en préservant le reste des périodes
  /// (découpe du milieu incluse). Une seule écriture atomique.
  Future<void> removeDay(CivilDate date) async {
    final current = await future;
    final updated = removeDateFromPeriods(
      current,
      date,
      newIdForSplit: ref.read(idGeneratorProvider).newId,
    );
    await _applyAndRefresh(updated.toList());
  }

  /// Supprime une période complète.
  Future<void> deletePeriod(String id) async {
    final current = await future;
    await _applyAndRefresh(
      [for (final p in current) if (p.id != id) p],
    );
  }
}

final vacationsControllerProvider =
    AsyncNotifierProvider<VacationsController, List<VacationPeriod>>(
  VacationsController.new,
);
