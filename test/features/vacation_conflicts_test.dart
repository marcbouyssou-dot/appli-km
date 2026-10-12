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
import 'package:mes_km/features/day/editable_day_total.dart';
import 'package:sembast/sembast_memory.dart' hide Finder;

/// Conflits congé <-> kilomètres : jamais les deux états silencieusement.
void main() {
  final today = CivilDate(2026, 10, 11);

  setUpAll(() async => initializeDateFormatting('fr_FR'));

  late MesKmDatabase database;

  setUp(() async {
    database =
        await MesKmDatabase.open(newDatabaseFactoryMemory(), name: 'vc.db');
  });

  tearDown(() => database.close());

  Future<void> seedPeriod(
      WidgetTester tester, CivilDate start, CivilDate end) async {
    await tester.runAsync(() => SembastVacationRepository(database.db).put(
        VacationPeriod(id: 'p-${start.toIso8601()}', startDate: start, endDate: end)));
  }

  Future<void> seedTrip(WidgetTester tester, CivilDate date, double km) async {
    await tester.runAsync(() => SembastTripRepository(database.db).put(Trip(
          id: 't-${date.toIso8601()}',
          date: date,
          distanceKm: km,
          createdAt: DateTime.utc(2026, 1, 1),
        )));
  }

  Future<void> seedFavorite(WidgetTester tester) async {
    await tester.runAsync(
        () => SembastFavoriteTripRepository(database.db).put(FavoriteTrip(
              id: 'fav-1',
              label: 'Cabinet ↔ EHPAD',
              distanceKm: 24,
              sortOrder: 0,
            )));
  }

  Future<void> pumpApp(WidgetTester tester) async {
    tester.view.physicalSize = const Size(500, 1800);
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

  Future<List<VacationPeriod>> storedPeriods(WidgetTester tester) async =>
      (await tester
          .runAsync(() => SembastVacationRepository(database.db).getAll()))!;

  testWidgets(
      'journée avec km : « Marquer comme congé » n’est plus proposé '
      '(UX-002B : l’action ne peut pas réussir), km intacts — la règle '
      'congé ≠ km reste couverte par le garde (tests ci-dessous)',
      (tester) async {
    await seedTrip(tester, today, 42);
    await pumpApp(tester);

    expect(find.byKey(const Key('mark-vacation-button')), findsNothing);
    expect(find.byKey(const Key('clear-day-button')), findsOneWidget,
        reason: 'une seule action exceptionnelle à la fois');

    expect(await storedPeriods(tester), isEmpty);
    expect(find.text('42 km'), findsOneWidget); // km intacts
  });

  testWidgets(
      'aujourd’hui en congé : état « Congé » à la place du compteur, '
      'retrait possible', (tester) async {
    await seedPeriod(tester, today, today);
    await pumpApp(tester);

    expect(find.byKey(const Key('vacation-card')), findsOneWidget);
    expect(find.text('Congé'), findsOneWidget);
    expect(find.byKey(dayTotalFieldKey), findsNothing); // pas de faux total
    expect(find.byKey(const Key('mark-vacation-button')), findsNothing);

    await tester.tap(find.byKey(const Key('remove-vacation-button')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('vacation-card')), findsNothing);
    expect(find.byKey(dayTotalFieldKey), findsOneWidget);
    expect(await storedPeriods(tester), isEmpty);
  });

  testWidgets(
      'jour congé + « Ajouter un trajet » : Annuler ne change rien ; '
      'confirmer retire le jour et enregistre le trajet (période découpée)',
      (tester) async {
    await seedPeriod(tester, CivilDate(2026, 10, 3), CivilDate(2026, 10, 10));
    await seedPeriod(tester, today, today);
    await pumpApp(tester);

    // Annulation.
    await tester.tap(find.text('Ajouter un trajet'));
    await tester.pumpAndSettle();
    expect(
      find.text('Cette journée est marquée comme congé.'),
      findsOneWidget,
    );
    await tester.tap(find.text('Annuler'));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('vacation-card')), findsOneWidget);
    expect(await storedPeriods(tester), hasLength(2));

    // Confirmation puis saisie du trajet.
    await tester.tap(find.text('Ajouter un trajet'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Retirer le congé et continuer'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.widgetWithText(TextField, 'Distance comptabilisée (km)'),
      '24',
    );
    await tester.pump(); // bouton actif (UX-003B1)
    await tester.tap(find.text('Ajouter'));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('vacation-card')), findsNothing);
    expect(find.text('24 km'), findsOneWidget);
    // L'autre période (3-10) est intacte.
    final remaining = await storedPeriods(tester);
    expect(remaining, hasLength(1));
    expect(remaining.single.startDate, CivilDate(2026, 10, 3));
    expect(remaining.single.endDate, CivilDate(2026, 10, 10));
  });

  testWidgets(
      'jour congé + favori : confirmation, retrait du jour, Trip ajouté',
      (tester) async {
    await seedFavorite(tester);
    await seedPeriod(tester, today, today);
    await pumpApp(tester);

    await tester.tap(find.byKey(const Key('favorite-fav-1')));
    await tester.pumpAndSettle();
    expect(
      find.text('Cette journée est marquée comme congé.'),
      findsOneWidget,
    );
    await tester.tap(find.text('Retirer le congé et continuer'));
    await tester.pumpAndSettle();
    await tester.pump(const Duration(seconds: 1));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('vacation-card')), findsNothing);
    final field = tester.widget<TextField>(find.byKey(dayTotalFieldKey));
    expect(field.controller!.text, '24');
    expect(await storedPeriods(tester), isEmpty);
  });
}
