import 'package:flutter/material.dart';

/// Typographie Mes Km (UX-001) — « data-first » pour les chiffres.
///
/// POLICE : pile système non disponible sous Flutter Web/CanvasKit — le
/// moteur rastérise lui-même les glyphes et ne peut pas utiliser les polices
/// de l'appareil (la pile CSS `-apple-system`/`system-ui` est un concept DOM).
/// Déclarer ces familles ferait silencieusement retomber sur Roboto avec un
/// avertissement. Conformément au lot : PAS de police embarquée sans
/// justification démontrée — on garde la police par défaut et on construit
/// l'identité par l'échelle, les graisses et les chiffres tabulaires.
/// (L'embarquement d'Inter reste une option documentée pour un lot futur.)
abstract final class AppTypography {
  /// Chiffres à chasse fixe : un nombre qui change ne « danse » plus.
  static const List<FontFeature> tabularFigures = [
    FontFeature.tabularFigures(),
  ];

  /// Le grand compteur du jour (~56, poids fort, tabulaire).
  static const TextStyle counter = TextStyle(
    fontSize: 56,
    height: 1.05,
    fontWeight: FontWeight.w800,
    fontFeatures: tabularFigures,
    letterSpacing: -1.0,
  );

  /// Grand titre d'écran (« Aujourd'hui », « Calendrier »…).
  static const TextStyle screenTitle = TextStyle(
    fontSize: 28,
    height: 1.15,
    fontWeight: FontWeight.w700,
    letterSpacing: -0.4,
  );

  /// Titre de section — petit, semi-gras, légèrement espacé.
  /// (La casse reste celle du texte fourni : jamais transformée.)
  static const TextStyle sectionTitle = TextStyle(
    fontSize: 13,
    height: 1.2,
    fontWeight: FontWeight.w600,
    letterSpacing: 1.1,
  );

  /// Valeur numérique mise en avant (totaux, montants).
  static const TextStyle value = TextStyle(
    fontSize: 22,
    height: 1.2,
    fontWeight: FontWeight.w700,
    fontFeatures: tabularFigures,
    letterSpacing: -0.2,
  );

  static const TextStyle body = TextStyle(fontSize: 16, height: 1.35);

  static const TextStyle caption = TextStyle(fontSize: 13, height: 1.3);

  /// Applique l'échelle Mes Km sur le textTheme Material de base.
  /// Les tailles de corps restent proches des défauts (Dynamic Type et
  /// absence d'overflow déjà validés) ; les chiffres deviennent tabulaires
  /// sur tous les styles susceptibles d'afficher des valeurs.
  static TextTheme scale(TextTheme base) => base.copyWith(
        displayLarge: base.displayLarge?.merge(counter),
        headlineLarge: base.headlineLarge?.merge(screenTitle),
        headlineMedium: base.headlineMedium?.copyWith(
          fontWeight: FontWeight.w700,
          fontFeatures: tabularFigures,
        ),
        headlineSmall: base.headlineSmall?.copyWith(
          fontWeight: FontWeight.w700,
          fontFeatures: tabularFigures,
        ),
        titleLarge: base.titleLarge?.copyWith(
          fontWeight: FontWeight.w600,
          fontFeatures: tabularFigures,
        ),
        titleMedium: base.titleMedium?.copyWith(
          fontWeight: FontWeight.w600,
          fontFeatures: tabularFigures,
        ),
        titleSmall: base.titleSmall?.copyWith(
          fontFeatures: tabularFigures,
        ),
        labelSmall: base.labelSmall?.copyWith(
          fontFeatures: tabularFigures,
        ),
      );
}
