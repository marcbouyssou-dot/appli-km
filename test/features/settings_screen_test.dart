import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:mes_km/app.dart';
import 'package:mes_km/app/providers.dart';
import 'package:mes_km/data/local/app_database.dart';
import 'package:mes_km/data/local/sembast_settings_repository.dart';
import 'package:mes_km/domain/models/app_settings.dart';
import 'package:mes_km/domain/models/civil_date.dart';
import 'package:sembast/sembast_memory.dart' hide Finder;

// Réglages (KM-012) : identité des documents — champs AppSettings existants,
// sauvegarde locale immédiate, sans toucher aux autres réglages.
void main() {
  setUpAll(() async => initializeDateFormatting('fr_FR'));

  late MesKmDatabase database;

  setUp(() async {
    database =
        await MesKmDatabase.open(newDatabaseFactoryMemory(), name: 'st.db');
  });

  tearDown(() => database.close());

  Future<void> pumpApp(WidgetTester tester) async {
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
  }

  Future<void> openSettings(WidgetTester tester) async {
    await tester.tap(find.byIcon(Icons.more_horiz_outlined));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Réglages'));
    await tester.pumpAndSettle();
  }

  Finder field(String label) => find.ancestor(
      of: find.text(label), matching: find.byType(TextField));

  testWidgets(
      'saisie persistée immédiatement, préremplie à la réouverture, '
      'autres réglages intacts', (tester) async {
    await tester.runAsync(() => SembastSettingsRepository(database.db)
        .save(AppSettings(mainVehicleId: 'v-principal')));

    await pumpApp(tester);
    await openSettings(tester);
    expect(find.text('INFORMATIONS POUR LES DOCUMENTS'), findsOneWidget);

    await tester.enterText(field('Nom / structure'), 'Marc Infirmier');
    await tester.pump();
    await tester.enterText(field('Adresse'), '12 rue des Lilas');
    await tester.pump();
    await tester.enterText(field('Ville'), '19700 Seilhac');
    await tester.pumpAndSettle();

    final saved = await tester.runAsync(
        () => SembastSettingsRepository(database.db).get());
    expect(saved!.displayName, 'Marc Infirmier');
    expect(saved.address, '12 rue des Lilas');
    expect(saved.city, '19700 Seilhac');
    expect(saved.mainVehicleId, 'v-principal',
        reason: 'les réglages non affichés ne doivent pas être perdus');

    // Réouverture : champs préremplis depuis la base.
    await tester.tap(find.byType(BackButton));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Réglages'));
    await tester.pumpAndSettle();
    expect(
        tester.widget<TextField>(field('Nom / structure')).controller!.text,
        'Marc Infirmier');
    expect(tester.widget<TextField>(field('Ville')).controller!.text,
        '19700 Seilhac');
  });

  testWidgets('champ vidé : la valeur redevient « non renseignée »',
      (tester) async {
    await tester.runAsync(() => SembastSettingsRepository(database.db)
        .save(AppSettings(displayName: 'Ancien Nom', city: 'Tulle')));

    await pumpApp(tester);
    await openSettings(tester);

    await tester.enterText(field('Nom / structure'), '');
    await tester.pumpAndSettle();

    final saved = await tester.runAsync(
        () => SembastSettingsRepository(database.db).get());
    expect(saved!.displayName, isNull);
    expect(saved.city, 'Tulle');
  });
}
