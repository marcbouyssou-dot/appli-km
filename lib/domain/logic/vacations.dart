import '../models/vacation_period.dart';

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
