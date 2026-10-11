import 'package:sembast_web/sembast_web.dart';

import 'app_database.dart';

/// Ouverture de la base Mes Km sur la cible Web/PWA (IndexedDB).
///
/// Seul fichier de la couche données qui connaisse la plateforme Web :
/// il n'est importé que par le bootstrap Web de l'application. Un futur
/// adaptateur iOS natif fournira son propre `open…` (par ex. sembast_io)
/// sans toucher aux repositories ni au domaine.
Future<MesKmDatabase> openMesKmDatabaseWeb({
  String name = MesKmDatabase.defaultName,
}) =>
    MesKmDatabase.open(databaseFactoryWeb, name: name);
