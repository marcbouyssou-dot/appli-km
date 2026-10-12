import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:mes_km/app.dart';
import 'package:mes_km/app/providers.dart';
import 'package:mes_km/data/local/app_database.dart';
import 'package:mes_km/data/local/sembast_favorite_trip_repository.dart';
import 'package:mes_km/domain/models/civil_date.dart';
import 'package:mes_km/domain/models/favorite_trip.dart';
import 'package:sembast/sembast_memory.dart' hide Finder;

// UX-006B : gestion des favoris alignée (data-first) + liaison
// Documents -> Réglages. Comportements strictement préservés.
void main() {
  setUpAll(() async => initializeDateFormatting('fr_FR'));

  late MesKmDatabase database;

  setUp(() async {
    database =
        await MesKmDatabase.open(newDatabaseFactoryMemory(), name: 'sp.db');
  });

  tearDown(() => database.close());

  Future<void> seedFavorites(WidgetTester tester) async {
    await tester.runAsync(() async {
      final repo = SembastFavoriteTripRepository(database.db);
      await repo.put(FavoriteTrip(
          id: 'f-a', label: 'Travail', distanceKm: 70, sortOrder: 0));
      await repo.put(FavoriteTrip(
          id: 'f-b', label: 'EHPAD', distanceKm: 24, sortOrder: 1));
    });
  }

  Future<void> pumpOnManage(WidgetTester tester) async {
    tester.view.physicalSize = const Size(500, 1200);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(ProviderScope(
      overrides: [
        databaseProvider.overrideWithValue(database),
        todayDateProvider.overrideWithValue(() => CivilDate(2026, 10, 12)),
      ],
      child: const MesKmApp(),
    ));
    await tester.pumpAndSettle();
    await tester.tap(find.byIcon(Icons.more_horiz_outlined));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Trajets favoris'));
    await tester.pumpAndSettle();
  }

  testWidgets(
      'liste data-first : plus de Card par favori ; nom + km visibles ; '
      'réordonner conservé ; Supprimer rouge SÉPARÉ des flèches et '
      'toujours confirmé ; tap ligne = fiche', (tester) async {
    await seedFavorites(tester);
    await pumpOnManage(tester);

    final listArea = find.byType(ListView).last;
    expect(find.descendant(of: listArea, matching: find.byType(Card)),
        findsNothing, reason: 'grammaire V1 : filets, pas de cartes');
    expect(find.text('Travail'), findsOneWidget);
    expect(find.text('70 km'), findsOneWidget);

    // Réordonner : EHPAD monte en premier.
    final rowB = find.byKey(const Key('manage-favorite-f-b'));
    await tester.tap(find.descendant(
        of: rowB, matching: find.byIcon(Icons.arrow_upward)));
    await tester.pumpAndSettle();
    final yB =
        tester.getTopLeft(find.byKey(const Key('manage-favorite-f-b'))).dy;
    final yA =
        tester.getTopLeft(find.byKey(const Key('manage-favorite-f-a'))).dy;
    expect(yB, lessThan(yA), reason: 'Monter fonctionne toujours');

    // Suppression : icône ROUGE, séparée par un filet vertical, confirmée.
    final deleteIcon = find.descendant(
        of: rowB, matching: find.byIcon(Icons.delete_outline));
    final context = tester.element(deleteIcon);
    expect(
        tester
            .widget<IconButton>(find.ancestor(
                of: deleteIcon, matching: find.byType(IconButton)))
            .color,
        Theme.of(context).colorScheme.error,
        reason: 'le destructif ne se confond pas avec le réordonnancement');
    expect(find.descendant(of: rowB, matching: find.byType(VerticalDivider)),
        findsOneWidget);

    await tester.tap(deleteIcon);
    await tester.pumpAndSettle();
    expect(find.text('Supprimer ce favori ?'), findsOneWidget);
    await tester.tap(find.text('Annuler'));
    await tester.pumpAndSettle();
    expect(find.text('EHPAD'), findsOneWidget, reason: 'annulation sûre');

    // Tap ligne = fiche d'édition (formulaire UX-003B inchangé).
    await tester.tap(find.byKey(const Key('manage-favorite-f-a')));
    await tester.pumpAndSettle();
    expect(find.text('Modifier le favori'), findsOneWidget);
    await tester.tap(find.text('Annuler'));
    await tester.pumpAndSettle();

    // Création : un toucher, même formulaire.
    await tester.tap(find.text('Nouveau favori'));
    await tester.pumpAndSettle();
    expect(find.text('Nouveau trajet favori'), findsOneWidget);
  });

  testWidgets('Documents : liaison Réglages visible et navigable ; '
      'PDF/CSV et sélecteur d’année préservés', (tester) async {
    tester.view.physicalSize = const Size(500, 1200);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(ProviderScope(
      overrides: [
        databaseProvider.overrideWithValue(database),
        todayDateProvider.overrideWithValue(() => CivilDate(2026, 10, 12)),
      ],
      child: const MesKmApp(),
    ));
    await tester.pumpAndSettle();
    await tester.tap(find.byIcon(Icons.more_horiz_outlined));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Documents'));
    await tester.pumpAndSettle();

    expect(find.text('2026'), findsOneWidget);
    expect(find.text('RELEVÉ ANNUEL'), findsOneWidget);
    expect(find.text('DONNÉES DÉTAILLÉES'), findsOneWidget);
    expect(find.byKey(const Key('create-pdf-button')), findsOneWidget);
    expect(find.byKey(const Key('create-csv-button')), findsOneWidget);
    expect(find.text('Aucune donnée en 2026.'), findsOneWidget);
    expect(
        find.text('L’en-tête du PDF utilise vos informations de'),
        findsOneWidget);

    await tester.tap(find.byKey(const Key('docs-open-settings')));
    await tester.pumpAndSettle();
    expect(find.text('INFORMATIONS POUR LES DOCUMENTS'), findsOneWidget,
        reason: 'le lien ouvre le même écran Réglages, sans plomberie');
  });
}
