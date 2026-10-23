import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:mes_km/app.dart';
import 'package:mes_km/app/providers.dart';
import 'package:mes_km/data/backup/backup_file_gateway.dart';
import 'package:mes_km/data/local/app_database.dart';
import 'package:mes_km/data/local/sembast_favorite_trip_repository.dart';
import 'package:mes_km/data/local/sembast_trip_repository.dart';
import 'package:mes_km/data/local/sembast_vacation_repository.dart';
import 'package:mes_km/domain/models/civil_date.dart';
import 'package:mes_km/domain/models/favorite_trip.dart';
import 'package:mes_km/domain/models/trip.dart';
import 'package:mes_km/domain/models/vacation_period.dart';
import 'package:mes_km/features/day/editable_day_total.dart';
import 'package:sembast/sembast_memory.dart' hide Finder;

/// Passerelle factice : capture l'export, fournit le fichier « choisi ».
/// Le vrai partage/sélecteur iOS reste à la recette humaine.
class FakeBackupFileGateway implements BackupFileGateway {
  String? savedName;
  String? savedContent;
  String? fileToPick;
  bool cancelPick = false;
  bool cancelShare = false;
  Object? saveError;

  @override
  Future<BackupSaveOutcome> saveBackupFile({
    required String fileName,
    required String content,
  }) async {
    if (saveError != null) throw saveError!;
    if (cancelShare) return BackupSaveOutcome.cancelled;
    savedName = fileName;
    savedContent = content;
    return BackupSaveOutcome.completed;
  }

  String? savedBinaryName;
  List<int>? savedBytes;
  String? savedMimeType;

  @override
  Future<BackupSaveOutcome> saveFile({
    required String fileName,
    required List<int> bytes,
    required String mimeType,
  }) async {
    if (saveError != null) throw saveError!;
    if (cancelShare) return BackupSaveOutcome.cancelled;
    savedBinaryName = fileName;
    savedBytes = bytes;
    savedMimeType = mimeType;
    return BackupSaveOutcome.completed;
  }

  @override
  Future<String?> pickBackupFile() async => cancelPick ? null : fileToPick;
}

void main() {
  final today = CivilDate(2026, 10, 11);

  setUpAll(() async => initializeDateFormatting('fr_FR'));

  late MesKmDatabase database;
  late FakeBackupFileGateway gateway;

  setUp(() async {
    database =
        await MesKmDatabase.open(newDatabaseFactoryMemory(), name: 'bf.db');
    gateway = FakeBackupFileGateway();
  });

  tearDown(() => database.close());

  Future<void> seedRecognizableData(WidgetTester tester) async {
    await tester.runAsync(() async {
      await SembastTripRepository(database.db).put(Trip(
        id: 't-today',
        date: today,
        distanceKm: 42,
        createdAt: DateTime.utc(2026, 10, 11, 9),
      ));
      await SembastTripRepository(database.db).put(Trip(
        id: 't-old',
        date: CivilDate(2026, 3, 17),
        distanceKm: 87,
        createdAt: DateTime.utc(2026, 3, 17, 9),
      ));
      await SembastFavoriteTripRepository(database.db).put(FavoriteTrip(
          id: 'f-1', label: 'TEST BACKUP', distanceKm: 24, sortOrder: 0));
      await SembastVacationRepository(database.db).put(VacationPeriod(
          id: 'p-1',
          startDate: CivilDate(2026, 8, 3),
          endDate: CivilDate(2026, 8, 10)));
    });
  }

  Future<void> wipeData(WidgetTester tester) async {
    await tester.runAsync(() async {
      await SembastTripRepository(database.db).delete('t-today');
      await SembastFavoriteTripRepository(database.db).delete('f-1');
      await SembastVacationRepository(database.db).replaceAll(const []);
    });
  }

  Future<void> pumpApp(WidgetTester tester) async {
    tester.view.physicalSize = const Size(500, 1800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(ProviderScope(
      overrides: [
        databaseProvider.overrideWithValue(database),
        todayDateProvider.overrideWithValue(() => today),
        backupFileGatewayProvider.overrideWithValue(gateway),
      ],
      child: const MesKmApp(),
    ));
    await tester.pumpAndSettle();
  }

  Future<void> openBackupScreen(WidgetTester tester) async {
    await tester.tap(find.byIcon(Icons.more_horiz_outlined));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Sauvegarde'));
    await tester.pumpAndSettle();
  }

  String totalText(WidgetTester tester) =>
      tester.widget<TextField>(find.byKey(dayTotalFieldKey)).controller!.text;

  testWidgets('export : fichier nommé, contenu versionné, date affichée',
      (tester) async {
    await seedRecognizableData(tester);
    await pumpApp(tester);
    await openBackupScreen(tester);

    expect(find.text('MES DONNÉES'), findsOneWidget);
    expect(find.textContaining('Dernière sauvegarde exportée'), findsNothing);

    await tester.tap(find.byKey(const Key('create-backup-button')));
    await tester.pumpAndSettle();

    expect(gateway.savedName,
        matches(r'^MesKm-Sauvegarde-\d{4}-\d{2}-\d{2}\.kmbackup$'));
    expect(gateway.savedName, isNot(endsWith('.json')),
        reason: 'jamais .kmbackup.json');
    expect(gateway.savedContent, contains('"schemaVersion": 4'));
    expect(gateway.savedContent, contains('TEST BACKUP'));
    expect(find.textContaining('Dernière sauvegarde exportée'),
        findsOneWidget);
    expect(find.text('Sauvegarde créée.'), findsOneWidget);
    await tester.pump(const Duration(seconds: 5));
    await tester.pumpAndSettle();
  });

  testWidgets(
      'restauration complète : aperçu, Annuler sans écriture, puis '
      'restauration et rafraîchissement immédiat partout', (tester) async {
    await seedRecognizableData(tester);
    await pumpApp(tester);
    await openBackupScreen(tester);
    await tester.tap(find.byKey(const Key('create-backup-button')));
    await tester.pumpAndSettle();
    final backupJson = gateway.savedContent!;
    await tester.pump(const Duration(seconds: 5));

    // Mutations volontaires après l'export.
    await wipeData(tester);

    // APERÇU : aucune écriture avant confirmation.
    gateway.fileToPick = backupJson;
    await tester.tap(find.byKey(const Key('restore-backup-button')));
    await tester.pumpAndSettle();
    expect(find.text('Sauvegarde Mes Km'), findsOneWidget);
    expect(find.text('Journées avec kilomètres'), findsOneWidget);
    expect(find.text('129 km'), findsOneWidget); // 42 + 87
    expect(find.textContaining('remplacera les données'), findsOneWidget);

    await tester.tap(find.text('Annuler'));
    await tester.pumpAndSettle();
    final tripsAfterCancel = await tester
        .runAsync(() => SembastTripRepository(database.db).getAll());
    expect(tripsAfterCancel!.map((t) => t.id).toList(), ['t-old'],
        reason: 'Annuler => aucune écriture');

    // Restauration confirmée.
    await tester.tap(find.byKey(const Key('restore-backup-button')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Restaurer'));
    await tester.pumpAndSettle();
    expect(find.text('Données restaurées.'), findsOneWidget);
    await tester.pump(const Duration(seconds: 5));
    await tester.pumpAndSettle();

    // Rafraîchissement immédiat, sans relancer l'app :
    await tester.tap(find.byType(BackButton));
    await tester.pumpAndSettle();
    await tester.tap(find.byIcon(Icons.today_outlined));
    await tester.pumpAndSettle();
    expect(totalText(tester), '42');
    expect(find.text('TEST BACKUP'), findsOneWidget); // favori revenu

    await tester.tap(find.byIcon(Icons.calendar_month_outlined));
    await tester.pumpAndSettle();
    expect(
      find.descendant(
          of: find.byKey(const Key('cal-cell-2026-10-11')),
          matching: find.text('42 km')),
      findsOneWidget,
    );
  });

  testWidgets(
      'annulation du partage : ni « Sauvegarde créée », ni message d’échec, '
      'pas de date d’export enregistrée', (tester) async {
    await pumpApp(tester);
    await openBackupScreen(tester);

    gateway.cancelShare = true;
    await tester.tap(find.byKey(const Key('create-backup-button')));
    await tester.pumpAndSettle();

    expect(find.text('Sauvegarde créée.'), findsNothing);
    expect(find.textContaining('Impossible'), findsNothing);
    expect(find.textContaining('Dernière sauvegarde exportée'), findsNothing);
  });

  testWidgets(
      'vraie erreur d’export : message compréhensible, jamais de '
      'NoSuchMethodError à l’écran', (tester) async {
    await pumpApp(tester);
    await openBackupScreen(tester);

    gateway.saveError =
        NoSuchMethodError.withInvocation(null, Invocation.method(#canShare, []));
    await tester.tap(find.byKey(const Key('create-backup-button')));
    await tester.pumpAndSettle();

    expect(
      find.text('Impossible de créer la sauvegarde. Réessayez.'),
      findsOneWidget,
    );
    expect(find.textContaining('NoSuchMethodError'), findsNothing);
    expect(find.textContaining('canShare'), findsNothing);
    await tester.pump(const Duration(seconds: 5));
    await tester.pumpAndSettle();
  });

  testWidgets('fichier invalide : refus clair, données intactes',
      (tester) async {
    await seedRecognizableData(tester);
    await pumpApp(tester);
    await openBackupScreen(tester);

    gateway.fileToPick = 'pas une sauvegarde';
    await tester.tap(find.byKey(const Key('restore-backup-button')));
    await tester.pumpAndSettle();

    expect(find.text('Restauration impossible'), findsOneWidget);
    expect(find.textContaining('sauvegarde Mes Km'), findsOneWidget);
    await tester.tap(find.text('OK'));
    await tester.pumpAndSettle();

    final trips = await tester
        .runAsync(() => SembastTripRepository(database.db).getAll());
    expect(trips, hasLength(2), reason: 'aucune donnée touchée');
  });

  testWidgets('version future : refus explicite', (tester) async {
    await pumpApp(tester);
    await openBackupScreen(tester);

    gateway.fileToPick =
        '{"schemaVersion": 99, "exportedAt": "2026-01-01T00:00:00Z", '
        '"data": {}}';
    await tester.tap(find.byKey(const Key('restore-backup-button')));
    await tester.pumpAndSettle();

    expect(
      find.textContaining('version plus récente de Mes Km'),
      findsOneWidget,
    );
    await tester.tap(find.text('OK'));
    await tester.pumpAndSettle();
  });

  testWidgets('sélection annulée : rien ne se passe', (tester) async {
    await pumpApp(tester);
    await openBackupScreen(tester);

    gateway.cancelPick = true;
    await tester.tap(find.byKey(const Key('restore-backup-button')));
    await tester.pumpAndSettle();

    expect(find.text('Sauvegarde Mes Km'), findsNothing);
    expect(find.text('Restauration impossible'), findsNothing);
  });
}
