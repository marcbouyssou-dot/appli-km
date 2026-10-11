import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:mes_km/app.dart';
import 'package:mes_km/app/providers.dart';
import 'package:mes_km/data/local/app_database.dart';
import 'package:mes_km/domain/models/civil_date.dart';
import 'package:mes_km/theme/app_theme.dart';
import 'package:mes_km/theme/mes_km_colors.dart';
import 'package:mes_km/theme/tokens.dart';
import 'package:mes_km/theme/vehicle_accent.dart';
import 'package:mes_km/widgets/app_buttons.dart';
import 'package:mes_km/widgets/empty_state.dart';
import 'package:mes_km/widgets/grouped_list.dart';
import 'package:mes_km/widgets/key_value_row.dart';
import 'package:mes_km/widgets/km_badge.dart';
import 'package:mes_km/widgets/period_selector.dart';
import 'package:mes_km/widgets/section_header.dart';
import 'package:mes_km/widgets/status_banner.dart';
import 'package:sembast/sembast_memory.dart' hide Finder;

// Design system Mes Km (UX-001) : palette explicite, rôles sémantiques,
// tokens, composants partagés — et invariants tactiles.
void main() {
  setUpAll(() async => initializeDateFormatting('fr_FR'));

  group('palette et rôles', () {
    test('light : rôles d’identité explicites', () {
      final scheme = AppTheme.light().colorScheme;
      expect(scheme.primary, AppPalette.primary);
      expect(scheme.surface, AppPalette.surface);
      expect(scheme.onSurface, AppPalette.textPrimary);
      expect(scheme.onSurfaceVariant, AppPalette.textSecondary);
      expect(AppTheme.light().scaffoldBackgroundColor, AppPalette.background);
      final semantic = AppTheme.light().extension<MesKmColors>()!;
      expect(semantic.success, AppPalette.success);
      expect(semantic.warning, AppPalette.warning);
    });

    test('dark : défini réellement, pas une inversion du light', () {
      final scheme = AppTheme.dark().colorScheme;
      expect(scheme.brightness, Brightness.dark);
      expect(scheme.primary, AppPalette.primaryDark);
      expect(AppTheme.dark().scaffoldBackgroundColor,
          AppPalette.backgroundDark);
      final semantic = AppTheme.dark().extension<MesKmColors>()!;
      expect(semantic.warning, AppPalette.warningDark);
      expect(semantic.warningContainer,
          isNot(AppPalette.warningContainer),
          reason: 'les containers sombres sont des couleurs dédiées');
    });

    test(
        'le warning fiscal est distinct du primaire ET de l’ancienne '
        'teinte congés', () {
      for (final theme in [AppTheme.light(), AppTheme.dark()]) {
        final semantic = theme.extension<MesKmColors>()!;
        final scheme = theme.colorScheme;
        expect(semantic.warning, isNot(scheme.primary));
        expect(semantic.warningContainer, isNot(scheme.primaryContainer));
        expect(semantic.warningContainer, isNot(scheme.tertiaryContainer),
            reason: 'provisoire (ambre) ≠ congé (sarcelle)');
      }
    });
  });

  group('tokens', () {
    test('rayons : fin des grosses pilules', () {
      expect(AppRadius.s, 12);
      expect(AppRadius.m, 16);
      expect(AppRadius.l, lessThanOrEqualTo(20));
      final cardShape =
          AppTheme.light().cardTheme.shape! as RoundedRectangleBorder;
      expect(cardShape.borderRadius,
          BorderRadius.circular(AppRadius.m),
          reason: 'carte standard : 16');
    });

    test('tactile : invariants jamais réduits', () {
      expect(AppSizes.minTouchTarget, greaterThanOrEqualTo(48));
      expect(AppSizes.primaryActionHeight, greaterThanOrEqualTo(56));
      final buttonMin = AppTheme.light()
          .textButtonTheme
          .style!
          .minimumSize!
          .resolve(const {})!;
      expect(buttonMin.height, greaterThanOrEqualTo(48));
    });

    test('ThemeMode.system conservé', () {
      final app = const MesKmApp().build(FakeBuildContext()) as MaterialApp;
      expect(app.themeMode, ThemeMode.system);
      expect(app.theme, isNotNull);
      expect(app.darkTheme, isNotNull);
    });
  });

  group('composants partagés', () {
    Future<void> pump(WidgetTester tester, Widget child,
        {ThemeData? theme}) async {
      await tester.pumpWidget(MaterialApp(
        theme: theme ?? AppTheme.light(),
        home: Scaffold(body: Center(child: child)),
      ));
    }

    testWidgets('SectionHeader : texte EXACT, jamais transformé',
        (tester) async {
      await pump(tester, const SectionHeader('Trajets détaillés'));
      expect(find.text('Trajets détaillés'), findsOneWidget);
    });

    testWidgets('StatusBanner warning : fond ambre + texte + icône',
        (tester) async {
      await pump(
        tester,
        const StatusBanner(
          kind: StatusBannerKind.warning,
          text: 'Simulation indicative — barème des revenus 2025.',
        ),
      );
      expect(find.text('Simulation indicative — barème des revenus 2025.'),
          findsOneWidget);
      expect(find.byIcon(Icons.schedule_outlined), findsOneWidget,
          reason: 'jamais la couleur seule : icône + texte');
      final box = tester.widget<Container>(find.byType(Container));
      expect((box.decoration! as BoxDecoration).color,
          MesKmColors.light.warningContainer);
    });

    testWidgets('StatusBanner error : fond destructif', (tester) async {
      await pump(tester,
          const StatusBanner(kind: StatusBannerKind.error, text: 'Alerte'));
      final box = tester.widget<Container>(find.byType(Container));
      expect((box.decoration! as BoxDecoration).color,
          AppTheme.light().colorScheme.errorContainer);
    });

    testWidgets('PeriodSelector : chevrons avec clés, cibles larges',
        (tester) async {
      var previous = 0;
      var next = 0;
      await pump(
        tester,
        PeriodSelector(
          label: '2026',
          onPrevious: () => previous++,
          onNext: () => next++,
          previousKey: const Key('p'),
          nextKey: const Key('n'),
          previousTooltip: 'Précédent',
          nextTooltip: 'Suivant',
        ),
      );
      await tester.tap(find.byKey(const Key('p')));
      await tester.tap(find.byKey(const Key('n')));
      expect((previous, next), (1, 1));
      expect(tester.getSize(find.byKey(const Key('p'))).height,
          greaterThanOrEqualTo(AppSizes.minTouchTarget));
    });

    testWidgets('PrimaryButton : la clé vit sur le FilledButton interne '
        '(compatibilité tests existants), hauteur 56', (tester) async {
      await pump(
        tester,
        SizedBox(
          width: 300,
          child: PrimaryButton(
            key: const Key('action'),
            label: 'Créer',
            onPressed: () {},
          ),
        ),
      );
      final button =
          tester.widget<FilledButton>(find.byKey(const Key('action')));
      expect(button, isA<FilledButton>());
      expect(tester.getSize(find.byKey(const Key('action'))).height,
          greaterThanOrEqualTo(AppSizes.primaryActionHeight));
    });

    testWidgets('QuietButton : cible >= 48', (tester) async {
      await pump(
        tester,
        QuietButton(
            key: const Key('quiet'), label: 'Effacer', onPressed: () {}),
      );
      expect(tester.getSize(find.byKey(const Key('quiet'))).height,
          greaterThanOrEqualTo(AppSizes.minTouchTarget));
    });

    testWidgets('GroupedList : séparateurs internes entre les lignes',
        (tester) async {
      await pump(
        tester,
        const GroupedList(children: [
          ListTile(title: Text('A')),
          ListTile(title: Text('B')),
          ListTile(title: Text('C')),
        ]),
      );
      expect(find.byType(Divider), findsNWidgets(2));
      expect(find.byType(Card), findsOneWidget,
          reason: 'une seule surface pour tout le groupe');
    });

    testWidgets('KmBadge, KeyValueRow, EmptyState : rendus simples',
        (tester) async {
      await pump(
        tester,
        const Column(children: [
          KmBadge('+24 km'),
          KeyValueRow(label: 'Journées', value: '12'),
          EmptyState('Aucun favori pour le moment.'),
        ]),
      );
      expect(find.text('+24 km'), findsOneWidget);
      expect(find.text('Journées'), findsOneWidget);
      expect(find.text('12'), findsOneWidget);
      expect(find.text('Aucun favori pour le moment.'), findsOneWidget);
    });
  });

  group('identité UX-001B', () {
    test('Inter est la famille du thème (police embarquée, pas Roboto)', () {
      expect(AppTheme.light().textTheme.bodyMedium?.fontFamily, 'Inter');
      expect(AppTheme.dark().textTheme.titleLarge?.fontFamily, 'Inter');
    });

    test('navigation légère : plus de capsule, sélection par la couleur', () {
      final nav = AppTheme.light().navigationBarTheme;
      expect(nav.indicatorColor, Colors.transparent);
      final selected = nav.labelTextStyle!
          .resolve({WidgetState.selected})!;
      expect(selected.color, AppPalette.primary);
      expect(selected.fontWeight, FontWeight.w700);
    });

    testWidgets(
        'compteur héros : plus de carte, zone entièrement tactile, '
        'pédagogie permanente retirée, affordance crayon présente',
        (tester) async {
      final database = await MesKmDatabase.open(newDatabaseFactoryMemory(),
          name: 'ds3.db');
      addTearDown(database.close);
      await tester.pumpWidget(ProviderScope(
        overrides: [
          databaseProvider.overrideWithValue(database),
          todayDateProvider.overrideWithValue(() => CivilDate(2026, 10, 12)),
        ],
        child: const MesKmApp(),
      ));
      await tester.pumpAndSettle();

      final hero = find.byKey(const Key('day-total-card'));
      expect(hero, findsOneWidget);
      expect(
        find.ancestor(of: hero, matching: find.byType(Card)),
        findsNothing,
        reason: 'le chiffre vit dans la page, pas dans une carte',
      );
      expect(tester.getSize(hero).height,
          greaterThanOrEqualTo(AppSizes.minTouchTarget));
      expect(find.text('Touchez la carte pour modifier le total'),
          findsNothing);
      expect(
        find.descendant(
            of: hero, matching: find.byIcon(Icons.edit_outlined)),
        findsOneWidget,
        reason: 'affordance discrète mais explicite',
      );

      // Le comportement compteur validé est inchangé : tap => édition.
      await tester.tap(hero);
      await tester.pumpAndSettle();
      await tester.enterText(
          find.byKey(const Key('day-total-field')), '23');
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pumpAndSettle();
      final field = tester.widget<TextField>(
          find.byKey(const Key('day-total-field')));
      expect(field.controller!.text, '23');
    });
  });

  group('personnalité UX-001C', () {
    test('accents de contenu : trois rôles, light et dark dédiés', () {
      final light = AppTheme.light().extension<MesKmColors>()!;
      final dark = AppTheme.dark().extension<MesKmColors>()!;
      // Chaque couleur a un sens : mobilité, favori, donnée.
      expect(light.mobility, AppPalette.mobility);
      expect(light.favorite, AppPalette.favorite);
      expect(light.data, AppPalette.data);
      expect(dark.mobility, AppPalette.mobilityDark);
      expect(dark.favorite, AppPalette.favoriteDark);
      expect(dark.data, AppPalette.dataDark);
      // Pas d'arc-en-ciel : les trois accents sont distincts entre eux
      // et distincts des rôles sémantiques existants.
      final all = {
        light.mobility, light.favorite, light.data,
        light.success, light.warning, light.vacation,
        AppTheme.light().colorScheme.primary,
      };
      expect(all, hasLength(7));
    });

    test('accent véhicule : DÉTERMINISTE, stable, neutre pour null', () {
      final theme = AppTheme.light();
      final a1 = vehicleAccent(theme, 'peugeot');
      final a2 = vehicleAccent(theme, 'peugeot');
      expect(a1, a2, reason: 'le même véhicule garde la même couleur');
      expect(vehicleAccent(theme, null), theme.colorScheme.outline,
          reason: 'sans véhicule = gris neutre, jamais un accent');
    });

    testWidgets(
        'Aujourd\'hui : héros toujours sans Card, trait signature présent, '
        '« Ajouter un trajet » bleu Mes Km >= 56 px', (tester) async {
      final database = await MesKmDatabase.open(newDatabaseFactoryMemory(),
          name: 'ds4.db');
      addTearDown(database.close);
      await tester.pumpWidget(ProviderScope(
        overrides: [
          databaseProvider.overrideWithValue(database),
          todayDateProvider.overrideWithValue(() => CivilDate(2026, 10, 12)),
        ],
        child: const MesKmApp(),
      ));
      await tester.pumpAndSettle();

      final hero = find.byKey(const Key('day-total-card'));
      expect(find.ancestor(of: hero, matching: find.byType(Card)),
          findsNothing);

      final addTrip = find.text('Ajouter un trajet');
      expect(addTrip, findsOneWidget);
      final inkFinder =
          find.ancestor(of: addTrip, matching: find.byType(Ink));
      expect(inkFinder, findsWidgets);
      expect(tester.getSize(inkFinder.first).height,
          greaterThanOrEqualTo(AppSizes.primaryActionHeight));
      final decoration = tester.widget<Ink>(inkFinder.first).decoration!
          as BoxDecoration;
      expect(decoration.gradient!.colors.first, AppPalette.primary,
          reason: 'action principale = bleu Mes Km');
    });

    testWidgets('Plus : trois groupes, zéro Card/ListTile visible, '
        'pictogrammes pastel porteurs de sens', (tester) async {
      final database = await MesKmDatabase.open(newDatabaseFactoryMemory(),
          name: 'ds5.db');
      addTearDown(database.close);
      tester.view.physicalSize = const Size(500, 1800);
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

      expect(find.text('MES TRAJETS'), findsOneWidget);
      expect(find.text('MES DONNÉES'), findsOneWidget);
      expect(find.text('APPLICATION'), findsOneWidget);
      final moreScroll = find.byType(ListView).last;
      expect(
          find.descendant(of: moreScroll, matching: find.byType(Card)),
          findsNothing);
      expect(
          find.descendant(of: moreScroll, matching: find.byType(ListTile)),
          findsNothing);
      // Les cinq destinations restent présentes et navigables.
      for (final label in [
        'Trajets favoris', 'Véhicules', 'Documents', 'Sauvegarde', 'Réglages',
      ]) {
        expect(find.descendant(of: moreScroll, matching: find.text(label)),
            findsOneWidget);
      }
    });
  });

  group('application réelle', () {
    testWidgets(
        'petit iPhone (320x568) : les 4 onglets se construisent sans '
        'overflow avec le nouveau thème', (tester) async {
      final database = await MesKmDatabase.open(newDatabaseFactoryMemory(),
          name: 'ds.db');
      addTearDown(database.close);
      tester.view.physicalSize = const Size(320, 568);
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

      for (final icon in [
        Icons.calendar_month_outlined,
        Icons.bar_chart_outlined,
        Icons.more_horiz_outlined,
        Icons.today_outlined,
      ]) {
        await tester.tap(find.byIcon(icon));
        await tester.pumpAndSettle();
      }
      // Un overflow ferait échouer le test (exception de rendu).
    });

    testWidgets('mode sombre réel : fond sombre dédié appliqué',
        (tester) async {
      final database = await MesKmDatabase.open(newDatabaseFactoryMemory(),
          name: 'ds2.db');
      addTearDown(database.close);
      tester.platformDispatcher.platformBrightnessTestValue =
          Brightness.dark;
      addTearDown(tester.platformDispatcher.clearPlatformBrightnessTestValue);

      await tester.pumpWidget(ProviderScope(
        overrides: [
          databaseProvider.overrideWithValue(database),
          todayDateProvider.overrideWithValue(() => CivilDate(2026, 10, 12)),
        ],
        child: const MesKmApp(),
      ));
      await tester.pumpAndSettle();

      final scaffold = tester.widget<Scaffold>(find.byType(Scaffold).first);
      final context = tester.element(find.byType(Scaffold).first);
      expect(scaffold.backgroundColor ?? Theme.of(context).scaffoldBackgroundColor,
          AppPalette.backgroundDark);
    });
  });
}

/// Contexte factice : MesKmApp.build n'utilise pas le context.
class FakeBuildContext extends Fake implements BuildContext {}
