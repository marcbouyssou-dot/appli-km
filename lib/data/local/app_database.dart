import 'package:sembast/sembast.dart';

/// Base locale de Mes Km (sembast).
///
/// La technologie concrète (IndexedDB via sembast_web, fichier via
/// sembast_io plus tard) est fournie par la [DatabaseFactory] passée à
/// [open] : ce fichier n'importe aucune API Web.
class MesKmDatabase {
  MesKmDatabase._(this.db);

  /// Version du schéma de stockage. Incrémentée à chaque évolution,
  /// accompagnée d'une entrée dans [_migrations].
  static const int schemaVersion = 1;

  static const String defaultName = 'mes_km.db';

  /// Migrations v(n-1) -> v(n), exécutées en séquence à l'ouverture.
  /// v1 est la création initiale : les stores sembast sont implicites,
  /// aucune action nécessaire.
  static final Map<int, Future<void> Function(Database db)> _migrations = {};

  final Database db;

  static Future<MesKmDatabase> open(
    DatabaseFactory factory, {
    String name = defaultName,
  }) async {
    final db = await factory.openDatabase(
      name,
      version: schemaVersion,
      onVersionChanged: (db, oldVersion, newVersion) async {
        if (oldVersion > newVersion) {
          throw StateError(
            'Base de données plus récente (v$oldVersion) que cette version '
            'de l’application (v$newVersion) : ouverture refusée pour '
            'ne pas corrompre les données.',
          );
        }
        for (var v = oldVersion + 1; v <= newVersion; v++) {
          await _migrations[v]?.call(db);
        }
      },
    );
    return MesKmDatabase._(db);
  }

  int get version => db.version;

  Future<void> close() => db.close();
}

/// Stores du schéma v1. Les clés sont des String :
/// - trips / favorite_trips / vehicles / vacation_periods : id (UUID) ;
/// - day_extras : la date civile `yyyy-MM-dd` (au plus un par jour) ;
/// - settings : enregistrement unique [settingsRecordKey].
final tripsStore = stringMapStoreFactory.store('trips');
final dayExtrasStore = stringMapStoreFactory.store('day_extras');
final favoriteTripsStore = stringMapStoreFactory.store('favorite_trips');
final vehiclesStore = stringMapStoreFactory.store('vehicles');
final vacationPeriodsStore = stringMapStoreFactory.store('vacation_periods');
final settingsStore = stringMapStoreFactory.store('settings');

const String settingsRecordKey = 'app';
