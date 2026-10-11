import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:mes_km/app.dart';
import 'package:mes_km/app/providers.dart';
import 'package:mes_km/data/local/app_database.dart';
import 'package:mes_km/features/today/editable_day_total.dart';
import 'package:sembast/sembast_memory.dart' hide Finder;

void main() {
  setUpAll(() async {
    await initializeDateFormatting('fr_FR');
  });

  late MesKmDatabase database;

  setUp(() async {
    database =
        await MesKmDatabase.open(newDatabaseFactoryMemory(), name: 'shell.db');
  });

  tearDown(() => database.close());

  Future<void> pumpApp(WidgetTester tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [databaseProvider.overrideWithValue(database)],
        child: const MesKmApp(),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('Mes Km démarre sans crash sur l’écran Aujourd’hui',
      (tester) async {
    await pumpApp(tester);

    expect(find.byType(NavigationBar), findsOneWidget);
    // La grande valeur éditable affiche 0 pour une journée vide.
    final totalField =
        tester.widget<TextField>(find.byKey(dayTotalFieldKey));
    expect(totalField.controller!.text, '0');
    expect(find.text('km aujourd’hui'), findsOneWidget);
  });

  testWidgets('les 4 destinations sont présentes', (tester) async {
    await pumpApp(tester);

    expect(find.widgetWithText(NavigationBar, 'Aujourd’hui'),
        findsOneWidget);
    expect(find.widgetWithText(NavigationBar, 'Calendrier'), findsOneWidget);
    expect(find.widgetWithText(NavigationBar, 'Statistiques'), findsOneWidget);
    expect(find.widgetWithText(NavigationBar, 'Plus'), findsOneWidget);
  });

  testWidgets('chaque onglet s’ouvre correctement', (tester) async {
    await pumpApp(tester);

    await tester.tap(find.byIcon(Icons.calendar_month_outlined));
    await tester.pumpAndSettle();
    expect(find.text('Le calendrier de vos kilomètres'), findsOneWidget);

    await tester.tap(find.byIcon(Icons.bar_chart_outlined));
    await tester.pumpAndSettle();
    expect(find.text('Vos statistiques kilométriques'), findsOneWidget);

    await tester.tap(find.byIcon(Icons.more_horiz_outlined));
    await tester.pumpAndSettle();
    expect(find.text('Véhicules'), findsOneWidget);
    expect(find.text('Documents'), findsOneWidget);
    expect(find.text('Sauvegarde'), findsOneWidget);
    expect(find.text('Réglages'), findsOneWidget);

    await tester.tap(find.byIcon(Icons.today_outlined));
    await tester.pumpAndSettle();
    expect(find.text('km aujourd’hui'), findsOneWidget);
  });

  testWidgets(
      'viewport iPhone : chaque destination répond à un tap sur son libellé',
      (tester) async {
    // Dimensions logiques d'un iPhone récent.
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await pumpApp(tester);

    Finder navLabel(String label) => find.descendant(
          of: find.byType(NavigationBar),
          matching: find.text(label),
        );

    await tester.tap(navLabel('Calendrier'));
    await tester.pumpAndSettle();
    expect(find.text('Le calendrier de vos kilomètres'), findsOneWidget);

    await tester.tap(navLabel('Statistiques'));
    await tester.pumpAndSettle();
    expect(find.text('Vos statistiques kilométriques'), findsOneWidget);

    await tester.tap(navLabel('Plus'));
    await tester.pumpAndSettle();
    expect(find.text('Réglages'), findsOneWidget);

    await tester.tap(navLabel('Aujourd’hui'));
    await tester.pumpAndSettle();
    expect(find.text('km aujourd’hui'), findsOneWidget);
  });

  testWidgets('le thème suit le mode système (clair/sombre)', (tester) async {
    tester.platformDispatcher.platformBrightnessTestValue = Brightness.dark;
    addTearDown(tester.platformDispatcher.clearPlatformBrightnessTestValue);

    await pumpApp(tester);

    final context = tester.element(find.byType(NavigationBar));
    expect(Theme.of(context).brightness, Brightness.dark);

    tester.platformDispatcher.platformBrightnessTestValue = Brightness.light;
    await tester.pumpAndSettle();

    final lightContext = tester.element(find.byType(NavigationBar));
    expect(Theme.of(lightContext).brightness, Brightness.light);
  });
}
