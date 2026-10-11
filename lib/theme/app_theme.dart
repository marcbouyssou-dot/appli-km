import 'package:flutter/material.dart';

import 'app_typography.dart';
import 'mes_km_colors.dart';
import 'tokens.dart';

/// Thèmes Mes Km (UX-001) — « iOS calme / utilitaire premium ».
///
/// L'identité est portée par une palette EXPLICITE ([AppPalette]) : le seed
/// Material ne sert plus que de squelette pour les rôles exotiques, tous les
/// rôles porteurs d'identité sont définis à la main, en clair ET en sombre.
/// Les écrans ne définissent jamais de couleur en dur : tout passe par ici
/// (ColorScheme + [MesKmColors] pour succès/avertissement/congé).
abstract final class AppTheme {
  static ThemeData light() => _base(Brightness.light);

  static ThemeData dark() => _base(Brightness.dark);

  static ColorScheme _scheme(Brightness brightness) {
    final skeleton = ColorScheme.fromSeed(
      seedColor: AppPalette.primary,
      brightness: brightness,
    );
    return switch (brightness) {
      Brightness.light => skeleton.copyWith(
          primary: AppPalette.primary,
          onPrimary: AppPalette.onPrimary,
          primaryContainer: AppPalette.primaryContainer,
          onPrimaryContainer: AppPalette.onPrimaryContainer,
          tertiary: AppPalette.vacation,
          tertiaryContainer: AppPalette.vacationContainer,
          onTertiaryContainer: AppPalette.onVacationContainer,
          error: AppPalette.destructive,
          onError: AppPalette.onDestructive,
          errorContainer: AppPalette.destructiveContainer,
          onErrorContainer: AppPalette.onDestructiveContainer,
          surface: AppPalette.surface,
          onSurface: AppPalette.textPrimary,
          onSurfaceVariant: AppPalette.textSecondary,
          surfaceContainerLowest: AppPalette.background,
          surfaceContainerLow: AppPalette.surface,
          surfaceContainer: AppPalette.surfaceAlt,
          surfaceContainerHigh: AppPalette.surfaceAlt,
          surfaceContainerHighest: AppPalette.surfaceAlt,
          outline: AppPalette.outline,
          outlineVariant: AppPalette.outlineVariant,
        ),
      Brightness.dark => skeleton.copyWith(
          primary: AppPalette.primaryDark,
          onPrimary: AppPalette.onPrimaryDark,
          primaryContainer: AppPalette.primaryContainerDark,
          onPrimaryContainer: AppPalette.onPrimaryContainerDark,
          tertiary: AppPalette.vacationDark,
          tertiaryContainer: AppPalette.vacationContainerDark,
          onTertiaryContainer: AppPalette.onVacationContainerDark,
          error: AppPalette.destructiveDark,
          onError: AppPalette.onDestructiveDark,
          errorContainer: AppPalette.destructiveContainerDark,
          onErrorContainer: AppPalette.onDestructiveContainerDark,
          surface: AppPalette.surfaceDark,
          onSurface: AppPalette.textPrimaryDark,
          onSurfaceVariant: AppPalette.textSecondaryDark,
          surfaceContainerLowest: AppPalette.backgroundDark,
          surfaceContainerLow: AppPalette.surfaceDark,
          surfaceContainer: AppPalette.surfaceAltDark,
          surfaceContainerHigh: AppPalette.surfaceAltDark,
          surfaceContainerHighest: AppPalette.surfaceAltDark,
          outline: AppPalette.outlineDark,
          outlineVariant: AppPalette.outlineVariantDark,
        ),
    };
  }

  static ThemeData _base(Brightness brightness) {
    final scheme = _scheme(brightness);
    final semantic = brightness == Brightness.light
        ? MesKmColors.light
        : MesKmColors.dark;
    final background = brightness == Brightness.light
        ? AppPalette.background
        : AppPalette.backgroundDark;

    final base = ThemeData(colorScheme: scheme, fontFamily: 'Inter');

    return base.copyWith(
      extensions: [semantic],
      textTheme: AppTypography.scale(base.textTheme),
      scaffoldBackgroundColor: background,

      // AppBar calme : même fond que l'écran, titre net, pas d'ombre.
      appBarTheme: AppBarTheme(
        backgroundColor: background,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        titleTextStyle: AppTypography.scale(base.textTheme)
            .titleLarge
            ?.copyWith(color: scheme.onSurface),
      ),

      // Carte standard : surface claire, radius 16, aucune ombre — le
      // contraste vient de la surface sur le fond, pas de l'élévation.
      cardTheme: CardThemeData(
        elevation: 0,
        color: scheme.surface,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.m),
        ),
        margin: EdgeInsets.zero,
      ),

      listTileTheme: ListTileThemeData(
        minVerticalPadding: AppSpacing.m,
        iconColor: scheme.onSurfaceVariant,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.s),
        ),
      ),

      dividerTheme: DividerThemeData(
        color: scheme.outlineVariant,
        thickness: 1,
        space: 1,
      ),

      // Contrôles : cibles >= 48 px (invariant), coins AppRadius.s.
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size(64, AppSizes.minTouchTarget),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.m),
          ),
          textStyle: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          minimumSize:
              const Size(AppSizes.minTouchTarget, AppSizes.minTouchTarget),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.s),
          ),
          textStyle: const TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: const Size(64, AppSizes.minTouchTarget),
          side: BorderSide(color: scheme.outlineVariant),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.m),
          ),
          textStyle: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      iconButtonTheme: IconButtonThemeData(
        style: IconButton.styleFrom(
          minimumSize:
              const Size(AppSizes.minTouchTarget, AppSizes.minTouchTarget),
        ),
      ),

      // Champs : contour discret, focus bleu net, coins AppRadius.s.
      inputDecorationTheme: InputDecorationTheme(
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.s),
          borderSide: BorderSide(color: scheme.outlineVariant),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.s),
          borderSide: BorderSide(color: scheme.outlineVariant),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.s),
          borderSide: BorderSide(color: scheme.primary, width: 1.6),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.s),
          borderSide: BorderSide(color: scheme.error),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.s),
          borderSide: BorderSide(color: scheme.error, width: 1.6),
        ),
      ),

      // Navigation légère (UX-001B) : plus de capsule — la sélection se lit
      // par la couleur et le poids. Cibles tactiles inchangées.
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: background,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        indicatorColor: Colors.transparent,
        iconTheme: WidgetStateProperty.resolveWith(
          (states) => IconThemeData(
            color: states.contains(WidgetState.selected)
                ? scheme.primary
                : scheme.onSurfaceVariant,
          ),
        ),
        labelTextStyle: WidgetStateProperty.resolveWith(
          (states) => TextStyle(
            fontSize: 12,
            fontWeight: states.contains(WidgetState.selected)
                ? FontWeight.w700
                : FontWeight.w600,
            color: states.contains(WidgetState.selected)
                ? scheme.primary
                : scheme.onSurfaceVariant,
          ),
        ),
      ),

      // Sheets et dialogues : mêmes coins (AppRadius.l), même surface.
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: scheme.surface,
        surfaceTintColor: Colors.transparent,
        dragHandleColor: scheme.outlineVariant,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.l)),
        ),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: scheme.surface,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.l),
        ),
      ),

      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.s),
        ),
      ),
    );
  }
}
