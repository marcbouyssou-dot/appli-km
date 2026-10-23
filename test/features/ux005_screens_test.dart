import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:mes_km/app/providers.dart';
import 'package:mes_km/data/local/app_database.dart';
import 'package:mes_km/data/local/codecs.dart';
import 'package:mes_km/data/local/sembast_settings_repository.dart';
import 'package:mes_km/domain/models/app_settings.dart';
import 'package:mes_km/domain/models/civil_date.dart';
import 'package:mes_km/domain/models/favorite_trip.dart';
import 'package:mes_km/features/day/editable_day_total.dart';
import 'package:mes_km/features/settings/accountant_screen.dart';
import 'package:mes_km/features/today/favorite_days_screen.dart';
import 'package:sembast/sembast_memory.dart' hide Finder;

void main() {
  setUpAll(() => initializeDateFormatting('fr_FR'));
  final today = CivilDate(2026, 10, 22);
  late MesKmDatabase db;
  setUp(() async {
    db = await MesKmDatabase.open(newDatabaseFactoryMemory());
  });
  tearDown(() => db.close());
  Future<void> pump(
    WidgetTester t,
    Widget screen, {
    Size size = const Size(375, 812),
    bool dark = false,
    double scale = 1,
  }) async {
    t.view.physicalSize = size;
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.reset);
    await t.pumpWidget(
      ProviderScope(
        overrides: [
          databaseProvider.overrideWithValue(db),
          todayDateProvider.overrideWithValue(() => today),
        ],
        child: MaterialApp(
          theme: dark
              ? ThemeData.dark(useMaterial3: true)
              : ThemeData.light(useMaterial3: true),
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(
              context,
            ).copyWith(textScaler: TextScaler.linear(scale)),
            child: child!,
          ),
          home: Builder(
            builder: (context) => Scaffold(
              body: TextButton(
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute<void>(builder: (_) => screen),
                ),
                child: const Text('Ouvrir'),
              ),
            ),
          ),
        ),
      ),
    );
    await t.tap(find.text('Ouvrir'));
    await t.pumpAndSettle();
  }

  Future<void> visible(WidgetTester t, Finder f) async {
    if (f.evaluate().isEmpty) {
      await t.scrollUntilVisible(
        f,
        200,
        scrollable: find.byType(Scrollable).first,
      );
    } else {
      await t.ensureVisible(f);
    }
    await t.pumpAndSettle();
  }

  for (final value in [0.0, 1.0, 42.0, 999.0, 1234567.8]) {
    testWidgets('compteur $value km sur petit iPhone et édition conservée', (
      t,
    ) async {
      await pump(
        t,
        Scaffold(
          body: EditableDayTotal(date: today, totalKm: value),
        ),
        size: const Size(320, 568),
        scale: 1.5,
      );
      expect(find.text('km'), findsOneWidget);
      expect(find.text('aujourd’hui'), findsOneWidget);
      expect(t.takeException(), isNull);
      await t.tap(find.byKey(dayTotalCardKey));
      await t.pump();
      expect(
        t.widget<TextField>(find.byKey(dayTotalFieldKey)).focusNode!.hasFocus,
        isTrue,
      );
      expect(t.takeException(), isNull);
    });
  }
  for (final size in [
    const Size(320, 568),
    const Size(390, 844),
    const Size(430, 932),
    const Size(1024, 768),
  ]) {
    testWidgets(
      'calendrier multi-sélection responsive $size et annulation sans écriture',
      (t) async {
        final favorite = FavoriteTrip(
          id: 'f',
          label: 'Cabinet → Clinique',
          distanceKm: 12,
          sortOrder: 0,
        );
        await t.runAsync(
          () => favoriteTripsStore
              .record('f')
              .put(db.db, favoriteTripToDb(favorite)),
        );
        await pump(
          t,
          FavoriteDaysScreen(favorite: favorite),
          size: size,
          dark: size.width == 390,
        );
        await t.tap(find.byKey(const Key('batch-day-2026-10-05')));
        await t.tap(find.byKey(const Key('batch-day-2026-10-12')));
        await t.pumpAndSettle();
        final checkbox = find.byType(CheckboxListTile);
        await visible(t, checkbox);
        await t.tap(checkbox);
        await t.pumpAndSettle();
        final review = find.byKey(const Key('review-favorite-days'));
        await visible(t, review);
        await t.tap(review);
        await t.pumpAndSettle();
        expect(find.text('Ajouter 2 trajets'), findsOneWidget);
        expect(t.takeException(), isNull);
        await t.tap(find.text('Annuler'));
        await t.pumpAndSettle();
        expect(await t.runAsync(() => tripsStore.count(db.db)), 0);
        await t.tap(review);
        await t.pumpAndSettle();
        await t.tap(find.byKey(const Key('confirm-favorite-days')));
        await t.pumpAndSettle();
        expect(await t.runAsync(() => tripsStore.count(db.db)), 2);
        expect(t.takeException(), isNull);
      },
    );
  }
  testWidgets(
    'cabinet : validation, création, modification, suppression avec clavier et scroll',
    (t) async {
      await t.runAsync(
        () => SembastSettingsRepository(
          db.db,
        ).save(AppSettings(displayName: 'Profil conservé')),
      );
      await pump(t, const AccountantScreen(), size: const Size(320, 568));
      await t.enterText(
        find.byKey(const Key('accountant-0')),
        'Cabinet Équilibre',
      );
      await visible(t, find.byKey(const Key('accountant-7')));
      await t.enterText(find.byKey(const Key('accountant-7')), 'incorrect');
      await visible(t, find.text('Enregistrer'));
      await t.tap(find.text('Enregistrer'));
      await t.pumpAndSettle();
      expect(find.text('Vérifiez l’adresse email.'), findsOneWidget);
      await visible(t, find.byKey(const Key('accountant-7')));
      await t.enterText(
        find.byKey(const Key('accountant-7')),
        'cabinet@example.fr',
      );
      await visible(t, find.text('Enregistrer'));
      await t.tap(find.text('Enregistrer'));
      await t.pumpAndSettle();
      var settings = await t.runAsync(
        () => SembastSettingsRepository(db.db).get(),
      );
      expect(settings!.accountant!.name, 'Cabinet Équilibre');
      expect(settings.displayName, 'Profil conservé');
      await t.tap(find.text('Ouvrir'));
      await t.pumpAndSettle();
      await t.enterText(
        find.byKey(const Key('accountant-0')),
        'Cabinet Modifié',
      );
      await visible(t, find.text('Enregistrer'));
      await t.tap(find.text('Enregistrer'));
      await t.pumpAndSettle();
      settings = await t.runAsync(() => SembastSettingsRepository(db.db).get());
      expect(settings!.accountant!.name, 'Cabinet Modifié');
      await t.pump(const Duration(seconds: 5));
      await t.pumpAndSettle();
      await t.tap(find.text('Ouvrir'));
      await t.pumpAndSettle();
      await visible(t, find.text('Effacer les coordonnées'));
      await t.tap(find.text('Effacer les coordonnées'));
      await t.pumpAndSettle();
      await t.tap(find.text('Effacer'));
      await t.pumpAndSettle();
      settings = await t.runAsync(() => SembastSettingsRepository(db.db).get());
      expect(settings!.accountant, isNull);
      expect(t.takeException(), isNull);
    },
  );
  testWidgets(
    'cabinet : champs et validation accessibles avec clavier affiché',
    (t) async {
      await pump(t, const AccountantScreen(), size: const Size(390, 844));
      await t.enterText(
        find.byKey(const Key('accountant-0')),
        'Cabinet clavier',
      );
      t.view.viewInsets = const FakeViewPadding(bottom: 320);
      await t.pumpAndSettle();
      await visible(t, find.byKey(const Key('accountant-7')));
      await t.enterText(
        find.byKey(const Key('accountant-7')),
        'test@example.fr',
      );
      await visible(t, find.text('Enregistrer'));
      expect(
        t.getRect(find.text('Enregistrer')).bottom,
        lessThanOrEqualTo(844 - 320),
      );
      expect(t.takeException(), isNull);
      await t.tap(find.text('Enregistrer'));
      await t.pumpAndSettle();
      final saved = await t.runAsync(
        () => SembastSettingsRepository(db.db).get(),
      );
      expect(saved!.accountant!.name, 'Cabinet clavier');
    },
  );
}
