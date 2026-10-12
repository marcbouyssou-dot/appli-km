import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:mes_km/app.dart';
import 'package:mes_km/app/providers.dart';
import 'package:mes_km/data/local/app_database.dart';
import 'package:mes_km/data/local/sembast_favorite_trip_repository.dart';
import 'package:mes_km/data/local/sembast_trip_repository.dart';
import 'package:mes_km/data/network/route_distance_service.dart';
import 'package:mes_km/domain/models/civil_date.dart';
import 'package:mes_km/domain/models/favorite_trip.dart';
import 'package:sembast/sembast_memory.dart' hide Finder;

/// Service factice : compte les appels (confidentialité) et rend un
/// résultat programmé.
class FakeRouteService implements RouteDistanceService {
  FakeRouteService(this.result);

  RouteDistanceResult result;
  int callCount = 0;
  String? lastOrigin;
  String? lastDestination;

  @override
  Future<RouteDistanceResult> estimate({
    required String origin,
    required String destination,
  }) async {
    callCount++;
    lastOrigin = origin;
    lastDestination = destination;
    return result;
  }
}

/// Garde-fou : le tap d'un favori ne doit JAMAIS toucher le réseau.
class ExplodingRouteService implements RouteDistanceService {
  @override
  Future<RouteDistanceResult> estimate({
    required String origin,
    required String destination,
  }) async {
    fail('Aucun appel réseau ne doit avoir lieu ici.');
  }
}

void main() {
  final day = CivilDate(2026, 10, 11);

  setUpAll(() async => initializeDateFormatting('fr_FR'));

  late MesKmDatabase database;

  setUp(() async {
    database =
        await MesKmDatabase.open(newDatabaseFactoryMemory(), name: 'rc.db');
  });

  tearDown(() => database.close());

  Future<void> pumpApp(WidgetTester tester, RouteDistanceService service,
      {CivilDate? today}) async {
    tester.view.physicalSize = const Size(500, 1800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(ProviderScope(
      overrides: [
        databaseProvider.overrideWithValue(database),
        todayDateProvider.overrideWithValue(() => today ?? day),
        routeDistanceServiceProvider.overrideWithValue(service),
      ],
      child: const MesKmApp(),
    ));
    await tester.pumpAndSettle();
  }

  Future<void> openTripForm(WidgetTester tester) async {
    await tester.tap(find.text('Ajouter un trajet'));
    await tester.pumpAndSettle();
    // UX-003B : les adresses vivent dans « Itinéraire et détails »,
    // repliée à la création — on l'ouvre comme le ferait l'utilisateur.
    await tester.tap(find.byKey(const Key('optional-section-toggle')));
    await tester.pumpAndSettle();
  }

  Future<void> fillAddresses(WidgetTester tester) async {
    await tester.enterText(
        find.widgetWithText(TextField, 'Départ'), 'Maison');
    await tester.enterText(
        find.widgetWithText(TextField, 'Destination'), 'Cabinet');
    await tester.pumpAndSettle();
  }

  String distanceFieldText(WidgetTester tester) => tester
      .widget<TextField>(
          find.widgetWithText(TextField, 'Distance comptabilisée (km)'))
      .controller!
      .text;

  testWidgets(
      'CONFIDENTIALITÉ : bouton absent sans adresses, AUCUN appel réseau '
      'avant « Calculer la distance »', (tester) async {
    final service = FakeRouteService(const RouteDistanceSuccess(
        oneWayKm: 12.4, originLabel: 'A', destinationLabel: 'B'));
    await pumpApp(tester, service);
    await openTripForm(tester);

    expect(find.byKey(const Key('route-calc-button')), findsNothing);

    await fillAddresses(tester);
    expect(find.byKey(const Key('route-calc-button')), findsOneWidget);
    expect(
      find.text('Le calcul utilise un service cartographique en ligne.'),
      findsOneWidget,
    );
    expect(service.callCount, 0,
        reason: 'rien n’est envoyé avant l’action explicite');
  });

  testWidgets(
      'calcul : aller 12,4 proposé, A/R double à l’utilisation, '
      'modification manuelle conservée, Trip enregistré', (tester) async {
    final service = FakeRouteService(const RouteDistanceSuccess(
        oneWayKm: 12.4,
        originLabel: 'Maison, Seilhac',
        destinationLabel: 'Cabinet, Seilhac'));
    await pumpApp(tester, service);
    await openTripForm(tester);
    await fillAddresses(tester);

    await tester.tap(find.byKey(const Key('route-calc-button')));
    await tester.pumpAndSettle();

    expect(service.callCount, 1);
    expect(service.lastOrigin, 'Maison');
    expect(
      find.text('Aller : 12,4 km · Aller-retour : 24,8 km'),
      findsOneWidget,
    );

    // A/R activé -> « Utiliser 24,8 km ».
    await tester.tap(find.text('Aller-retour'));
    await tester.pumpAndSettle();
    expect(find.text('Utiliser 24,8 km'), findsOneWidget);
    await tester.tap(find.byKey(const Key('route-calc-use')));
    await tester.pumpAndSettle();
    expect(distanceFieldText(tester), '24,8');

    // L'utilisateur reste maître : modification manuelle.
    await tester.enterText(
      find.widgetWithText(TextField, 'Distance comptabilisée (km)'),
      '25',
    );
    await tester.tap(find.text('Ajouter'));
    await tester.pumpAndSettle();

    final trip = (await tester.runAsync(
            () => SembastTripRepository(database.db).getByDate(day)))!
        .single;
    expect(trip.distanceKm, 25, reason: 'valeur manuelle conservée');
    expect(trip.isRoundTrip, isTrue);
  });

  testWidgets('hors ligne : message propre, formulaire intact et utilisable',
      (tester) async {
    final service = FakeRouteService(const RouteOffline());
    await pumpApp(tester, service);
    await openTripForm(tester);
    await fillAddresses(tester);

    await tester.tap(find.byKey(const Key('route-calc-button')));
    await tester.pumpAndSettle();

    expect(
      find.text('Calcul indisponible hors ligne. '
          'Vous pouvez saisir la distance manuellement.'),
      findsOneWidget,
    );
    // Saisies conservées, saisie manuelle possible, enregistrement OK.
    expect(find.text('Maison'), findsOneWidget);
    await tester.enterText(
      find.widgetWithText(TextField, 'Distance comptabilisée (km)'),
      '7,5',
    );
    await tester.pump(); // le bouton passe à l'état actif
    await tester.tap(find.text('Ajouter'));
    await tester.pumpAndSettle();
    final trips = await tester.runAsync(
        () => SembastTripRepository(database.db).getByDate(day));
    expect(trips!.single.distanceKm, 7.5);
  });

  testWidgets('adresse introuvable : message dédié, rien de perdu',
      (tester) async {
    final service =
        FakeRouteService(const RouteAddressNotFound(isOrigin: false));
    await pumpApp(tester, service);
    await openTripForm(tester);
    await fillAddresses(tester);

    await tester.tap(find.byKey(const Key('route-calc-button')));
    await tester.pumpAndSettle();

    expect(find.textContaining('introuvable'), findsOneWidget);
    expect(find.text('Cabinet'), findsOneWidget);
  });

  testWidgets(
      'ambiguïté : propositions affichées, choix => champ mis à jour et '
      'calcul relancé', (tester) async {
    final service = FakeRouteService(const RouteAddressAmbiguous(
      isOrigin: true,
      suggestions: ['Seilhac, Corrèze', 'Seilhac, Autre-Lieu'],
    ));
    await pumpApp(tester, service);
    await openTripForm(tester);
    await fillAddresses(tester);

    await tester.tap(find.byKey(const Key('route-calc-button')));
    await tester.pumpAndSettle();
    expect(find.text('Plusieurs lieux pour le départ'), findsOneWidget);

    // Choix -> le service renvoie maintenant un succès.
    service.result = const RouteDistanceSuccess(
        oneWayKm: 6.4, originLabel: 'Seilhac, Corrèze', destinationLabel: 'B');
    await tester.tap(find.text('Seilhac, Corrèze'));
    await tester.pumpAndSettle();

    expect(service.callCount, 2);
    expect(service.lastOrigin, 'Seilhac, Corrèze',
        reason: 'le champ départ reprend le libellé choisi');
    expect(find.byKey(const Key('route-calc-result')), findsOneWidget);
  });

  testWidgets(
      'FAVORI : calcul A/R 35 => 70 enregistrés ; le tap du favori '
      'n’utilise JAMAIS le réseau', (tester) async {
    final service = FakeRouteService(const RouteDistanceSuccess(
        oneWayKm: 35, originLabel: 'Maison', destinationLabel: 'Cabinet'));
    await pumpApp(tester, service);

    await tester.tap(find.text('Créer un trajet favori'));
    await tester.pumpAndSettle();
    await tester.enterText(
        find.widgetWithText(TextField, 'Nom du favori'), 'Travail');
    await tester.tap(find.byKey(const Key('optional-section-toggle')));
    await tester.pumpAndSettle();
    await fillAddresses(tester);
    await tester.ensureVisible(find.text('Aller-retour'));
    await tester.tap(find.text('Aller-retour'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.byKey(const Key('route-calc-button')));
    await tester.tap(find.byKey(const Key('route-calc-button')));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.byKey(const Key('route-calc-use')));
    await tester.tap(find.byKey(const Key('route-calc-use')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Créer le favori'));
    await tester.pumpAndSettle();

    expect(find.text('+70 km'), findsOneWidget);
    expect(service.callCount, 1,
        reason: 'le réseau n’a servi qu’à CONFIGURER le favori');
  });

  testWidgets(
      'tap d’un favori : distance exacte ajoutée, ZÉRO appel réseau '
      '(service explosif)', (tester) async {
    await tester.runAsync(() => SembastFavoriteTripRepository(database.db)
        .put(FavoriteTrip(
            id: 'fav-1',
            label: 'Travail',
            distanceKm: 70,
            defaultRoundTrip: true,
            sortOrder: 0)));

    // Si quoi que ce soit touche le service, le test échoue (fail()).
    await pumpApp(tester, ExplodingRouteService());

    await tester.tap(find.byKey(const Key('favorite-fav-1')));
    await tester.pumpAndSettle();
    await tester.pump(const Duration(seconds: 1));
    await tester.pumpAndSettle();

    final field = tester.widget<TextField>(
        find.byKey(const Key('day-total-field')));
    expect(field.controller!.text, '70');
    final trip = (await tester.runAsync(
            () => SembastTripRepository(database.db).getByDate(day)))!
        .single;
    expect(trip.distanceKm, 70);
    expect(trip.isRoundTrip, isTrue);
  });
}
