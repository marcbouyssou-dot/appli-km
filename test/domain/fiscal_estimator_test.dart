import 'package:flutter_test/flutter_test.dart';
import 'package:mes_km/domain/logic/fiscal_estimator.dart';
import 'package:mes_km/domain/models/fiscal_reference.dart';
import 'package:mes_km/domain/models/vehicle.dart';

// Estimateur fiscal PUR (KM-013). La fixture reprend la STRUCTURE et les
// valeurs du barème officiel des revenus 2025 (vérifiées dans
// fiscal_asset_test.dart contre l'asset embarqué) ; l'asset de production
// reste la seule source de vérité de l'app.
void main() {
  FiscalBracket b(int? maxKm, double rate, [double constant = 0]) =>
      FiscalBracket(maxKm: maxKm, rate: rate, constant: constant);

  final reference = FiscalReference(
    incomeYear: 2025,
    publicationYear: 2026,
    source: 'Fixture de test',
    verifiedAt: '2026-10-11',
    referenceVersion: 1,
    electricMultiplier: 1.2,
    scales: [
      FiscalScale(kind: FiscalScaleKind.car, powerMinCv: null, powerMaxCv: 3,
          brackets: [b(5000, 0.529), b(20000, 0.316, 1065), b(null, 0.370)]),
      FiscalScale(kind: FiscalScaleKind.car, powerMinCv: 4, powerMaxCv: 4,
          brackets: [b(5000, 0.606), b(20000, 0.340, 1330), b(null, 0.407)]),
      FiscalScale(kind: FiscalScaleKind.car, powerMinCv: 5, powerMaxCv: 5,
          brackets: [b(5000, 0.636), b(20000, 0.357, 1395), b(null, 0.427)]),
      FiscalScale(kind: FiscalScaleKind.car, powerMinCv: 6, powerMaxCv: 6,
          brackets: [b(5000, 0.665), b(20000, 0.374, 1457), b(null, 0.447)]),
      FiscalScale(kind: FiscalScaleKind.car, powerMinCv: 7, powerMaxCv: null,
          brackets: [b(5000, 0.697), b(20000, 0.394, 1515), b(null, 0.470)]),
      FiscalScale(
          kind: FiscalScaleKind.motorcycle, powerMinCv: null, powerMaxCv: 2,
          brackets: [b(3000, 0.395), b(6000, 0.099, 891), b(null, 0.248)]),
      FiscalScale(
          kind: FiscalScaleKind.motorcycle, powerMinCv: 3, powerMaxCv: 5,
          brackets: [b(3000, 0.468), b(6000, 0.082, 1158), b(null, 0.275)]),
      FiscalScale(
          kind: FiscalScaleKind.motorcycle, powerMinCv: 6, powerMaxCv: null,
          brackets: [b(3000, 0.606), b(6000, 0.079, 1583), b(null, 0.343)]),
      FiscalScale(kind: FiscalScaleKind.moped, powerMinCv: null,
          powerMaxCv: null,
          brackets: [b(3000, 0.315), b(6000, 0.079, 711), b(null, 0.198)]),
    ],
  );

  Vehicle car(int? cv, {Motorization motorization = Motorization.other}) =>
      Vehicle(
          id: 'car',
          name: 'Voiture test',
          category: VehicleCategory.car,
          fiscalPowerCv: cv,
          motorization: motorization);

  Vehicle twoWheeler({
    TwoWheelerFiscalClass? twoWheelerClass,
    int? cv,
    Motorization motorization = Motorization.other,
  }) =>
      Vehicle(
          id: 'tw',
          name: 'Deux-roues test',
          category: VehicleCategory.twoWheeler,
          fiscalPowerCv: cv,
          twoWheelerClass: twoWheelerClass,
          motorization: motorization);

  double amount(FiscalVehicleEstimate estimate) =>
      (estimate as FiscalEstimateAvailable).amountEur;

  FiscalVehicleEstimate estimate(Vehicle vehicle, double km) =>
      estimateVehicleFiscal(
          vehicle: vehicle, annualKm: km, reference: reference);

  group('automobile — tranche du kilométrage TOTAL, jamais progressif', () {
    test('0 km : estimation nulle mais disponible', () {
      expect(amount(estimate(car(6), 0)), 0);
    });

    test('bornes exactes 5 000 / 5 001 / 20 000 / 20 001 (6 CV)', () {
      expect(amount(estimate(car(6), 5000)), 5000 * 0.665); // 3325
      expect(amount(estimate(car(6), 5001)),
          closeTo(5001 * 0.374 + 1457, 1e-9));
      expect(amount(estimate(car(6), 20000)), 20000 * 0.374 + 1457); // 8937
      expect(amount(estimate(car(6), 20001)),
          closeTo(20001 * 0.447, 1e-9));
    });

    test('exemple de référence : 6 CV, 8 000 km => 8 000 × 0,374 + 1 457',
        () {
      expect(amount(estimate(car(6), 8000)), 4449);
    });

    test('puissances : plages 3 CV et moins / 4 / 5 / 7 CV et plus', () {
      expect(amount(estimate(car(2), 1000)), 529); // barème « 3 CV et moins »
      expect(amount(estimate(car(3), 1000)), 529);
      expect(amount(estimate(car(4), 10000)), 10000 * 0.340 + 1330);
      expect(amount(estimate(car(5), 4000)), 4000 * 0.636);
      expect(amount(estimate(car(7), 25000)), 25000 * 0.470);
      expect(amount(estimate(car(11), 25000)), 25000 * 0.470,
          reason: '11 CV relève du barème « 7 CV et plus »');
    });

    test('électrique : montant majoré (× 1,2), signalé', () {
      final result =
          estimate(car(5, motorization: Motorization.electric), 4000);
      expect(amount(result), closeTo(4000 * 0.636 * 1.2, 1e-9));
      expect((result as FiscalEstimateAvailable).electricApplied, isTrue);
      final other = estimate(car(5), 4000) as FiscalEstimateAvailable;
      expect(other.electricApplied, isFalse);
    });
  });

  group('deux-roues — jamais le barème moto appliqué d’office', () {
    test('moto 3-5 CV : trois tranches (3 000 / 6 000)', () {
      final moto = twoWheeler(
          twoWheelerClass: TwoWheelerFiscalClass.motorcycle, cv: 4);
      expect(amount(estimate(moto, 2000)), 2000 * 0.468);
      expect(amount(estimate(moto, 4000)), 4000 * 0.082 + 1158);
      expect(amount(estimate(moto, 7000)), closeTo(7000 * 0.275, 1e-9));
    });

    test('moto 1-2 CV et plus de 5 CV : plages distinctes', () {
      expect(
          amount(estimate(
              twoWheeler(
                  twoWheelerClass: TwoWheelerFiscalClass.motorcycle, cv: 1),
              3500)),
          3500 * 0.099 + 891);
      expect(
          amount(estimate(
              twoWheeler(
                  twoWheelerClass: TwoWheelerFiscalClass.motorcycle, cv: 6),
              3000)),
          3000 * 0.606);
    });

    test('cyclomoteur : aucune puissance requise', () {
      final moped = twoWheeler(twoWheelerClass: TwoWheelerFiscalClass.moped);
      expect(amount(estimate(moped, 2500)), closeTo(2500 * 0.315, 1e-9));
      expect(amount(estimate(moped, 5000)), 5000 * 0.079 + 711);
      expect(amount(estimate(moped, 6500)), 6500 * 0.198);
    });

    test('électrique sur deux-roues : majoration appliquée aussi', () {
      final moped = twoWheeler(
          twoWheelerClass: TwoWheelerFiscalClass.moped,
          motorization: Motorization.electric);
      expect(amount(estimate(moped, 2500)),
          closeTo(2500 * 0.315 * 1.2, 1e-9));
    });
  });

  group('cas indisponibles — aucune extrapolation silencieuse', () {
    test('motorisation non renseignée : incomplet (jamais supposée)', () {
      final result =
          estimate(car(6, motorization: Motorization.unspecified), 8000);
      expect(result, isA<FiscalVehicleIncomplete>());
      expect((result as FiscalVehicleIncomplete).missing,
          [MissingVehicleInfo.motorization]);
    });

    test('voiture sans puissance fiscale : incomplet', () {
      final result = estimate(car(null), 8000);
      expect((result as FiscalVehicleIncomplete).missing,
          [MissingVehicleInfo.fiscalPower]);
    });

    test('deux-roues sans classe fiscale : incomplet (moto ≠ cyclomoteur)',
        () {
      final result = estimate(twoWheeler(cv: 4), 2000);
      expect((result as FiscalVehicleIncomplete).missing,
          [MissingVehicleInfo.twoWheelerClass]);
    });

    test('moto sans puissance : incomplet', () {
      final result = estimate(
          twoWheeler(twoWheelerClass: TwoWheelerFiscalClass.motorcycle),
          2000);
      expect((result as FiscalVehicleIncomplete).missing,
          [MissingVehicleInfo.fiscalPower]);
    });

    test('manques cumulés : tous signalés', () {
      final result = estimate(
          car(null, motorization: Motorization.unspecified), 8000);
      expect(
          (result as FiscalVehicleIncomplete).missing,
          containsAll([
            MissingVehicleInfo.motorization,
            MissingVehicleInfo.fiscalPower,
          ]));
    });

    test('référentiel sans barème correspondant : indisponible typé', () {
      final carsOnly = FiscalReference(
        incomeYear: 2025,
        publicationYear: 2026,
        source: 'Fixture partielle',
        verifiedAt: '2026-10-11',
        referenceVersion: 1,
        electricMultiplier: 1.2,
        scales: [
          FiscalScale(
              kind: FiscalScaleKind.car, powerMinCv: null, powerMaxCv: null,
              brackets: [b(null, 0.5)]),
        ],
      );
      final result = estimateVehicleFiscal(
        vehicle:
            twoWheeler(twoWheelerClass: TwoWheelerFiscalClass.moped),
        annualKm: 1000,
        reference: carsOnly,
      );
      expect(result, isA<FiscalScaleUnavailable>());
    });
  });

  test(
      'deux véhicules : chacun sa tranche — jamais les kilomètres '
      'additionnés avant barème', () {
    // 2 × 3 000 km (6 CV) reste dans la 1re tranche de chaque véhicule…
    final separate =
        amount(estimate(car(6), 3000)) + amount(estimate(car(6), 3000));
    expect(separate, 2 * 3000 * 0.665); // 3 990
    // …alors que 6 000 km additionnés changeraient de tranche.
    expect(separate, isNot(amount(estimate(car(6), 6000))));
  });
}
