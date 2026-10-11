import 'package:flutter/material.dart';

import 'tokens.dart';

/// Rôles sémantiques absents de ColorScheme (UX-001) : succès, avertissement
/// et congé. Accès : `theme.extension<MesKmColors>()!` ou [MesKmColorsX].
///
/// Usage strict (pas de couleur décorative) :
/// - success : confirmations d'état positif ;
/// - warning : provisoire / à compléter (dont la simulation fiscale) ;
/// - vacation : l'état « Congé » (distinct, ni positif ni alarmant).
@immutable
class MesKmColors extends ThemeExtension<MesKmColors> {
  const MesKmColors({
    required this.success,
    required this.onSuccess,
    required this.successContainer,
    required this.onSuccessContainer,
    required this.warning,
    required this.onWarning,
    required this.warningContainer,
    required this.onWarningContainer,
    required this.vacation,
    required this.vacationContainer,
    required this.onVacationContainer,
  });

  final Color success;
  final Color onSuccess;
  final Color successContainer;
  final Color onSuccessContainer;
  final Color warning;
  final Color onWarning;
  final Color warningContainer;
  final Color onWarningContainer;
  final Color vacation;
  final Color vacationContainer;
  final Color onVacationContainer;

  static const light = MesKmColors(
    success: AppPalette.success,
    onSuccess: AppPalette.onSuccess,
    successContainer: AppPalette.successContainer,
    onSuccessContainer: AppPalette.onSuccessContainer,
    warning: AppPalette.warning,
    onWarning: AppPalette.onWarning,
    warningContainer: AppPalette.warningContainer,
    onWarningContainer: AppPalette.onWarningContainer,
    vacation: AppPalette.vacation,
    vacationContainer: AppPalette.vacationContainer,
    onVacationContainer: AppPalette.onVacationContainer,
  );

  static const dark = MesKmColors(
    success: AppPalette.successDark,
    onSuccess: AppPalette.onSuccessDark,
    successContainer: AppPalette.successContainerDark,
    onSuccessContainer: AppPalette.onSuccessContainerDark,
    warning: AppPalette.warningDark,
    onWarning: AppPalette.onWarningDark,
    warningContainer: AppPalette.warningContainerDark,
    onWarningContainer: AppPalette.onWarningContainerDark,
    vacation: AppPalette.vacationDark,
    vacationContainer: AppPalette.vacationContainerDark,
    onVacationContainer: AppPalette.onVacationContainerDark,
  );

  @override
  MesKmColors copyWith({
    Color? success,
    Color? onSuccess,
    Color? successContainer,
    Color? onSuccessContainer,
    Color? warning,
    Color? onWarning,
    Color? warningContainer,
    Color? onWarningContainer,
    Color? vacation,
    Color? vacationContainer,
    Color? onVacationContainer,
  }) =>
      MesKmColors(
        success: success ?? this.success,
        onSuccess: onSuccess ?? this.onSuccess,
        successContainer: successContainer ?? this.successContainer,
        onSuccessContainer: onSuccessContainer ?? this.onSuccessContainer,
        warning: warning ?? this.warning,
        onWarning: onWarning ?? this.onWarning,
        warningContainer: warningContainer ?? this.warningContainer,
        onWarningContainer: onWarningContainer ?? this.onWarningContainer,
        vacation: vacation ?? this.vacation,
        vacationContainer: vacationContainer ?? this.vacationContainer,
        onVacationContainer:
            onVacationContainer ?? this.onVacationContainer,
      );

  @override
  MesKmColors lerp(MesKmColors? other, double t) {
    if (other == null) return this;
    Color mix(Color a, Color b) => Color.lerp(a, b, t)!;
    return MesKmColors(
      success: mix(success, other.success),
      onSuccess: mix(onSuccess, other.onSuccess),
      successContainer: mix(successContainer, other.successContainer),
      onSuccessContainer: mix(onSuccessContainer, other.onSuccessContainer),
      warning: mix(warning, other.warning),
      onWarning: mix(onWarning, other.onWarning),
      warningContainer: mix(warningContainer, other.warningContainer),
      onWarningContainer: mix(onWarningContainer, other.onWarningContainer),
      vacation: mix(vacation, other.vacation),
      vacationContainer: mix(vacationContainer, other.vacationContainer),
      onVacationContainer:
          mix(onVacationContainer, other.onVacationContainer),
    );
  }
}

extension MesKmColorsX on ThemeData {
  MesKmColors get mesKm => extension<MesKmColors>() ?? MesKmColors.light;
}
