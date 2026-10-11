import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:mes_km/app.dart';
import 'package:mes_km/app/providers.dart';
import 'package:mes_km/data/local/app_database.dart';
import 'package:mes_km/data/local/sembast_day_extra_repository.dart';
import 'package:mes_km/data/local/sembast_trip_repository.dart';
import 'package:mes_km/data/local/sembast_vehicle_repository.dart';
import 'package:mes_km/domain/models/civil_date.dart';
import 'package:mes_km/domain/models/day_extra.dart';
import 'package:mes_km/domain/models/trip.dart';
import 'package:mes_km/domain/models/vehicle.dart';
import 'package:mes_km/features/statistics/monthly_bar_chart.dart';
import 'package:mes_km/widgets/km_format.dart';
import 'package:sembast/sembast_memory.dart' hide Finder;

void main() {
  final today = CivilDate(2026, 10, 11);

  setUpAll(() async => initializeDateFormatting('fr_FR'));

  late MesKmDatabase database;

  setUp(() async {
    database =
        await MesKmDatabase.open(newDatabaseFactoryMemory(), name: 'sui.db');
  });

  tearDown(() => database.close());

  Future<void> seedData(WidgetTester tester) async {
    await tester.runAsync(() async {
      await SembastVehicleRepository(database.db).put(Vehicle(
          id: 'peugeot', name: 'Peugeot 3008', category: VehicleCategory.car));
      await SembastVehicleRepository(database.db).put(Vehicle(
          id: 'clio',
          name: 'Ancienne Clio',
          category: VehicleCategory.car,
          archivedAt: DateTime.utc(2026, 6, 1)));
      await SembastTripRepository(database.db).put(Trip(
          id: 't-1',
          date: CivilDate(2026, 10, 5),
          distanceKm: 742,
          vehicleId: 'peugeot',
          createdAt: DateTime.utc(2026, 10, 5)));
      await SembastTripRepository(database.db).put(Trip(
          id: 't-2',
          date: CivilDate(2026, 3, 1),
          distanceKm: 840,
          vehicleId: 'clio',
          createdAt: DateTime.utc(2026, 3, 1)));
      await SembastDayExtraRepository(database.db)
          .set(DayExtra(date: CivilDate(2026, 10, 7), extraKm: 300));
      // Année précédente pour la comparaison.
      await SembastTripRepository(database.db).put(Trip(
          id: 't-old',
          date: CivilDate(2025, 6, 1),
          distanceKm: 1000,
          createdAt: DateTime.utc(2025, 6, 1)));
    });
  }

  Future<void> pumpOnStats(WidgetTester tester,
      {Size size = const Size(500, 1800)}) async {
    tester.view.physicalSize = size;
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
    await tester.tap(find.byIcon(Icons.bar_chart_outlined));
    await tester.pumpAndSettle();
  }

  testWidgets(
      'chiffres principaux, graphique, véhicules (actif + archivé + sans), '
      'mois et année par véhicule, comparaison N-1', (tester) async {
    await seedData(tester);
    await pumpOnStats(tester);

    expect(find.text('TOTAL ANNÉE'), findsOneWidget);
    expect(find.text(formatKmGrouped(1882)), findsOneWidget); // 742+840+300
    expect(find.text('Octobre 2026'), findsOneWidget);
    expect(find.text(formatKmGrouped(1042)), findsOneWidget); // mois : 742+300
    expect(find.text('Jours avec km'), findsOneWidget);
    expect(find.text('3'), findsOneWidget);
    expect(find.text('Moyenne / jour actif'), findsOneWidget);

    expect(find.byType(MonthlyBarChart), findsOneWidget);

    expect(find.text('PAR VÉHICULE'), findsOneWidget);
    expect(find.text('Peugeot 3008'), findsOneWidget);
    expect(
        find.text('Octobre : 742 km · 2026 : 742 km'), findsOneWidget);
    expect(find.text('Ancienne Clio (archivé)'), findsOneWidget);
    expect(find.text('Octobre : 0 km · 2026 : 840 km'), findsOneWidget);
    expect(find.text('Sans véhicule renseigné'), findsOneWidget);
    expect(find.text('Octobre : 300 km · 2026 : 300 km'), findsOneWidget);

    // Comparaison discrète avec 2025.
    expect(find.textContaining('vs 2025 : ${formatKmGrouped(1000)}'), findsOneWidget);
    expect(find.textContaining('+882 km'), findsOneWidget);
    expect(find.textContaining('+88,2 %'), findsOneWidget);
  });

  testWidgets('navigation année + mois + retour année courante',
      (tester) async {
    await seedData(tester);
    await pumpOnStats(tester);

    await tester.tap(find.byKey(const Key('stats-prev-year')));
    await tester.pumpAndSettle();
    expect(find.text('2025'), findsOneWidget);
    expect(find.text(formatKmGrouped(1000)), findsOneWidget);
    expect(find.byKey(const Key('stats-today-button')), findsOneWidget);

    await tester.tap(find.byKey(const Key('stats-today-button')));
    await tester.pumpAndSettle();
    expect(find.text('2026'), findsOneWidget);

    await tester.tap(find.byKey(const Key('stats-prev-month')));
    await tester.pumpAndSettle();
    expect(find.text('Septembre 2026'), findsOneWidget);
    expect(find.text('Septembre : 0 km · 2026 : 742 km'), findsOneWidget);
  });

  testWidgets('année vide : état propre à zéro, sans comparaison',
      (tester) async {
    await pumpOnStats(tester);

    await tester.tap(find.byKey(const Key('stats-prev-year')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('stats-prev-year')));
    await tester.pumpAndSettle();

    expect(find.text('2024'), findsOneWidget);
    expect(find.text('0 km'), findsWidgets);
    expect(find.text('Aucun kilomètre enregistré en 2024.'), findsOneWidget);
    expect(find.textContaining('vs 2023'), findsNothing);
  });

  testWidgets('petit iPhone (320x568) : aucun overflow', (tester) async {
    await seedData(tester);
    await pumpOnStats(tester, size: const Size(320, 568));

    // Le défilement atteint le bas sans exception de layout.
    await tester.drag(find.byType(ListView).first, const Offset(0, -1200));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });

  testWidgets(
      'rafraîchissement : saisie sur Aujourd’hui visible en revenant',
      (tester) async {
    await pumpOnStats(tester);
    expect(find.text('0 km'), findsWidgets);

    await tester.tap(find.byIcon(Icons.today_outlined));
    await tester.pumpAndSettle();
    await tester.enterText(
        find.byKey(const Key('day-total-field')), '87');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.bar_chart_outlined));
    await tester.pumpAndSettle();
    expect(find.text('87 km'), findsWidgets);
    expect(find.text('1'), findsOneWidget); // jours avec km
  });
}
