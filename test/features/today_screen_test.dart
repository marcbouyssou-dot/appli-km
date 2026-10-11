import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:mes_km/app.dart';
import 'package:mes_km/app/providers.dart';
import 'package:mes_km/data/local/app_database.dart';
import 'package:mes_km/data/local/sembast_day_extra_repository.dart';
import 'package:mes_km/data/local/sembast_trip_repository.dart';
import 'package:mes_km/data/repositories/trip_repository.dart';
import 'package:mes_km/domain/models/civil_date.dart';
import 'package:mes_km/domain/models/day_extra.dart';
import 'package:mes_km/domain/models/trip.dart';
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

  testWidgets('affiche le total dérivé des données existantes',
      (tester) async {
    await seedTrip(tester, 't-1', 24);
    await seedExtra(tester, 45);

    await pumpApp(tester);

    expect(find.text('69 km'), findsOneWidget);
  });

  testWidgets('saisie directe du total du jour', (tester) async {
    await pumpApp(tester);

    await tester.tap(find.text('Saisir le total du jour'));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField), '87');
    await tester.tap(find.text('Valider'));
    await tester.pumpAndSettle();

    // Total du jour + ligne « Autres kilomètres » (extra 87).
    expect(find.text('87 km'), findsNWidgets(2));
    expect(find.text('Autres kilomètres'), findsOneWidget);
  });

  testWidgets('ajout d’un trajet manuel', (tester) async {
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
    expect(find.text('24,5 km'), findsNWidgets(2)); // total + ligne trajet
  });

  testWidgets('décomposition : détaillés + autres kilomètres',
      (tester) async {
    await seedTrip(tester, 't-1', 24);
    await seedTrip(tester, 't-2', 18);
    await seedExtra(tester, 45);

    await pumpApp(tester);

    expect(find.text('87 km'), findsOneWidget);
    expect(find.text('Trajets détaillés'), findsOneWidget);
    expect(find.text('24 km'), findsOneWidget);
    expect(find.text('18 km'), findsOneWidget);
    expect(find.text('Autres kilomètres'), findsOneWidget);
    expect(find.text('45 km'), findsOneWidget);
  });

  testWidgets(
      'RÉGRESSION iPhone KM-004A : extra 87 seul, saisir 0 => journée vide',
      (tester) async {
    await seedExtra(tester, 87);

    await pumpApp(tester);
    expect(find.text('87 km'), findsNWidgets(2)); // total + autres km

    await tester.tap(find.text('Saisir le total du jour'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), '0');
    await tester.tap(find.text('Valider'));
    await tester.pumpAndSettle();

    expect(find.text('0 km'), findsOneWidget);
    expect(find.text('Autres kilomètres'), findsNothing);
    expect(
      find.text('Aucun kilomètre enregistré aujourd’hui.'),
      findsOneWidget,
    );
  });

  testWidgets('bouton « Remettre la journée à zéro » efface l’extra',
      (tester) async {
    await seedExtra(tester, 87);

    await pumpApp(tester);
    await tester.tap(find.text('Saisir le total du jour'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Remettre la journée à zéro'));
    await tester.pumpAndSettle();

    expect(find.text('0 km'), findsOneWidget);
    expect(find.text('Autres kilomètres'), findsNothing);
  });

  testWidgets(
      'remise à zéro avec trajets détaillés => refus métier, trips intacts',
      (tester) async {
    await seedTrip(tester, 't-1', 24);
    await seedTrip(tester, 't-2', 18);

    await pumpApp(tester);
    await tester.tap(find.text('Saisir le total du jour'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Remettre la journée à zéro'));
    await tester.pumpAndSettle();

    expect(
      find.text('Les trajets détaillés totalisent déjà 42 km.'),
      findsOneWidget,
    );

    await tester.tap(find.text('Annuler'));
    await tester.pumpAndSettle();
    expect(find.text('42 km'), findsOneWidget);
    expect(find.text('24 km'), findsOneWidget);
    expect(find.text('18 km'), findsOneWidget);
  });

  testWidgets('refus d’un total inférieur aux trajets détaillés',
      (tester) async {
    await seedTrip(tester, 't-1', 24);
    await seedTrip(tester, 't-2', 18);

    await pumpApp(tester);
    expect(find.text('42 km'), findsOneWidget);

    await tester.tap(find.text('Saisir le total du jour'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), '40');
    await tester.tap(find.text('Valider'));
    await tester.pumpAndSettle();

    // Le refus est affiché dans la feuille, rien n'est modifié.
    expect(
      find.text('Les trajets détaillés totalisent déjà 42 km.'),
      findsOneWidget,
    );

    await tester.tap(find.text('Annuler'));
    await tester.pumpAndSettle();
    expect(find.text('42 km'), findsOneWidget);
    expect(find.text('Autres kilomètres'), findsNothing);
  });

  testWidgets('suppression avec confirmation, DayExtra inchangé',
      (tester) async {
    await seedTrip(tester, 't-24', 24);
    await seedTrip(tester, 't-18', 18);
    await seedExtra(tester, 45);

    await pumpApp(tester);
    expect(find.text('87 km'), findsOneWidget);

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
    expect(find.text('69 km'), findsOneWidget);
    expect(find.text('45 km'), findsOneWidget); // extra intact
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

    // Premier frame : lecture asynchrone en cours, pas de « 0 km » définitif.
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(find.text('0 km'), findsNothing);

    await tester.pumpAndSettle();
    expect(find.text('0 km'), findsOneWidget);
  });

  testWidgets('erreur de lecture : message + réessayer, jamais « 0 km »',
      (tester) async {
    await pumpApp(tester, tripRepository: _ThrowingTripRepository());

    expect(
      find.text('Impossible de lire les données du jour.'),
      findsOneWidget,
    );
    expect(find.text('Réessayer'), findsOneWidget);
    expect(find.text('0 km'), findsNothing);
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
