import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mes_km/app/providers.dart';
import 'package:mes_km/data/local/app_database.dart';
import 'package:mes_km/data/local/sembast_day_extra_repository.dart';
import 'package:mes_km/data/local/sembast_favorite_trip_repository.dart';
import 'package:mes_km/data/local/sembast_trip_repository.dart';
import 'package:mes_km/domain/logic/day_total.dart';
import 'package:mes_km/domain/models/civil_date.dart';
import 'package:mes_km/domain/models/day_extra.dart';
import 'package:mes_km/domain/models/favorite_trip.dart';
import 'package:mes_km/domain/models/trip.dart';
import 'package:mes_km/features/day/day_controller.dart';
import 'package:sembast/sembast_memory.dart';

void main() {
  final day = CivilDate(2026, 10, 11);
  late DatabaseFactory factory;
  late MesKmDatabase database;
  late ProviderContainer container;

  Future<ProviderContainer> makeContainer() async {
    final c = ProviderContainer(overrides: [
      databaseProvider.overrideWithValue(database),
      todayDateProvider.overrideWithValue(() => day),
    ]);
    addTearDown(c.dispose);
    return c;
  }

  setUp(() async {
    factory = newDatabaseFactoryMemory();
    database = await MesKmDatabase.open(factory, name: 'today.db');
    container = await makeContainer();
    // Comme DayView, attendre le chargement initial avant d'autoriser
    // une mutation : sinon build() peut terminer après _refresh() et
    // remplacer l'état testé par son ancien instantané vide.
    await container.read(dayControllerProvider(day).future);
  });

  tearDown(() => database.close());

  DayController controller() =>
      container.read(dayControllerProvider(day).notifier);

  Future<DayState> state() =>
      container.read(dayControllerProvider(day).future);

  Future<void> seedTrips2418() async {
    await controller().addTrip(distanceKm: 24, isRoundTrip: false);
    await controller().addTrip(distanceKm: 18, isRoundTrip: false);
  }

  test('journée vide => total 0', () async {
    final s = await state();
    expect(s.totalKm, 0);
    expect(s.isEmpty, isTrue);
  });

  test('total direct 87 => DayExtra 87 persisté', () async {
    final result = await controller().declareTotal(87);
    expect(result, isA<DailyTotalAdjusted>());

    expect((await state()).totalKm, 87);
    final stored =
        await SembastDayExtraRepository(database.db).getForDate(day);
    expect(stored?.extraKm, 87);
  });

  test('24 + 18 puis total 87 => extra 45, trips intacts', () async {
    await seedTrips2418();
    await controller().declareTotal(87);

    final s = await state();
    expect(s.detailedKm, 42);
    expect(s.extraKm, 45);
    expect(s.totalKm, 87);
    expect(s.trips.map((t) => t.distanceKm).toList()..sort(), [18, 24]);
  });

  test('24 + 18 puis total 42 => extra supprimé (absence logique)', () async {
    await seedTrips2418();
    await controller().declareTotal(87);
    await controller().declareTotal(42);

    final s = await state();
    expect(s.extra, isNull);
    expect(s.totalKm, 42);
    expect(
      await SembastDayExtraRepository(database.db).getForDate(day),
      isNull,
    );
  });

  test(
      'RÉGRESSION iPhone KM-004A : extra 87 seul puis total 0 '
      '=> accepté, DayExtra absent, total 0', () async {
    await controller().declareTotal(87);
    expect((await state()).extraKm, 87);

    final result = await controller().declareTotal(0);

    expect(result, isA<DailyTotalAdjusted>());
    final s = await state();
    expect(s.totalKm, 0);
    expect(s.extra, isNull);
    expect(s.isEmpty, isTrue,
        reason: 'aucune donnée kilométrique restante pour la journée');
    expect(
      await SembastDayExtraRepository(database.db).getForDate(day),
      isNull,
    );
  });

  test('total 0 avec trajets détaillés => refus, aucun Trip supprimé',
      () async {
    await seedTrips2418();

    final result = await controller().declareTotal(0);

    result as DailyTotalBelowDetailed;
    expect(result.detailedKm, 42);
    expect(result.requestedKm, 0);
    final s = await state();
    expect(s.trips, hasLength(2));
    expect(s.totalKm, 42);
  });

  test('24 + 18 puis total 40 => refus, stockage inchangé', () async {
    await seedTrips2418();
    await controller().declareTotal(87);

    final result = await controller().declareTotal(40);

    result as DailyTotalBelowDetailed;
    expect(result.detailedKm, 42);
    expect(result.requestedKm, 40);

    final s = await state();
    expect(s.totalKm, 87);
    expect(s.extraKm, 45);
    expect(
      (await SembastDayExtraRepository(database.db).getForDate(day))?.extraKm,
      45,
    );
  });

  test('ajout de trajet persisté avec métadonnées', () async {
    await controller().addTrip(
      distanceKm: 48,
      isRoundTrip: true,
      origin: 'Maison',
      destination: 'Client',
      purpose: 'RDV',
    );

    final stored = await SembastTripRepository(database.db).getByDate(day);
    expect(stored.single.distanceKm, 48);
    expect(stored.single.isRoundTrip, isTrue);
    expect(stored.single.origin, 'Maison');
    expect(stored.single.destination, 'Client');
    expect(stored.single.purpose, 'RDV');
    expect(stored.single.date, day);
  });

  test('modification de trajet : même id, createdAt préservé', () async {
    await controller().addTrip(distanceKm: 24, isRoundTrip: false);
    final original = (await state()).trips.single;

    await controller().updateTrip(
      original,
      distanceKm: 30,
      isRoundTrip: true,
      origin: 'Dépôt',
    );

    final stored =
        await SembastTripRepository(database.db).getById(original.id);
    expect(stored?.distanceKm, 30);
    expect(stored?.isRoundTrip, isTrue);
    expect(stored?.origin, 'Dépôt');
    expect(stored?.createdAt, original.createdAt);
    expect(await SembastTripRepository(database.db).getAll(), hasLength(1));
  });

  test('suppression de trajet persistée', () async {
    await seedTrips2418();
    final trips = (await state()).trips;

    await controller().deleteTrip(trips.first.id);

    expect((await state()).trips, hasLength(1));
    expect(await SembastTripRepository(database.db).getAll(), hasLength(1));
  });

  test('supprimer un trajet ne modifie pas le DayExtra', () async {
    await seedTrips2418();
    await controller().declareTotal(87); // extra 45

    final tripOf18 =
        (await state()).trips.firstWhere((t) => t.distanceKm == 18);
    await controller().deleteTrip(tripOf18.id);

    final s = await state();
    expect(s.extraKm, 45, reason: 'l’extra reste 45');
    expect(s.totalKm, 69, reason: 'le total dérivé diminue honnêtement');
  });

  group('favoris — ajout en un toucher', () {
    FavoriteTrip favorite({double km = 24, bool roundTrip = false}) =>
        FavoriteTrip(
          id: 'fav-1',
          label: 'Cabinet ↔ EHPAD',
          distanceKm: km,
          defaultRoundTrip: roundTrip,
          origin: 'Cabinet',
          destination: 'EHPAD',
          purpose: 'Tournée',
          sortOrder: 0,
        );

    test('un tap crée un Trip : distance EXACTE, métadonnées copiées',
        () async {
      await controller().addTripFromFavorite(favorite(roundTrip: true));

      final trips = await SembastTripRepository(database.db).getByDate(day);
      final trip = trips.single;
      expect(trip.distanceKm, 24, reason: 'aucun doublement');
      expect(trip.isRoundTrip, isTrue);
      expect(trip.origin, 'Cabinet');
      expect(trip.destination, 'EHPAD');
      expect(trip.purpose, 'Tournée');
      expect(trip.id, isNot('fav-1'), reason: 'Trip indépendant du favori');
      expect((await state()).totalKm, 24);
    });

    test('deux taps => deux Trips distincts, +48', () async {
      await controller().addTripFromFavorite(favorite());
      await controller().addTripFromFavorite(favorite());

      final trips = await SembastTripRepository(database.db).getByDate(day);
      expect(trips, hasLength(2));
      expect(trips[0].id, isNot(trips[1].id));
      expect((await state()).totalKm, 48);
    });

    test('DayExtra JAMAIS recalculé : extra 33 + tap 24 => total 57',
        () async {
      await controller().declareTotal(33);

      await controller().addTripFromFavorite(favorite());

      final s = await state();
      expect(s.extraKm, 33, reason: 'extra inchangé');
      expect(s.totalKm, 57, reason: 'le favori AJOUTE des kilomètres');
    });

    test('supprimer un Trip issu d’un favori n’affecte jamais '
        'le FavoriteTrip', () async {
      final favoriteRepo = SembastFavoriteTripRepository(database.db);
      await favoriteRepo.put(favorite());
      await controller().addTripFromFavorite(favorite());

      final trip = (await state()).trips.single;
      await controller().deleteTrip(trip.id);

      expect((await state()).trips, isEmpty);
      expect(await favoriteRepo.getAllOrdered(), hasLength(1),
          reason: 'le favori global reste disponible');
    });

    test('réouverture : Trips issus de favoris toujours présents', () async {
      await controller().addTripFromFavorite(favorite());
      await database.close();

      database = await MesKmDatabase.open(factory, name: 'today.db');
      container = await makeContainer();

      expect((await state()).totalKm, 24);
    });
  });

  group('effacer la journée', () {
    test('DayExtra seul => 0', () async {
      await controller().declareTotal(33);

      await controller().clearDay();

      final s = await state();
      expect(s.totalKm, 0);
      expect(s.isEmpty, isTrue);
      expect(
        await SembastDayExtraRepository(database.db).getForDate(day),
        isNull,
      );
    });

    test('3 Trips seuls => 0', () async {
      await controller().addTrip(distanceKm: 24, isRoundTrip: false);
      await controller().addTrip(distanceKm: 24, isRoundTrip: false);
      await controller().addTrip(distanceKm: 18, isRoundTrip: false);

      await controller().clearDay();

      expect((await state()).isEmpty, isTrue);
      expect(await SembastTripRepository(database.db).getByDate(day), isEmpty);
    });

    test('Trips + DayExtra (24+24+18 + extra 33 = 99) => tout effacé',
        () async {
      await controller().addTrip(distanceKm: 24, isRoundTrip: false);
      await controller().addTrip(distanceKm: 24, isRoundTrip: false);
      await controller().addTrip(distanceKm: 18, isRoundTrip: false);
      await controller().declareTotal(99); // extra 33
      expect((await state()).totalKm, 99);

      await controller().clearDay();

      final s = await state();
      expect(s.totalKm, 0);
      expect(s.trips, isEmpty);
      expect(s.extra, isNull);
    });

    test('favoris et autre journée intacts', () async {
      final favoriteRepo = SembastFavoriteTripRepository(database.db);
      await favoriteRepo.put(FavoriteTrip(
          id: 'fav', label: 'Cabinet', distanceKm: 24, sortOrder: 0));
      await SembastTripRepository(database.db).put(Trip(
        id: 'autre',
        date: CivilDate(2026, 10, 10),
        distanceKm: 55,
        createdAt: DateTime.utc(2026, 10, 10),
      ));
      await controller().addTrip(distanceKm: 24, isRoundTrip: false);

      await controller().clearDay();

      expect(await favoriteRepo.getAllOrdered(), hasLength(1));
      expect(
        (await SembastTripRepository(database.db)
                .getByDate(CivilDate(2026, 10, 10)))
            .single
            .distanceKm,
        55,
      );
    });

    test('réouverture : la journée effacée reste vide', () async {
      await controller().addTrip(distanceKm: 24, isRoundTrip: false);
      await controller().declareTotal(57);
      await controller().clearDay();
      await database.close();

      database = await MesKmDatabase.open(factory, name: 'today.db');
      container = await makeContainer();

      expect((await state()).isEmpty, isTrue);
    });
  });

  test('réouverture après remise à zéro : la journée reste vide', () async {
    await controller().declareTotal(87);
    await controller().declareTotal(0);
    await database.close();

    database = await MesKmDatabase.open(factory, name: 'today.db');
    container = await makeContainer();

    final s = await state();
    expect(s.isEmpty, isTrue);
    expect(s.totalKm, 0);
  });

  test('réouverture de la base : les données du jour réapparaissent',
      () async {
    await seedTrips2418();
    await controller().declareTotal(87);
    await database.close();

    // Réouverture (la factory mémoire conserve le « fichier »).
    database = await MesKmDatabase.open(factory, name: 'today.db');
    container = await makeContainer();

    final s = await state();
    expect(s.detailedKm, 42);
    expect(s.extraKm, 45);
    expect(s.totalKm, 87);
  });

  test('les trips d’autres jours ne polluent pas aujourd’hui',
      () async {
    await SembastTripRepository(database.db).put(Trip(
      id: 'autre-jour',
      date: CivilDate(2026, 10, 10),
      distanceKm: 99,
      createdAt: DateTime.utc(2026, 10, 10),
    ));
    await SembastDayExtraRepository(database.db)
        .set(DayExtra(date: CivilDate(2026, 10, 10), extraKm: 11));

    final s = await state();
    expect(s.totalKm, 0);
  });
}
