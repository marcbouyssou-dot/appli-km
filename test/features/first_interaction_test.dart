import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:mes_km/app.dart';
import 'package:mes_km/app/providers.dart';
import 'package:mes_km/data/local/app_database.dart';
import 'package:mes_km/domain/models/civil_date.dart';
import 'package:mes_km/features/day/editable_day_total.dart';
import 'package:sembast/sembast_memory.dart' hide Finder;

/// FIRST INTERACTION AFTER STARTUP — régression du bug KM-006D :
/// sur app fraîche, la TOUTE PREMIÈRE interaction doit fonctionner,
/// sans avoir touché le compteur au préalable.
///
/// NOTE : ces tests ne reproduisent pas Safari iOS (géométrie de la page
/// hôte) — ils verrouillent le comportement Flutter ; la partie Safari est
/// couverte par la recette iPhone dédiée.
void main() {
  final day = CivilDate(2026, 10, 11);

  setUpAll(() async => initializeDateFormatting('fr_FR'));

  late MesKmDatabase database;

  setUp(() async {
    database =
        await MesKmDatabase.open(newDatabaseFactoryMemory(), name: 'fi.db');
  });

  tearDown(() => database.close());

  /// Instance fraîche de l'app, aucune interaction préalable.
  Future<void> pumpFreshApp(WidgetTester tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(ProviderScope(
      overrides: [
        databaseProvider.overrideWithValue(database),
        todayDateProvider.overrideWithValue(() => day),
      ],
      child: const MesKmApp(),
    ));
    await tester.pumpAndSettle();
  }

  Finder navLabel(String label) => find.descendant(
        of: find.byType(NavigationBar),
        matching: find.text(label),
      );

  testWidgets('aucun champ texte n’a le focus au premier frame',
      (tester) async {
    await pumpFreshApp(tester);

    final editables = tester.widgetList<EditableText>(
      find.byType(EditableText, skipOffstage: false),
    );
    for (final editable in editables) {
      expect(editable.focusNode.hasFocus, isFalse);
    }
  });

  testWidgets('première interaction = tap Calendrier => s’ouvre',
      (tester) async {
    await pumpFreshApp(tester);

    await tester.tap(navLabel('Calendrier'));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('cal-prev')), findsOneWidget);
  });

  testWidgets('première interaction = tap Statistiques => s’ouvre',
      (tester) async {
    await pumpFreshApp(tester);

    await tester.tap(navLabel('Statistiques'));
    await tester.pumpAndSettle();

    expect(find.text('Vos statistiques kilométriques'), findsOneWidget);
  });

  testWidgets('première interaction = tap Plus => s’ouvre',
      (tester) async {
    await pumpFreshApp(tester);

    await tester.tap(navLabel('Plus'));
    await tester.pumpAndSettle();

    expect(find.text('Trajets favoris'), findsOneWidget);
    expect(find.text('Réglages'), findsOneWidget);
  });

  testWidgets(
      'première interaction = compteur => fonctionne, puis navigation OK',
      (tester) async {
    await pumpFreshApp(tester);

    await tester.tap(find.byKey(dayTotalCardKey));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(dayTotalFieldKey), '87');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pumpAndSettle();

    final field =
        tester.widget<TextField>(find.byKey(dayTotalFieldKey));
    expect(field.controller!.text, '87');

    await tester.tap(navLabel('Calendrier'));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('cal-prev')), findsOneWidget);
  });
}
