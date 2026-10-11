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
import 'package:mes_km/data/local/sembast_favorite_trip_repository.dart';
import 'package:mes_km/data/local/sembast_trip_repository.dart';
import 'package:mes_km/data/local/sembast_vacation_repository.dart';
import 'package:mes_km/domain/models/vacation_period.dart';
import 'package:mes_km/domain/models/civil_date.dart';
import 'package:mes_km/domain/models/day_extra.dart';
import 'package:mes_km/domain/models/favorite_trip.dart';
import 'package:mes_km/features/day/editable_day_total.dart';
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
    expect(find.byKey(const Key('cal-prev')), findsOneWidget);

    await tester.tap(navLabel('Aujourd’hui'));
    await tester.pumpAndSettle();
    expect(find.text('km aujourd’hui'), findsOneWidget);
  });

  testWidgets('Web réel : deux taps favori => deux Trips persistés (+48)',
      (tester) async {
    final database =
        await MesKmDatabase.open(newDatabaseFactoryMemory(), name: 'wf.db');
    addTearDown(database.close);

    await tester.runAsync(
        () => SembastFavoriteTripRepository(database.db).put(FavoriteTrip(
              id: 'fav-1',
              label: 'Cabinet ↔ EHPAD',
              distanceKm: 24,
              sortOrder: 0,
            )));

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

    await tester.tap(find.byKey(const Key('favorite-fav-1')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('favorite-fav-1')));
    await tester.pumpAndSettle();

    final totalText = tester
        .widget<TextField>(find.byKey(dayTotalFieldKey))
        .controller!
        .text;
    expect(totalText, '48');
    final trips = await tester
        .runAsync(() => SembastTripRepository(database.db).getByDate(day));
    expect(trips, hasLength(2));

    await tester.pump(const Duration(seconds: 1));
    await tester.pumpAndSettle();
  });

  testWidgets(
      'Web réel : calendrier — édition d’une journée passée, retour '
      'rafraîchi, navigation basse OK', (tester) async {
    final database =
        await MesKmDatabase.open(newDatabaseFactoryMemory(), name: 'wc.db');
    addTearDown(database.close);

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

    await tester.tap(find.byIcon(Icons.calendar_month_outlined));
    await tester.pumpAndSettle();
    expect(find.text('Octobre 2026'), findsOneWidget);

    // Tap au bord de la cellule du 5, édition rétroactive à 87.
    final rect =
        tester.getRect(find.byKey(const Key('cal-cell-2026-10-05')));
    await tester.tapAt(rect.topLeft + const Offset(4, 4));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(dayTotalFieldKey), '87');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pumpAndSettle();

    await tester.tap(find.byType(BackButton));
    await tester.pumpAndSettle();
    expect(
      find.descendant(
        of: find.byKey(const Key('cal-cell-2026-10-05')),
        matching: find.text('87 km'),
      ),
      findsOneWidget,
    );

    // Persistance IndexedDB vérifiée côté stockage.
    final stored = await tester.runAsync(() =>
        SembastDayExtraRepository(database.db)
            .getForDate(CivilDate(2026, 10, 5)));
    expect(stored?.extraKm, 87);

    // Navigation basse après clavier.
    await tester.tap(find.byIcon(Icons.today_outlined));
    await tester.pumpAndSettle();
    expect(find.text('km aujourd’hui'), findsOneWidget);
  });

  testWidgets(
      'Web réel : congés — période visible, retrait d\u2019un jour, '
      'persistance IndexedDB', (tester) async {
    final database =
        await MesKmDatabase.open(newDatabaseFactoryMemory(), name: 'wv.db');
    addTearDown(database.close);

    await tester.runAsync(() => SembastVacationRepository(database.db).put(
        VacationPeriod(
            id: 'p-1',
            startDate: CivilDate(2026, 10, 3),
            endDate: CivilDate(2026, 10, 10))));

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

    await tester.tap(find.byIcon(Icons.calendar_month_outlined));
    await tester.pumpAndSettle();
    expect(
      find.descendant(
          of: find.byKey(const Key('cal-cell-2026-10-05')),
          matching: find.text('Congé')),
      findsOneWidget,
    );

    // Retirer le congé du 6 depuis le détail.
    await tester.tap(find.byKey(const Key('cal-cell-2026-10-06')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('remove-vacation-button')));
    await tester.pumpAndSettle();
    await tester.tap(find.byType(BackButton));
    await tester.pumpAndSettle();

    expect(
      find.descendant(
          of: find.byKey(const Key('cal-cell-2026-10-06')),
          matching: find.text('Congé')),
      findsNothing,
    );

    final stored = await tester
        .runAsync(() => SembastVacationRepository(database.db).getAll());
    expect(stored, hasLength(2)); // 3-5 et 7-10, découpe persistée
  });
}
