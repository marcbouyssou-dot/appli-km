import 'dart:ui';

/// Palette Mes Km (UX-001) — direction « iOS calme / utilitaire premium ».
///
/// Les couleurs d'identité sont EXPLICITES (plus dérivées d'un seed) :
/// un seul bleu de marque, des couleurs sémantiques sobres (succès,
/// avertissement, destructif) et des surfaces calmes. Le mode sombre est
/// défini réellement, pas inversé automatiquement.
abstract final class AppPalette {
  // --- Light -------------------------------------------------------------
  static const Color primary = Color(0xFF1D5BD8);
  static const Color onPrimary = Color(0xFFFFFFFF);
  static const Color primaryContainer = Color(0xFFDCE7FB);
  static const Color onPrimaryContainer = Color(0xFF10316F);

  static const Color success = Color(0xFF2E9E5B);
  static const Color onSuccess = Color(0xFFFFFFFF);
  static const Color successContainer = Color(0xFFDCF2E4);
  static const Color onSuccessContainer = Color(0xFF0F4D2A);

  static const Color warning = Color(0xFFB45309);
  static const Color onWarning = Color(0xFFFFFFFF);
  static const Color warningContainer = Color(0xFFFDEBD2);
  static const Color onWarningContainer = Color(0xFF6B3105);

  static const Color destructive = Color(0xFFBA1A1A);
  static const Color onDestructive = Color(0xFFFFFFFF);
  static const Color destructiveContainer = Color(0xFFFFDAD6);
  static const Color onDestructiveContainer = Color(0xFF93000A);

  /// Congé : état distinct (ni succès, ni avertissement) — sarcelle calme.
  static const Color vacation = Color(0xFF2E7D7B);
  static const Color vacationContainer = Color(0xFFD3ECEA);
  static const Color onVacationContainer = Color(0xFF0E3B3A);

  static const Color background = Color(0xFFFBFCFE); // quasi blanc, très légèrement bleuté
  static const Color surface = Color(0xFFFFFFFF);
  static const Color surfaceAlt = Color(0xFFEAEEF6);
  static const Color outline = Color(0xFF6E7684);
  static const Color outlineVariant = Color(0xFFD9DEE8);

  static const Color textPrimary = Color(0xFF1A1C20); // presque noir
  static const Color textSecondary = Color(0xFF545C68);

  // --- Dark (défini réellement, pas une inversion) ------------------------
  static const Color primaryDark = Color(0xFF7AA7FF);
  static const Color onPrimaryDark = Color(0xFF0A2A66);
  static const Color primaryContainerDark = Color(0xFF1E3A74);
  static const Color onPrimaryContainerDark = Color(0xFFD6E2FF);

  static const Color successDark = Color(0xFF6FCF97);
  static const Color onSuccessDark = Color(0xFF06351C);
  static const Color successContainerDark = Color(0xFF1D4030);
  static const Color onSuccessContainerDark = Color(0xFFC9ECD7);

  static const Color warningDark = Color(0xFFF4B860);
  static const Color onWarningDark = Color(0xFF402500);
  static const Color warningContainerDark = Color(0xFF4A3012);
  static const Color onWarningContainerDark = Color(0xFFFBE1B8);

  static const Color destructiveDark = Color(0xFFFFB4AB);
  static const Color onDestructiveDark = Color(0xFF690005);
  static const Color destructiveContainerDark = Color(0xFF93000A);
  static const Color onDestructiveContainerDark = Color(0xFFFFDAD6);

  static const Color vacationDark = Color(0xFF86CFCC);
  static const Color vacationContainerDark = Color(0xFF1C4A49);
  static const Color onVacationContainerDark = Color(0xFFBDEEEB);

  static const Color backgroundDark = Color(0xFF111318);
  static const Color surfaceDark = Color(0xFF1A1D23);
  static const Color surfaceAltDark = Color(0xFF242832);
  static const Color outlineDark = Color(0xFF8C93A0);
  static const Color outlineVariantDark = Color(0xFF3A4048);

  static const Color textPrimaryDark = Color(0xFFE8EAEF);
  static const Color textSecondaryDark = Color(0xFFA7AFBC);
}

/// Espacements — échelle validée (KM-014), inchangée.
abstract final class AppSpacing {
  static const double xs = 4;
  static const double s = 8;
  static const double m = 12;
  static const double l = 16;
  static const double xl = 24;
  static const double xxl = 32;
}

/// Rayons UX-001 : fin des « grosses pilules » (24 par défaut abandonné).
/// s = contrôles/cellules, m = carte standard, l = sheets/dialogues.
abstract final class AppRadius {
  static const double s = 12;
  static const double m = 16;
  static const double l = 20;
}

abstract final class AppSizes {
  /// Taille minimale d'une zone tactile confortable — INVARIANT (>= 48).
  static const double minTouchTarget = 48;

  /// Hauteur des actions principales pleine largeur.
  static const double primaryActionHeight = 56;
}
