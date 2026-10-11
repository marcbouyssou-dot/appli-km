import 'package:flutter/material.dart';

import 'tokens.dart';

/// Thèmes clair et sombre de Mes Km, centralisés.
/// Les écrans ne définissent jamais de couleur en dur : tout passe par ici.
abstract final class AppTheme {
  static ThemeData light() => _base(Brightness.light);

  static ThemeData dark() => _base(Brightness.dark);

  static ThemeData _base(Brightness brightness) {
    final scheme = ColorScheme.fromSeed(
      seedColor: AppColors.brandBlue,
      brightness: brightness,
    );

    return ThemeData(
      colorScheme: scheme,
      scaffoldBackgroundColor: scheme.surfaceContainerLowest,
      cardTheme: CardThemeData(
        elevation: 0,
        color: scheme.surfaceContainerLow,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.l),
        ),
        margin: EdgeInsets.zero,
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: scheme.surfaceContainerLowest,
        indicatorColor: scheme.primaryContainer,
      ),
      listTileTheme: ListTileThemeData(
        minVerticalPadding: AppSpacing.m,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.m),
        ),
      ),
    );
  }
}
