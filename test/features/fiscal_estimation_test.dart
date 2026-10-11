import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:mes_km/app.dart';
import 'package:mes_km/app/providers.dart';
import 'package:mes_km/data/fiscal/fiscal_reference_store.dart';
import 'package:mes_km/data/local/app_database.dart';
import 'package:mes_km/data/local/sembast_day_extra_repository.dart';
import 'package:mes_km/data/local/sembast_trip_repository.dart';
import 'package:mes_km/data/local/sembast_vehicle_repository.dart';
import 'package:mes_km/domain/models/civil_date.dart';
import 'package:mes_km/domain/models/day_extra.dart';
import 'package:mes_km/domain/models/fiscal_reference.dart';
import 'package:mes_km/domain/models/trip.dart';
import 'package:mes_km/domain/models/vehicle.dart';
import 'package:mes_km/widgets/km_format.dart';
import 'package:sembast/sembast_memory.dart' hide Finder;

// Section ESTIMATION KILOMÉTRIQUE (KM-013) : widgets, simulation provisoire
// explicite, navigation « Compléter le véhicule », rafraîchissement.
// Référentiel = FIXTURE (le vrai asset est vérifié par fiscal_asset_test).
void main() {
  final today = CivilDate(2026, 10, 11);

  FiscalBracket b(int? maxKm, double rate, [double constant = 0]) =>
      FiscalBracket(maxKm: maxKm, rate: rate, constant: constant);

  final reference2025 = FiscalReference(
    incomeYear: 2025,
    publicationYear: 2026,
    source: 'Fixture de test',
    verifiedAt: '2026-10-11',
    referenceVersion: 1,
    electricMultiplier: 1.2,
    scales: [
      FiscalScale(kind: FiscalScaleKind.car, powerMinCv: 5, powerMaxCv: 5,
          brackets: [b(5000, 0.636), b(20000, 0.357, 1395), b(null, 0.427)]),
      FiscalScale(kind: FiscalScaleKind.car, powerMinCv: 6, powerMaxCv: 6,
          brackets: [b(5000, 0.665), b(20000, 0.374, 1457), b(null, 0.447)]),
      FiscalScale(
          kind: FiscalScaleKind.motorcycle, powerMinCv: 3, powerMaxCv: 5,
          brackets: [b(3000, 0.468), b(6000, 0.082, 1158), b(null, 0.275)]),
    ],
  );

  setUpAll(() async => initializeDateFormatting('fr_FR'));

  late MesKmDatabase database;

  setUp(() async {
    database =
        await MesKmDatabase.open(newDatabaseFactoryMemory(), name: 'fe.db');
  });

  tearDown(() => database.close());

  Future<void> seedTrip(
          WidgetTester tester, CivilDate date, double km, String? vehicleId) =>
      tester.runAsync(() => SembastTripRepository(database.db).put(Trip(
            id: 't-${date.toIso8601()}-$km-$vehicleId',
            date: date,
            distanceKm: km,
            vehicleId: vehicleId,
            createdAt: DateTime.utc(date.year, date.month, date.day, 9),
          )));

  Future<void> seedVehicle(WidgetTester tester, Vehicle vehicle) => tester
      .runAsync(() => SembastVehicleRepository(database.db).put(vehicle));

  Future<void> pumpApp(WidgetTester tester) async {
    tester.view.physicalSize = const Size(600, 3200);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(ProviderScope(
      overrides: [
        databaseProvider.overrideWithValue(database),
        todayDateProvider.overrideWithValue(() => today),
        fiscalReferenceStoreProvider
            .overrideWithValue(FiscalReferenceStore([reference2025])),
      ],
      child: const MesKmApp(),
    ));
    await tester.pumpAndSettle();
    await tester.tap(find.byIcon(Icons.bar_chart_outlined));
    await tester.pumpAndSettle();
  }

  Future<void> goToYear2025(WidgetTester tester) async {
    await tester.tap(find.byKey(const Key('stats-prev-year')));
    await tester.pumpAndSettle();
  }

  testWidgets(
      'année 2025 : barème officiel appliqué, montants par véhicule, '
      'incomplet signalé, sous-total et km sans véhicule à part',
      (tester) async {
    await seedVehicle(
        tester,
        Vehicle(
            id: 'peugeot',
            name: 'Peugeot 2008',
            category: VehicleCategory.car,
            fiscalPowerCv: 6,
            motorization: Motorization.other));
    await seedVehicle(
        tester,
        Vehicle(
            id: 'zoe',
            name: 'Renault Zoé',
            category: VehicleCategory.car,
            fiscalPowerCv: 5,
            motorization: Motorization.electric));
    await seedVehicle(
        tester,
        Vehicle(
            id: 'moto',
            name: 'BMW R80',
            category: VehicleCategory.twoWheeler,
            fiscalPowerCv: 4,
            motorization: Motorization.other)); // classe deux-roues absente
    await seedTrip(tester, CivilDate(2025, 3, 10), 8000, 'peugeot');
    await seedTrip(tester, CivilDate(2025, 4, 2), 4000, 'zoe');
    await seedTrip(tester, CivilDate(2025, 5, 2), 1000, 'moto');
    await tester.runAsync(() => SembastDayExtraRepository(database.db)
        .set(DayExtra(date: CivilDate(2025, 6, 1), extraKm: 300)));

    await pumpApp(tester);
    await goToYear2025(tester);

    expect(find.text('ESTIMATION KILOMÉTRIQUE'), findsOneWidget);
    expect(
        find.text('Kilomètres 2025 · barème officiel des revenus 2025 '
            '(publié en 2026).'),
        findsOneWidget);
    expect(find.byKey(const Key('fiscal-provisional-banner')), findsNothing);

    // Peugeot 2008 : 8 000 × 0,374 + 1 457 = 4 449 €.
    final peugeotRow = find.byKey(const Key('fiscal-row-peugeot'));
    expect(
        find.descendant(
            of: peugeotRow, matching: find.text('6 CV — Autre motorisation')),
        findsOneWidget);
    expect(
        find.descendant(
            of: peugeotRow,
            matching: find.text(
                'Estimation indicative : ${formatEurRounded(4449)}')),
        findsOneWidget);

    // Zoé électrique : 4 000 × 0,636 × 1,2 = 3 052,8 => 3 053 €.
    expect(
        find.descendant(
            of: find.byKey(const Key('fiscal-row-zoe')),
            matching: find.text(
                'Estimation indicative : ${formatEurRounded(3052.8)}')),
        findsOneWidget);

    // Moto sans classe fiscale : signalée, jamais estimée d'office.
    final motoRow = find.byKey(const Key('fiscal-row-moto'));
    expect(
        find.descendant(
            of: motoRow,
            matching: find.text(
                'Informations véhicule à compléter : type de deux-roues.')),
        findsOneWidget);
    expect(find.byKey(const Key('fiscal-complete-moto')), findsOneWidget);

    // Estimation PARTIELLE : jamais « TOTAL » trompeur.
    expect(find.text('Sous-total des véhicules estimables'), findsOneWidget);
    expect(find.text('TOTAL ESTIMÉ'), findsNothing);
    expect(
        find.descendant(
            of: find.byKey(const Key('fiscal-total')),
            matching: find.text(formatEurRounded(4449 + 3052.8))),
        findsOneWidget);

    // Kilomètres sans véhicule : à part, non inclus.
    expect(
        find.textContaining('Kilomètres sans véhicule : '
            '${formatKmGrouped(300)}'),
        findsOneWidget);
  });

  testWidgets(
      '« Compléter le véhicule » : fiche ouverte directement, estimation '
      'rafraîchie au retour, TOTAL ESTIMÉ quand tout est estimable',
      (tester) async {
    await seedVehicle(
        tester,
        Vehicle(
            id: 'moto',
            name: 'BMW R80',
            category: VehicleCategory.twoWheeler,
            fiscalPowerCv: 4,
            motorization: Motorization.other));
    await seedTrip(tester, CivilDate(2025, 5, 2), 1000, 'moto');

    await pumpApp(tester);
    await goToYear2025(tester);
    expect(find.text('Sous-total des véhicules estimables'), findsNothing,
        reason: 'aucun véhicule estimable : pas de ligne de total');

    await tester.tap(find.byKey(const Key('fiscal-complete-moto')));
    await tester.pumpAndSettle();

    // La fiche du véhicule s'ouvre directement (formulaire existant).
    expect(find.text('Modifier le véhicule'), findsOneWidget);
    await tester.tap(find.byKey(const Key('two-wheeler-class-field')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Moto (plus de 50 cm³)').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Enregistrer'));
    await tester.pumpAndSettle();

    // Retour aux statistiques : estimation immédiatement à jour.
    await tester.tap(find.byType(BackButton));
    await tester.pumpAndSettle();
    expect(
        find.text('Estimation indicative : ${formatEurRounded(468)}'),
        findsOneWidget); // 1 000 × 0,468
    expect(find.text('TOTAL ESTIMÉ'), findsOneWidget);
    expect(find.text('Sous-total des véhicules estimables'), findsNothing);
  });

  testWidgets(
      '2026 sans barème : aucun barème appliqué silencieusement ; '
      'simulation provisoire sur action explicite, millésime affiché en '
      'permanence, réinitialisée au changement d’année', (tester) async {
    await seedVehicle(
        tester,
        Vehicle(
            id: 'peugeot',
            name: 'Peugeot 2008',
            category: VehicleCategory.car,
            fiscalPowerCv: 6,
            motorization: Motorization.other));
    await seedTrip(tester, CivilDate(2026, 2, 1), 1000, 'peugeot');
    await seedTrip(tester, CivilDate(2025, 3, 10), 8000, 'peugeot');

    await pumpApp(tester);

    // 2026 : pas de barème définitif.
    expect(find.text('Barème officiel non disponible pour cette année.'),
        findsOneWidget);
    expect(find.textContaining('Estimation indicative :'), findsNothing);

    // Simulation PROVISOIRE : action explicite.
    await tester.tap(find.byKey(const Key('fiscal-simulate-button')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('fiscal-provisional-banner')), findsOneWidget);
    expect(find.text('Simulation indicative — barème des revenus 2025.'),
        findsOneWidget);
    // 1 000 × 0,665 = 665 €.
    expect(find.text('Estimation indicative : ${formatEurRounded(665)}'),
        findsOneWidget);

    // Changement d'année : 2025 = barème OFFICIEL, bannière provisoire absente.
    await goToYear2025(tester);
    expect(find.byKey(const Key('fiscal-provisional-banner')), findsNothing);
    expect(find.text('Estimation indicative : ${formatEurRounded(4449)}'),
        findsOneWidget);

    // Retour en 2026 : la simulation provisoire doit être REDEMANDÉE.
    await tester.tap(find.byKey(const Key('stats-next-year')));
    await tester.pumpAndSettle();
    expect(find.text('Barème officiel non disponible pour cette année.'),
        findsOneWidget);
    expect(find.byKey(const Key('fiscal-simulate-button')), findsOneWidget);
    expect(find.byKey(const Key('fiscal-provisional-banner')), findsNothing);
  });

  testWidgets('année sans kilomètres : message sobre, aucun bouton',
      (tester) async {
    await pumpApp(tester);
    expect(find.text('Aucun kilomètre à estimer en 2026.'), findsOneWidget);
    expect(find.byKey(const Key('fiscal-simulate-button')), findsNothing);
  });
}
