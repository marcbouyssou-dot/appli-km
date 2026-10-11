import 'package:intl/intl.dart';

import '../domain/models/km.dart';

/// Valeur kilométrique seule, format français :
/// entier sans décimale (« 87 »), sinon un dixième (« 87,5 »).
String formatKmValue(double km) {
  final value = normalizeKm(km);
  if (value == value.roundToDouble()) {
    return '${value.round()}';
  }
  return value.toStringAsFixed(1).replaceAll('.', ',');
}

/// Formatage français des kilomètres pour l'affichage :
/// valeur entière sans décimale (« 87 km »), sinon un dixième (« 87,5 km »).
String formatKm(double km) => '${formatKmValue(km)} km';

/// Analyse une saisie utilisateur en kilomètres (virgule ou point acceptés).
/// Retourne null si la saisie n'est pas un nombre.
double? parseKmInput(String input) =>
    double.tryParse(input.trim().replaceAll(',', '.'));

/// Format d'AFFICHAGE français avec séparateur de milliers (« 12 842 km »).
/// Réservé aux écrans de lecture (statistiques…) — jamais pour un champ
/// éditable, dont le texte doit rester compatible avec [parseKmInput].
String formatKmGrouped(double km) {
  final value = normalizeKm(km);
  return '${NumberFormat('#,##0.#', 'fr_FR').format(value)} km';
}

/// Montant indicatif en euros, ARRONDI à l'euro (« 3 149 € ») : une
/// estimation affichée au centime suggérerait une précision fiscale
/// qu'elle n'a pas.
String formatEurRounded(double eur) =>
    '${NumberFormat('#,##0', 'fr_FR').format(eur.round())} €';
