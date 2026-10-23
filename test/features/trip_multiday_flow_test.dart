import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:mes_km/app/providers.dart';
import 'package:mes_km/data/local/app_database.dart';
import 'package:mes_km/data/local/codecs.dart';
import 'package:mes_km/domain/models/civil_date.dart';
import 'package:mes_km/domain/models/trip.dart';
import 'package:mes_km/domain/models/vacation_period.dart';
import 'package:mes_km/domain/models/vehicle.dart';
import 'package:mes_km/features/day/day_view.dart';
import 'package:mes_km/features/day/trip_days_screen.dart';
import 'package:sembast/sembast_memory.dart' hide Finder;

void main() {
  setUpAll(() => initializeDateFormatting('fr_FR'));
  final today = CivilDate(2026, 10, 23), past = CivilDate(2026, 10, 5);
  late MesKmDatabase db;
  setUp(() async {
    db = await MesKmDatabase.open(newDatabaseFactoryMemory());
  });
  tearDown(() => db.close());
  Future<void> pump(
    WidgetTester t, {
    double width = 390,
    double height = 1000,
    CivilDate? day,
    double scale = 1,
  }) async {
    t.view.physicalSize = Size(width, height);
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
            appBar: AppBar(title: const Text('Journée')),
            body: DayView(date: day ?? today),
          ),
        ),
      ),
    );
    await t.pumpAndSettle();
  }

  Future<void> visible(WidgetTester t, Finder finder) async {
    if (finder.evaluate().isEmpty) {
      await t.scrollUntilVisible(
        finder,
        160,
        scrollable: find.byType(Scrollable).last,
      );
    } else {
      await t.ensureVisible(finder);
    }
    await t.pumpAndSettle();
  }

  Future<void> tap(WidgetTester t, Finder finder) async {
    await visible(t, finder);
    await t.tap(finder);
    await t.pumpAndSettle();
  }

  Finder day(CivilDate d) => find.byKey(Key('batch-day-${d.toIso8601()}'));
  Finder getReview() => find.byKey(const Key('review-favorite-days'));
  Future<void> input(WidgetTester t, {String distance = '70'}) async {
    await tap(t, find.text('Ajouter un trajet'));
    await t.enterText(
      find.widgetWithText(TextField, 'Distance comptabilisée (km)'),
      distance,
    );
    await t.pumpAndSettle();
  }

  Future<void> multi(WidgetTester t) async {
    await tap(t, find.byKey(const Key('new-trip-multi-day')));
    await tap(t, find.text('Enregistrer le trajet'));
  }

  Future<int> count(WidgetTester t) async =>
      (await t.runAsync(() => tripsStore.count(db.db)))!;
  Future<void> confirm(WidgetTester t) async {
    final checkbox = find.byType(CheckboxListTile);
    if (checkbox.evaluate().isNotEmpty) await tap(t, checkbox);
    await tap(t, getReview());
    await tap(t, find.byKey(const Key('confirm-favorite-days')));
  }

  Future<void> seed(WidgetTester t, Trip trip) async =>
      t.runAsync(() => tripsStore.record(trip.id).put(db.db, tripToDb(trip)));

  testWidgets(
    'date passée explicite, choix unique par défaut, enregistrement direct',
    (t) async {
      await pump(t, day: past);
      await input(t, distance: '23');
      expect(find.text('lundi 5 octobre 2026'), findsOneWidget);
      expect(
        t.widget<RadioGroup<bool>>(find.byType(RadioGroup<bool>)).groupValue,
        isFalse,
      );
      expect(find.text('Enregistrer le trajet'), findsOneWidget);
      expect(find.text('Ajouter'), findsNothing);
      expect(await count(t), 0);
      await tap(t, find.text('Enregistrer le trajet'));
      expect(find.byType(TripDaysScreen), findsNothing);
      final trips = await t.runAsync(() => tripsStore.find(db.db));
      expect(trips!.single.value['date'], past.toIso8601());
      expect(trips.single.value['distanceKm'], 23);
    },
  );
  testWidgets(
    'choix multi-jours sans écriture, zéro date interdit, retour garde le mode',
    (t) async {
      await pump(t);
      await input(t);
      expect(find.text('Aujourd’hui'), findsOneWidget);
      await tap(t, find.byKey(const Key('new-trip-multi-day')));
      expect(find.byType(TripDaysScreen), findsNothing);
      expect(await count(t), 0);
      await tap(t, find.text('Enregistrer le trajet'));
      await tap(t, day(today));
      await visible(t, getReview());
      expect(t.widget<FilledButton>(getReview()).onPressed, isNull);
      expect(await count(t), 0);
      await t.pageBack();
      await t.pumpAndSettle();
      expect(
        t.widget<RadioGroup<bool>>(find.byType(RadioGroup<bool>)).groupValue,
        isTrue,
      );
      expect(find.text('70'), findsOneWidget);
      await tap(t, find.text('Enregistrer le trajet'));
      expect(find.byType(TripDaysScreen), findsOneWidget);
      expect(await count(t), 0);
    },
  );
  for (final n in [1, 2, 5, 10]) {
    testWidgets(
      '$n trajets : report visible du bon trajet et suppression directe',
      (t) async {
        for (var i = 0; i < n; i++) {
          await seed(
            t,
            Trip(
              id: 'source-$i',
              date: past,
              distanceKm: 20.0 + i,
              purpose: 'Mission $i',
              createdAt: DateTime.utc(2026, 10, 1, i),
            ),
          );
        }
        await pump(t, day: past, width: 320, height: 568);
        expect(find.byType(PopupMenuButton<String>), findsNothing);
        expect(find.text('Reporter sur d’autres jours'), findsNWidgets(n));
        for (var i = 0; i < n; i++) {
          await tap(t, find.byKey(Key('report-trip-source-$i')));
          final screen = t.widget<TripDaysScreen>(find.byType(TripDaysScreen));
          expect(screen.source.tripId, 'source-$i');
          expect(screen.template.distanceKm, 20.0 + i);
          expect(screen.template.purpose, 'Mission $i');
          expect(await count(t), n);
          await t.pageBack();
          await t.pumpAndSettle();
        }
        await tap(t, find.byKey(Key('delete-trip-source-${n - 1}')));
        await tap(t, find.text('Supprimer').last);
        expect(await count(t), n - 1);
        expect(
          await t.runAsync(
            () => tripsStore.record('source-${n - 1}').get(db.db),
          ),
          isNull,
        );
        expect(t.takeException(), isNull);
      },
    );
  }

  testWidgets('saisie simple conservée, multi-jours sans création de favori', (
    t,
  ) async {
    await pump(t);
    await input(t, distance: '12');
    await tap(t, find.text('Enregistrer le trajet'));
    expect(await count(t), 1);
    await input(t);
    await multi(t);
    expect(await count(t), 1);
    await tap(t, day(past));
    await confirm(t);
    expect(find.byType(TripDaysScreen), findsNothing);
    expect(await count(t), 3); // simple + aujourd’hui + passé
    expect(await t.runAsync(() => favoriteTripsStore.count(db.db)), 0);
    expect(t.takeException(), isNull);
  });
  testWidgets(
    'retour conserve tous les champs ; annulation et récapitulatif sans écriture',
    (t) async {
      await pump(t);
      await input(t);
      await tap(t, find.text('Aller-retour'));
      await tap(t, find.text('Itinéraire et détails'));
      for (final (label, text) in [
        ('Départ', 'Cabinet'),
        ('Destination', 'Clinique'),
        ('Motif', 'Tournée'),
      ]) {
        await visible(t, find.widgetWithText(TextField, label));
        await t.enterText(find.widgetWithText(TextField, label), text);
      }
      await multi(t);
      await tap(t, day(past));
      await tap(t, find.byType(CheckboxListTile));
      await tap(t, getReview());
      expect(await count(t), 0);
      await tap(t, find.text('Annuler'));
      await t.pageBack();
      await t.pumpAndSettle();
      for (final value in ['70', 'Cabinet', 'Clinique', 'Tournée']) {
        expect(find.text(value), findsOneWidget);
      }
      expect(
        t.widget<SwitchListTile>(find.byType(SwitchListTile)).value,
        isTrue,
      );
      await tap(t, find.text('Annuler'));
      expect(await count(t), 0);
    },
  );
  testWidgets(
    'date initiale désélectionnée : seul le passé confirmé reçoit le trajet',
    (t) async {
      await pump(t);
      await input(t);
      await multi(t);
      await tap(t, day(today));
      await tap(t, day(past));
      await confirm(t);
      final trips = await t.runAsync(() => tripsStore.find(db.db));
      expect(trips!.single.value['date'], past.toIso8601());
    },
  );
  testWidgets('sélection conservée entre mois, futur désactivé', (t) async {
    await pump(t);
    await input(t);
    await multi(t);
    final future = t.widget<TextButton>(day(today.addDays(1)));
    expect(future.onPressed, isNull);
    await tap(t, find.byTooltip('Mois précédent'));
    await tap(t, day(CivilDate(2026, 9, 14)));
    await tap(t, find.byTooltip('Mois suivant'));
    await tap(t, find.text('Voir les dates choisies'));
    expect(find.textContaining('14/09/2026'), findsOneWidget);
    expect(find.textContaining('23/10/2026'), findsOneWidget);
    await confirm(t);
    expect(await count(t), 2);
  });
  testWidgets(
    'congé du jour initial préservé dès ouverture, annulation et validation multi-jours',
    (t) async {
      final vacation = vacationPeriodToDb(
        VacationPeriod(id: 'holiday', startDate: today, endDate: today),
      );
      await t.runAsync(
        () => vacationPeriodsStore.record('holiday').put(db.db, vacation),
      );
      await pump(t);
      await input(t);
      expect(find.text('Cette journée est marquée comme congé.'), findsNothing);
      await multi(t);
      await tap(t, day(past));
      await tap(t, find.byType(CheckboxListTile));
      await tap(t, getReview());
      expect(find.textContaining('1 jour(s) de congé exclus'), findsOneWidget);
      await tap(t, find.byKey(const Key('confirm-favorite-days')));
      expect(await count(t), 1);
      expect(
        await t.runAsync(
          () => vacationPeriodsStore.record('holiday').get(db.db),
        ),
        vacation,
      );
    },
  );

  for (final date in [today, past]) {
    testWidgets(
      'report depuis journée $date, source intacte et copies indépendantes',
      (t) async {
        final source = Trip(
          id: 'source',
          date: date,
          distanceKm: 70,
          isRoundTrip: true,
          origin: 'Cabinet',
          destination: 'Clinique',
          purpose: 'Visite',
          vehicleId: null,
          createdAt: DateTime.utc(2026, 10, 1),
        );
        await seed(t, source);
        await pump(t, day: date);
        await tap(t, find.byKey(const Key('report-trip-source')));
        expect(await count(t), 1);
        await tap(t, day(date));
        if (find.byType(CheckboxListTile).evaluate().isNotEmpty) {
          await tap(t, find.byType(CheckboxListTile));
        }
        await tap(t, getReview());
        expect(find.text('Aucun nouveau trajet à ajouter.'), findsOneWidget);
        expect(find.byKey(const Key('confirm-favorite-days')), findsNothing);
        await tap(t, find.text('Annuler'));
        final target = CivilDate(2026, 10, 12);
        await tap(t, day(target));
        await tap(t, find.byType(CheckboxListTile));
        await tap(t, getReview());
        expect(
          find.textContaining('1 trajet(s) déjà présent(s)'),
          findsOneWidget,
        );
        expect(find.text('Trajets à ajouter : 1'), findsOneWidget);
        await tap(t, find.byKey(const Key('confirm-favorite-days')));
        expect(await count(t), 2);
        expect(
          await t.runAsync(() => tripsStore.record('source').get(db.db)),
          tripToDb(source),
        );
        expect(t.takeException(), isNull);
      },
    );
  }
  testWidgets(
    'véhicule historique proposé, principal actuel jamais substitué',
    (t) async {
      final source = Trip(
        id: 'source',
        date: past,
        distanceKm: 70,
        vehicleId: 'old',
        createdAt: DateTime.utc(2026, 10, 1),
      );
      await t.runAsync(() async {
        for (final v in [
          Vehicle(
            id: 'old',
            name: 'Historique',
            category: VehicleCategory.car,
            archivedAt: DateTime(2026, 10, 20),
          ),
          Vehicle(
            id: 'current',
            name: 'Principal actuel',
            category: VehicleCategory.car,
          ),
        ]) {
          await vehiclesStore.record(v.id).put(db.db, vehicleToDb(v));
        }
        await settingsStore.record(settingsRecordKey).put(db.db, {
          'mainVehicleId': 'current',
        });
      });
      await seed(t, source);
      await pump(t, day: past);
      await tap(t, find.byKey(const Key('report-trip-source')));
      await tap(t, day(CivilDate(2026, 10, 12)));
      await visible(t, find.byKey(const ValueKey('batch-vehicle-old')));
      expect(find.byKey(const ValueKey('batch-vehicle-old')), findsOneWidget);
      await confirm(t);
      final all = await t.runAsync(() => tripsStore.find(db.db));
      expect(all!.every((s) => s.value['vehicleId'] == 'old'), isTrue);
    },
  );
  testWidgets(
    'nouveau trajet : véhicule choisi dans le formulaire conservé pour le lot',
    (t) async {
      await t.runAsync(() async {
        for (final v in [
          Vehicle(id: 'main', name: 'Principal', category: VehicleCategory.car),
          Vehicle(
            id: 'chosen',
            name: 'Véhicule choisi',
            category: VehicleCategory.car,
          ),
        ]) {
          await vehiclesStore.record(v.id).put(db.db, vehicleToDb(v));
        }
        await settingsStore.record(settingsRecordKey).put(db.db, {
          'mainVehicleId': 'main',
        });
      });
      await pump(t);
      await input(t);
      await tap(t, find.byKey(const Key('trip-vehicle-field')));
      await tap(t, find.text('Véhicule choisi').last);
      await multi(t);
      await visible(t, find.byKey(const ValueKey('batch-vehicle-chosen')));
      expect(
        find.byKey(const ValueKey('batch-vehicle-chosen')),
        findsOneWidget,
      );
      await tap(t, day(past));
      await confirm(t);
      final all = await t.runAsync(() => tripsStore.find(db.db));
      expect(all!.length, 2);
      expect(all.every((s) => s.value['vehicleId'] == 'chosen'), isTrue);
    },
  );
  testWidgets(
    'véhicule source disparu : avertissement et choix null confirmé, jamais principal actuel',
    (t) async {
      final source = Trip(
        id: 'source',
        date: past,
        distanceKm: 70,
        vehicleId: 'missing',
        createdAt: DateTime.utc(2026, 10, 1),
      );
      await seed(t, source);
      await t.runAsync(() async {
        await vehiclesStore
            .record('main')
            .put(
              db.db,
              vehicleToDb(
                Vehicle(
                  id: 'main',
                  name: 'Principal actuel',
                  category: VehicleCategory.car,
                ),
              ),
            );
        await settingsStore.record(settingsRecordKey).put(db.db, {
          'mainVehicleId': 'main',
        });
      });
      await pump(t, day: past);
      await tap(t, find.byKey(const Key('report-trip-source')));
      await tap(t, day(today));
      await visible(t, find.byType(CheckboxListTile));
      expect(find.textContaining('n’est plus disponible'), findsOneWidget);
      await visible(t, getReview());
      expect(t.widget<FilledButton>(getReview()).onPressed, isNull);
      await confirm(t);
      final all = await t.runAsync(() => tripsStore.find(db.db));
      expect(
        all!.singleWhere((s) => s.key != 'source').value['vehicleId'],
        isNull,
      );
    },
  );
  for (final (width, height, scale) in [
    (320.0, 568.0, 1.0),
    (375.0, 667.0, 1.0),
    (390.0, 844.0, 1.0),
    (430.0, 932.0, 1.3),
  ]) {
    testWidgets(
      'formulaire clavier + scroll + multi-jours sur ${width}px @ $scale',
      (t) async {
        await pump(t, width: width, height: height, scale: scale);
        await input(t, distance: '1234567,8');
        t.view.viewPadding = const FakeViewPadding(bottom: 34);
        await t.pumpAndSettle();
        expect(
          t.getRect(find.text('Enregistrer le trajet')).bottom,
          lessThanOrEqualTo(height - 34),
        );
        t.view.viewInsets = const FakeViewPadding(bottom: 240);
        await t.pumpAndSettle();
        final shortcut = find.byKey(const Key('new-trip-multi-day'));
        await visible(t, shortcut);
        final r = t.getRect(shortcut);
        expect(r.height, greaterThanOrEqualTo(44));
        expect(r.bottom, lessThanOrEqualTo(height - 240));
        expect(t.takeException(), isNull);
        t.view.viewInsets = FakeViewPadding.zero;
        await t.pumpAndSettle();
        await multi(t);
        expect(find.byType(TripDaysScreen), findsOneWidget);
        expect(t.takeException(), isNull);
        await t.pageBack();
        await t.pumpAndSettle();
        await tap(t, find.text('Annuler'));
        expect(await count(t), 0);
      },
    );
  }
}
