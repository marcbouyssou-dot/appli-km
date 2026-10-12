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
import 'package:sembast/sembast_memory.dart' hide Finder;

// UX-003B : formulaires quotidiens — CAS COURANT D'ABORD.
// Preuves : essentiel immédiat, section « Itinéraire et détails » repliée à
// la création / auto-dépliée en édition, action principale épinglée
// accessible clavier ouvert, capacités intégralement préservées.
void main() {
  final today = CivilDate(2026, 10, 12);

  setUpAll(() async => initializeDateFormatting('fr_FR'));

  late MesKmDatabase database;

  setUp(() async {
    database =
        await MesKmDatabase.open(newDatabaseFactoryMemory(), name: 'df.db');
  });

  tearDown(() => database.close());

  Future<void> pumpApp(WidgetTester tester,
      {Size size = const Size(500, 900)}) async {
    tester.view.physicalSize = size;
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

  Finder field(String label) => find.widgetWithText(TextField, label);

  group('TRAJET', () {
    testWidgets(
        'création : distance + A/R + « Ajouter » immédiats ; section '
        'repliée, champs cachés ; dépliage révèle tout, calcul atteignable',
        (tester) async {
      await pumpApp(tester);
      await tester.tap(find.text('Ajouter un trajet'));
      await tester.pumpAndSettle();

      // Essentiel immédiatement visible.
      expect(field('Distance comptabilisée (km)'), findsOneWidget);
      expect(find.text('Aller-retour'), findsOneWidget);
      expect(find.text('Ajouter'), findsOneWidget); // action épinglée
      expect(find.text('Annuler'), findsOneWidget); // en-tête compact

      // Section repliée : champs facultatifs absents du rendu.
      expect(find.text('Itinéraire et détails'), findsOneWidget);
      expect(field('Départ'), findsNothing);
      expect(field('Destination'), findsNothing);
      expect(field('Motif'), findsNothing);

      await tester.tap(find.byKey(const Key('optional-section-toggle')));
      await tester.pumpAndSettle();
      expect(field('Départ'), findsOneWidget);
      expect(field('Destination'), findsOneWidget);
      expect(field('Motif'), findsOneWidget);

      // Le calcul d'itinéraire reste atteignable (comportement intact :
      // bouton visible dès que les deux adresses existent).
      await tester.enterText(field('Départ'), 'Maison');
      await tester.enterText(field('Destination'), 'Cabinet');
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('route-calc-button')), findsOneWidget);
    });

    testWidgets(
        'édition : détails existants => section auto-dépliée, valeurs '
        'préservées, enregistrement OK', (tester) async {
      await tester.runAsync(() => SembastTripRepository(database.db).put(Trip(
            id: 't-1',
            date: today,
            distanceKm: 24,
            origin: 'Maison',
            purpose: 'Tournée',
            createdAt: DateTime.utc(2026, 10, 12, 9),
          )));
      await pumpApp(tester);

      await tester.tap(find.text('24 km'));
      await tester.pumpAndSettle();

      // Auto-dépliée : les valeurs facultatives sont immédiatement là.
      expect(
          tester.widget<TextField>(field('Départ')).controller!.text,
          'Maison');
      expect(
          tester.widget<TextField>(field('Motif')).controller!.text,
          'Tournée');

      await tester.enterText(
          field('Distance comptabilisée (km)'), '30');
      await tester.tap(find.text('Enregistrer'));
      await tester.pumpAndSettle();

      final trips = await tester
          .runAsync(() => SembastTripRepository(database.db).getAll());
      expect(trips!.single.distanceKm, 30);
      expect(trips.single.origin, 'Maison', reason: 'valeurs préservées');
    });

    testWidgets(
        'édition sans détails : la section peut rester repliée',
        (tester) async {
      await tester.runAsync(() => SembastTripRepository(database.db).put(Trip(
            id: 't-2',
            date: today,
            distanceKm: 12,
            createdAt: DateTime.utc(2026, 10, 12, 9),
          )));
      await pumpApp(tester);
      await tester.tap(find.text('12 km'));
      await tester.pumpAndSettle();
      expect(field('Départ'), findsNothing);
      expect(find.text('Itinéraire et détails'), findsOneWidget);
    });
  });

  group('FAVORI', () {
    testWidgets(
        'création simple SANS ouvrir la section : nom + distance + Créer',
        (tester) async {
      await pumpApp(tester);
      // Sans favori existant, l'entrée est l'invitation dédiée.
      await tester.tap(find.text('Créer un trajet favori'));
      await tester.pumpAndSettle();

      expect(field('Nom du favori'), findsOneWidget);
      expect(field('Distance comptabilisée (km)'), findsOneWidget);
      expect(find.text('Créer le favori'), findsOneWidget);
      expect(field('Départ'), findsNothing); // repliée

      await tester.enterText(field('Nom du favori'), 'Travail');
      await tester.enterText(
          field('Distance comptabilisée (km)'), '70');
      await tester.tap(find.text('Créer le favori'));
      await tester.pumpAndSettle();

      expect(find.text('Travail'), findsOneWidget);
      expect(find.text('+70 km'), findsOneWidget);

      // Dépliage disponible à la demande.
      await tester.tap(find.byKey(const Key('create-favorite-row')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('optional-section-toggle')));
      await tester.pumpAndSettle();
      expect(field('Départ'), findsOneWidget);
      expect(field('Motif'), findsOneWidget);
    });

    testWidgets(
        'édition : détails => auto-dépliée ; Enregistrer et Supprimer '
        'préservés', (tester) async {
      await tester.runAsync(
          () => SembastFavoriteTripRepository(database.db).put(FavoriteTrip(
                id: 'f-1',
                label: 'Tournée',
                distanceKm: 24,
                origin: 'Maison',
                destination: 'EHPAD',
                sortOrder: 0,
              )));
      await pumpApp(tester);
      await tester.tap(find.byKey(const Key('edit-favorite-f-1')));
      await tester.pumpAndSettle();

      expect(
          tester.widget<TextField>(field('Départ')).controller!.text,
          'Maison');
      expect(find.text('Enregistrer'), findsOneWidget);
      await tester.ensureVisible(
          find.byKey(const Key('delete-favorite-from-form')));
      expect(find.byKey(const Key('delete-favorite-from-form')),
          findsOneWidget);

      await tester.enterText(field('Nom du favori'), 'Tournée EHPAD');
      await tester.tap(find.text('Enregistrer'));
      await tester.pumpAndSettle();
      final favorites = await tester.runAsync(
          () => SembastFavoriteTripRepository(database.db).getAllOrdered());
      expect(favorites!.single.label, 'Tournée EHPAD');
      expect(favorites.single.origin, 'Maison');
    });
  });

  group('CLAVIER / PETIT ÉCRAN', () {
    testWidgets(
        'clavier ouvert : l’action épinglée reste visible et actionnable',
        (tester) async {
      await pumpApp(tester, size: const Size(390, 700));
      await tester.tap(find.text('Ajouter un trajet'));
      await tester.pumpAndSettle();

      // Simule le clavier iOS (~300 px).
      tester.view.viewInsets = const FakeViewPadding(bottom: 300);
      addTearDown(tester.view.resetViewInsets);
      await tester.pumpAndSettle();

      final button = find.text('Ajouter');
      expect(button, findsOneWidget);
      final center = tester.getCenter(button);
      expect(center.dy, lessThan(700 - 300),
          reason: 'le bouton vit AU-DESSUS du clavier');
      // Et le champ actif n'est pas recouvert par la zone d'action.
      final fieldRect =
          tester.getRect(field('Distance comptabilisée (km)'));
      final actionTop =
          tester.getTopLeft(find.text('Ajouter')).dy - 12;
      expect(fieldRect.bottom, lessThan(actionTop),
          reason: 'le bouton ne recouvre jamais le champ actif');

      await tester.enterText(
          field('Distance comptabilisée (km)'), '42');
      await tester.tap(button);
      await tester.pumpAndSettle();
      tester.view.resetViewInsets;
      final trips = await tester
          .runAsync(() => SembastTripRepository(database.db).getAll());
      expect(trips!.single.distanceKm, 42);
    });

    testWidgets('320×568 : section dépliée, corps défilant, pied stable',
        (tester) async {
      await pumpApp(tester, size: const Size(320, 568));
      await tester.tap(find.text('Ajouter un trajet'));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('optional-section-toggle')));
      await tester.pumpAndSettle();

      // Le corps défile au-dessus de l'action épinglée.
      await tester.ensureVisible(field('Motif'));
      await tester.pumpAndSettle();
      expect(find.text('Ajouter'), findsOneWidget);
      // Aucun overflow (une exception de rendu ferait échouer le test).
    });
  });
}
