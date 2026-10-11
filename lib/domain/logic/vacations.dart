import '../models/civil_date.dart';
import '../models/vacation_period.dart';

/// Une date est-elle couverte par l'une des périodes de congés ?
/// (JOUR VIDE ≠ CONGÉ : seul ce statut explicite compte.)
bool isVacationDate(Iterable<VacationPeriod> periods, CivilDate date) =>
    periods.any((period) => period.contains(date));

/// Retire une date d'un ensemble de périodes de congés. Fonction pure.
///
/// - période d'un seul jour -> supprimée ;
/// - retrait du début -> start + 1 ;
/// - retrait de la fin -> end - 1 ;
/// - retrait du milieu -> période divisée : la première moitié conserve
///   l'id d'origine, la seconde reçoit un id fourni par [newIdForSplit]
///   (généré par la couche application, jamais par le domaine).
List<VacationPeriod> removeDateFromPeriods(
  Iterable<VacationPeriod> periods,
  CivilDate date, {
  required String Function() newIdForSplit,
}) {
  final result = <VacationPeriod>[];

  for (final period in periods) {
    if (!period.contains(date)) {
      result.add(period);
      continue;
    }
    if (period.startDate == period.endDate) {
      continue; // jour unique : la période disparaît
    }
    if (date == period.startDate) {
      result.add(VacationPeriod(
        id: period.id,
        startDate: date.addDays(1),
        endDate: period.endDate,
        label: period.label,
      ));
    } else if (date == period.endDate) {
      result.add(VacationPeriod(
        id: period.id,
        startDate: period.startDate,
        endDate: date.addDays(-1),
        label: period.label,
      ));
    } else {
      result.add(VacationPeriod(
        id: period.id,
        startDate: period.startDate,
        endDate: date.addDays(-1),
        label: period.label,
      ));
      result.add(VacationPeriod(
        id: newIdForSplit(),
        startDate: date.addDays(1),
        endDate: period.endDate,
        label: period.label,
      ));
    }
  }

  return List.unmodifiable(result);
}

/// Fusionne les périodes de congés qui se chevauchent ou se touchent
/// directement (ex. 1–5 août + 6–10 août => 1–10 août).
///
/// Fonction pure : la liste d'entrée n'est pas modifiée et l'ordre d'entrée
/// n'influence pas le résultat (tri interne par date de début).
/// Une période fusionnée conserve l'id de la période la plus ancienne
/// absorbée, et son label (à défaut, le premier label rencontré).
List<VacationPeriod> mergeVacationPeriods(Iterable<VacationPeriod> periods) {
  final sorted = periods.toList()
    ..sort((a, b) {
      final byStart = a.startDate.compareTo(b.startDate);
      return byStart != 0 ? byStart : a.endDate.compareTo(b.endDate);
    });

  final merged = <VacationPeriod>[];

  for (final period in sorted) {
    if (merged.isEmpty) {
      merged.add(period);
      continue;
    }

    final current = merged.last;
    final touchesOrOverlaps =
        !period.startDate.isAfter(current.endDate.addDays(1));

    if (!touchesOrOverlaps) {
      merged.add(period);
      continue;
    }

    final furthestEnd = period.endDate.isAfter(current.endDate)
        ? period.endDate
        : current.endDate;

    merged[merged.length - 1] = VacationPeriod(
      id: current.id,
      startDate: current.startDate,
      endDate: furthestEnd,
      label: current.label ?? period.label,
    );
  }

  return List.unmodifiable(merged);
}
