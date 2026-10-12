import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:mes_km/app.dart';
import 'package:mes_km/app/providers.dart';
import 'package:mes_km/data/local/app_database.dart';
import 'package:mes_km/domain/models/civil_date.dart';
import 'package:mes_km/features/vehicles/vehicles_controller.dart';
import 'package:sembast/sembast_memory.dart' hide Finder;

void main() {
  setUpAll(() async => initializeDateFormatting('fr_FR'));

  late MesKmDatabase database;

  setUp(() async {
    database =
        await MesKmDatabase.open(newDatabaseFactoryMemory(), name: 'vui.db');
  });

  tearDown(() => database.close());

  Future<void> pumpOnVehicles(WidgetTester tester) async {
    tester.view.physicalSize = const Size(500, 1800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(ProviderScope(
      overrides: [
        databaseProvider.overrideWithValue(database),
        todayDateProvider.overrideWithValue(() => CivilDate(2026, 10, 11)),
      ],
      child: const MesKmApp(),
    ));
    await tester.pumpAndSettle();
    await tester.tap(find.byIcon(Icons.more_horiz_outlined));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Véhicules'));
    await tester.pumpAndSettle();
  }

  Future<void> addVehicle(WidgetTester tester, String name,
      {String? cv}) async {
    await tester.tap(find.byKey(const Key('add-vehicle-button')));
    await tester.pumpAndSettle();
    await tester.enterText(find.widgetWithText(TextField, 'Nom'), name);
    if (cv != null) {
      await tester.enterText(
          find.widgetWithText(TextField, 'Puissance fiscale (CV, facultatif)'),
          cv);
    }
    await tester.pump(); // bouton actif (grammaire UX-003B1)
    await tester.tap(find.text('Ajouter le véhicule'));
    await tester.pumpAndSettle();
  }

  testWidgets(
      'Plus -> Véhicules : création (premier = Principal), détails affichés',
      (tester) async {
    await pumpOnVehicles(tester);
    expect(find.text('Aucun véhicule pour le moment.'), findsOneWidget);

    await addVehicle(tester, 'Peugeot 3008', cv: '6');

    expect(find.text('Peugeot 3008'), findsOneWidget);
    expect(find.text('Principal'), findsOneWidget);
    expect(
        find.text('Voiture · 6 CV · Motorisation non renseignée'),
        findsOneWidget);
  });

  testWidgets('changer de principal via l’action explicite',
      (tester) async {
    await pumpOnVehicles(tester);
    await addVehicle(tester, 'Peugeot');
    await addVehicle(tester, 'Renault');

    // Un seul badge Principal (Peugeot) + action sur Renault.
    expect(find.text('Principal'), findsOneWidget);
    final renaultId =
        (await tester.runAsync(() => SembastRead.renaultId(database)))!;
    await tester.tap(find.byKey(Key('set-main-$renaultId')));
    await tester.pumpAndSettle();

    // Le badge a changé de carte : Renault est maintenant principal.
    expect(find.text('Principal'), findsOneWidget);
    expect(
      find.byKey(Key('set-main-$renaultId')),
      findsNothing,
      reason: 'le principal n’a plus l’action',
    );
  });

  testWidgets('archiver (confirmation) puis réactiver', (tester) async {
    await pumpOnVehicles(tester);
    await addVehicle(tester, 'Peugeot');
    final id =
        (await tester.runAsync(() => SembastRead.firstVehicleId(database)))!;

    await tester.tap(find.byKey(Key('archive-$id')));
    await tester.pumpAndSettle();
    expect(find.text('Archiver ce véhicule ?'), findsOneWidget);
    expect(find.textContaining('restent attribués'), findsOneWidget);
    await tester.tap(find.widgetWithText(FilledButton, 'Archiver'));
    await tester.pumpAndSettle();

    expect(find.text('Véhicules archivés'), findsOneWidget);
    expect(find.byKey(Key('archived-$id')), findsOneWidget);
    expect(find.text('Principal'), findsNothing);

    await tester.tap(find.byKey(Key('unarchive-$id')));
    await tester.pumpAndSettle();
    expect(find.text('Véhicules archivés'), findsNothing);
    expect(find.byKey(Key('vehicle-$id')), findsOneWidget);
  });
}

/// Petites lectures d'ids pour cibler les clés dynamiques.
class SembastRead {
  static Future<String?> firstVehicleId(MesKmDatabase database) async {
    final container = ProviderContainer(
        overrides: [databaseProvider.overrideWithValue(database)]);
    try {
      final s = await container.read(vehiclesControllerProvider.future);
      return s.vehicles.isEmpty ? null : s.vehicles.first.id;
    } finally {
      container.dispose();
    }
  }

  static Future<String?> renaultId(MesKmDatabase database) async {
    final container = ProviderContainer(
        overrides: [databaseProvider.overrideWithValue(database)]);
    try {
      final s = await container.read(vehiclesControllerProvider.future);
      for (final v in s.vehicles) {
        if (v.name == 'Renault') return v.id;
      }
      return null;
    } finally {
      container.dispose();
    }
  }
}
