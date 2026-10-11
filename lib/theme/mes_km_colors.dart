import 'package:flutter/material.dart';

import 'tokens.dart';

/// Rôles sémantiques absents de ColorScheme (UX-001) : succès, avertissement
/// et congé. Accès : `theme.extension<MesKmColors>()!` ou [MesKmColorsX].
///
/// Usage strict (pas de couleur décorative) :
/// - success : confirmations d'état positif ;
/// - warning : provisoire / à compléter (dont la simulation fiscale) ;
/// - vacation : l'état « Congé » (distinct, ni positif ni alarmant) ;
/// - mobility : véhicule / mobilité (turquoise doux) ;
/// - favorite : favori / récurrence (orange chaud doux) ;
/// - data : documents / sauvegarde (indigo modéré).
/// Jamais « pour faire joli » : une couleur = un sens.
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
    required this.mobility,
    required this.mobilityContainer,
    required this.onMobilityContainer,
    required this.favorite,
    required this.favoriteContainer,
    required this.onFavoriteContainer,
    required this.data,
    required this.dataContainer,
    required this.onDataContainer,
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
  final Color mobility;
  final Color mobilityContainer;
  final Color onMobilityContainer;
  final Color favorite;
  final Color favoriteContainer;
  final Color onFavoriteContainer;
  final Color data;
  final Color dataContainer;
  final Color onDataContainer;

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
    mobility: AppPalette.mobility,
    mobilityContainer: AppPalette.mobilityContainer,
    onMobilityContainer: AppPalette.onMobilityContainer,
    favorite: AppPalette.favorite,
    favoriteContainer: AppPalette.favoriteContainer,
    onFavoriteContainer: AppPalette.onFavoriteContainer,
    data: AppPalette.data,
    dataContainer: AppPalette.dataContainer,
    onDataContainer: AppPalette.onDataContainer,
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
    mobility: AppPalette.mobilityDark,
    mobilityContainer: AppPalette.mobilityContainerDark,
    onMobilityContainer: AppPalette.onMobilityContainerDark,
    favorite: AppPalette.favoriteDark,
    favoriteContainer: AppPalette.favoriteContainerDark,
    onFavoriteContainer: AppPalette.onFavoriteContainerDark,
    data: AppPalette.dataDark,
    dataContainer: AppPalette.dataContainerDark,
    onDataContainer: AppPalette.onDataContainerDark,
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
    Color? mobility,
    Color? mobilityContainer,
    Color? onMobilityContainer,
    Color? favorite,
    Color? favoriteContainer,
    Color? onFavoriteContainer,
    Color? data,
    Color? dataContainer,
    Color? onDataContainer,
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
        mobility: mobility ?? this.mobility,
        mobilityContainer: mobilityContainer ?? this.mobilityContainer,
        onMobilityContainer:
            onMobilityContainer ?? this.onMobilityContainer,
        favorite: favorite ?? this.favorite,
        favoriteContainer: favoriteContainer ?? this.favoriteContainer,
        onFavoriteContainer:
            onFavoriteContainer ?? this.onFavoriteContainer,
        data: data ?? this.data,
        dataContainer: dataContainer ?? this.dataContainer,
        onDataContainer: onDataContainer ?? this.onDataContainer,
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
      mobility: mix(mobility, other.mobility),
      mobilityContainer: mix(mobilityContainer, other.mobilityContainer),
      onMobilityContainer:
          mix(onMobilityContainer, other.onMobilityContainer),
      favorite: mix(favorite, other.favorite),
      favoriteContainer: mix(favoriteContainer, other.favoriteContainer),
      onFavoriteContainer:
          mix(onFavoriteContainer, other.onFavoriteContainer),
      data: mix(data, other.data),
      dataContainer: mix(dataContainer, other.dataContainer),
      onDataContainer: mix(onDataContainer, other.onDataContainer),
    );
  }
}

extension MesKmColorsX on ThemeData {
  MesKmColors get mesKm => extension<MesKmColors>() ?? MesKmColors.light;
}
