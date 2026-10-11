import 'package:flutter/material.dart';

/// Couleurs de marque Mes Km (héritées de l'esprit bleu/vert de la V1).
abstract final class AppColors {
  static const Color brandBlue = Color(0xFF007AFF);
  static const Color brandGreen = Color(0xFF34C759);
}

/// Espacements, rayons et tailles centralisés.
/// Aucune dimension spécifique à un modèle d'iPhone.
abstract final class AppSpacing {
  static const double xs = 4;
  static const double s = 8;
  static const double m = 12;
  static const double l = 16;
  static const double xl = 24;
  static const double xxl = 32;
}

abstract final class AppRadius {
  static const double m = 16;
  static const double l = 24;
}

abstract final class AppSizes {
  /// Taille minimale d'une zone tactile confortable.
  static const double minTouchTarget = 48;
}
