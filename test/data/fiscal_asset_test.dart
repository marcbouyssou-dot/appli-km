import 'package:flutter_test/flutter_test.dart';
import 'package:mes_km/data/fiscal/fiscal_reference_store.dart';
import 'package:mes_km/domain/logic/fiscal_estimator.dart';
import 'package:mes_km/domain/models/fiscal_reference.dart';
import 'package:mes_km/domain/models/vehicle.dart';

// Asset de PRODUCTION assets/fiscal/bareme-revenus-2025.json : valeurs
// OFFICIELLES vérifiées le 2026-10-11 contre la Brochure pratique IR 2026
// (revenus 2025, p. 25) et BOFiP BOI-BAREME-000001 (version en vigueur du
// 20/07/2023, arrêté du 27 mars 2023 ; barème reconduit sans revalorisation).
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late FiscalReference reference;

  setUpAll(() async {
    final store = await loadFiscalReferenceStore();
    expect(store.references, hasLength(1),
        reason: 'un seul millésime embarqué (revenus 2025)');
    reference = store.forIncomeYear(2025)!;
    expect(store.latest!.incomeYear, 2025);
    expect(store.forIncomeYear(2026), isNull,
        reason: 'aucun barème définitif pour les revenus 2026');
  });

  test('millésime et traçabilité', () {
    expect(reference.incomeYear, 2025);
    expect(reference.publicationYear, 2026);
    expect(reference.referenceVersion, 1);
    expect(reference.verifiedAt, '2026-10-11');
    expect(reference.source, contains('BOI-BAREME-000001'));
    expect(reference.source, contains('Brochure pratique IR 2026'));
    expect(reference.source, contains('27 mars 2023'));
    expect(reference.electricMultiplier, 1.2);
  });

  test('barème automobile : les 5 plages et leurs 15 valeurs officielles',
      () {
    (double, double, double, double, double) rates(int cv, int kmIndex) {
      final values = <double>[];
      for (final band in [3, 4, 5, 6, 7]) {
        final scale = reference.scaleFor(FiscalScaleKind.car, band)!;
        final bracket = scale.brackets[kmIndex];
        values.add(kmIndex == 1 ? bracket.constant : bracket.rate);
      }
      return (values[0], values[1], values[2], values[3], values[4]);
    }

    // d <= 5 000 : coefficients.
    expect(rates(3, 0), (0.529, 0.606, 0.636, 0.665, 0.697));
    // 5 001-20 000 : constantes (coefficients vérifiés ci-dessous).
    expect(rates(3, 1), (1065.0, 1330.0, 1395.0, 1457.0, 1515.0));
    // > 20 000 : coefficients.
    expect(rates(3, 2), (0.370, 0.407, 0.427, 0.447, 0.470));

    final midRates = [
      for (final band in [3, 4, 5, 6, 7])
        reference.scaleFor(FiscalScaleKind.car, band)!.brackets[1].rate,
    ];
    expect(midRates, [0.316, 0.340, 0.357, 0.374, 0.394]);
  });

  test('barème moto : trois plages, seuils 3 000 / 6 000', () {
    final low = reference.scaleFor(FiscalScaleKind.motorcycle, 2)!;
    final mid = reference.scaleFor(FiscalScaleKind.motorcycle, 4)!;
    final high = reference.scaleFor(FiscalScaleKind.motorcycle, 6)!;
    expect([for (final s in [low, mid, high]) s.brackets[0].rate],
        [0.395, 0.468, 0.606]);
    expect([for (final s in [low, mid, high]) s.brackets[1].rate],
        [0.099, 0.082, 0.079]);
    expect([for (final s in [low, mid, high]) s.brackets[1].constant],
        [891.0, 1158.0, 1583.0]);
    expect([for (final s in [low, mid, high]) s.brackets[2].rate],
        [0.248, 0.275, 0.343]);
    expect(low.brackets[0].maxKm, 3000);
    expect(low.brackets[1].maxKm, 6000);
  });

  test('barème cyclomoteur : sans condition de puissance', () {
    final moped = reference.scaleFor(FiscalScaleKind.moped, null)!;
    expect(moped.brackets[0].rate, 0.315);
    expect(moped.brackets[1].rate, 0.079);
    expect(moped.brackets[1].constant, 711);
    expect(moped.brackets[2].rate, 0.198);
  });

  test('exemple officiel de bout en bout : 6 CV, 8 000 km => 4 449 €', () {
    final result = estimateVehicleFiscal(
      vehicle: Vehicle(
          id: 'v',
          name: 'Exemple',
          category: VehicleCategory.car,
          fiscalPowerCv: 6,
          motorization: Motorization.other),
      annualKm: 8000,
      reference: reference,
    );
    expect((result as FiscalEstimateAvailable).amountEur, 4449);
  });
}
