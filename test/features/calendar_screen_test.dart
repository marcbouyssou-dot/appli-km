import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:mes_km/app.dart';
import 'package:mes_km/app/providers.dart';
import 'package:mes_km/data/local/app_database.dart';
import 'package:mes_km/data/local/sembast_day_extra_repository.dart';
import 'package:mes_km/data/local/sembast_favorite_trip_repository.dart';
import 'package:mes_km/data/local/sembast_trip_repository.dart';
import 'package:mes_km/data/local/sembast_vacation_repository.dart';
import 'package:mes_km/domain/models/civil_date.dart';
import 'package:mes_km/domain/models/day_extra.dart';
import 'package:mes_km/domain/models/favorite_trip.dart';
import 'package:mes_km/domain/models/trip.dart';
import 'package:mes_km/domain/models/vacation_period.dart';
import 'package:mes_km/features/day/editable_day_total.dart';
import 'package:sembast/sembast_memory.dart' hide Finder;

void main() {
  final today = CivilDate(2026, 10, 11);

  setUpAll(() async {
    await initializeDateFormatting('fr_FR');
  });

  late MesKmDatabase database;

  setUp(() async {
    database = await MesKmDatabase.open(newDatabaseFactoryMemory(),
        name: 'calui.db');
  });

  tearDown(() => database.close());

  Future<void> seedTrip(
      WidgetTester tester, CivilDate date, double km) async {
    await tester.runAsync(() => SembastTripRepository(database.db).put(Trip(
          id: 't-${date.toIso8601()}-$km',
          date: date,
          distanceKm: km,
          createdAt: DateTime.utc(2026, 1, 1),
        )));
  }

  Future<void> seedExtra(
      WidgetTester tester, CivilDate date, double km) async {
    await tester.runAsync(() => SembastDayExtraRepository(database.db)
        .set(DayExtra(date: date, extraKm: km)));
  }

  Future<void> pumpOnCalendar(WidgetTester tester, {CivilDate? now}) async {
    tester.view.physicalSize = const Size(500, 1800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          databaseProvider.overrideWithValue(database),
          todayDateProvider.overrideWithValue(() => now ?? today),
        ],
        child: const MesKmApp(),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byIcon(Icons.calendar_month_outlined));
    await tester.pumpAndSettle();
  }

  Finder cell(String iso) => find.byKey(Key('cal-cell-$iso'));

  String totalFieldText(WidgetTester tester) =>
      tester.widget<TextField>(find.byKey(dayTotalFieldKey)).controller!.text;

  Future<void> editDetailTotal(WidgetTester tester, String text) async {
    await tester.enterText(find.byKey(dayTotalFieldKey), text);
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pumpAndSettle();
  }

  testWidgets(
      'calendrier mensuel : mois, total, jours avec km, jour vide sobre',
      (tester) async {
    await seedTrip(tester, today, 42);
    await seedExtra(tester, CivilDate(2026, 10, 5), 87);

    await pumpOnCalendar(tester);

    expect(find.text('Octobre 2026'), findsOneWidget);
    expect(find.text('129 km'), findsOneWidget); // total du mois
    expect(
      find.descendant(of: cell('2026-10-11'), matching: find.text('42 km')),
      findsOneWidget,
    );
    expect(
      find.descendant(of: cell('2026-10-05'), matching: find.text('87 km')),
      findsOneWidget,
    );
    // Jour vide : uniquement son numéro.
    expect(
      find.descendant(
          of: cell('2026-10-20'), matching: find.textContaining('km')),
      findsNothing,
    );
  });

  testWidgets(
      'tap au BORD d’une cellule ouvre le détail de la bonne date',
      (tester) async {
    await seedExtra(tester, CivilDate(2026, 10, 5), 87);
    await pumpOnCalendar(tester);

    final rect = tester.getRect(cell('2026-10-05'));
    await tester.tapAt(rect.topLeft + const Offset(4, 4));
    await tester.pumpAndSettle();

    expect(find.text('Lundi 5 octobre 2026'), findsOneWidget);
    expect(totalFieldText(tester), '87');
  });

  testWidgets(
      'saisie rétroactive : 87 sur jour vide, retour calendrier rafraîchi',
      (tester) async {
    await pumpOnCalendar(tester);
    expect(find.text('0 km'), findsOneWidget); // total du mois vide

    await tester.tap(cell('2026-10-05'));
    await tester.pumpAndSettle();
    await editDetailTotal(tester, '87');
    expect(totalFieldText(tester), '87');

    await tester.tap(find.byType(BackButton));
    await tester.pumpAndSettle();

    expect(
      find.descendant(of: cell('2026-10-05'), matching: find.text('87 km')),
      findsOneWidget,
    );
    // Cellule du 5 + total du mois (87 est le seul jour renseigné).
    expect(find.text('87 km'), findsNWidgets(2));

    // Réouverture du 5 : la valeur persiste.
    await tester.tap(cell('2026-10-05'));
    await tester.pumpAndSettle();
    expect(totalFieldText(tester), '87');
  });

  testWidgets(
      'journée passée : trajets 24+18 puis total 87 => autres 45 ; '
      'effacement => cellule vide et total mensuel recalculé',
      (tester) async {
    await pumpOnCalendar(tester);

    await tester.tap(cell('2026-10-07'));
    await tester.pumpAndSettle();

    Future<void> addTrip(String km) async {
      await tester.tap(find.text('Ajouter un trajet'));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.widgetWithText(TextField, 'Distance comptabilisée (km)'),
        km,
      );
      await tester.pump(); // bouton actif (UX-003B1)
      await tester.tap(find.text('Ajouter'));
      await tester.pumpAndSettle();
    }

    await addTrip('24');
    await addTrip('18');
    await editDetailTotal(tester, '87');

    expect(find.text('Autres kilomètres'), findsOneWidget);
    expect(find.text('45 km'), findsOneWidget);

    // Effacer la journée depuis le détail.
    await tester.tap(find.byKey(const Key('clear-day-button')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Effacer'));
    await tester.pumpAndSettle();
    expect(totalFieldText(tester), '0');

    await tester.tap(find.byType(BackButton));
    await tester.pumpAndSettle();
    expect(
      find.descendant(
          of: cell('2026-10-07'), matching: find.textContaining('km')),
      findsNothing,
    );
    expect(find.text('0 km'), findsOneWidget); // total mensuel recalculé
  });

  group('favoris sur journée passée (UI)', () {
    Future<void> seedFavorite(WidgetTester tester) async {
      await tester.runAsync(
          () => SembastFavoriteTripRepository(database.db).put(FavoriteTrip(
                id: 'fav-1',
                label: 'Cabinet ↔ EHPAD',
                distanceKm: 24,
                sortOrder: 0,
              )));
    }

    Future<void> flushSnackBar(WidgetTester tester) async {
      await tester.pump(const Duration(seconds: 1));
      await tester.pumpAndSettle();
    }

    testWidgets(
        'favori visible sur le 5 octobre ; deux taps => +48 daté du 5 ; '
        'extra inchangé ; retour calendrier rafraîchi', (tester) async {
      await seedFavorite(tester);
      await seedExtra(tester, CivilDate(2026, 10, 5), 33);
      await pumpOnCalendar(tester);

      await tester.tap(cell('2026-10-05'));
      await tester.pumpAndSettle();

      // Même section favoris que sur Aujourd'hui, au-dessus d'Ajouter.
      expect(find.text('Trajets favoris'), findsOneWidget);
      expect(find.text('+24 km'), findsOneWidget);

      await tester.tap(find.byKey(const Key('favorite-fav-1')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('favorite-fav-1')));
      await tester.pumpAndSettle();
      await flushSnackBar(tester);

      expect(totalFieldText(tester), '81'); // 33 + 24 + 24
      expect(find.text('33 km'), findsOneWidget); // extra intact
      final trips = await tester.runAsync(() =>
          SembastTripRepository(database.db)
              .getByDate(CivilDate(2026, 10, 5)));
      expect(trips, hasLength(2));
      final todayTrips = await tester.runAsync(
          () => SembastTripRepository(database.db).getByDate(today));
      expect(todayTrips, isEmpty, reason: 'rien créé aujourd’hui');

      await tester.tap(find.byType(BackButton));
      await tester.pumpAndSettle();
      expect(
        find.descendant(of: cell('2026-10-05'), matching: find.text('81 km')),
        findsOneWidget,
      );
      expect(find.text('81 km'), findsNWidgets(2)); // cellule + total du mois
    });

    testWidgets(
        'favori créé depuis une journée passée : global, visible sur '
        'Aujourd’hui', (tester) async {
      await pumpOnCalendar(tester);

      await tester.tap(cell('2026-10-05'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Créer un trajet favori'));
      await tester.pumpAndSettle();
      await tester.enterText(
          find.widgetWithText(TextField, 'Nom du favori'), 'Dépôt');
      await tester.enterText(
        find.widgetWithText(TextField, 'Distance comptabilisée (km)'),
        '7,5',
      );
      await tester.pump(); // bouton actif (UX-003B1)
      await tester.tap(find.text('Créer le favori'));
      await tester.pumpAndSettle();
      expect(find.text('Dépôt'), findsOneWidget);

      // Retour calendrier puis Aujourd'hui : même liste globale.
      await tester.tap(find.byType(BackButton));
      await tester.pumpAndSettle();
      await tester.tap(find.byIcon(Icons.today_outlined));
      await tester.pumpAndSettle();
      expect(find.text('Dépôt'), findsOneWidget);
      expect(find.text('+7,5 km'), findsOneWidget);
    });
  });

  testWidgets(
      'raccourci Modifier depuis une journée passée : favori global modifié '
      'partout, la date consultée n’a aucun effet', (tester) async {
    await tester.runAsync(
        () => SembastFavoriteTripRepository(database.db).put(FavoriteTrip(
              id: 'fav-1',
              label: 'Travail',
              distanceKm: 70,
              sortOrder: 0,
            )));
    await pumpOnCalendar(tester);

    await tester.tap(cell('2026-10-05'));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('edit-favorite-fav-1')), findsOneWidget);

    await tester.tap(find.byKey(const Key('edit-favorite-fav-1')));
    await tester.pumpAndSettle();
    expect(find.text('Modifier le favori'), findsOneWidget);
    await tester.enterText(
      find.widgetWithText(TextField, 'Distance comptabilisée (km)'),
      '72',
    );
    await tester.pump(); // bouton actif (UX-003B1)
    await tester.tap(find.text('Enregistrer'));
    await tester.pumpAndSettle();

    // Retour gestion -> détail -> calendrier -> Aujourd'hui.
    await tester.tap(find.byType(BackButton));
    await tester.pumpAndSettle();
    expect(find.text('+72 km'), findsOneWidget); // journée passée à jour

    await tester.tap(find.byType(BackButton));
    await tester.pumpAndSettle();
    await tester.tap(find.byIcon(Icons.today_outlined));
    await tester.pumpAndSettle();
    expect(find.text('+72 km'), findsOneWidget); // global, aussi Aujourd'hui

    // Aucune date passée n'a reçu de Trip par le raccourci.
    final trips = await tester
        .runAsync(() => SembastTripRepository(database.db).getAll());
    expect(trips, isEmpty);
  });

  testWidgets(
      'suppression globale (via Plus) : le favori disparaît des journées '
      'passées, les Trips historiques restent', (tester) async {
    await tester.runAsync(
        () => SembastFavoriteTripRepository(database.db).put(FavoriteTrip(
              id: 'fav-1',
              label: 'Cabinet ↔ EHPAD',
              distanceKm: 24,
              sortOrder: 0,
            )));
    await pumpOnCalendar(tester);

    // Un Trip historique issu du favori sur le 5.
    await tester.tap(cell('2026-10-05'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('favorite-fav-1')));
    await tester.pumpAndSettle();
    await tester.pump(const Duration(seconds: 1));
    await tester.pumpAndSettle();
    await tester.tap(find.byType(BackButton));
    await tester.pumpAndSettle();

    // Suppression globale depuis Plus.
    await tester.tap(find.byIcon(Icons.more_horiz_outlined));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Trajets favoris'));
    await tester.pumpAndSettle();
    await tester.tap(find.byIcon(Icons.delete_outline));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Supprimer'));
    await tester.pumpAndSettle();
    await tester.tap(find.byType(BackButton));
    await tester.pumpAndSettle();

    // La journée passée ne propose plus le favori, mais garde son Trip.
    await tester.tap(find.byIcon(Icons.calendar_month_outlined));
    await tester.pumpAndSettle();
    await tester.tap(cell('2026-10-05'));
    await tester.pumpAndSettle();
    expect(find.text('Créer un trajet favori'), findsOneWidget);
    expect(find.byKey(const Key('favorite-fav-1')), findsNothing);
    expect(find.text('Trajets détaillés'), findsOneWidget);
    expect(totalFieldText(tester), '24');
  });

  group('congés (UI calendrier)', () {
    Future<void> seedPeriod(
        WidgetTester tester, CivilDate start, CivilDate end) async {
      await tester.runAsync(() => SembastVacationRepository(database.db).put(
          VacationPeriod(
              id: 'p-${start.toIso8601()}', startDate: start, endDate: end)));
    }

    testWidgets(
        'ajout d’une période 3→10 via la feuille : cellules marquées '
        '« Congé » (indice textuel, pas seulement couleur)', (tester) async {
      await pumpOnCalendar(tester);

      await tester.tap(find.byKey(const Key('cal-vacations-button')));
      await tester.pumpAndSettle();

      // Les taps du sélecteur sont restreints au dialogue (le calendrier
      // derrière la feuille affiche les mêmes numéros de jours).
      Finder inPicker(String text) => find.descendant(
            of: find.byType(DatePickerDialog),
            matching: find.text(text),
          );

      // Du 3…
      await tester.tap(find.byKey(const Key('vacation-start')));
      await tester.pumpAndSettle();
      await tester.tap(inPicker('3'));
      await tester.tap(inPicker('OK'));
      await tester.pumpAndSettle();
      // …au 10.
      await tester.tap(find.byKey(const Key('vacation-end')));
      await tester.pumpAndSettle();
      await tester.tap(inPicker('10'));
      await tester.tap(inPicker('OK'));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('vacation-add')));
      await tester.pumpAndSettle();
      // La liste minimale montre la période créée.
      expect(find.text('3 oct. 2026 → 10 oct. 2026'), findsOneWidget);

      await tester.tap(find.text('Fermer'));
      await tester.pumpAndSettle();

      for (final day in ['03', '05', '10']) {
        expect(
          find.descendant(
              of: cell('2026-10-$day'), matching: find.text('Congé')),
          findsOneWidget,
        );
      }
      expect(
        find.descendant(
            of: cell('2026-10-02'), matching: find.text('Congé')),
        findsNothing,
      );
    });

    testWidgets(
        'retirer le congé du 6 depuis le détail : 3-5 et 7-10 restent',
        (tester) async {
      await seedPeriod(
          tester, CivilDate(2026, 10, 3), CivilDate(2026, 10, 10));
      await pumpOnCalendar(tester);

      await tester.tap(cell('2026-10-06'));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('vacation-card')), findsOneWidget);

      await tester.tap(find.byKey(const Key('remove-vacation-button')));
      await tester.pumpAndSettle();
      await tester.tap(find.byType(BackButton));
      await tester.pumpAndSettle();

      expect(
        find.descendant(
            of: cell('2026-10-06'), matching: find.text('Congé')),
        findsNothing,
      );
      for (final day in ['05', '07']) {
        expect(
          find.descendant(
              of: cell('2026-10-$day'), matching: find.text('Congé')),
          findsOneWidget,
        );
      }
    });

    testWidgets('suppression d’une période complète via la feuille',
        (tester) async {
      await seedPeriod(
          tester, CivilDate(2026, 10, 3), CivilDate(2026, 10, 10));
      await pumpOnCalendar(tester);

      await tester.tap(find.byKey(const Key('cal-vacations-button')));
      await tester.pumpAndSettle();
      await tester.tap(find.byIcon(Icons.delete_outline));
      await tester.pumpAndSettle();
      expect(
        find.text('Supprimer cette période de congés ?'),
        findsOneWidget,
      );
      await tester.tap(find.text('Supprimer'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Fermer'));
      await tester.pumpAndSettle();

      expect(
        find.descendant(
            of: cell('2026-10-05'), matching: find.text('Congé')),
        findsNothing,
      );
    });

    testWidgets('marquer une journée vide depuis le détail', (tester) async {
      await pumpOnCalendar(tester);

      await tester.tap(cell('2026-10-20'));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('mark-vacation-button')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('vacation-card')), findsOneWidget);

      await tester.tap(find.byType(BackButton));
      await tester.pumpAndSettle();
      expect(
        find.descendant(
            of: cell('2026-10-20'), matching: find.text('Congé')),
        findsOneWidget,
      );
    });
  });

  testWidgets('navigation mois précédent/suivant + retour aujourd’hui',
      (tester) async {
    await seedTrip(tester, CivilDate(2026, 9, 30), 99);
    await pumpOnCalendar(tester);

    expect(find.byKey(const Key('cal-today-button')), findsNothing);

    await tester.tap(find.byKey(const Key('cal-prev')));
    await tester.pumpAndSettle();
    expect(find.text('Septembre 2026'), findsOneWidget);
    expect(find.text('99 km'), findsNWidgets(2)); // total + cellule du 30

    await tester.tap(find.byKey(const Key('cal-today-button')));
    await tester.pumpAndSettle();
    expect(find.text('Octobre 2026'), findsOneWidget);

    await tester.tap(find.byKey(const Key('cal-next')));
    await tester.pumpAndSettle();
    expect(find.text('Novembre 2026'), findsOneWidget);
  });

  testWidgets('décembre -> janvier au changement d’année',
      (tester) async {
    await seedTrip(tester, CivilDate(2025, 12, 31), 30);
    await pumpOnCalendar(tester, now: CivilDate(2026, 1, 15));

    expect(find.text('Janvier 2026'), findsOneWidget);
    await tester.tap(find.byKey(const Key('cal-prev')));
    await tester.pumpAndSettle();
    expect(find.text('Décembre 2025'), findsOneWidget);
    expect(
      find.descendant(of: cell('2025-12-31'), matching: find.text('30 km')),
      findsOneWidget,
    );
  });

  testWidgets(
      'rafraîchissement croisé : modifier aujourd’hui via calendrier '
      'puis retour Aujourd’hui ; navigation basse fonctionnelle',
      (tester) async {
    await pumpOnCalendar(tester);

    await tester.tap(cell('2026-10-11'));
    await tester.pumpAndSettle();
    await editDetailTotal(tester, '50');
    await tester.tap(find.byType(BackButton));
    await tester.pumpAndSettle();

    expect(
      find.descendant(of: cell('2026-10-11'), matching: find.text('50 km')),
      findsOneWidget,
    );

    // Onglet Aujourd'hui synchronisé (même date => même contrôleur).
    await tester.tap(find.byIcon(Icons.today_outlined));
    await tester.pumpAndSettle();
    expect(totalFieldText(tester), '50');

    // Navigation basse toujours fiable après édition + clavier.
    await tester.tap(find.byIcon(Icons.bar_chart_outlined));
    await tester.pumpAndSettle();
    expect(find.text('TOTAL ANNÉE'), findsOneWidget);
  });
}
