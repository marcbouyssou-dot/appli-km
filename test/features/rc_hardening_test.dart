import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:mes_km/app.dart';
import 'package:mes_km/app/providers.dart';
import 'package:mes_km/data/local/app_database.dart';
import 'package:mes_km/data/local/sembast_favorite_trip_repository.dart';
import 'package:mes_km/data/local/sembast_trip_repository.dart';
import 'package:mes_km/data/local/sembast_vacation_repository.dart';
import 'package:mes_km/domain/models/civil_date.dart';
import 'package:mes_km/domain/models/favorite_trip.dart';
import 'package:mes_km/domain/models/trip.dart';
import 'package:mes_km/domain/models/vacation_period.dart';
import 'package:sembast/sembast_memory.dart' hide Finder;

// UX-007B : durcissement RC — matrice viewport × échelle AVEC DONNÉES
// (l'angle mort des tests précédents), et Semantics critiques.
void main() {
  final today = CivilDate(2026, 10, 12);

  setUpAll(() async => initializeDateFormatting('fr_FR'));

  late MesKmDatabase database;

  setUp(() async {
    database = await MesKmDatabase.open(newDatabaseFactoryMemory(),
        name: 'rc.db');
  });

  tearDown(() => database.close());

  Future<void> seed(WidgetTester tester) => tester.runAsync(() async {
        await SembastFavoriteTripRepository(database.db).put(FavoriteTrip(
            id: 'f1',
            label: 'Travail',
            distanceKm: 70,
            sortOrder: 0,
            origin: 'Maison',
            destination: 'Cabinet'));
        await SembastTripRepository(database.db).put(Trip(
            id: 't1',
            date: today,
            distanceKm: 25,
            createdAt: DateTime.utc(2026, 10, 12, 9)));
        await SembastVacationRepository(database.db).put(VacationPeriod(
            id: 'p1',
            startDate: CivilDate(2026, 10, 20),
            endDate: CivilDate(2026, 10, 22)));
      });

  Future<void> pumpApp(WidgetTester tester,
      {required Size size, required double scale}) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1.0;
    tester.platformDispatcher.textScaleFactorTestValue = scale;
    addTearDown(tester.view.reset);
    addTearDown(tester.platformDispatcher.clearAllTestValues);
    await tester.pumpWidget(ProviderScope(
      overrides: [
        databaseProvider.overrideWithValue(database),
        todayDateProvider.overrideWithValue(() => today),
      ],
      child: const MesKmApp(),
    ));
    await tester.pumpAndSettle();
  }

  group('AUJOURD’HUI + FAVORI — matrice sans débordement', () {
    for (final (size, scale) in [
      (const Size(320, 568), 1.0),
      (const Size(390, 844), 1.0),
      (const Size(390, 844), 1.3),
      (const Size(390, 844), 1.5),
      (const Size(390, 844), 2.0),
    ]) {
      testWidgets('${size.width.toInt()}×${size.height.toInt()} @ $scale',
          (tester) async {
        await seed(tester);
        await pumpApp(tester, size: size, scale: scale);
        // Un débordement lèverait une exception de rendu => échec.
        expect(find.text('+70 km'), findsOneWidget);
        expect(find.byKey(const Key('edit-favorite-f1')), findsOneWidget);
      });
    }

    testWidgets('320 @ 1.0 : 1 tap ajoute, Modifier reste distinct',
        (tester) async {
      await seed(tester);
      await pumpApp(tester, size: const Size(320, 568), scale: 1.0);

      await tester.ensureVisible(find.byKey(const Key('favorite-f1')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('favorite-f1')));
      await tester.pumpAndSettle();
      await tester.pump(const Duration(seconds: 1));
      await tester.pumpAndSettle();
      var trips = await tester
          .runAsync(() => SembastTripRepository(database.db).getAll());
      expect(trips, hasLength(2), reason: 'ajout 1 tap intact');

      final editButton = find.byKey(const Key('edit-favorite-f1'));
      expect(tester.getSize(editButton).height, greaterThanOrEqualTo(48));
      await tester.ensureVisible(editButton);
      await tester.pumpAndSettle();
      await tester.tap(editButton);
      await tester.pumpAndSettle();
      expect(find.text('Modifier le favori'), findsOneWidget);
      trips = await tester
          .runAsync(() => SembastTripRepository(database.db).getAll());
      expect(trips, hasLength(2), reason: 'Modifier n’ajoute jamais');
    });
  });

  group('CALENDRIER avec données — matrice sans débordement', () {
    for (final scale in [1.0, 1.3, 1.5, 2.0]) {
      testWidgets('390×844 @ $scale : « 25 km » et « Congé » rendus',
          (tester) async {
        await seed(tester);
        await pumpApp(tester,
            size: const Size(390, 844), scale: scale);
        await tester.tap(find.byIcon(Icons.calendar_month_outlined));
        await tester.pumpAndSettle();

        expect(
          find.descendant(
              of: find.byKey(const Key('cal-cell-2026-10-12')),
              matching: find.text('25 km')),
          findsOneWidget,
          reason: 'suffixe km conservé à l’échelle $scale',
        );
        expect(
          find.descendant(
              of: find.byKey(const Key('cal-cell-2026-10-21')),
              matching: find.text('Congé')),
          findsOneWidget,
        );
      });
    }

    testWidgets('échelle 1.0 : hauteur de cellule inchangée (58)',
        (tester) async {
      await seed(tester);
      await pumpApp(tester, size: const Size(390, 844), scale: 1.0);
      await tester.tap(find.byIcon(Icons.calendar_month_outlined));
      await tester.pumpAndSettle();
      expect(
          tester
              .getSize(find.byKey(const Key('cal-cell-2026-10-12')))
              .height,
          60, // 58 + 2 px de marge interne (1 px de chaque côté)
          reason: 'apparence HUMAN PASS sanctuarisée à l’échelle 1');
    });
  });

  group('SEMANTICS critiques', () {
    testWidgets(
        'compteur : « Total du jour » + valeur, modifiable ; cellules '
        'calendrier : une annonce par jour ; graphique : résumé',
        (tester) async {
      final handle = tester.ensureSemantics();
      await seed(tester);
      await pumpApp(tester, size: const Size(500, 1400), scale: 1.0);

      // Compteur.
      final counter =
          tester.getSemantics(find.byKey(const Key('day-total-field')));
      expect(counter.label, contains('Total du jour'));
      expect(counter.hint, contains('modifiable'));
      expect(counter.value, '25');

      // Cellules calendrier : une unité, sans doublons.
      await tester.tap(find.byIcon(Icons.calendar_month_outlined));
      await tester.pumpAndSettle();
      final worked = tester
          .getSemantics(find.byKey(const Key('cal-cell-2026-10-12')));
      expect(worked.label, 'Lundi 12 octobre 2026, aujourd’hui, 25 km');
      expect(worked.flagsCollection.isButton, isTrue);
      final vacation = tester
          .getSemantics(find.byKey(const Key('cal-cell-2026-10-21')));
      expect(vacation.label, 'Mercredi 21 octobre 2026, congé');
      final empty = tester
          .getSemantics(find.byKey(const Key('cal-cell-2026-10-15')));
      expect(empty.label, 'Jeudi 15 octobre 2026');

      // Graphique : un résumé concis.
      await tester.tap(find.byIcon(Icons.bar_chart_outlined));
      await tester.pumpAndSettle();
      expect(
        find.bySemanticsLabel(RegExp(
            r'Évolution mensuelle des kilomètres\. Maximum : octobre')),
        findsOneWidget,
      );
      handle.dispose();
    });
  });
}
