import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mes_km/app/providers.dart';
import 'package:mes_km/data/local/app_database.dart';
import 'package:mes_km/data/local/sembast_favorite_trip_repository.dart';
import 'package:mes_km/features/today/favorites_controller.dart';
import 'package:sembast/sembast_memory.dart' hide Finder;

void main() {
  late DatabaseFactory factory;
  late MesKmDatabase database;
  late ProviderContainer container;

  ProviderContainer makeContainer() {
    final c = ProviderContainer(overrides: [
      databaseProvider.overrideWithValue(database),
    ]);
    addTearDown(c.dispose);
    return c;
  }

  setUp(() async {
    factory = newDatabaseFactoryMemory();
    database = await MesKmDatabase.open(factory, name: 'fav.db');
    container = makeContainer();
  });

  tearDown(() => database.close());

  FavoritesController controller() =>
      container.read(favoritesControllerProvider.notifier);

  Future<void> seedThree() async {
    await controller().create(label: 'Cabinet ↔ EHPAD', distanceKm: 24);
    await controller().create(label: 'Domicile ↔ Cabinet', distanceKm: 18);
    await controller().create(label: 'Dépôt', distanceKm: 7.5);
  }

  test('création persistée, ordre d’ajout conservé', () async {
    await seedThree();

    final stored =
        await SembastFavoriteTripRepository(database.db).getAllOrdered();
    expect(stored.map((f) => f.label).toList(),
        ['Cabinet ↔ EHPAD', 'Domicile ↔ Cabinet', 'Dépôt']);
    expect(stored.map((f) => f.sortOrder).toList(), [0, 1, 2]);
  });

  test('modification persistée : même id, position conservée', () async {
    await seedThree();
    final original = (await container
            .read(favoritesControllerProvider.future))
        .firstWhere((f) => f.distanceKm == 24);

    await controller().updateFavorite(
      original,
      label: original.label,
      distanceKm: 26,
      defaultRoundTrip: true,
    );

    final stored = await SembastFavoriteTripRepository(database.db)
        .getAllOrdered();
    final updated = stored.firstWhere((f) => f.id == original.id);
    expect(updated.distanceKm, 26);
    expect(updated.defaultRoundTrip, isTrue);
    expect(updated.sortOrder, original.sortOrder);
    expect(stored, hasLength(3));
  });

  test('suppression persistée', () async {
    await seedThree();
    final favorites =
        await container.read(favoritesControllerProvider.future);

    await controller().deleteFavorite(favorites[1].id);

    final stored =
        await SembastFavoriteTripRepository(database.db).getAllOrdered();
    expect(stored.map((f) => f.label).toList(),
        ['Cabinet ↔ EHPAD', 'Dépôt']);
  });

  test('réorganisation par flèches persistée', () async {
    await seedThree();
    final favorites =
        await container.read(favoritesControllerProvider.future);

    // Descend le premier, remonte le dernier.
    await controller().move(favorites[0].id, 1);
    final after = await container.read(favoritesControllerProvider.future);
    expect(after.map((f) => f.distanceKm).toList(), [18, 24, 7.5]);

    await controller().move(favorites[2].id, -1);
    final stored =
        await SembastFavoriteTripRepository(database.db).getAllOrdered();
    expect(stored.map((f) => f.distanceKm).toList(), [18, 7.5, 24]);
    expect(stored.map((f) => f.sortOrder).toList(), [0, 1, 2]);
  });

  test('réouverture : favoris et ordre conservés', () async {
    await seedThree();
    await controller().move(
      (await container.read(favoritesControllerProvider.future))[0].id,
      1,
    );
    await database.close();

    database = await MesKmDatabase.open(factory, name: 'fav.db');
    container = makeContainer();

    final favorites =
        await container.read(favoritesControllerProvider.future);
    expect(favorites.map((f) => f.distanceKm).toList(), [18, 24, 7.5]);
  });
}
