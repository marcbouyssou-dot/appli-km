import 'civil_date.dart';
import 'km.dart';
import 'text.dart';

/// Kilomètres non détaillés d'une journée.
///
/// Porte l'écart entre un total déclaré par l'utilisateur et la somme des
/// trajets détaillés du jour. Au plus un DayExtra par date.
/// Une valeur de 0 signifie l'absence logique de kilomètres non détaillés :
/// la logique métier ne produit pas de DayExtra à 0 (voir day_total.dart).
class DayExtra {
  DayExtra({
    required this.date,
    required double extraKm,
    String? note,
  })  : extraKm = normalizeKm(extraKm),
        note = cleanText(note) {
    if (this.extraKm < 0) {
      throw ArgumentError(
        'DayExtra.extraKm ne peut pas être négatif (reçu : $extraKm).',
      );
    }
  }

  final CivilDate date;

  /// Kilomètres non détaillés, canonisés au dixième, toujours >= 0.
  final double extraKm;

  final String? note;

  /// Absence logique de kilomètres non détaillés.
  bool get isNone => extraKm == 0;
}
