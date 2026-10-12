import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

// UX-008C : preuve automatisée du shell hors ligne sur le BUILD GÉNÉRÉ
// (pas seulement les sources). Limite honnête : ces tests vérifient la
// cohérence précache/navigation du build ; ils ne simulent PAS iOS —
// l'autorité finale reste la recette iPhone hors ligne.
void main() {
  const root = 'build/web';

  test(
      'build généré : sw.js précache un shell COMPLET et cohérent, la '
      'navigation retombe sur le shell, start_url/scope/base alignés', () {
    if (!File('$root/index.html').existsSync() ||
        !File('$root/sw.js').existsSync()) {
      markTestSkipped(
          'Build absent — exécuter d’abord : tool/build_web.sh');
      return;
    }

    final sw = File('$root/sw.js').readAsStringSync();

    // 1) Liste de précache extraite et parsée réellement.
    final match =
        RegExp(r'const PRECACHE = (\[[\s\S]*?\]);').firstMatch(sw);
    expect(match, isNotNull, reason: 'liste PRECACHE présente');
    final precache =
        (jsonDecode(match!.group(1)!) as List).cast<String>();

    // Le shell indispensable au démarrage hors ligne.
    for (final required in [
      '/',
      '/index.html',
      '/flutter_bootstrap.js',
      '/main.dart.js',
      '/manifest.json',
      '/canvaskit/canvaskit.wasm',
      '/assets/assets/fonts/Inter-Regular.ttf',
      '/assets/assets/brand/meskm-logo.png',
      '/assets/assets/fiscal/bareme-revenus-2025.json',
      '/assets/AssetManifest.bin',
      '/icons/Icon-192.png',
    ]) {
      expect(precache, contains(required), reason: required);
    }

    // 2) Chaque entrée précachée existe réellement dans le build :
    //    un addAll échouerait sinon, et le SW ne s'installerait jamais.
    for (final entry in precache.where((e) => e != '/')) {
      expect(File('$root$entry').existsSync(), isTrue,
          reason: 'fichier manquant pour le précache : $entry');
    }

    // Le désinstalleur Flutter n'est jamais précaché ni enregistré.
    expect(precache, isNot(contains('/flutter_service_worker.js')));

    // 3) Navigation : réseau d'abord, repli sur le shell caché « / ».
    expect(sw, contains("req.mode === 'navigate'"));
    expect(sw, contains("caches.match('/'"));
    // 4) Aucune dépendance réseau obligatoire au bootstrap : pas de
    //    skipWaiting sauvage, cache versionné par build.
    expect(sw, isNot(contains('self.skipWaiting')));
    expect(sw, contains("CACHE_NAME = 'meskm-shell-'"));

    // 5) Cohérence start_url / base / scope : sw.js servi À LA RACINE
    //    (scope « / » par défaut), base href « / », start_url « . ».
    final builtIndex = File('$root/index.html').readAsStringSync();
    expect(builtIndex, contains('<base href="/">'));
    // UX-008D : CanvasKit LOCAL (le défaut Flutter charge le renderer
    // depuis gstatic => écran de démarrage éternel hors ligne).
    expect(builtIndex, contains('"useLocalCanvasKit":true'));
    expect(builtIndex, contains("serviceWorker.register('sw.js')"));
    // Le loader minifié contient le mot dans son API : l'invariant
    // réel est l'appel NU (aucune serviceWorkerVersion injectée).
    expect(builtIndex, contains('_flutter.loader.load();'));
    expect(builtIndex, isNot(contains('serviceWorkerVersion: "')),
        reason: 'le désinstalleur Flutter ne doit plus être enregistré');
    final manifest = File('$root/manifest.json').readAsStringSync();
    expect(manifest, contains('"start_url": "."'));
  });

  test('générateur : un build identifié intègre son BUILD_ID', () {
    if (!File('$root/sw.js').existsSync()) {
      markTestSkipped('Build absent.');
      return;
    }
    final sw = File('$root/sw.js').readAsStringSync();
    final id =
        RegExp(r"const BUILD_ID = '([^']+)';").firstMatch(sw)?.group(1);
    expect(id, isNotNull);
    expect(id, isNotEmpty);
  });
}
