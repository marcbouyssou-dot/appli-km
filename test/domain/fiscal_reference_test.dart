import 'package:flutter_test/flutter_test.dart';
import 'package:mes_km/domain/models/fiscal_reference.dart';

// Référentiel fiscal (KM-013) : validation structurelle au chargement —
// un référentiel douteux est REJETÉ, jamais corrigé silencieusement.
// Valeurs FICTIVES : uniquement des fixtures de test.
void main() {
  Map<String, Object?> valid() => {
        'referenceVersion': 1,
        'incomeYear': 2025,
        'publicationYear': 2026,
        'source': 'Fixture de test (fictive)',
        'verifiedAt': '2026-10-11',
        'electricMultiplier': 1.2,
        'scales': [
          {
            'kind': 'car',
            'powerMinCv': null,
            'powerMaxCv': 3,
            'brackets': [
              {'maxKm': 5000, 'rate': 0.5, 'constant': 0},
              {'maxKm': 20000, 'rate': 0.3, 'constant': 1000},
              {'maxKm': null, 'rate': 0.4, 'constant': 0},
            ],
          },
        ],
      };

  test('référentiel valide : toutes les métadonnées conservées', () {
    final reference = FiscalReference.fromJson(valid());
    expect(reference.incomeYear, 2025);
    expect(reference.publicationYear, 2026);
    expect(reference.referenceVersion, 1);
    expect(reference.source, isNotEmpty);
    expect(reference.verifiedAt, '2026-10-11');
    expect(reference.electricMultiplier, 1.2);
    expect(reference.scales.single.kind, FiscalScaleKind.car);
    expect(reference.scales.single.brackets, hasLength(3));
  });

  test('sélection de tranche : bornes incluses, dernière ouverte', () {
    final scale = FiscalReference.fromJson(valid()).scales.single;
    expect(scale.bracketFor(0).rate, 0.5);
    expect(scale.bracketFor(5000).rate, 0.5);
    expect(scale.bracketFor(5001).rate, 0.3);
    expect(scale.bracketFor(20000).rate, 0.3);
    expect(scale.bracketFor(20001).rate, 0.4);
  });

  test('plages de puissance : bornes ouvertes et fermées', () {
    final scale = FiscalReference.fromJson(valid()).scales.single;
    expect(scale.coversPower(1), isTrue);
    expect(scale.coversPower(3), isTrue);
    expect(scale.coversPower(4), isFalse);
    expect(scale.coversPower(null), isFalse,
        reason: 'puissance manquante : jamais couvert par une plage bornée');
  });

  test('rejets : chaque invariant structurel est contrôlé', () {
    void rejects(Map<String, Object?> Function(Map<String, Object?>) mutate) {
      expect(() => FiscalReference.fromJson(mutate(valid())),
          throwsA(isA<FormatException>()));
    }

    rejects((m) => m..remove('incomeYear'));
    rejects((m) => m..['incomeYear'] = 1800);
    rejects((m) => m..['publicationYear'] = 2024); // avant les revenus
    rejects((m) => m..['source'] = '   ');
    rejects((m) => m..remove('verifiedAt'));
    rejects((m) => m..['electricMultiplier'] = 0.8);
    rejects((m) => m..['electricMultiplier'] = 'douze');
    rejects((m) => m..['scales'] = <Object?>[]);
    rejects((m) => m
      ..['scales'] = [
        {
          'kind': 'tracteur', // famille inconnue
          'brackets': [
            {'maxKm': null, 'rate': 0.5, 'constant': 0},
          ],
        },
      ]);
    rejects((m) => m
      ..['scales'] = [
        {'kind': 'car', 'brackets': <Object?>[]}, // aucune tranche
      ]);
    rejects((m) => m
      ..['scales'] = [
        {
          'kind': 'car',
          'brackets': [
            {'maxKm': 5000, 'rate': 0.5, 'constant': 0}, // pas de tranche ouverte
          ],
        },
      ]);
    rejects((m) => m
      ..['scales'] = [
        {
          'kind': 'car',
          'brackets': [
            {'maxKm': 20000, 'rate': 0.5, 'constant': 0},
            {'maxKm': 5000, 'rate': 0.3, 'constant': 0}, // bornes décroissantes
            {'maxKm': null, 'rate': 0.4, 'constant': 0},
          ],
        },
      ]);
    rejects((m) => m
      ..['scales'] = [
        {
          'kind': 'car',
          'brackets': [
            {'maxKm': 5000, 'rate': -0.1, 'constant': 0}, // coefficient négatif
            {'maxKm': null, 'rate': 0.4, 'constant': 0},
          ],
        },
      ]);
    rejects((m) => m
      ..['scales'] = [
        {
          'kind': 'car',
          'powerMinCv': 7,
          'powerMaxCv': 4, // plage incohérente
          'brackets': [
            {'maxKm': null, 'rate': 0.4, 'constant': 0},
          ],
        },
      ]);
  });
}
