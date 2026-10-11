import 'app_database.dart';
import 'web_database.dart';

/// Cible Web/PWA : IndexedDB via sembast_web.
Future<MesKmDatabase> openPlatformDatabase() => openMesKmDatabaseWeb();
