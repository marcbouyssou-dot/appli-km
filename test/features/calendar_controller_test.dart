import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mes_km/app/providers.dart';
import 'package:mes_km/data/local/app_database.dart';
import 'package:mes_km/data/local/sembast_day_extra_repository.dart';
import 'package:mes_km/data/local/sembast_trip_repository.dart';
import 'package:mes_km/domain/models/civil_date.dart';
import 'package:mes_km/domain/models/day_extra.dart';
import 'package:mes_km/domain/models/trip.dart';
import 'package:mes_km/features/calendar/calendar_controller.dart';
import 'package:mes_km/features/day/day_controller.dart';
import 'package:sembast/sembast_memory.dart' hide Finder;

void main() {
  late MesKmDatabase database;
  late ProviderContainer container;

  ProviderContainer makeContainer({CivilDate? today}) {
    final c = ProviderContainer(overrides: [
      databaseProvider.overrideWithValue(database),
      todayDateProvider
          .overrideWithValue(() => today ?? CivilDate(2026, 10, 11)),
    ]);
    addTearDown(c.dispose);
    return c;
  }

  setUp(() async {
    database =
        await MesKmDatabase.open(newDatabaseFactoryMemory(), name: 'cal.db');
  });

  tearDown(() => database.close());

  Future<void> seedTrip(CivilDate date, double km, {String? id}) =>
      SembastTripRepository(database.db).put(Trip(
        id: id ?? 't-${date.toIso8601()}-$km',
        date: date,
        distanceKm: km,
        createdAt: DateTime.utc(2026, 1, 1),
      ));

  CalendarController controller() =>
      container.read(calendarControllerProvider.notifier);

  Future<CalendarState> state() =>
      container.read(calendarControllerProvider.future);

  test('mois vide : aucun total, mois courant affiché', () async {
    container = makeContainer();

    final s = await state();
    expect(s.year, 2026);
    expect(s.month, 10);
    expect(s.dayTotals, isEmpty);
    expect(s.monthTotal, 0);
    expect(s.isCurrentMonth, isTrue);
  });

  test('plusieurs journées : totaux par jour + total mensuel dérivé',
      () async {
    await seedTrip(CivilDate(2026, 10, 11), 24);
    await seedTrip(CivilDate(2026, 10, 11), 18);
    await SembastDayExtraRepository(database.db)
        .set(DayExtra(date: CivilDate(2026, 10, 5), extraKm: 87));
    container = makeContainer();

    final s = await state();
    expect(s.dayTotals[CivilDate(2026, 10, 11)], 42);
    expect(s.dayTotals[CivilDate(2026, 10, 5)], 87);
    expect(s.monthTotal, 129);
  });

  test('seule la plage du mois demandé est chargée', () async {
    await seedTrip(CivilDate(2026, 9, 30), 99);
    await seedTrip(CivilDate(2026, 11, 1), 55);
    await seedTrip(CivilDate(2026, 10, 1), 10);
    await seedTrip(CivilDate(2026, 10, 31), 20);
    container = makeContainer();

    final s = await state();
    expect(s.dayTotals, hasLength(2), reason: 'bornes du mois incluses');
    expect(s.monthTotal, 30);
  });

  test('changement de mois précédent/suivant', () async {
    await seedTrip(CivilDate(2026, 9, 30), 99);
    container = makeContainer();
    await state();

    await controller().previousMonth();
    var s = await state();
    expect([s.year, s.month], [2026, 9]);
    expect(s.monthTotal, 99);
    expect(s.isCurrentMonth, isFalse);

    await controller().nextMonth();
    await controller().nextMonth();
    s = await state();
    expect([s.year, s.month], [2026, 11]);
    expect(s.monthTotal, 0);

    await controller().goToCurrentMonth();
    s = await state();
    expect([s.year, s.month], [2026, 10]);
  });

  test('décembre -> janvier et retour (changement d’année)', () async {
    await seedTrip(CivilDate(2025, 12, 31), 30);
    container = makeContainer(today: CivilDate(2026, 1, 15));
    await state();

    await controller().previousMonth();
    var s = await state();
    expect([s.year, s.month], [2025, 12]);
    expect(s.monthTotal, 30);

    await controller().nextMonth();
    s = await state();
    expect([s.year, s.month], [2026, 1]);
  });

  test('refresh automatique après modification d’une journée', () async {
    container = makeContainer();
    expect((await state()).monthTotal, 0);

    // Mutation via le contrôleur de journée -> bump de version -> rechargement.
    final day = CivilDate(2026, 10, 5);
    await container
        .read(dayControllerProvider(day).notifier)
        .declareTotal(87);

    final s = await state();
    expect(s.dayTotals[day], 87);
    expect(s.monthTotal, 87);

    await container.read(dayControllerProvider(day).notifier).clearDay();
    expect((await state()).monthTotal, 0);
  });
}
