import 'civil_date.dart';
import 'text.dart';

/// Période de congés, bornes incluses.
/// Un jour unique est une période dont startDate == endDate.
/// Un jour sans kilomètres n'est jamais déduit congé automatiquement.
class VacationPeriod {
  VacationPeriod({
    required this.id,
    required this.startDate,
    required this.endDate,
    String? label,
  }) : label = cleanText(label) {
    if (id.trim().isEmpty) {
      throw ArgumentError('VacationPeriod.id ne doit pas être vide.');
    }
    if (startDate.isAfter(endDate)) {
      throw ArgumentError(
        'VacationPeriod : startDate ($startDate) doit être <= '
        'endDate ($endDate).',
      );
    }
  }

  final String id;
  final CivilDate startDate;
  final CivilDate endDate;
  final String? label;

  bool contains(CivilDate date) =>
      !date.isBefore(startDate) && !date.isAfter(endDate);
}
