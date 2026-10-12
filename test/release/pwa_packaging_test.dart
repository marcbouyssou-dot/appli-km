import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:mes_km/app.dart';
import 'package:mes_km/app/build_info.dart';
import 'package:mes_km/app/providers.dart';
import 'package:mes_km/data/local/app_database.dart';
import 'package:mes_km/domain/models/civil_date.dart';
import 'package:sembast/sembast_memory.dart' hide Finder;

// UX-008B : empaquetage PWA final — icônes maskable dérivées de l'artwork
// validé, métadonnées/couleurs de marque, version visible, avertissement
// données locales. Architecture de démarrage sanctuarisée.
void main() {
  setUpAll(() async => initializeDateFormatting('fr_FR'));

  int pngWidth(List<int> bytes) =>
      (bytes[16] << 24) | (bytes[17] << 16) | (bytes[18] << 8) | bytes[19];
  int pngHeight(List<int> bytes) =>
      (bytes[20] << 24) | (bytes[21] << 16) | (bytes[22] << 8) | bytes[23];

  group('ICÔNES', () {
    test('maskable : dimensions exactes 192/512', () {
      for (final (path, size) in [
        ('web/icons/Icon-maskable-192.png', 192),
        ('web/icons/Icon-maskable-512.png', 512),
      ]) {
        final bytes = File(path).readAsBytesSync();
        expect(pngWidth(bytes), size, reason: path);
        expect(pngHeight(bytes), size, reason: path);
      }
    });

    testWidgets(
        'maskable 512 : l’artwork VOITURE (rouge + cadre vert), plus le '
        'logo Flutter bleu ; marge blanche sûre pour les masques',
        (tester) async {
      final result = await tester.runAsync(() async {
        final bytes =
            File('web/icons/Icon-maskable-512.png').readAsBytesSync();
        final codec = await ui.instantiateImageCodec(bytes);
        final image = (await codec.getNextFrame()).image;
        final data =
            (await image.toByteData(format: ui.ImageByteFormat.rawRgba))!;
        int red = 0, green = 0, blue = 0;
        bool cornersWhite = true;
        for (var y = 0; y < 512; y += 8) {
          for (var x = 0; x < 512; x += 8) {
            final i = (y * 512 + x) * 4;
            final r = data.getUint8(i),
                g = data.getUint8(i + 1),
                b = data.getUint8(i + 2);
            if (r > 180 && g < 100 && b < 100) red++;
            if (g > 140 && r < 120 && b < 120) green++;
            if (b > 150 && r < 100) blue++;
          }
        }
        for (final (x, y) in [(5, 5), (506, 5), (5, 506), (506, 506)]) {
          final i = (y * 512 + x) * 4;
          if (data.getUint8(i) < 240 ||
              data.getUint8(i + 1) < 240 ||
              data.getUint8(i + 2) < 240) {
            cornersWhite = false;
          }
        }
        return (red, green, blue, cornersWhite);
      });
      final (red, green, blue, cornersWhite) = result!;
      expect(red, greaterThan(20), reason: 'la voiture rouge est présente');
      expect(green, greaterThan(20), reason: 'le cadre vert est présent');
      expect(blue, 0, reason: 'le logo Flutter bleu a disparu');
      expect(cornersWhite, isTrue,
          reason: 'marge blanche : zone sûre maskable');
    });

    test('icônes standard et manifest : références intactes', () {
      final manifest = File('web/manifest.json').readAsStringSync();
      for (final ref in [
        'icons/Icon-192.png',
        'icons/Icon-512.png',
        'icons/Icon-maskable-192.png',
        'icons/Icon-maskable-512.png',
      ]) {
        expect(manifest, contains(ref));
      }
      expect(File('web/favicon.png').existsSync(), isTrue);
      expect(File('web/index.html').readAsStringSync(),
          contains('apple-touch-icon" href="icons/Icon-192.png"'));
    });
  });

  group('MÉTADONNÉES / DÉMARRAGE', () {
    test('manifest : identité Mes Km + couleurs de marque', () {
      final m = File('web/manifest.json').readAsStringSync();
      expect(m, contains('"name": "Mes Km"'));
      expect(m, contains('"short_name": "Mes Km"'));
      expect(m, contains('"display": "standalone"'));
      expect(m, contains('"orientation": "portrait-primary"'));
      expect(m, contains('"lang": "fr"'));
      expect(m, contains('"theme_color": "#1D5BD8"'));
      expect(m, contains('"background_color": "#FBFCFE"'));
    });

    test('index.html : couleurs alignées, architecture de démarrage '
        'SANCTUARISÉE (bootstrap 800 ms, retrait au premier frame)', () {
      final h = File('web/index.html').readAsStringSync();
      expect(h, contains('content="#FBFCFE" media="(prefers-color-scheme: light)"'));
      expect(h, contains('content="#111318" media="(prefers-color-scheme: dark)"'));
      expect(h, contains('background-color: #FBFCFE'));
      expect(h, contains('background-color: #111318'));
      expect(h, contains('color: #1D5BD8'));
      expect(h, isNot(contains('#007AFF')));
      expect(h, isNot(contains('#F9F9FF')));
      // Invariants premier-toucher / démarrage (KM-006C/D) :
      expect(h, contains('timeoutMillis: 800'));
      expect(h, contains('flutter-first-frame'));
      expect(h, contains('splash-pulse'));
      expect(h, isNot(contains('position: fixed;\n      body')));
    });
  });

  group('VERSION', () {
    test('format : « Mes Km 1.0.0 · sha » ; repli propre sans SHA', () {
      expect(versionLine('abc1234'), 'Mes Km 1.0.0 · abc1234');
      expect(versionLine('dev'), 'Mes Km 1.0.0');
      expect(versionLine(''), 'Mes Km 1.0.0');
      expect(File('pubspec.yaml').readAsStringSync(),
          contains('version: 1.0.0+2'));
    });

    testWidgets('Réglages : ligne de version discrète, pas d’écran À '
        'propos ; avertissement données locales en Sauvegarde',
        (tester) async {
      final database = await MesKmDatabase.open(newDatabaseFactoryMemory(),
          name: 'pk.db');
      addTearDown(database.close);
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

      expect(find.text('À propos'), findsNothing);
      await tester.tap(find.text('Réglages'));
      await tester.pumpAndSettle();
      expect(find.textContaining('Mes Km 1.0.0'), findsOneWidget);

      await tester.tap(find.byType(BackButton));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Sauvegarde'));
      await tester.pumpAndSettle();
      expect(
          find.textContaining(
              'Supprimer l’application ou ses données de site'),
          findsOneWidget);
      expect(find.byKey(const Key('create-backup-button')), findsOneWidget);
      expect(find.byKey(const Key('restore-backup-button')), findsOneWidget);
    });
  });
}
