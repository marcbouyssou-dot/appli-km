import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:mes_km/app.dart';
import 'package:mes_km/app/providers.dart';
import 'package:mes_km/data/local/app_database.dart';
import 'package:mes_km/domain/models/civil_date.dart';
import 'package:sembast/sembast_memory.dart' hide Finder;

// LEGAL-001B : page « Informations légales » — contenus préparés, garde-fous
// critiques (pas d'e-mail inexistant, pas de (R), pas de placeholder).
void main() {
  setUpAll(() async => initializeDateFormatting('fr_FR'));

  late MesKmDatabase database;

  setUp(() async {
    database =
        await MesKmDatabase.open(newDatabaseFactoryMemory(), name: 'lg.db');
  });

  tearDown(() => database.close());

  Future<void> pumpOnMore(WidgetTester tester) async {
    tester.view.physicalSize = const Size(500, 1400);
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
  }

  // La page est une ListView paresseuse : le texte défilé hors écran est
  // démonté. On collecte donc le texte EN CUMULANT pendant le défilement.
  // Les fenêtres de collecte se chevauchent : on déduplique par contenu de
  // widget Text (chaque paragraphe de la page est une chaîne distincte).
  Future<String> collectAllText(WidgetTester tester) async {
    final seen = <String>{};
    final scrollable = find.byType(Scrollable).first;
    List<String> snapshot() => tester
        .widgetList<Text>(find.byType(Text))
        .map((t) => t.data ?? '')
        .toList();
    var previous = '';
    for (var i = 0; i < 40; i++) {
      final current = snapshot();
      seen.addAll(current);
      final joined = current.join('\n');
      if (joined == previous) break; // bas atteint : plus rien ne bouge
      previous = joined;
      await tester.drag(scrollable, const Offset(0, -500));
      await tester.pumpAndSettle();
    }
    return seen.join('\n');
  }

  testWidgets(
      'Plus → APPLICATION : « Informations légales » sous Réglages, '
      'entrées existantes intactes, tap ouvre la page', (tester) async {
    await pumpOnMore(tester);

    expect(find.text('APPLICATION'), findsOneWidget);
    expect(find.text('Réglages'), findsOneWidget);
    expect(find.text('Informations légales'), findsOneWidget);
    expect(find.text('Mentions, confidentialité et conditions'),
        findsOneWidget);
    // Sous Réglages, dans le même groupe.
    expect(tester.getTopLeft(find.text('Informations légales')).dy,
        greaterThan(tester.getTopLeft(find.text('Réglages')).dy));
    // Les autres entrées sont inchangées.
    for (final label in [
      'Trajets favoris', 'Véhicules', 'Documents', 'Sauvegarde',
    ]) {
      expect(find.text(label), findsOneWidget);
    }

    await tester.tap(find.text('Informations légales'));
    await tester.pumpAndSettle();
    expect(find.byType(AppBar), findsOneWidget);
    expect(find.text('Informations légales'), findsWidgets);
  });

  testWidgets(
      'page légale : quatre sections, contenus clefs présents, '
      'garde-fous critiques respectés', (tester) async {
    await pumpOnMore(tester);
    await tester.tap(find.text('Informations légales'));
    await tester.pumpAndSettle();

    final text = await collectAllText(tester);

    // Quatre en-têtes de section.
    for (final section in [
      'MENTIONS LÉGALES',
      'CONFIDENTIALITÉ',
      'CONDITIONS D’UTILISATION — PHASE PILOTE',
      'PROPRIÉTÉ INTELLECTUELLE',
    ]) {
      expect(text, contains(section), reason: section);
    }
    // Mentions.
    expect(text, contains('Marc Bouyssou'));
    expect(text, contains('Rue Combe Maurette'));
    expect(text, contains('19700 Seilhac'));
    expect(text, contains('Netlify, Inc.'));
    // Confidentialité : local d'abord, itinéraire, suppression/sauvegarde.
    expect(text, contains('local d’abord'));
    expect(text, contains('Nominatim/OpenStreetMap et OSRM'));
    expect(text, contains('peut supprimer les données locales'));
    expect(text, contains('sauvegarde récente'));
    // Jamais prétendre un accès de l'éditeur aux données locales.
    expect(text.toLowerCase(),
        isNot(contains('l’éditeur peut accéder')));
    // Conditions : pilote gratuit + fiscal indicatif + responsabilité.
    expect(text, contains('gratuitement dans le cadre d’une phase pilote'));
    expect(text, contains('simulation indicative'));
    expect(text,
        contains('ni un calcul d’impôt, ni un conseil fiscal'));
    expect(text, contains('L’utilisateur reste responsable'));
    // PI : copyright, pas de marque revendiquée, OSM/ODbL.
    expect(text, contains('© 2026 MB'));
    expect(text, contains('Aucun dépôt de marque « Mes Km »'));
    expect(text, contains('© les contributeurs OpenStreetMap'));
    expect(text, contains('ODbL'));
    expect(text, contains('SIL Open Font License'));

    // GARDE-FOUS CRITIQUES (LEGAL-001C : contact opérationnel).
    // Le contact figure DEUX fois : Mentions légales + Droits (confidentialité).
    expect('contact@meskm.fr'.allMatches(text).length, 2,
        reason: 'contact opérationnel dans Mentions ET Confidentialité');
    expect('@'.allMatches(text).length, 2,
        reason: 'aucune autre adresse e-mail que contact@meskm.fr');
    expect(text, isNot(contains('sera mise à disposition')),
        reason: 'plus aucune formulation « contact à venir »');
    expect(text, isNot(contains('sera indiqué')),
        reason: 'plus aucune formulation « contact à venir »');
    expect(text, contains('à titre non professionnel'),
        reason: 'régime LCEN art. 1-1, II (éditeur non professionnel)');
    expect(text, isNot(contains('®')));
    expect(text, isNot(contains('marque déposée')));
    expect(text, isNot(contains('À COMPLÉTER')));

    // Licences des composants : vue standard Flutter.
    await tester.scrollUntilVisible(
        find.byKey(const Key('legal-licenses-button')), 400,
        scrollable: find.byType(Scrollable).first);
    await tester.tap(find.byKey(const Key('legal-licenses-button')));
    await tester.pumpAndSettle();
    expect(find.byType(LicensePage), findsOneWidget);
  });
}
