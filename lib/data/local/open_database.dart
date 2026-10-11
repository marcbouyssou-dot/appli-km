import 'app_database.dart';
import 'open_database_stub.dart'
    if (dart.library.js_interop) 'open_database_web.dart' as impl;

/// Ouvre la base locale avec l'adaptateur de la plateforme courante.
/// Le reste de l'application ne connaît jamais la technologie sous-jacente.
Future<MesKmDatabase> openMesKmDatabase() => impl.openPlatformDatabase();
