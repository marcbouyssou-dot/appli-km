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
import 'package:mes_km/data/repositories/trip_repository.dart';
import 'package:mes_km/domain/models/civil_date.dart';
import 'package:mes_km/domain/models/day_extra.dart';
import 'package:mes_km/domain/models/favorite_trip.dart';
import 'package:mes_km/domain/models/trip.dart';
import 'package:mes_km/features/today/editable_day_total.dart';
import 'package:sembast/sembast_memory.dart';

void main() {
  final day = CivilDate(2026, 10, 11);

  setUpAll(() async {
    await initializeDateFormatting('fr_FR');
  });

  late MesKmDatabase database;

  setUp(() async {
    database =
        await MesKmDatabase.open(newDatabaseFactoryMemory(), name: 'ui.db');
  });

  tearDown(() => database.close());

  // Les accès directs aux repositories depuis un corps de testWidgets passent
  // par tester.runAsync : sembast s'appuie sur de vrais timers, gelés dans la
  // zone FakeAsync tant qu'aucun pump n'avance le temps simulé.
  Future<void> seedTrip(WidgetTester tester, String id, double km) async {
    await tester.runAsync(() => SembastTripRepository(database.db).put(Trip(
          id: id,
          date: day,
          distanceKm: km,
          // createdAt distincts pour un ordre d'affichage déterministe.
          createdAt: DateTime.utc(2026, 10, 11, 8, km.round() % 60),
        )));
  }

  Future<void> seedExtra(WidgetTester tester, double km) async {
    await tester.runAsync(() => SembastDayExtraRepository(database.db)
        .set(DayExtra(date: day, extraKm: km)));
  }

  Future<void> pumpApp(
    WidgetTester tester, {
    TripRepository? tripRepository,
  }) async {
    // Surface haute type iPhone : la ListView construit toutes les sections
    // (une ListView ne matérialise pas ses enfants hors écran).
    tester.view.physicalSize = const Size(500, 1800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          databaseProvider.overrideWithValue(database),
          todayDateProvider.overrideWithValue(() => day),
          if (tripRepository != null)
            tripRepositoryProvider.overrideWithValue(tripRepository),
        ],
        child: const MesKmApp(),
      ),
    );
    await tester.pumpAndSettle();
  }

  /// Saisit [text] dans la grande valeur puis termine l'édition (« OK »).
  Future<void> editTotal(WidgetTester tester, String text) async {
    await tester.enterText(find.byKey(dayTotalFieldKey), text);
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pumpAndSettle();
  }

  /// Vérifie la valeur affichée par le compteur (texte du champ ;
  /// `find.text` matcherait aussi le filigrane hint, toujours monté).
  void expectTotal(WidgetTester tester, String value) {
    final field = tester.widget<TextField>(find.byKey(dayTotalFieldKey));
    expect(field.controller!.text, value);
  }

  bool totalFieldHasFocus(WidgetTester tester) {
    final editable = tester.widget<EditableText>(find.descendant(
      of: find.byKey(dayTotalFieldKey),
      matching: find.byType(EditableText),
    ));
    return editable.focusNode.hasFocus;
  }

  testWidgets('affiche le total dérivé des données existantes',
      (tester) async {
    await seedTrip(tester, 't-1', 24);
    await seedExtra(tester, 45);

    await pumpApp(tester);

    expectTotal(tester, '69'); // grande valeur éditable
    expect(find.text('km aujourd’hui'), findsOneWidget);
  });

  testWidgets('toucher la grande valeur ouvre l’édition (clavier)',
      (tester) async {
    await pumpApp(tester);
    expect(totalFieldHasFocus(tester), isFalse);

    await tester.tap(find.byKey(dayTotalFieldKey));
    await tester.pumpAndSettle();

    expect(totalFieldHasFocus(tester), isTrue);
  });

  testWidgets(
      'UN SEUL tap au BORD de la carte (pas sur les chiffres) ouvre '
      'l’édition ; la première frappe remplace l’ancienne valeur',
      (tester) async {
    await seedExtra(tester, 33);
    await pumpApp(tester);
    expect(totalFieldHasFocus(tester), isFalse);

    final cardRect = tester.getRect(find.byKey(dayTotalCardKey));
    await tester.tapAt(cardRect.topLeft + const Offset(12, 12));
    await tester.pumpAndSettle();

    expect(totalFieldHasFocus(tester), isTrue);
    // Effet compteur : champ vidé (la frappe part de zéro, aucune sélection
    // nécessaire), ancienne valeur affichée en filigrane.
    final field = tester.widget<TextField>(find.byKey(dayTotalFieldKey));
    expect(field.controller!.text, isEmpty);
    expect(field.decoration?.hintText, '33');
    expect(field.enableInteractiveSelection, isFalse);
  });

  testWidgets('la frappe s’affiche immédiatement en grand (87,5)',
      (tester) async {
    await seedExtra(tester, 33);
    await pumpApp(tester);

    await tester.tap(find.byKey(dayTotalCardKey));
    await tester.pumpAndSettle();

    // Pendant la frappe, AVANT la fin d'édition : la valeur est visible.
    await tester.enterText(find.byKey(dayTotalFieldKey), '87,5');
    await tester.pump();
    expect(find.text('87,5'), findsOneWidget);

    // Fin d'édition : commit.
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pumpAndSettle();
    expectTotal(tester, '87,5');
    final stored = await tester.runAsync(
        () => SembastDayExtraRepository(database.db).getForDate(day));
    expect(stored?.extraKm, 87.5);
  });

  testWidgets(
      'édition abandonnée sans frappe : valeur conservée, rien d’écrit',
      (tester) async {
    await seedExtra(tester, 33);
    await pumpApp(tester);

    await tester.tap(find.byKey(dayTotalCardKey));
    await tester.pumpAndSettle();
    // Fin d'édition sans aucune frappe (champ resté vide).
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pumpAndSettle();

    expectTotal(tester, '33');
    final stored = await tester.runAsync(
        () => SembastDayExtraRepository(database.db).getForDate(day));
    expect(stored?.extraKm, 33);
  });

  testWidgets('RÉGRESSION recette : 33 km persistés => 0 via édition directe',
      (tester) async {
    await seedExtra(tester, 33);
    await pumpApp(tester);
    expectTotal(tester, '33');

    // Tap sur la carte (zone large), puis 0.
    await tester.tap(find.byKey(dayTotalCardKey));
    await tester.pumpAndSettle();
    await editTotal(tester, '0');

    expectTotal(tester, '0');
    expect(find.text('Autres kilomètres'), findsNothing);
    final stored = await tester.runAsync(
        () => SembastDayExtraRepository(database.db).getForDate(day));
    expect(stored, isNull);
  });

  testWidgets('la navigation basse fonctionne encore après édition du total',
      (tester) async {
    await pumpApp(tester);

    await editTotal(tester, '87');
    expectTotal(tester, '87');

    await tester.tap(find.text('Calendrier'));
    await tester.pumpAndSettle();
    expect(find.text('Le calendrier de vos kilomètres'), findsOneWidget);

    await tester.tap(find.text('Statistiques'));
    await tester.pumpAndSettle();
    expect(find.text('Vos statistiques kilométriques'), findsOneWidget);

    await tester.tap(find.text('Plus'));
    await tester.pumpAndSettle();
    expect(find.text('Véhicules'), findsOneWidget);

    await tester.tap(find.text('Aujourd’hui').last);
    await tester.pumpAndSettle();
    expectTotal(tester, '87');
  });

  testWidgets('le texte obsolète de l’ancienne feuille a disparu',
      (tester) async {
    await seedExtra(tester, 45);
    await pumpApp(tester);

    expect(find.text('Autres kilomètres'), findsOneWidget);
    expect(
      find.textContaining('Saisir le total du jour'),
      findsNothing,
    );
  });

  testWidgets('saisie directe : 87 affiché puis persisté', (tester) async {
    await pumpApp(tester);

    await editTotal(tester, '87');

    expectTotal(tester, '87');
    expect(find.text('Autres kilomètres'), findsOneWidget);
    expect(find.text('87 km'), findsOneWidget); // ligne autres kilomètres

    final stored = await tester.runAsync(
        () => SembastDayExtraRepository(database.db).getForDate(day));
    expect(stored?.extraKm, 87);
  });

  testWidgets('virgule française acceptée (24,5)', (tester) async {
    await pumpApp(tester);

    await editTotal(tester, '24,5');

    expectTotal(tester, '24,5');
    final stored = await tester.runAsync(
        () => SembastDayExtraRepository(database.db).getForDate(day));
    expect(stored?.extraKm, 24.5);
  });

  testWidgets(
      'RÉGRESSION KM-004A/B : 87 puis édition à 0 => journée vide',
      (tester) async {
    await seedExtra(tester, 87);

    await pumpApp(tester);
    expectTotal(tester, '87');

    await editTotal(tester, '0');

    expectTotal(tester, '0');
    expect(find.text('Autres kilomètres'), findsNothing);
    expect(
      find.text('Aucun kilomètre enregistré aujourd’hui.'),
      findsOneWidget,
    );
    final stored = await tester.runAsync(
        () => SembastDayExtraRepository(database.db).getForDate(day));
    expect(stored, isNull);
  });

  testWidgets(
      'Trips 24+18 : tentative 40 refusée, dernière valeur valide restaurée',
      (tester) async {
    await seedTrip(tester, 't-1', 24);
    await seedTrip(tester, 't-2', 18);

    await pumpApp(tester);
    expectTotal(tester, '42');

    await editTotal(tester, '40');

    expect(
      find.text('Les trajets détaillés totalisent déjà 42 km.'),
      findsOneWidget,
    );
    expectTotal(tester, '42'); // valeur restaurée
    expect(find.text('24 km'), findsOneWidget);
    expect(find.text('18 km'), findsOneWidget);

    // Laisse la snackbar expirer (timer en attente sinon).
    await tester.pump(const Duration(seconds: 5));
    await tester.pumpAndSettle();
  });

  testWidgets('saisie invalide : valeur restaurée, rien n’est écrit',
      (tester) async {
    await seedExtra(tester, 87);

    await pumpApp(tester);
    await editTotal(tester, 'abc');

    expectTotal(tester, '87');
    final stored = await tester.runAsync(
        () => SembastDayExtraRepository(database.db).getForDate(day));
    expect(stored?.extraKm, 87);
  });

  testWidgets('« Ajouter un trajet » reste fonctionnel', (tester) async {
    await pumpApp(tester);

    await tester.tap(find.text('Ajouter un trajet'));
    await tester.pumpAndSettle();

    await tester.enterText(
      find.widgetWithText(TextField, 'Distance comptabilisée (km)'),
      '24,5',
    );
    await tester.tap(find.text('Ajouter'));
    await tester.pumpAndSettle();

    expect(find.text('Trajets détaillés'), findsOneWidget);
    expect(find.text('24,5 km'), findsOneWidget); // ligne trajet
    expectTotal(tester, '24,5'); // grande valeur
  });

  testWidgets('décomposition : détaillés + autres kilomètres',
      (tester) async {
    await seedTrip(tester, 't-1', 24);
    await seedTrip(tester, 't-2', 18);
    await seedExtra(tester, 45);

    await pumpApp(tester);

    expectTotal(tester, '87');
    expect(find.text('Trajets détaillés'), findsOneWidget);
    expect(find.text('24 km'), findsOneWidget);
    expect(find.text('18 km'), findsOneWidget);
    expect(find.text('Autres kilomètres'), findsOneWidget);
    expect(find.text('45 km'), findsOneWidget);
  });

  testWidgets('suppression avec confirmation, DayExtra inchangé',
      (tester) async {
    await seedTrip(tester, 't-24', 24);
    await seedTrip(tester, 't-18', 18);
    await seedExtra(tester, 45);

    await pumpApp(tester);
    expectTotal(tester, '87');

    // Supprime le trajet de 18 km (bouton de SA ligne, pas un index).
    final row18 = find.ancestor(
      of: find.text('18 km'),
      matching: find.byType(ListTile),
    );
    await tester.tap(
      find.descendant(of: row18, matching: find.byIcon(Icons.delete_outline)),
    );
    await tester.pumpAndSettle();
    expect(find.text('Supprimer ce trajet ?'), findsOneWidget);

    await tester.tap(find.text('Supprimer'));
    await tester.pumpAndSettle();

    expect(find.text('18 km'), findsNothing);
    expectTotal(tester, '69');
    expect(find.text('45 km'), findsOneWidget); // extra intact
  });

  group('trajets favoris', () {
    Future<void> seedFavorite(
      WidgetTester tester, {
      String id = 'fav-1',
      String label = 'Cabinet ↔ EHPAD',
      double km = 24,
      int sortOrder = 0,
    }) async {
      await tester.runAsync(
          () => SembastFavoriteTripRepository(database.db).put(FavoriteTrip(
                id: id,
                label: label,
                distanceKm: km,
                sortOrder: sortOrder,
              )));
    }

    Future<void> flushSnackBar(WidgetTester tester) async {
      await tester.pump(const Duration(seconds: 1));
      await tester.pumpAndSettle();
    }

    testWidgets('aucun favori : invitation discrète, pas de section lourde',
        (tester) async {
      await pumpApp(tester);

      expect(find.text('Créer un trajet favori'), findsOneWidget);
      expect(find.text('Trajets favoris'), findsNothing);
      expect(find.text('Gérer'), findsNothing);
    });

    testWidgets(
        'section visible ; UN tap grossier sur la ligne ajoute les km ; '
        'deux taps additionnent', (tester) async {
      await seedFavorite(tester);
      await pumpApp(tester);

      expect(find.text('Trajets favoris'), findsOneWidget);
      expect(find.text('Cabinet ↔ EHPAD'), findsOneWidget);
      expect(find.text('+24 km'), findsOneWidget);

      // Tap au bord de la ligne, pas sur le « + » : toute la ligne agit.
      final rowRect =
          tester.getRect(find.byKey(const Key('favorite-fav-1')));
      await tester.tapAt(rowRect.topLeft + const Offset(10, 10));
      await tester.pumpAndSettle();
      expectTotal(tester, '24');

      await tester.tapAt(rowRect.topLeft + const Offset(10, 10));
      await tester.pumpAndSettle();
      expectTotal(tester, '48');

      // Deux Trips distincts visibles dans la décomposition.
      expect(find.text('24 km', skipOffstage: false), findsNWidgets(3));
      await flushSnackBar(tester);
    });

    testWidgets('DayExtra inchangé : extra 33 + tap favori => 57',
        (tester) async {
      await seedFavorite(tester);
      await seedExtra(tester, 33);
      await pumpApp(tester);
      expectTotal(tester, '33');

      await tester.tap(find.byKey(const Key('favorite-fav-1')));
      await tester.pumpAndSettle();

      expectTotal(tester, '57');
      expect(find.text('Autres kilomètres'), findsOneWidget);
      expect(find.text('33 km'), findsOneWidget); // extra intact
      await flushSnackBar(tester);
    });

    testWidgets('création d’un favori depuis l’invitation',
        (tester) async {
      await pumpApp(tester);

      await tester.tap(find.text('Créer un trajet favori'));
      await tester.pumpAndSettle();

      await tester.enterText(
          find.widgetWithText(TextField, 'Nom du favori'), 'Dépôt');
      await tester.enterText(
        find.widgetWithText(TextField, 'Distance comptabilisée (km)'),
        '7,5',
      );
      await tester.tap(find.text('Créer le favori'));
      await tester.pumpAndSettle();

      expect(find.text('Trajets favoris'), findsOneWidget);
      expect(find.text('Dépôt'), findsOneWidget);
      expect(find.text('+7,5 km'), findsOneWidget);
    });

    testWidgets(
        'modification via Gérer : anciens Trips intacts, prochain tap = 26',
        (tester) async {
      await seedFavorite(tester);
      await pumpApp(tester);

      // Un Trip de 24 d'abord.
      await tester.tap(find.byKey(const Key('favorite-fav-1')));
      await tester.pumpAndSettle();
      await flushSnackBar(tester);
      expectTotal(tester, '24');

      // Gérer -> éditer -> 26.
      await tester.tap(find.text('Gérer'));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('manage-favorite-fav-1')));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.widgetWithText(TextField, 'Distance comptabilisée (km)'),
        '26',
      );
      await tester.tap(find.text('Enregistrer'));
      await tester.pumpAndSettle();
      expect(find.text('26 km'), findsOneWidget); // ligne de gestion

      // Retour Aujourd'hui : l'ancien Trip reste 24, le tap suivant fait 26.
      await tester.tap(find.byType(BackButton));
      await tester.pumpAndSettle();
      expect(find.text('+26 km'), findsOneWidget);
      expect(find.text('24 km', skipOffstage: false), findsNWidgets(1));

      await tester.tap(find.byKey(const Key('favorite-fav-1')));
      await tester.pumpAndSettle();
      expectTotal(tester, '50');
      await flushSnackBar(tester);
    });

    testWidgets('suppression confirmée dans Gérer', (tester) async {
      await seedFavorite(tester);
      await pumpApp(tester);

      await tester.tap(find.text('Gérer'));
      await tester.pumpAndSettle();
      await tester.tap(find.byIcon(Icons.delete_outline));
      await tester.pumpAndSettle();
      expect(find.text('Supprimer ce favori ?'), findsOneWidget);

      await tester.tap(find.text('Supprimer'));
      await tester.pumpAndSettle();
      expect(find.text('Aucun favori pour le moment.'), findsOneWidget);

      await tester.tap(find.byType(BackButton));
      await tester.pumpAndSettle();
      expect(find.text('Créer un trajet favori'), findsOneWidget);
    });

    testWidgets('réorganisation par flèches dans Gérer', (tester) async {
      await seedFavorite(tester, id: 'f-a', label: 'A', km: 24, sortOrder: 0);
      await seedFavorite(tester, id: 'f-b', label: 'B', km: 18, sortOrder: 1);
      await pumpApp(tester);

      await tester.tap(find.text('Gérer'));
      await tester.pumpAndSettle();

      double topOf(String id) =>
          tester.getTopLeft(find.byKey(Key('manage-favorite-$id'))).dy;
      expect(topOf('f-a') < topOf('f-b'), isTrue);

      // Descend A sous B.
      await tester.tap(find.byIcon(Icons.arrow_downward).first);
      await tester.pumpAndSettle();
      expect(topOf('f-b') < topOf('f-a'), isTrue);

      // L'ordre est aussi celui d'Aujourd'hui.
      await tester.tap(find.byType(BackButton));
      await tester.pumpAndSettle();
      final todayTopA =
          tester.getTopLeft(find.byKey(const Key('favorite-f-a'))).dy;
      final todayTopB =
          tester.getTopLeft(find.byKey(const Key('favorite-f-b'))).dy;
      expect(todayTopB < todayTopA, isTrue);
    });

    testWidgets(
        'après usage des favoris : compteur direct et curseur masqué OK',
        (tester) async {
      await seedFavorite(tester);
      await pumpApp(tester);

      final field = tester.widget<TextField>(find.byKey(dayTotalFieldKey));
      expect(field.showCursor, isFalse, reason: 'curseur clignotant masqué');

      await tester.tap(find.byKey(const Key('favorite-fav-1')));
      await tester.pumpAndSettle();
      await flushSnackBar(tester);

      await editTotal(tester, '87');
      expectTotal(tester, '87');
      expect(find.text('Autres kilomètres'), findsOneWidget);
    });
  });

  testWidgets('état de chargement avant les données', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          databaseProvider.overrideWithValue(database),
          todayDateProvider.overrideWithValue(() => day),
        ],
        child: const MesKmApp(),
      ),
    );

    // Premier frame : lecture asynchrone en cours, pas de « 0 » définitif.
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(find.text('0'), findsNothing);

    await tester.pumpAndSettle();
    expectTotal(tester, '0');
  });

  testWidgets('erreur de lecture : message + réessayer, jamais de total',
      (tester) async {
    await pumpApp(tester, tripRepository: _ThrowingTripRepository());

    expect(
      find.text('Impossible de lire les données du jour.'),
      findsOneWidget,
    );
    expect(find.text('Réessayer'), findsOneWidget);
    expect(find.text('0'), findsNothing);
  });
}

class _ThrowingTripRepository implements TripRepository {
  @override
  Future<List<Trip>> getByDate(CivilDate date) =>
      throw StateError('lecture impossible');

  @override
  Future<List<Trip>> getAll() => throw StateError('lecture impossible');

  @override
  Future<List<Trip>> getBetween(CivilDate start, CivilDate end) =>
      throw StateError('lecture impossible');

  @override
  Future<Trip?> getById(String id) => throw StateError('lecture impossible');

  @override
  Future<void> put(Trip trip) => throw StateError('écriture impossible');

  @override
  Future<void> delete(String id) => throw StateError('écriture impossible');
}
