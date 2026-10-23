import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:mes_km/app/providers.dart';
import 'package:mes_km/data/local/app_database.dart';
import 'package:mes_km/data/local/sembast_favorite_trip_repository.dart';
import 'package:mes_km/data/local/sembast_trip_repository.dart';
import 'package:mes_km/domain/models/civil_date.dart';
import 'package:mes_km/domain/models/favorite_trip.dart';
import 'package:mes_km/features/today/favorite_days_screen.dart';
import 'package:mes_km/features/today/favorites_section.dart';
import 'package:sembast/sembast_memory.dart' hide Finder;

void main() {
  setUpAll(() => initializeDateFormatting('fr_FR'));
  late MesKmDatabase db;
  final today = CivilDate(2026, 10, 23);
  setUp(() async {
    db = await MesKmDatabase.open(newDatabaseFactoryMemory());
  });
  tearDown(() => db.close());

  for (final (width, count, km, scale) in [
    (320.0, 1, 70.0, 1.0),
    (320.0, 3, 1234567.8, 1.5),
    (390.0, 3, 1.0, 1.0),
    (375.0, 2, 70.0, 1.0),
    (430.0, 1, 70.0, 1.0),
  ]) {
    testWidgets(
      'Aujourd’hui multi-jours : ${width}px, $count favoris, $km km, échelle $scale',
      (t) async {
        await t.runAsync(() async {
          for (var i = 0; i < count; i++) {
            await SembastFavoriteTripRepository(db.db).put(
              FavoriteTrip(
                id: 'f$i',
                label:
                    'Travail et déplacements professionnels au cabinet numéro $i',
                distanceKm: km,
                defaultRoundTrip: true,
                sortOrder: i,
              ),
            );
          }
        });
        t.view.physicalSize = Size(width, 1800);
        t.view.devicePixelRatio = 1;
        addTearDown(t.view.reset);
        await t.pumpWidget(
          ProviderScope(
            overrides: [
              databaseProvider.overrideWithValue(db),
              todayDateProvider.overrideWithValue(() => today),
            ],
            child: MaterialApp(
              builder: (context, child) => MediaQuery(
                data: MediaQuery.of(
                  context,
                ).copyWith(textScaler: TextScaler.linear(scale)),
                child: child!,
              ),
              home: Scaffold(
                body: SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  child: FavoritesSection(date: today),
                ),
              ),
            ),
          ),
        );
        await t.pumpAndSettle();
        expect(find.text('Autres jours'), findsNWidgets(count));
        expect(t.takeException(), isNull);
        final target = find.byKey(Key('multi-day-favorite-f${count - 1}'));
        await t.ensureVisible(target);
        final rect = t.getRect(target);
        expect(rect.width, greaterThanOrEqualTo(44));
        expect(rect.height, greaterThanOrEqualTo(44));
        await t.tap(target);
        await t.pumpAndSettle();
        final screen = t.widget<FavoriteDaysScreen>(
          find.byType(FavoriteDaysScreen),
        );
        expect(screen.favorite.id, 'f${count - 1}');
        expect(
          await t.runAsync(() => SembastTripRepository(db.db).getByDate(today)),
          isEmpty,
        );
        await t.pageBack();
        await t.pumpAndSettle();
        final add = find.byKey(const Key('add-favorite-f0'));
        await t.ensureVisible(add);
        await t.tap(add);
        await t.pumpAndSettle();
        final trips = await t.runAsync(
          () => SembastTripRepository(db.db).getByDate(today),
        );
        expect(trips!.single.distanceKm, km);
        expect(trips.single.date, today);
        expect(t.takeException(), isNull);
      },
    );
  }
}
