import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:mes_km/app.dart';
import 'package:mes_km/app/providers.dart';
import 'package:mes_km/data/local/app_database.dart';
import 'package:mes_km/data/local/sembast_favorite_trip_repository.dart';
import 'package:mes_km/data/local/sembast_trip_repository.dart';
import 'package:mes_km/domain/models/civil_date.dart';
import 'package:mes_km/domain/models/favorite_trip.dart';
import 'package:mes_km/domain/models/trip.dart';
import 'package:mes_km/widgets/section_header.dart';
import 'package:sembast/sembast_memory.dart' hide Finder;

// UX-002B : écran Aujourd'hui rationalisé — preuves explicites des cinq
// directions humaines validées, sans aucun changement métier.
void main() {
  final today = CivilDate(2026, 10, 12);

  setUpAll(() async => initializeDateFormatting('fr_FR'));

  late MesKmDatabase database;

  setUp(() async {
    database =
        await MesKmDatabase.open(newDatabaseFactoryMemory(), name: 'ts.db');
  });

  tearDown(() => database.close());

  Future<void> seedTrip(WidgetTester tester, double km) =>
      tester.runAsync(() => SembastTripRepository(database.db).put(Trip(
            id: 't-$km',
            date: today,
            distanceKm: km,
            createdAt: DateTime.utc(2026, 10, 12, 9),
          )));

  Future<void> seedFavorite(WidgetTester tester) => tester.runAsync(() =>
      SembastFavoriteTripRepository(database.db).put(FavoriteTrip(
          id: 'fav-1', label: 'Travail', distanceKm: 70, sortOrder: 0)));

  Future<void> pumpApp(WidgetTester tester) async {
    tester.view.physicalSize = const Size(500, 1800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(ProviderScope(
      overrides: [
        databaseProvider.overrideWithValue(database),
        todayDateProvider.overrideWithValue(() => today),
      ],
      child: const MesKmApp(),
    ));
    await tester.pumpAndSettle();
  }

  Future<void> flushSnackBar(WidgetTester tester) async {
    await tester.pump(const Duration(seconds: 1));
    await tester.pumpAndSettle();
  }

  testWidgets(
      'en-tête : plus de grand titre « Aujourd’hui » dans le contenu, '
      'la date complète est la seule ligne de contexte', (tester) async {
    await pumpApp(tester);

    // Le libellé « Aujourd'hui » ne subsiste QUE dans la barre d'onglets.
    expect(
      find.descendant(
        of: find.byType(ListView),
        matching: find.text('Aujourd’hui'),
      ),
      findsNothing,
    );
    expect(find.widgetWithText(NavigationBar, 'Aujourd’hui'),
        findsOneWidget);
    expect(find.text('Lundi 12 octobre 2026'), findsOneWidget);
  });

  testWidgets(
      '« Nouveau favori » vit dans l’en-tête de section : 1 tap, même '
      'formulaire ; la ligne favori reste un ajout 1 tap et « Modifier » '
      'reste distinct', (tester) async {
    await seedFavorite(tester);
    await pumpApp(tester);

    // En-tête de section = titre + action de création côte à côte.
    final headerRow = find.ancestor(
      of: find.byKey(const Key('create-favorite-row')),
      matching: find.byType(Row),
    );
    expect(
      find.descendant(
          of: headerRow.first, matching: find.byType(SectionHeader)),
      findsOneWidget,
      reason: 'la création vit dans l’en-tête « Trajets favoris »',
    );

    await tester.tap(find.byKey(const Key('create-favorite-row')));
    await tester.pumpAndSettle();
    expect(find.text('Nouveau trajet favori'), findsOneWidget);
    await tester.tap(find.text('Annuler'));
    await tester.pumpAndSettle();

    // Ajout 1 tap inchangé ; Modifier n'ajoute rien.
    await tester.tap(find.byKey(const Key('favorite-fav-1')));
    await tester.pumpAndSettle();
    await flushSnackBar(tester);
    var trips = await tester
        .runAsync(() => SembastTripRepository(database.db).getAll());
    expect(trips, hasLength(1));

    await tester.tap(find.byKey(const Key('edit-favorite-fav-1')));
    await tester.pumpAndSettle();
    expect(find.text('Modifier le favori'), findsOneWidget);
    trips = await tester
        .runAsync(() => SembastTripRepository(database.db).getAll());
    expect(trips, hasLength(1), reason: 'Modifier n’ajoute jamais');
  });

  testWidgets(
      'pied contextuel : jour vide => congé seul ; jour non vide => '
      'effacer seul ; état vide redondant absent', (tester) async {
    await pumpApp(tester);

    // Jour vide.
    expect(find.byKey(const Key('mark-vacation-button')), findsOneWidget);
    expect(find.byKey(const Key('clear-day-button')), findsNothing);
    expect(find.text('Aucun kilomètre enregistré ce jour-là.'),
        findsNothing, reason: 'le compteur à 0 est l’état vide');

    // Jour non vide (via le bouton bleu inchangé : même formulaire).
    await tester.tap(find.text('Ajouter un trajet'));
    await tester.pumpAndSettle();
    expect(find.text('Distance comptabilisée (km)'), findsOneWidget);
    await tester.enterText(
        find.widgetWithText(TextField, 'Distance comptabilisée (km)'),
        '42');
    await tester.pump(); // le bouton passe à l'état actif
    await tester.tap(find.text('Enregistrer le trajet'));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('clear-day-button')), findsOneWidget);
    expect(find.byKey(const Key('mark-vacation-button')), findsNothing,
        reason: 'jamais une action qui ne peut pas réussir');
  });

  testWidgets(
      'protection métier congé ≠ km intacte : le refus vit toujours dans '
      'la vue (défense en profondeur), même si le chemin UI a disparu',
      (tester) async {
    await seedTrip(tester, 42);
    await pumpApp(tester);
    // Le garde-fou d'un jour en congé reste couvert par
    // vacation_conflicts_test ; ici on prouve simplement qu'aucune période
    // n'a pu être créée depuis Aujourd'hui.
    expect(find.byKey(const Key('mark-vacation-button')), findsNothing);
    expect(find.text('42 km'), findsOneWidget);
  });
}
