import 'app_database.dart';

/// Plateformes sans adaptateur de stockage (iOS/desktop natifs pour
/// l'instant) : l'application compile mais refuse explicitement de démarrer.
/// Un futur lot fournira l'adaptateur natif (par ex. sembast_io) ici.
Future<MesKmDatabase> openPlatformDatabase() async {
  throw UnsupportedError(
    'Aucun adaptateur de stockage pour cette plateforme. '
    'Mes Km V2 est actuellement distribué en PWA.',
  );
}
