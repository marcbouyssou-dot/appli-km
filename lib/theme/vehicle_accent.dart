import 'package:flutter/material.dart';

import 'mes_km_colors.dart';

/// Accent STABLE par véhicule (UX-001C).
///
/// Fonction DÉTERMINISTE du vehicleId : le même véhicule garde la même
/// couleur à chaque lancement et partout où ce langage sera réutilisé.
/// `null` (kilomètres sans véhicule) = gris neutre — jamais un accent.
Color vehicleAccent(ThemeData theme, String? vehicleId) {
  if (vehicleId == null) return theme.colorScheme.outline;
  final semantic = theme.mesKm;
  final cycle = [
    semantic.mobility,
    semantic.favorite,
    semantic.data,
    theme.colorScheme.primary,
  ];
  var hash = 0;
  for (final unit in vehicleId.codeUnits) {
    hash = (hash * 31 + unit) & 0x7fffffff;
  }
  return cycle[hash % cycle.length];
}
