/// Estimateur fiscal PUR (KM-013).
///
/// SIMULATEUR INDICATIF : ne détermine jamais une déduction fiscale.
/// Chaque véhicule est estimé SÉPARÉMENT, avec la formule de la tranche
/// correspondant à son kilométrage annuel TOTAL (pas de calcul progressif,
/// jamais d'addition des kilomètres de deux véhicules avant barème).
/// Les kilomètres sans véhicule ne sont pas estimables.
library;

import '../models/fiscal_reference.dart';
import '../models/vehicle.dart';

/// Information manquante empêchant l'estimation d'un véhicule.
enum MissingVehicleInfo { motorization, fiscalPower, twoWheelerClass }

/// Résultat typé — aucune extrapolation silencieuse.
sealed class FiscalVehicleEstimate {
  const FiscalVehicleEstimate();
}

/// Estimation disponible pour ce véhicule.
class FiscalEstimateAvailable extends FiscalVehicleEstimate {
  const FiscalEstimateAvailable({
    required this.amountEur,
    required this.electricApplied,
  });

  /// Montant indicatif en euros (non arrondi — l'affichage arrondit).
  final double amountEur;
  final bool electricApplied;
}

/// Informations véhicule à compléter (motorisation, puissance, classe).
class FiscalVehicleIncomplete extends FiscalVehicleEstimate {
  const FiscalVehicleIncomplete(this.missing);

  final List<MissingVehicleInfo> missing;
}

/// Aucun barème du référentiel ne couvre ce véhicule.
class FiscalScaleUnavailable extends FiscalVehicleEstimate {
  const FiscalScaleUnavailable();
}

/// Estime les frais kilométriques indicatifs d'UN véhicule sur UNE année.
///
/// [annualKm] : kilomètres de l'année attribués à CE véhicule (attribution
/// historique figée — jamais recalculée depuis le véhicule principal actuel).
FiscalVehicleEstimate estimateVehicleFiscal({
  required Vehicle vehicle,
  required double annualKm,
  required FiscalReference reference,
}) {
  final missing = <MissingVehicleInfo>[];

  // On ne suppose JAMAIS une motorisation (un ancien véhicule n'est pas
  // « probablement thermique ») : non renseignée => pas d'estimation.
  if (vehicle.motorization == Motorization.unspecified) {
    missing.add(MissingVehicleInfo.motorization);
  }

  final FiscalScaleKind kind;
  switch (vehicle.category) {
    case VehicleCategory.car:
      kind = FiscalScaleKind.car;
      if (vehicle.fiscalPowerCv == null) {
        missing.add(MissingVehicleInfo.fiscalPower);
      }
    case VehicleCategory.twoWheeler:
      // Jamais de barème moto appliqué d'office à tous les deux-roues.
      switch (vehicle.twoWheelerClass) {
        case null:
          missing.add(MissingVehicleInfo.twoWheelerClass);
          kind = FiscalScaleKind.motorcycle; // non utilisé (incomplet)
        case TwoWheelerFiscalClass.motorcycle:
          kind = FiscalScaleKind.motorcycle;
          if (vehicle.fiscalPowerCv == null) {
            missing.add(MissingVehicleInfo.fiscalPower);
          }
        case TwoWheelerFiscalClass.moped:
          kind = FiscalScaleKind.moped;
      }
  }
  if (missing.isNotEmpty) return FiscalVehicleIncomplete(missing);

  final scale = reference.scaleFor(kind, vehicle.fiscalPowerCv);
  if (scale == null) return const FiscalScaleUnavailable();

  // Formule de la tranche du kilométrage annuel TOTAL du véhicule.
  final bracket = scale.bracketFor(annualKm);
  var amount = annualKm * bracket.rate + bracket.constant;

  final electric = vehicle.motorization == Motorization.electric;
  if (electric) amount *= reference.electricMultiplier;

  return FiscalEstimateAvailable(
    amountEur: amount,
    electricApplied: electric,
  );
}
