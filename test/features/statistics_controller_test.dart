import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mes_km/app/providers.dart';
import 'package:mes_km/data/local/app_database.dart';
import 'package:mes_km/data/local/sembast_day_extra_repository.dart';
import 'package:mes_km/data/local/sembast_settings_repository.dart';
import 'package:mes_km/data/local/sembast_trip_repository.dart';
import 'package:mes_km/data/local/sembast_vacation_repository.dart';
import 'package:mes_km/data/local/sembast_vehicle_repository.dart';
import 'package:mes_km/domain/models/app_settings.dart';
import 'package:mes_km/domain/models/civil_date.dart';
import 'package:mes_km/domain/models/day_extra.dart';
import 'package:mes_km/domain/models/trip.dart';
import 'package:mes_km/domain/models/vacation_period.dart';
import 'package:mes_km/domain/models/vehicle.dart';
import 'package:mes_km/features/day/day_controller.dart';
import 'package:mes_km/features/statistics/statistics_controller.dart';
import 'package:sembast/sembast_memory.dart' hide Finder;

void main() {
  final today = CivilDate(2026, 10, 11);
  late MesKmDatabase database;
  late ProviderContainer container;

  setUp(() async {
    database =
        await MesKmDatabase.open(newDatabaseFactoryMemory(), name: 'st.db');
    container = ProviderContainer(overrides: [
      databaseProvider.overrideWithValue(database),
      todayDateProvider.overrideWithValue(() => today),
    ]);
    addTearDown(container.dispose);
  });

  tearDown(() => database.close());

  StatisticsController controller() =>
      container.read(statisticsControllerProvider.notifier);

  Future<StatisticsState> state() =>
      container.read(statisticsControllerProvider.future);

  Future<void> seedTrip(CivilDate date, double km, {String? vehicleId}) =>
      SembastTripRepository(database.db).put(Trip(
        id: 't-${date.toIso8601()}-$km',
        date: date,
        distanceKm: km,
        vehicleId: vehicleId,
        createdAt: DateTime.utc(2026, 1, 1),
      ));

  Future<void> seedExtra(CivilDate date, double km, {String? vehicleId}) =>
      SembastDayExtraRepository(database.db)
          .set(DayExtra(date: date, extraKm: km, vehicleId: vehicleId));

  Future<void> seedVehicle(String id, String name,
      {bool archived = false}) =>
      SembastVehicleRepository(database.db).put(Vehicle(
        id: id,
        name: name,
        category: VehicleCategory.car,
        archivedAt: archived ? DateTime.utc(2026, 6, 1) : null,
      ));

  test('année vide : tout à 0, pas de comparaison', () async {
    final s = await state();
    expect(s.year, 2026);
    expect(s.month, 10);
    expect(s.yearTotal, 0);
    expect(s.monthlyTotals, everyElement(0));
    expect(s.activeDays, 0);
    expect(s.averagePerActiveDay, 0);
    expect(s.previousYearTotal, isNull);
    expect(s.vehicleStats, isEmpty);
  });

  test(
      'totaux annuels/mensuels (Trips + DayExtra), jours actifs, moyenne, '
      'par véhicule avec archivé et sans véhicule', () async {
    await seedVehicle('peugeot', 'Peugeot 3008');
    await seedVehicle('clio', 'Ancienne Clio', archived: true);

    await seedTrip(CivilDate(2026, 10, 5), 24, vehicleId: 'peugeot');
    await seedTrip(CivilDate(2026, 10, 5), 18, vehicleId: 'peugeot');
    await seedExtra(CivilDate(2026, 10, 7), 33, vehicleId: 'peugeot');
    await seedTrip(CivilDate(2026, 3, 1), 840, vehicleId: 'clio');
    await seedExtra(CivilDate(2026, 3, 2), 300); // sans véhicule

    final s = await state();
    expect(s.yearTotal, 24 + 18 + 33 + 840 + 300);
    expect(s.monthlyTotals[9], 75, reason: 'octobre'); // 24+18+33
    expect(s.monthlyTotals[2], 1140, reason: 'mars');
    expect(s.monthlyTotals[0], 0);
    expect(s.activeDays, 4);
    expect(s.averagePerActiveDay, (1215 / 4 * 10).round() / 10);
    expect(s.selectedMonthTotal, 75);

    expect(s.vehicleStats, hasLength(3));
    final peugeot =
        s.vehicleStats.firstWhere((v) => v.vehicleId == 'peugeot');
    expect(peugeot.yearKm, 75);
    expect(peugeot.monthKm, 75, reason: 'octobre sélectionné');
    expect(peugeot.isArchived, isFalse);
    final clio = s.vehicleStats.firstWhere((v) => v.vehicleId == 'clio');
    expect(clio.yearKm, 840);
    expect(clio.monthKm, 0);
    expect(clio.isArchived, isTrue, reason: 'archivé mais affiché');
    final none = s.vehicleStats.firstWhere((v) => v.vehicleId == null);
    expect(none.yearKm, 300);
    expect(none.label, 'Sans véhicule renseigné');
    expect(s.vehicleStats.last.vehicleId, isNull,
        reason: 'sans véhicule en dernier');
  });

  test('changer le véhicule PRINCIPAL ne change aucune statistique',
      () async {
    await seedVehicle('peugeot', 'Peugeot');
    await seedVehicle('renault', 'Renault');
    await seedTrip(CivilDate(2026, 10, 5), 100, vehicleId: 'peugeot');
    final before = await state();

    await SembastSettingsRepository(database.db)
        .save(AppSettings(mainVehicleId: 'renault'));
    container.invalidate(statisticsControllerProvider);
    final after = await state();

    expect(
      after.vehicleStats
          .firstWhere((v) => v.vehicleId == 'peugeot')
          .yearKm,
      before.vehicleStats
          .firstWhere((v) => v.vehicleId == 'peugeot')
          .yearKm,
    );
    expect(after.vehicleStats.where((v) => v.vehicleId == 'renault'),
        isEmpty);
  });

  test('comparaison année précédente : delta et pourcentage', () async {
    await seedTrip(CivilDate(2025, 6, 1), 11930);
    await seedTrip(CivilDate(2026, 6, 1), 12842);

    final s = await state();
    expect(s.previousYearTotal, 11930);
    expect(s.previousYearDelta, 912);
    expect(s.previousYearPercent, closeTo(7.6, 0.05));
  });

  test('navigation année (y c. bissextile) et mois ; requêtes bornées',
      () async {
    await seedTrip(CivilDate(2024, 2, 29), 50); // bissextile
    await seedTrip(CivilDate(2025, 12, 31), 30);
    await seedTrip(CivilDate(2026, 1, 1), 20);

    var s = await state();
    expect(s.yearTotal, 20, reason: '2026 seulement (bornes 1/1-31/12)');
    expect(s.monthlyTotals[0], 20);

    await controller().previousYear();
    s = await state();
    expect(s.year, 2025);
    expect(s.yearTotal, 30);
    expect(s.monthlyTotals[11], 30);
    expect(s.isCurrentYear, isFalse);

    await controller().previousYear();
    s = await state();
    expect(s.year, 2024);
    expect(s.yearTotal, 50);
    expect(s.monthlyTotals[1], 50, reason: '29 février compté en février');

    await controller().goToCurrentYear();
    s = await state();
    expect(s.year, 2026);

    await controller().previousMonth();
    expect((await state()).month, 9);
    await controller().nextMonth();
    await controller().nextMonth();
    expect((await state()).month, 11);
  });

  test('jours de congé de l’année (périodes rognées)', () async {
    await SembastVacationRepository(database.db).put(VacationPeriod(
        id: 'p',
        startDate: CivilDate(2025, 12, 30),
        endDate: CivilDate(2026, 1, 2)));

    expect((await state()).vacationDays, 2, reason: '1-2 janvier seulement');
  });

  test('refresh automatique après mutation d’une journée', () async {
    expect((await state()).yearTotal, 0);

    await container
        .read(dayControllerProvider(today).notifier)
        .declareTotal(87);

    final s = await state();
    expect(s.yearTotal, 87);
    expect(s.monthlyTotals[9], 87);
    expect(s.activeDays, 1);
  });
}
