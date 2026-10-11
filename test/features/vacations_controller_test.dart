import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mes_km/app/providers.dart';
import 'package:mes_km/data/local/app_database.dart';
import 'package:mes_km/data/local/sembast_vacation_repository.dart';
import 'package:mes_km/domain/models/civil_date.dart';
import 'package:mes_km/features/calendar/calendar_controller.dart';
import 'package:mes_km/features/vacations/vacations_controller.dart';
import 'package:sembast/sembast_memory.dart' hide Finder;

void main() {
  final today = CivilDate(2026, 10, 11);
  late DatabaseFactory factory;
  late MesKmDatabase database;
  late ProviderContainer container;

  ProviderContainer makeContainer() {
    final c = ProviderContainer(overrides: [
      databaseProvider.overrideWithValue(database),
      todayDateProvider.overrideWithValue(() => today),
    ]);
    addTearDown(c.dispose);
    return c;
  }

  setUp(() async {
    factory = newDatabaseFactoryMemory();
    database = await MesKmDatabase.open(factory, name: 'vac.db');
    container = makeContainer();
  });

  tearDown(() => database.close());

  VacationsController controller() =>
      container.read(vacationsControllerProvider.notifier);

  Future<List> periods() =>
      container.read(vacationsControllerProvider.future);

  test('marquer une journée => période d’un jour persistée', () async {
    await controller().markDay(CivilDate(2026, 10, 6));

    final stored =
        await SembastVacationRepository(database.db).getAll();
    expect(stored.single.startDate, CivilDate(2026, 10, 6));
    expect(stored.single.endDate, CivilDate(2026, 10, 6));
  });

  test('période + fusion : 3-10 puis 11-15 => 3-15', () async {
    await controller()
        .addPeriod(CivilDate(2026, 8, 3), CivilDate(2026, 8, 10));
    await controller()
        .addPeriod(CivilDate(2026, 8, 11), CivilDate(2026, 8, 15));

    final stored = await SembastVacationRepository(database.db).getAll();
    expect(stored, hasLength(1));
    expect(stored.single.startDate, CivilDate(2026, 8, 3));
    expect(stored.single.endDate, CivilDate(2026, 8, 15));
  });

  test('retirer un jour du milieu => découpe persistée, ids cohérents',
      () async {
    await controller()
        .addPeriod(CivilDate(2026, 8, 3), CivilDate(2026, 8, 10));
    final originalId = (await periods()).single.id;

    await controller().removeDay(CivilDate(2026, 8, 6));

    final stored = await SembastVacationRepository(database.db).getAll();
    expect(stored, hasLength(2));
    expect(stored[0].id, originalId);
    expect(stored[0].endDate, CivilDate(2026, 8, 5));
    expect(stored[1].id, isNot(originalId));
    expect(stored[1].startDate, CivilDate(2026, 8, 7));
    expect(stored[1].endDate, CivilDate(2026, 8, 10));
  });

  test('supprimer une période complète', () async {
    await controller()
        .addPeriod(CivilDate(2026, 8, 3), CivilDate(2026, 8, 10));
    await controller()
        .addPeriod(CivilDate(2026, 9, 1), CivilDate(2026, 9, 5));
    final first = (await periods()).first;

    await controller().deletePeriod(first.id);

    final stored = await SembastVacationRepository(database.db).getAll();
    expect(stored.single.startDate, CivilDate(2026, 9, 1));
  });

  test('réouverture : congés conservés', () async {
    await controller()
        .addPeriod(CivilDate(2026, 10, 3), CivilDate(2026, 10, 10));
    await database.close();

    database = await MesKmDatabase.open(factory, name: 'vac.db');
    container = makeContainer();

    final stored = await periods();
    expect(stored, hasLength(1));
  });

  test('rafraîchissement croisé : le calendrier voit les congés', () async {
    expect(
      (await container.read(calendarControllerProvider.future)).vacationDays,
      isEmpty,
    );

    await controller()
        .addPeriod(CivilDate(2026, 10, 3), CivilDate(2026, 10, 10));

    final calendar =
        await container.read(calendarControllerProvider.future);
    expect(calendar.vacationDays, contains(CivilDate(2026, 10, 3)));
    expect(calendar.vacationDays, contains(CivilDate(2026, 10, 10)));
    expect(calendar.vacationDays, hasLength(8));

    await controller().removeDay(CivilDate(2026, 10, 6));
    final updated =
        await container.read(calendarControllerProvider.future);
    expect(updated.vacationDays, isNot(contains(CivilDate(2026, 10, 6))));
    expect(updated.vacationDays, hasLength(7));
  });
}
