import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:mes_km/app.dart';
import 'package:mes_km/app/providers.dart';
import 'package:mes_km/data/backup/backup_file_gateway.dart';
import 'package:mes_km/data/local/app_database.dart';
import 'package:mes_km/data/local/sembast_day_extra_repository.dart';
import 'package:mes_km/data/local/sembast_settings_repository.dart';
import 'package:mes_km/data/local/sembast_trip_repository.dart';
import 'package:mes_km/data/local/sembast_vehicle_repository.dart';
import 'package:mes_km/data/network/route_distance_service.dart';
import 'package:mes_km/domain/models/app_settings.dart';
import 'package:mes_km/domain/models/civil_date.dart';
import 'package:mes_km/domain/models/day_extra.dart';
import 'package:mes_km/domain/models/trip.dart';
import 'package:mes_km/domain/models/vehicle.dart';
import 'package:mes_km/features/documents/pdf_preview_screen.dart';
import 'package:sembast/sembast_memory.dart' hide Finder;

/// Capture les documents « partagés » ; le vrai partage iOS reste à la
/// recette humaine.
class FakeDocumentsGateway implements BackupFileGateway {
  String? savedName;
  List<int>? savedBytes;
  String? savedMimeType;
  bool cancelShare = false;
  Object? saveError;

  @override
  Future<BackupSaveOutcome> saveFile({
    required String fileName,
    required List<int> bytes,
    required String mimeType,
  }) async {
    if (saveError != null) throw saveError!;
    if (cancelShare) return BackupSaveOutcome.cancelled;
    savedName = fileName;
    savedBytes = bytes;
    savedMimeType = mimeType;
    return BackupSaveOutcome.completed;
  }

  @override
  Future<BackupSaveOutcome> saveBackupFile({
    required String fileName,
    required String content,
  }) => throw UnimplementedError();

  @override
  Future<String?> pickBackupFile() => throw UnimplementedError();
}

/// PREUVE hors-ligne : générer un document ne doit déclencher AUCUN appel
/// réseau — ce service échoue le test s'il est seulement invoqué.
class ExplodingRouteService implements RouteDistanceService {
  @override
  Future<RouteDistanceResult> estimate({
    required String origin,
    required String destination,
  }) {
    fail('Aucun appel réseau ne doit avoir lieu pour générer un document.');
  }
}

void main() {
  final today = CivilDate(2026, 10, 11);

  setUpAll(() async => initializeDateFormatting('fr_FR'));

  late MesKmDatabase database;
  late FakeDocumentsGateway gateway;

  setUp(() async {
    database = await MesKmDatabase.open(
      newDatabaseFactoryMemory(),
      name: 'doc.db',
    );
    gateway = FakeDocumentsGateway();
  });

  tearDown(() => database.close());

  Future<void> seed(WidgetTester tester) async {
    await tester.runAsync(() async {
      await SembastVehicleRepository(database.db).put(
        Vehicle(
          id: 'v1',
          name: 'Peugeot 208',
          category: VehicleCategory.car,
          registration: 'AB-123-CD',
        ),
      );
      await SembastTripRepository(database.db).put(
        Trip(
          id: 't-today',
          date: today,
          distanceKm: 42,
          vehicleId: 'v1',
          origin: 'Maison',
          destination: 'Cabinet',
          createdAt: DateTime.utc(2026, 10, 11, 9),
        ),
      );
      await SembastTripRepository(database.db).put(
        Trip(
          id: 't-mars',
          date: CivilDate(2026, 3, 17),
          distanceKm: 87,
          createdAt: DateTime.utc(2026, 3, 17, 9),
        ),
      );
      await SembastDayExtraRepository(
        database.db,
      ).set(DayExtra(date: CivilDate(2026, 6, 2), extraKm: 11));
      // Une année précédente non vide, pour la navigation.
      await SembastTripRepository(database.db).put(
        Trip(
          id: 't-2025',
          date: CivilDate(2025, 5, 4),
          distanceKm: 30,
          createdAt: DateTime.utc(2025, 5, 4, 9),
        ),
      );
      await SembastSettingsRepository(
        database.db,
      ).save(AppSettings(displayName: 'Marc Infirmier'));
    });
  }

  Future<void> pumpApp(WidgetTester tester) async {
    tester.view.physicalSize = const Size(500, 1800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          databaseProvider.overrideWithValue(database),
          todayDateProvider.overrideWithValue(() => today),
          backupFileGatewayProvider.overrideWithValue(gateway),
          routeDistanceServiceProvider.overrideWithValue(
            ExplodingRouteService(),
          ),
        ],
        child: const MesKmApp(),
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<void> openDocuments(WidgetTester tester) async {
    await tester.tap(find.byIcon(Icons.more_horiz_outlined));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Documents'));
    await tester.pumpAndSettle();
  }

  Future<void> flushSnackbars(WidgetTester tester) async {
    await tester.pump(const Duration(seconds: 5));
    await tester.pumpAndSettle();
  }

  testWidgets(
    'Plus → Documents : année courante, total affiché, PDF prévisualisé et partagé '
    'hors-ligne avec le bon nom et le bon type',
    (tester) async {
      await seed(tester);
      await pumpApp(tester);
      await openDocuments(tester);

      expect(find.text('2026'), findsOneWidget);
      expect(find.text('140 km enregistrés'), findsOneWidget); // 42+87+11
      expect(find.text('Revenir à cette année'), findsNothing);

      await tester.tap(find.byKey(const Key('create-pdf-button')));
      await tester.pumpAndSettle();

      expect(gateway.savedName, isNull, reason: 'le choix ne partage rien');
      expect(find.text('Synthèse uniquement'), findsOneWidget);
      await tester.tap(find.byKey(const Key('preview-pdf-button')));
      await tester.pumpAndSettle();
      expect(find.text('Aperçu PDF'), findsOneWidget);
      expect(gateway.savedName, isNull, reason: 'l’aperçu précède le partage');
      final previewed = tester
          .widget<PdfPreviewScreen>(find.byType(PdfPreviewScreen))
          .document;
      await tester.tap(find.byKey(const Key('share-preview-pdf')));
      await tester.pumpAndSettle();
      expect(gateway.savedName, 'MesKm-Synthese-2026.pdf');
      expect(
        gateway.savedBytes,
        same(previewed.bytes),
        reason: 'le fichier affiché est partagé sans régénération',
      );
      expect(gateway.savedMimeType, 'application/pdf');
      expect(ascii.decode(gateway.savedBytes!.sublist(0, 5)), '%PDF-');
      expect(find.text('PDF partagé ou enregistré.'), findsOneWidget);
      await flushSnackbars(tester);
    },
  );

  testWidgets('CSV créé : nom, type octet-stream (leçon Safari KM-008B), '
      'contenu borné à l’année', (tester) async {
    await seed(tester);
    await pumpApp(tester);
    await openDocuments(tester);

    await tester.tap(find.byKey(const Key('create-csv-button')));
    await tester.pumpAndSettle();

    expect(gateway.savedName, 'MesKm-Detail-2026.csv');
    expect(gateway.savedMimeType, 'application/octet-stream');
    final csv = utf8.decode(gateway.savedBytes!);
    expect(csv, startsWith('Date;Type;Distance_km;'));
    expect(
      csv,
      contains(
        '2026-10-11;Trajet;42;Maison;Cabinet;;Non;Peugeot 208;'
        'AB-123-CD',
      ),
    );
    expect(csv, contains('2026-06-02;Non détaillé;11;'));
    expect(
      csv,
      isNot(contains('2025')),
      reason: 'le CSV 2026 ne contient que l’année 2026',
    );
    expect(find.text('Document créé.'), findsOneWidget);
    await flushSnackbars(tester);
  });

  testWidgets('navigation d’année : 2025 exportable, année vide désactivée', (
    tester,
  ) async {
    await seed(tester);
    await pumpApp(tester);
    await openDocuments(tester);

    await tester.tap(find.byKey(const Key('docs-prev-year')));
    await tester.pumpAndSettle();
    expect(find.text('2025'), findsOneWidget);
    expect(find.text('30 km enregistrés'), findsOneWidget);
    expect(find.text('Revenir à cette année'), findsOneWidget);

    await tester.tap(find.byKey(const Key('create-csv-button')));
    await tester.pumpAndSettle();
    expect(gateway.savedName, 'MesKm-Detail-2025.csv');
    expect(utf8.decode(gateway.savedBytes!), contains('2025-05-04;Trajet;30'));
    await flushSnackbars(tester);

    // 2024 : aucune donnée — boutons désactivés, message explicite.
    await tester.tap(find.byKey(const Key('docs-prev-year')));
    await tester.pumpAndSettle();
    expect(find.text('Aucune donnée en 2024.'), findsOneWidget);
    expect(
      tester
          .widget<FilledButton>(find.byKey(const Key('create-pdf-button')))
          .onPressed,
      isNull,
    );
    expect(
      tester
          .widget<FilledButton>(find.byKey(const Key('create-csv-button')))
          .onPressed,
      isNull,
    );

    await tester.tap(find.text('Revenir à cette année'));
    await tester.pumpAndSettle();
    expect(find.text('2026'), findsOneWidget);
  });

  testWidgets('annulation du partage : silencieuse (ni succès ni échec)', (
    tester,
  ) async {
    await seed(tester);
    await pumpApp(tester);
    await openDocuments(tester);

    gateway.cancelShare = true;
    await tester.tap(find.byKey(const Key('create-pdf-button')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('preview-pdf-button')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('share-preview-pdf')));
    await tester.pumpAndSettle();

    expect(find.text('PDF partagé ou enregistré.'), findsNothing);
    expect(find.text('Aperçu PDF'), findsOneWidget);
    expect(find.textContaining('Impossible'), findsNothing);
  });

  testWidgets('annuler le choix ou quitter l’aperçu ne partage aucun fichier', (
    tester,
  ) async {
    await seed(tester);
    await pumpApp(tester);
    await openDocuments(tester);
    await tester.tap(find.byKey(const Key('create-pdf-button')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Annuler'));
    await tester.pumpAndSettle();
    expect(gateway.savedBytes, isNull);
    await tester.tap(find.byKey(const Key('create-pdf-button')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('preview-pdf-button')));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Retour'));
    await tester.pumpAndSettle();
    expect(find.text('Documents'), findsOneWidget);
    expect(gateway.savedBytes, isNull);
  });

  testWidgets('format détaillé choisi explicitement, partage depuis l’aperçu', (
    tester,
  ) async {
    await seed(tester);
    await pumpApp(tester);
    await openDocuments(tester);
    await tester.tap(find.byKey(const Key('create-pdf-button')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Synthèse + détail'));
    await tester.tap(find.byKey(const Key('preview-pdf-button')));
    await tester.pumpAndSettle();
    expect(gateway.savedBytes, isNull);
    await tester.tap(find.byKey(const Key('share-preview-pdf')));
    await tester.pumpAndSettle();
    expect(gateway.savedName, 'MesKm-Releve-2026.pdf');
    expect(
      RegExp(
        r'/Type\s*/Page\b',
      ).allMatches(latin1.decode(gateway.savedBytes!)).length,
      greaterThan(1),
    );
  });

  testWidgets('erreur réelle : message compréhensible, jamais technique', (
    tester,
  ) async {
    await seed(tester);
    await pumpApp(tester);
    await openDocuments(tester);

    gateway.saveError = NoSuchMethodError.withInvocation(
      null,
      Invocation.method(#canShare, []),
    );
    await tester.tap(find.byKey(const Key('create-csv-button')));
    await tester.pumpAndSettle();

    expect(
      find.text('Impossible de créer le document. Réessayez.'),
      findsOneWidget,
    );
    expect(find.textContaining('NoSuchMethodError'), findsNothing);
    expect(find.textContaining('canShare'), findsNothing);
    await flushSnackbars(tester);
  });
}
