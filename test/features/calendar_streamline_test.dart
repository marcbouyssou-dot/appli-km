import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:mes_km/app.dart';
import 'package:mes_km/app/providers.dart';
import 'package:mes_km/data/local/app_database.dart';
import 'package:mes_km/data/local/sembast_trip_repository.dart';
import 'package:mes_km/data/local/sembast_vacation_repository.dart';
import 'package:mes_km/domain/models/civil_date.dart';
import 'package:mes_km/domain/models/trip.dart';
import 'package:mes_km/domain/models/vacation_period.dart';
import 'package:mes_km/widgets/km_format.dart';
import 'package:sembast/sembast_memory.dart' hide Finder;

// UX-004B : calendrier « month at a glance » — preuves des directions
// humaines (dont le suffixe « km » CONSERVÉ dans chaque cellule travaillée).
void main() {
  final today = CivilDate(2026, 10, 12);

  setUpAll(() async => initializeDateFormatting('fr_FR'));

  late MesKmDatabase database;

  setUp(() async {
    database =
        await MesKmDatabase.open(newDatabaseFactoryMemory(), name: 'cs.db');
  });

  tearDown(() => database.close());

  Future<void> seedTrip(WidgetTester tester, CivilDate date, double km) =>
      tester.runAsync(() => SembastTripRepository(database.db).put(Trip(
            id: 't-${date.toIso8601()}-$km',
            date: date,
            distanceKm: km,
            createdAt: DateTime.utc(date.year, date.month, date.day, 9),
          )));

  Future<void> pumpOnCalendar(WidgetTester tester) async {
    tester.view.physicalSize = const Size(500, 1400);
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
    await tester.tap(find.byIcon(Icons.calendar_month_outlined));
    await tester.pumpAndSettle();
  }

  testWidgets(
      'en-tête : plus de grand titre « Calendrier » dans le contenu, le '
      'mois est le premier titre ; BrandHeader intact', (tester) async {
    await pumpOnCalendar(tester);

    expect(
      find.descendant(
        of: find.byType(ListView),
        matching: find.text('Calendrier'),
      ),
      findsNothing,
    );
    expect(find.widgetWithText(NavigationBar, 'Calendrier'), findsOneWidget);
    expect(find.text('Octobre 2026'), findsOneWidget);
    expect(find.text('Vos kilomètres professionnels, simplement.'),
        findsWidgets);
  });

  testWidgets(
      'total mensuel : milliers groupés avec « km », couleur DONNÉE '
      '(encre, pas le bleu action)', (tester) async {
    await seedTrip(tester, CivilDate(2026, 10, 5), 800);
    await seedTrip(tester, CivilDate(2026, 10, 6), 434);
    await pumpOnCalendar(tester);

    final totalFinder = find.text(formatKmGrouped(1234)); // « 1 234 km »
    expect(totalFinder, findsOneWidget);
    final text = tester.widget<Text>(totalFinder);
    final context = tester.element(totalFinder);
    expect(text.style?.color, Theme.of(context).colorScheme.onSurface,
        reason: 'héros donnée = encre ; le bleu reste pour les actions');
  });

  testWidgets('jours de semaine désambiguïsés : L Ma Me J V S D',
      (tester) async {
    await pumpOnCalendar(tester);
    for (final label in ['L', 'Ma', 'Me', 'J', 'V', 'S', 'D']) {
      expect(find.text(label), findsOneWidget, reason: label);
    }
  });

  testWidgets(
      'cellule travaillée : numéro + « N km » (suffixe CONSERVÉ — décision '
      'humaine), typographie du thème, aujourd’hui lisible, tap → détail',
      (tester) async {
    await seedTrip(tester, today, 25);
    await pumpOnCalendar(tester);

    final cell = find.byKey(const Key('cal-cell-2026-10-12'));
    expect(
        find.descendant(of: cell, matching: find.text('12')), findsOneWidget);
    final kmText = find.descendant(of: cell, matching: find.text('25 km'));
    expect(kmText, findsOneWidget,
        reason: 'le suffixe « km » doit rester visible dans la cellule');
    // Typographie dérivée du thème (plus de 10 px en dur).
    final style = tester.widget<Text>(kmText).style;
    final context = tester.element(kmText);
    expect(style?.fontSize, Theme.of(context).textTheme.labelSmall?.fontSize);

    await tester.tap(cell);
    await tester.pumpAndSettle();
    expect(find.text('Lundi 12 octobre 2026'), findsOneWidget);
    await tester.tap(find.byType(BackButton));
    await tester.pumpAndSettle();
    expect(find.text('Octobre 2026'), findsOneWidget,
        reason: 'mois conservé au retour');
  });

  testWidgets(
      'congés : CHAQUE jour de la période garde son libellé « Congé » '
      '(comportement simple conservé — décision humaine)', (tester) async {
    await tester.runAsync(() => SembastVacationRepository(database.db)
        .put(VacationPeriod(
            id: 'p-1',
            startDate: CivilDate(2026, 10, 20),
            endDate: CivilDate(2026, 10, 22))));
    await pumpOnCalendar(tester);

    for (final day in [20, 21, 22]) {
      expect(
        find.descendant(
            of: find.byKey(Key('cal-cell-2026-10-$day')),
            matching: find.text('Congé')),
        findsOneWidget,
        reason: 'jour $day',
      );
    }
  });

  testWidgets(
      '« Ajouter des congés » vit SOUS la grille et ouvre la même feuille',
      (tester) async {
    await pumpOnCalendar(tester);

    final buttonY = tester
        .getTopLeft(find.byKey(const Key('cal-vacations-button')))
        .dy;
    final lastCellY = tester
        .getBottomLeft(find.byKey(const Key('cal-cell-2026-10-31')))
        .dy;
    expect(buttonY, greaterThan(lastCellY),
        reason: 'l’action rare vient après la grille');

    await tester.tap(find.byKey(const Key('cal-vacations-button')));
    await tester.pumpAndSettle();
    expect(find.text('Congés'), findsOneWidget);
    expect(find.text('Ajouter ces congés'), findsOneWidget);
  });
}
