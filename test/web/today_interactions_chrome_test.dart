@TestOn('browser')
library;

// Interactions critiques sur MOTEUR WEB RÉEL (Chrome) :
// grande carte tactile, remise à zéro, navigation basse après édition.
// Exécution explicite : flutter test --platform chrome test/web

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart' hide Finder;
import 'package:flutter_test/flutter_test.dart' show Finder;
import 'package:intl/date_symbol_data_local.dart';
import 'package:mes_km/app.dart';
import 'package:mes_km/app/providers.dart';
import 'package:mes_km/data/local/app_database.dart';
import 'package:mes_km/data/local/sembast_day_extra_repository.dart';
import 'package:mes_km/domain/models/civil_date.dart';
import 'package:mes_km/domain/models/day_extra.dart';
import 'package:mes_km/features/today/editable_day_total.dart';
import 'package:sembast/sembast_memory.dart' hide Finder;

void main() {
  final day = CivilDate(2026, 10, 11);

  setUpAll(() async => initializeDateFormatting('fr_FR'));

  testWidgets(
      'Web réel : tap bord de carte => édition ; 33 -> 0 ; navigation OK '
      'après édition', (tester) async {
    final database =
        await MesKmDatabase.open(newDatabaseFactoryMemory(), name: 'w.db');
    addTearDown(database.close);

    await tester.runAsync(() => SembastDayExtraRepository(database.db)
        .set(DayExtra(date: day, extraKm: 33)));

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
    String totalText() => tester
        .widget<TextField>(find.byKey(dayTotalFieldKey))
        .controller!
        .text;
    expect(totalText(), '33');

    // Un seul tap au bord de la carte : focus immédiat.
    final cardRect = tester.getRect(find.byKey(dayTotalCardKey));
    await tester.tapAt(cardRect.topLeft + const Offset(12, 12));
    await tester.pumpAndSettle();
    final editable = tester.widget<EditableText>(find.descendant(
      of: find.byKey(dayTotalFieldKey),
      matching: find.byType(EditableText),
    ));
    expect(editable.focusNode.hasFocus, isTrue);

    // Remise à zéro par saisie directe.
    await tester.enterText(find.byKey(dayTotalFieldKey), '0');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pumpAndSettle();
    expect(totalText(), '0');
    final stored = await tester.runAsync(
        () => SembastDayExtraRepository(database.db).getForDate(day));
    expect(stored, isNull);

    // Navigation basse fonctionnelle après édition/fermeture clavier.
    Finder navLabel(String label) => find.descendant(
          of: find.byType(NavigationBar),
          matching: find.text(label),
        );
    await tester.tap(navLabel('Calendrier'));
    await tester.pumpAndSettle();
    expect(find.text('Le calendrier de vos kilomètres'), findsOneWidget);

    await tester.tap(navLabel('Aujourd’hui'));
    await tester.pumpAndSettle();
    expect(find.text('km aujourd’hui'), findsOneWidget);
  });
}
