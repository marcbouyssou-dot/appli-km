import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:mes_km/app.dart';
import 'package:mes_km/app/providers.dart';
import 'package:mes_km/data/local/app_database.dart';
import 'package:sembast/sembast_memory.dart';

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
    expect(find.text('0 km'), findsOneWidget);
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
    expect(find.text('0 km'), findsOneWidget);
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
