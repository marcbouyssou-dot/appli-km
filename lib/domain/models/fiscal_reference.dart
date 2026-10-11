/// Référentiel des barèmes kilométriques officiels (KM-013).
///
/// Modèle PUR, construit depuis les assets JSON versionnés de
/// `assets/fiscal/` et VALIDÉ à la construction : un référentiel
/// structurellement douteux est rejeté (jamais d'extrapolation silencieuse).
/// Aucune valeur n'est codée en dur ici — les montants vivent dans l'asset,
/// avec leur source officielle et leur date de vérification.
library;

/// Famille de barème fiscal. Un deux-roues n'a PAS de barème unique :
/// moto (> 50 cm³) et cyclomoteur (≤ 50 cm³) sont des barèmes distincts.
enum FiscalScaleKind { car, motorcycle, moped }

/// Une tranche de distance : montant = km × [rate] + [constant].
/// La formule s'applique à la tranche du kilométrage annuel TOTAL du
/// véhicule — ce n'est pas un calcul progressif par tranches.
class FiscalBracket {
  FiscalBracket({required this.maxKm, required this.rate, required this.constant}) {
    if (rate.isNaN || rate <= 0) {
      throw const FormatException('Tranche invalide : coefficient <= 0.');
    }
    if (constant.isNaN || constant < 0) {
      throw const FormatException('Tranche invalide : constante négative.');
    }
    final max = maxKm;
    if (max != null && max <= 0) {
      throw const FormatException('Tranche invalide : borne <= 0.');
    }
  }

  /// Borne haute incluse en km ; null = dernière tranche (sans limite).
  final int? maxKm;
  final double rate;
  final double constant;
}

/// Un barème : une famille, une plage de puissance fiscale, des tranches.
class FiscalScale {
  FiscalScale({
    required this.kind,
    required this.powerMinCv,
    required this.powerMaxCv,
    required this.brackets,
  }) {
    if (brackets.isEmpty) {
      throw const FormatException('Barème invalide : aucune tranche.');
    }
    if (brackets.last.maxKm != null) {
      throw const FormatException(
          'Barème invalide : la dernière tranche doit être ouverte.');
    }
    int? previous;
    for (final bracket in brackets.sublist(0, brackets.length - 1)) {
      final max = bracket.maxKm;
      if (max == null) {
        throw const FormatException(
            'Barème invalide : tranche intermédiaire sans borne.');
      }
      if (previous != null && max <= previous) {
        throw const FormatException(
            'Barème invalide : bornes non croissantes.');
      }
      previous = max;
    }
    final min = powerMinCv;
    final max = powerMaxCv;
    if (min != null && max != null && max < min) {
      throw const FormatException(
          'Barème invalide : plage de puissance incohérente.');
    }
  }

  final FiscalScaleKind kind;

  /// Plage de puissance fiscale couverte (bornes incluses) ;
  /// null = ouverte de ce côté. Les cyclomoteurs n'ont pas de plage.
  final int? powerMinCv;
  final int? powerMaxCv;
  final List<FiscalBracket> brackets;

  bool coversPower(int? cv) {
    if (powerMinCv == null && powerMaxCv == null) return true;
    if (cv == null) return false;
    if (powerMinCv != null && cv < powerMinCv!) return false;
    if (powerMaxCv != null && cv > powerMaxCv!) return false;
    return true;
  }

  FiscalBracket bracketFor(double km) {
    for (final bracket in brackets) {
      final max = bracket.maxKm;
      if (max == null || km <= max) return bracket;
    }
    return brackets.last; // inatteignable : la dernière est ouverte.
  }
}

/// Barème kilométrique officiel d'une année de revenus.
class FiscalReference {
  FiscalReference({
    required this.incomeYear,
    required this.publicationYear,
    required this.source,
    required this.verifiedAt,
    required this.referenceVersion,
    required this.electricMultiplier,
    required this.scales,
  }) {
    if (incomeYear < 2000 || incomeYear > 2100) {
      throw const FormatException(
          'Référentiel invalide : année de revenus hors plage.');
    }
    if (publicationYear < incomeYear) {
      throw const FormatException(
          'Référentiel invalide : publication antérieure aux revenus.');
    }
    if (source.trim().isEmpty) {
      throw const FormatException('Référentiel invalide : source manquante.');
    }
    if (electricMultiplier.isNaN || electricMultiplier < 1) {
      throw const FormatException(
          'Référentiel invalide : majoration électrique < 1.');
    }
    if (scales.isEmpty) {
      throw const FormatException('Référentiel invalide : aucun barème.');
    }
  }

  /// Année des REVENUS concernés (le barème publié en 2026 concerne 2025).
  final int incomeYear;
  final int publicationYear;

  /// Sources officielles (brochure DGFiP, BOFiP) — jamais de valeur inventée.
  final String source;
  final String verifiedAt;
  final int referenceVersion;

  /// Majoration « véhicule électrique » appliquée au montant (ex. 1.2).
  final double electricMultiplier;
  final List<FiscalScale> scales;

  /// Barème couvrant [kind] et la puissance [cv] ; null si aucun.
  FiscalScale? scaleFor(FiscalScaleKind kind, int? cv) {
    for (final scale in scales) {
      if (scale.kind == kind && scale.coversPower(cv)) return scale;
    }
    return null;
  }

  factory FiscalReference.fromJson(Map<String, Object?> json) {
    int requireInt(String key) {
      final value = json[key];
      if (value is! int) {
        throw FormatException('Référentiel invalide : "$key" manquant.');
      }
      return value;
    }

    final rawScales = json['scales'];
    if (rawScales is! List) {
      throw const FormatException('Référentiel invalide : "scales" manquant.');
    }
    final electric = json['electricMultiplier'];
    final source = json['source'];
    final verifiedAt = json['verifiedAt'];
    if (source is! String || verifiedAt is! String) {
      throw const FormatException(
          'Référentiel invalide : source ou date de vérification manquante.');
    }

    return FiscalReference(
      incomeYear: requireInt('incomeYear'),
      publicationYear: requireInt('publicationYear'),
      referenceVersion: requireInt('referenceVersion'),
      source: source,
      verifiedAt: verifiedAt,
      electricMultiplier:
          electric is num ? electric.toDouble() : double.nan,
      scales: [
        for (final raw in rawScales)
          if (raw is Map<String, Object?>)
            _scaleFromJson(raw)
          else
            throw const FormatException(
                'Référentiel invalide : barème illisible.'),
      ],
    );
  }

  static FiscalScale _scaleFromJson(Map<String, Object?> json) {
    final kind = switch (json['kind']) {
      'car' => FiscalScaleKind.car,
      'motorcycle' => FiscalScaleKind.motorcycle,
      'moped' => FiscalScaleKind.moped,
      final other =>
        throw FormatException('Référentiel invalide : famille "$other".'),
    };
    final rawBrackets = json['brackets'];
    if (rawBrackets is! List) {
      throw const FormatException(
          'Référentiel invalide : tranches manquantes.');
    }
    return FiscalScale(
      kind: kind,
      powerMinCv: json['powerMinCv'] as int?,
      powerMaxCv: json['powerMaxCv'] as int?,
      brackets: [
        for (final raw in rawBrackets)
          if (raw is Map<String, Object?>)
            FiscalBracket(
              maxKm: raw['maxKm'] as int?,
              rate: (raw['rate'] is num)
                  ? (raw['rate'] as num).toDouble()
                  : double.nan,
              constant: (raw['constant'] is num)
                  ? (raw['constant'] as num).toDouble()
                  : double.nan,
            )
          else
            throw const FormatException(
                'Référentiel invalide : tranche illisible.'),
      ],
    );
  }
}
