import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'app.dart';
import 'app/providers.dart';
import 'data/fiscal/fiscal_reference_store.dart';
import 'data/local/app_database.dart';
import 'data/local/open_database.dart';

Future<void> main() async {
  final startup = Stopwatch()..start();
  WidgetsFlutterBinding.ensureInitialized();

  try {
    // Locale, base locale et référentiels fiscaux (assets locaux) en
    // parallèle : rien ne sérialise le bootstrap.
    late final MesKmDatabase database;
    late final FiscalReferenceStore fiscalStore;
    await Future.wait([
      initializeDateFormatting('fr_FR'),
      openMesKmDatabase().then((db) => database = db),
      loadFiscalReferenceStore().then((store) => fiscalStore = store),
    ]);
    _logStartup(startup, 'locale + base locale prêtes');

    runApp(
      ProviderScope(
        overrides: [
          databaseProvider.overrideWithValue(database),
          fiscalReferenceStoreProvider.overrideWithValue(fiscalStore),
        ],
        child: const MesKmApp(),
      ),
    );
    WidgetsBinding.instance.addPostFrameCallback(
      (_) => _logStartup(startup, 'premier frame Flutter'),
    );
  } catch (error) {
    runApp(StorageErrorApp(message: '$error'));
  }
}

/// Instrumentation de démarrage, debug uniquement (aucune télémétrie).
void _logStartup(Stopwatch watch, String step) {
  if (kDebugMode) {
    debugPrint('[startup] ${watch.elapsedMilliseconds} ms — $step');
  }
}
