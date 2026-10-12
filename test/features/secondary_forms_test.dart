import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:mes_km/app.dart';
import 'package:mes_km/app/providers.dart';
import 'package:mes_km/data/local/app_database.dart';
import 'package:mes_km/data/local/sembast_settings_repository.dart';
import 'package:mes_km/domain/models/app_settings.dart';
import 'package:mes_km/data/local/sembast_vacation_repository.dart';
import 'package:mes_km/data/local/sembast_vehicle_repository.dart';
import 'package:mes_km/domain/models/civil_date.dart';
import 'package:sembast/sembast_memory.dart' hide Finder;

// UX-003C : formulaires secondaires alignés sur la grammaire validée —
// bouton honnête, action épinglée, aucune capacité perdue.
void main() {
  final today = CivilDate(2026, 10, 12);

  setUpAll(() async => initializeDateFormatting('fr_FR'));

  late MesKmDatabase database;

  setUp(() async {
    database =
        await MesKmDatabase.open(newDatabaseFactoryMemory(), name: 'sf.db');
  });

  tearDown(() => database.close());

  Future<void> pumpApp(WidgetTester tester) async {
    tester.view.physicalSize = const Size(500, 1200);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(ProviderScope(
      overrides: [
        databaseProvider.overrideWithValue(database),
        todayDateProvider.overrideWithValue(() => today),
      ],
      child: const MesKmApp(),
    ));
    await tester.pumpAndSettle();
  }

  bool enabled(WidgetTester tester, String label) =>
      tester
          .widget<FilledButton>(find.ancestor(
              of: find.text(label), matching: find.byType(FilledButton)))
          .onPressed !=
      null;

  group('VÉHICULE', () {
    Future<void> openVehicles(WidgetTester tester) async {
      await tester.tap(find.byIcon(Icons.more_horiz_outlined));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Véhicules'));
      await tester.pumpAndSettle();
    }

    testWidgets(
        'création : nom vide => désactivé ; nom => actif ; CV invalide => '
        'désactivé ; tous les champs visibles sans accordéon ; création OK',
        (tester) async {
      await pumpApp(tester);
      await openVehicles(tester);
      await tester.tap(find.byKey(const Key('add-vehicle-button')));
      await tester.pumpAndSettle();

      // Formulaire COMPLET par nature : tout visible, pas de section repliée.
      expect(find.text('Itinéraire et détails'), findsNothing);
      expect(find.text('Motorisation'), findsOneWidget);
      expect(find.text('Voiture'), findsOneWidget);
      expect(
          find.text('Puissance fiscale (CV, facultatif)'), findsOneWidget);
      expect(find.text('Immatriculation (facultatif)'), findsOneWidget);

      expect(enabled(tester, 'Ajouter le véhicule'), isFalse);

      await tester.enterText(
          find.widgetWithText(TextField, 'Nom'), 'Peugeot 2008');
      await tester.pump();
      expect(enabled(tester, 'Ajouter le véhicule'), isTrue);

      await tester.enterText(
          find.widgetWithText(TextField, 'Puissance fiscale (CV, facultatif)'),
          '0');
      await tester.pump();
      expect(enabled(tester, 'Ajouter le véhicule'), isFalse,
          reason: 'CV saisi invalide : même critère que le submit');

      await tester.enterText(
          find.widgetWithText(TextField, 'Puissance fiscale (CV, facultatif)'),
          '6');
      await tester.pump();
      await tester.tap(find.text('Ajouter le véhicule'));
      await tester.pumpAndSettle();

      final vehicles = await tester
          .runAsync(() => SembastVehicleRepository(database.db).getAll());
      expect(vehicles!.single.name, 'Peugeot 2008');
      expect(vehicles.single.fiscalPowerCv, 6);
      expect(find.text('Principal'), findsOneWidget,
          reason: 'premier véhicule = principal (comportement préservé)');
    });

    testWidgets('édition : valeurs préservées, Enregistrer épinglé actif',
        (tester) async {
      await pumpApp(tester);
      await openVehicles(tester);
      await tester.tap(find.byKey(const Key('add-vehicle-button')));
      await tester.pumpAndSettle();
      await tester.enterText(
          find.widgetWithText(TextField, 'Nom'), 'Clio');
      await tester.pump();
      await tester.tap(find.text('Ajouter le véhicule'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Clio'));
      await tester.pumpAndSettle();
      expect(enabled(tester, 'Enregistrer'), isTrue);
      expect(
          tester
              .widget<TextField>(find.widgetWithText(TextField, 'Nom'))
              .controller!
              .text,
          'Clio');
      await tester.enterText(
          find.widgetWithText(TextField, 'Nom'), 'Clio V');
      await tester.pump();
      await tester.tap(find.text('Enregistrer'));
      await tester.pumpAndSettle();
      expect(find.text('Clio V'), findsOneWidget);
      // L'archivage reste disponible, inchangé.
      expect(find.text('Archiver'), findsOneWidget);
    });
  });

  group('CONGÉS', () {
    Future<void> openVacations(WidgetTester tester) async {
      await tester.tap(find.byIcon(Icons.calendar_month_outlined));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('cal-vacations-button')));
      await tester.pumpAndSettle();
    }

    Future<void> pickDay(WidgetTester tester, String keyName, int day) async {
      await tester.tap(find.byKey(Key(keyName)));
      await tester.pumpAndSettle();
      await tester.tap(find.descendant(
          of: find.byType(DatePickerDialog), matching: find.text('$day')));
      await tester.tap(find.text('OK'));
      await tester.pumpAndSettle();
    }

    testWidgets(
        'sans dates => « Ajouter ces congés » désactivé ; plage valide => '
        'actif et période créée ; plage inversée => désactivé, AUCUNE '
        'écriture invalide', (tester) async {
      await pumpApp(tester);
      await openVacations(tester);

      expect(enabled(tester, 'Ajouter ces congés'), isFalse);
      expect(find.text('Fermer'), findsOneWidget); // en-tête, pas Annuler

      await pickDay(tester, 'vacation-start', 20);
      // Au := Du par défaut (comportement préservé) => déjà valide.
      expect(enabled(tester, 'Ajouter ces congés'), isTrue);

      await pickDay(tester, 'vacation-end', 22);
      await tester.tap(find.byKey(const Key('vacation-add')));
      await tester.pumpAndSettle();

      var periods = await tester
          .runAsync(() => SembastVacationRepository(database.db).getAll());
      expect(periods!.single.startDate, CivilDate(2026, 10, 20));
      expect(periods.single.endDate, CivilDate(2026, 10, 22));

      // Plage inversée : bouton désactivé, rien d'écrit en plus.
      await pickDay(tester, 'vacation-start', 25);
      await pickDay(tester, 'vacation-end', 23);
      expect(enabled(tester, 'Ajouter ces congés'), isFalse);
      periods = await tester
          .runAsync(() => SembastVacationRepository(database.db).getAll());
      expect(periods, hasLength(1), reason: 'aucune écriture invalide');

      // Suppression confirmée préservée.
      await tester.tap(find.byIcon(Icons.delete_outline).first);
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilledButton, 'Supprimer'));
      await tester.pumpAndSettle();
      periods = await tester
          .runAsync(() => SembastVacationRepository(database.db).getAll());
      expect(periods, isEmpty);
    });
  });

  group('RÉGLAGES', () {
    testWidgets(
        'page conservée : valeurs chargées, save-on-change intact, le '
        'parcours clavier Next/Done ne perd rien', (tester) async {
      await tester.runAsync(() => SembastSettingsRepository(database.db)
          .save(AppSettings(displayName: 'Ancien')));
      await pumpApp(tester);
      await tester.tap(find.byIcon(Icons.more_horiz_outlined));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Réglages'));
      await tester.pumpAndSettle();

      expect(find.byType(AppBar), findsOneWidget); // page, pas une feuille
      expect(find.text('Enregistrer'), findsNothing,
          reason: 'save-on-change : pas de bouton Enregistrer');
      expect(
          tester
              .widget<TextField>(
                  find.widgetWithText(TextField, 'Nom / structure'))
              .controller!
              .text,
          'Ancien');

      await tester.enterText(
          find.widgetWithText(TextField, 'Nom / structure'), 'Marc');
      await tester.testTextInput.receiveAction(TextInputAction.next);
      await tester.pump();
      await tester.enterText(
          find.widgetWithText(TextField, 'Adresse'), '12 rue des Lilas');
      await tester.testTextInput.receiveAction(TextInputAction.next);
      await tester.pump();
      await tester.enterText(
          find.widgetWithText(TextField, 'Ville'), 'Seilhac');
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pumpAndSettle();

      final saved = await tester.runAsync(
          () => SembastSettingsRepository(database.db).get());
      expect(saved!.displayName, 'Marc');
      expect(saved.address, '12 rue des Lilas');
      expect(saved.city, 'Seilhac');
    });
  });
}

