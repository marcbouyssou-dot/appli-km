@TestOn('browser')
library;

// Test navigateur réel (KM-013) : validation du référentiel et arithmétique
// de l'estimateur dans un vrai moteur JavaScript (les doubles Dart y sont
// des Number JS — on prouve que les formules du barème restent exactes).
// Le chargement d'asset par rootBundle n'est pas exerçable dans ce harnais
// (requête jamais résolue) : le CONTENU de l'asset de production est vérifié
// par test/data/fiscal_asset_test.dart, et son embarquement par le build web
// (AssetManifest) + la recette iPhone hors ligne.
// Exécution : flutter test --platform chrome test/web

import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:mes_km/domain/logic/fiscal_estimator.dart';
import 'package:mes_km/domain/models/fiscal_reference.dart';
import 'package:mes_km/domain/models/vehicle.dart';

const _fixtureJson = '''
{
  "referenceVersion": 1,
  "incomeYear": 2025,
  "publicationYear": 2026,
  "source": "Fixture navigateur (BOI-BAREME-000001, valeurs du barème auto 6 CV)",
  "verifiedAt": "2026-10-11",
  "electricMultiplier": 1.2,
  "scales": [
    {
      "kind": "car",
      "powerMinCv": 6,
      "powerMaxCv": 6,
      "brackets": [
        {"maxKm": 5000, "rate": 0.665, "constant": 0},
        {"maxKm": 20000, "rate": 0.374, "constant": 1457},
        {"maxKm": null, "rate": 0.447, "constant": 0}
      ]
    }
  ]
}
''';

void main() {
  test('parsing, validation et formules exactes dans un moteur JS', () {
    final reference = FiscalReference.fromJson(
        jsonDecode(_fixtureJson) as Map<String, Object?>);
    expect(reference.incomeYear, 2025);
    expect(reference.scales.single.brackets, hasLength(3));

    final vehicle = Vehicle(
        id: 'v',
        name: 'Exemple',
        category: VehicleCategory.car,
        fiscalPowerCv: 6,
        motorization: Motorization.other);

    double amount(double km) => (estimateVehicleFiscal(
            vehicle: vehicle, annualKm: km, reference: reference)
        as FiscalEstimateAvailable)
        .amountEur;

    expect(amount(8000), 4449); // 8 000 × 0,374 + 1 457
    expect(amount(5000), 3325);
    expect(amount(20001), closeTo(20001 * 0.447, 1e-9));

    // Référentiel invalide : rejeté aussi côté web.
    final broken = jsonDecode(_fixtureJson) as Map<String, Object?>;
    broken['scales'] = <Object?>[];
    expect(() => FiscalReference.fromJson(broken),
        throwsA(isA<FormatException>()));
  });
}
