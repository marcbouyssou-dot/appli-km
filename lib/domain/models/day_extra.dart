import 'civil_date.dart';
import 'km.dart';
import 'text.dart';

/// Kilomètres non détaillés d'une journée.
///
/// Porte l'écart entre un total déclaré par l'utilisateur et la somme des
/// trajets détaillés du jour. Au plus un DayExtra par date.
/// Une valeur de 0 signifie l'absence logique de kilomètres non détaillés :
/// la logique métier ne produit pas de DayExtra à 0 (voir day_total.dart).
///
/// [vehicleId] : attribution FIGÉE à la création (véhicule principal du
/// moment, ou null) — changer de véhicule principal plus tard ne réattribue
/// jamais l'historique ; seule une correction explicite le modifie.
class DayExtra {
  DayExtra({
    required this.date,
    required double extraKm,
    String? vehicleId,
    String? note,
  })  : extraKm = normalizeKm(extraKm),
        vehicleId = cleanText(vehicleId),
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

  /// Véhicule attribué (figé à la saisie), null si aucun.
  final String? vehicleId;

  final String? note;

  /// Absence logique de kilomètres non détaillés.
  bool get isNone => extraKm == 0;
}
