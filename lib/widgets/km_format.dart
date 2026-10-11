import '../domain/models/km.dart';

/// Formatage français des kilomètres pour l'affichage :
/// valeur entière sans décimale (« 87 km »), sinon un dixième (« 87,5 km »).
String formatKm(double km) {
  final value = normalizeKm(km);
  if (value == value.roundToDouble()) {
    return '${value.round()} km';
  }
  return '${value.toStringAsFixed(1).replaceAll('.', ',')} km';
}

/// Analyse une saisie utilisateur en kilomètres (virgule ou point acceptés).
/// Retourne null si la saisie n'est pas un nombre.
double? parseKmInput(String input) =>
    double.tryParse(input.trim().replaceAll(',', '.'));
