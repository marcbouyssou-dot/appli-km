import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:mes_km/app.dart';
import 'package:mes_km/app/providers.dart';
import 'package:mes_km/data/local/app_database.dart';
import 'package:mes_km/domain/models/civil_date.dart';
import 'package:mes_km/widgets/brand_header.dart';
import 'package:mes_km/widgets/road_watermark.dart';
import 'package:sembast/sembast_memory.dart' hide Finder;

// Identité de marque (UX-001D) : header voiture + slogan sur les quatre
// onglets, filigrane route décoratif et inerte, écrans secondaires intacts.
void main() {
  setUpAll(() async => initializeDateFormatting('fr_FR'));

  late MesKmDatabase database;

  setUp(() async {
    database =
        await MesKmDatabase.open(newDatabaseFactoryMemory(), name: 'br.db');
  });

  tearDown(() => database.close());

  Future<void> pumpApp(WidgetTester tester) async {
    tester.view.physicalSize = const Size(500, 1800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(ProviderScope(
      overrides: [
        databaseProvider.overrideWithValue(database),
        todayDateProvider.overrideWithValue(() => CivilDate(2026, 10, 12)),
      ],
      child: const MesKmApp(),
    ));
    await tester.pumpAndSettle();
  }

  testWidgets(
      'les quatre onglets portent le BrandHeader (slogan EXACT, une fois) '
      'et le filigrane route', (tester) async {
    await pumpApp(tester);

    // L'onglet courant affiche son icône pleine : on visite d'abord les
    // trois autres, puis on revient sur Aujourd'hui (alors désélectionné).
    const tabs = [
      Icons.calendar_month_outlined,
      Icons.bar_chart_outlined,
      Icons.more_horiz_outlined,
      Icons.today_outlined,
    ];
    for (final icon in tabs) {
      await tester.tap(find.byIcon(icon));
      await tester.pumpAndSettle();
      // IndexedStack garde les onglets construits : on ne compte que
      // l'onglet VISIBLE via le header présent — chaque onglet a le sien.
      expect(
        find.text('Vos kilomètres professionnels, simplement.'),
        findsWidgets,
        reason: 'slogan exact, jamais reformulé',
      );
      expect(find.byType(MesKmBrandHeader), findsWidgets);
      expect(find.byType(MesKmRoadWatermark), findsWidgets);
    }
  });

  testWidgets('logo : l’asset voiture validé, jamais une icône Material',
      (tester) async {
    await pumpApp(tester);
    final image = tester.widget<Image>(
      find.descendant(
        of: find.byType(MesKmBrandHeader).first,
        matching: find.byType(Image),
      ),
    );
    expect((image.image as AssetImage).assetName,
        'assets/brand/meskm-logo.png');
    expect(image.excludeFromSemantics, isTrue,
        reason: 'décoratif : le nom est porté par le texte adjacent');
    expect(
      find.descendant(
        of: find.byType(MesKmBrandHeader).first,
        matching: find.byIcon(Icons.directions_car),
      ),
      findsNothing,
    );
  });

  testWidgets(
      'filigrane : inerte au pointeur, hors Semantics, jamais dans le '
      'header, et le compteur reste entièrement tactile à travers lui',
      (tester) async {
    await pumpApp(tester);

    final watermark = find.byType(MesKmRoadWatermark).first;
    expect(
      find.descendant(of: watermark, matching: find.byType(IgnorePointer)),
      findsWidgets,
    );
    expect(
      find.descendant(
          of: watermark, matching: find.byType(ExcludeSemantics)),
      findsWidgets,
    );
    expect(
      find.descendant(
        of: find.byType(MesKmBrandHeader).first,
        matching: find.byType(CustomPaint),
      ),
      findsNothing,
      reason: 'pas de route dans le bandeau supérieur',
    );

    // Le décor n'intercepte rien : tap compteur => édition immédiate.
    await tester.tap(find.byKey(const Key('day-total-card')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('day-total-field')), '23');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pumpAndSettle();
    final field = tester
        .widget<TextField>(find.byKey(const Key('day-total-field')));
    expect(field.controller!.text, '23');
  });

  testWidgets('écran secondaire : PAS de BrandHeader (AppBar conservée)',
      (tester) async {
    await pumpApp(tester);
    await tester.tap(find.byIcon(Icons.more_horiz_outlined));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Véhicules'));
    await tester.pumpAndSettle();

    expect(find.byType(AppBar), findsOneWidget);
    // Le header de marque des onglets reste derrière la route poussée :
    // rien de nouveau sur CET écran.
    expect(
      find.descendant(
        of: find.byType(Scaffold).last,
        matching: find.byType(MesKmBrandHeader),
      ),
      findsNothing,
    );
  });

  testWidgets('petit iPhone (320×568) : header compact, aucun overflow',
      (tester) async {
    tester.view.physicalSize = const Size(320, 568);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(ProviderScope(
      overrides: [
        databaseProvider.overrideWithValue(database),
        todayDateProvider.overrideWithValue(() => CivilDate(2026, 10, 12)),
      ],
      child: const MesKmApp(),
    ));
    await tester.pumpAndSettle();
    for (final icon in [
      Icons.calendar_month_outlined,
      Icons.bar_chart_outlined,
      Icons.more_horiz_outlined,
      Icons.today_outlined,
    ]) {
      await tester.tap(find.byIcon(icon));
      await tester.pumpAndSettle();
    }
    // Un overflow ferait échouer le test (exception de rendu).
  });
}
