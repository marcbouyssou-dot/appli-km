import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mes_km/app/providers.dart';
import 'package:mes_km/data/local/app_database.dart';
import 'package:mes_km/data/local/sembast_day_extra_repository.dart';
import 'package:mes_km/data/local/sembast_favorite_trip_repository.dart';
import 'package:mes_km/data/local/sembast_trip_repository.dart';
import 'package:mes_km/domain/logic/day_total.dart';
import 'package:mes_km/domain/models/civil_date.dart';
import 'package:mes_km/domain/models/favorite_trip.dart';
import 'package:mes_km/features/day/day_controller.dart';
import 'package:sembast/sembast_memory.dart' hide Finder;

/// Édition d'une JOURNÉE PASSÉE : toutes les opérations utilisent la
/// CivilDate sélectionnée, jamais « aujourd'hui », et ne polluent aucune
/// autre date.
void main() {
  final today = CivilDate(2026, 10, 11);
  final pastDay = CivilDate(2026, 3, 17);

  late MesKmDatabase database;
  late ProviderContainer container;

  setUp(() async {
    database =
        await MesKmDatabase.open(newDatabaseFactoryMemory(), name: 'past.db');
    container = ProviderContainer(overrides: [
      databaseProvider.overrideWithValue(database),
      todayDateProvider.overrideWithValue(() => today),
    ]);
    addTearDown(container.dispose);
  });

  tearDown(() => database.close());

  DayController past() =>
      container.read(dayControllerProvider(pastDay).notifier);

  Future<DayState> pastState() =>
      container.read(dayControllerProvider(pastDay).future);

  test('journée passée vide : total 54 => DayExtra daté du 17 mars', () async {
    final result = await past().declareTotal(54);

    expect(result, isA<DailyTotalAdjusted>());
    expect((await pastState()).totalKm, 54);
    final stored =
        await SembastDayExtraRepository(database.db).getForDate(pastDay);
    expect(stored?.extraKm, 54);
    expect(stored?.date, pastDay, reason: 'jamais la date du jour');
  });

  test('ajout de Trip à une date passée : Trip.date = date sélectionnée',
      () async {
    await past().addTrip(distanceKm: 24, isRoundTrip: false, origin: 'A');

    final stored =
        await SembastTripRepository(database.db).getByDate(pastDay);
    expect(stored.single.date, pastDay);
    expect(await SembastTripRepository(database.db).getByDate(today), isEmpty);
  });

  test('modification/suppression sur date passée', () async {
    await past().addTrip(distanceKm: 24, isRoundTrip: false);
    final original = (await pastState()).trips.single;

    await past().updateTrip(original, distanceKm: 30, isRoundTrip: true);
    final updated = (await pastState()).trips.single;
    expect(updated.distanceKm, 30);
    expect(updated.date, pastDay);

    await past().deleteTrip(updated.id);
    expect((await pastState()).trips, isEmpty);
  });

  test('scénario 42/87 puis refus 40 sur date passée', () async {
    await past().addTrip(distanceKm: 24, isRoundTrip: false);
    await past().addTrip(distanceKm: 18, isRoundTrip: false);

    final adjusted = await past().declareTotal(87);
    adjusted as DailyTotalAdjusted;
    expect((await pastState()).extraKm, 45);
    expect((await pastState()).totalKm, 87);

    final refused = await past().declareTotal(40);
    refused as DailyTotalBelowDetailed;
    expect(refused.detailedKm, 42);
    expect((await pastState()).totalKm, 87, reason: 'rien modifié');
  });

  group('favoris sur journée passée', () {
    final favorite = FavoriteTrip(
      id: 'fav-1',
      label: 'Cabinet ↔ EHPAD',
      distanceKm: 24,
      origin: 'Cabinet',
      destination: 'EHPAD',
      sortOrder: 0,
    );

    test('tap favori sur le 17 mars : Trip.date = 17 mars, rien aujourd’hui',
        () async {
      await past().addTripFromFavorite(favorite);

      final onPast =
          await SembastTripRepository(database.db).getByDate(pastDay);
      expect(onPast.single.date, pastDay);
      expect(onPast.single.distanceKm, 24);
      expect(onPast.single.origin, 'Cabinet');
      expect(
        await SembastTripRepository(database.db).getByDate(today),
        isEmpty,
        reason: 'jamais la date courante implicite',
      );
    });

    test('double tap : deux Trips distincts datés du 17 mars (+48)', () async {
      await past().addTripFromFavorite(favorite);
      await past().addTripFromFavorite(favorite);

      final trips =
          await SembastTripRepository(database.db).getByDate(pastDay);
      expect(trips, hasLength(2));
      expect(trips[0].id, isNot(trips[1].id));
      expect((await pastState()).totalKm, 48);
    });

    test('DayExtra passé inchangé : extra 33 + favori 24 => 57', () async {
      await past().declareTotal(33);

      await past().addTripFromFavorite(favorite);

      final s = await pastState();
      expect(s.extraKm, 33);
      expect(s.totalKm, 57);
    });

    test('supprimer le favori ne supprime aucun Trip historique', () async {
      final favoriteRepo = SembastFavoriteTripRepository(database.db);
      await favoriteRepo.put(favorite);
      await past().addTripFromFavorite(favorite);

      await favoriteRepo.delete(favorite.id);

      expect(await favoriteRepo.getAllOrdered(), isEmpty);
      final trips =
          await SembastTripRepository(database.db).getByDate(pastDay);
      expect(trips.single.distanceKm, 24,
          reason: 'le Trip créé est indépendant du favori');
    });
  });

  test('clear day atomique sur date passée, aujourd’hui intact',
      () async {
    // Données sur AUJOURD'HUI qui ne doivent jamais bouger.
    await container
        .read(dayControllerProvider(today).notifier)
        .declareTotal(42);

    await past().addTrip(distanceKm: 24, isRoundTrip: false);
    await past().declareTotal(87);
    await past().clearDay();

    expect((await pastState()).isEmpty, isTrue);
    final todayState =
        await container.read(dayControllerProvider(today).future);
    expect(todayState.totalKm, 42, reason: 'aucune pollution d’une autre date');
  });
}
