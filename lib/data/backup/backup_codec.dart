import 'dart:convert';

import '../../domain/logic/statistics.dart';
import '../../domain/models/app_settings.dart';
import '../../domain/models/civil_date.dart';
import '../../domain/models/day_extra.dart';
import '../../domain/models/favorite_trip.dart';
import '../../domain/models/km.dart';
import '../../domain/models/trip.dart';
import '../../domain/models/vacation_period.dart';
import '../../domain/models/vehicle.dart';
import '../local/codecs.dart';

/// Version du FORMAT de sauvegarde — indépendante du schéma de la base.
/// v2 (KM-009) : DayExtra porte une attribution véhicule figée (vehicleId?).
/// v3 (KM-013) : Vehicle porte motorization et twoWheelerClass (optionnels).
const int backupSchemaVersion = 3;

/// Version applicative embarquée dans l'enveloppe (information).
const String backupAppVersion = '1.0.0';

/// Sauvegarde créée par une version plus récente de Mes Km : refus total,
/// jamais de restauration partielle.
class BackupTooRecentException implements Exception {
  @override
  String toString() =>
      'Cette sauvegarde a été créée avec une version plus récente de Mes Km.';
}

/// Fichier illisible ou invalide (structure, invariants, références…).
class BackupFormatException implements Exception {
  BackupFormatException(this.message);

  final String message;

  @override
  String toString() => message;
}

/// Migrateurs purs v(n-1) -> v(n) appliqués en mémoire avant reconstruction.
/// Les .kmbackup déjà exportés (v1, KM-008) restent restaurables à jamais.
final Map<int, Map<String, Object?> Function(Map<String, Object?>)>
    backupMigrators = {
  // v1 -> v2 : les DayExtra gagnent vehicleId (attribution figée).
  // En v1 le champ n'existait pas ; son absence vaut null — rien d'autre
  // ne change dans l'enveloppe.
  2: (envelope) => envelope,
  // v2 -> v3 : les Vehicle gagnent motorization et twoWheelerClass.
  // Champs absents = motorisation NON RENSEIGNÉE / classe inconnue —
  // jamais de motorisation supposée pour un véhicule migré.
  3: (envelope) => envelope,
};

/// Contenu VALIDÉ d'une sauvegarde : modèles domaine reconstruits
/// (invariants revalidés par les constructeurs) + métadonnées d'aperçu.
/// Aucune écriture n'a eu lieu pour produire cet objet.
class BackupContent {
  BackupContent({
    required this.exportedAt,
    required this.trips,
    required this.dayExtras,
    required this.favorites,
    required this.vehicles,
    required this.vacationPeriods,
    required this.settings,
  });

  final DateTime exportedAt;
  final List<Trip> trips;
  final List<DayExtra> dayExtras;
  final List<FavoriteTrip> favorites;
  final List<Vehicle> vehicles;
  final List<VacationPeriod> vacationPeriods;
  final AppSettings settings;

  Map<CivilDate, double> get _byDay =>
      totalsByDay(trips: trips, extras: dayExtras);

  int get daysWithKm => _byDay.length;

  double get totalKm => sumKm(_byDay.values);

  /// Bornes d'années couvertes par les kilomètres ; null si aucune donnée.
  (int, int)? get yearRange {
    final years = _byDay.keys.map((d) => d.year);
    if (years.isEmpty) return null;
    var min = years.first;
    var max = years.first;
    for (final y in years) {
      if (y < min) min = y;
      if (y > max) max = y;
    }
    return (min, max);
  }
}

/// Encode l'enveloppe de sauvegarde en JSON lisible et déterministe.
String encodeBackup({
  required DateTime exportedAt,
  required List<Trip> trips,
  required List<DayExtra> dayExtras,
  required List<FavoriteTrip> favorites,
  required List<Vehicle> vehicles,
  required List<VacationPeriod> vacationPeriods,
  required AppSettings settings,
}) {
  final envelope = <String, Object?>{
    'schemaVersion': backupSchemaVersion,
    'appVersion': backupAppVersion,
    'exportedAt': exportedAt.toUtc().toIso8601String(),
    'counts': {
      'trips': trips.length,
      'dayExtras': dayExtras.length,
      'favoriteTrips': favorites.length,
      'vehicles': vehicles.length,
      'vacationPeriods': vacationPeriods.length,
    },
    'data': {
      'trips': [
        for (final t in trips) {'id': t.id, ...tripToDb(t)},
      ],
      'dayExtras': [
        for (final e in dayExtras)
          {'date': e.date.toIso8601(), ...dayExtraToDb(e)},
      ],
      'favoriteTrips': [
        for (final f in favorites) {'id': f.id, ...favoriteTripToDb(f)},
      ],
      'vehicles': [
        for (final v in vehicles) {'id': v.id, ...vehicleToDb(v)},
      ],
      'vacationPeriods': [
        for (final p in vacationPeriods)
          {'id': p.id, ...vacationPeriodToDb(p)},
      ],
      'settings': appSettingsToDb(settings),
    },
  };
  return const JsonEncoder.withIndent('  ').convert(envelope);
}

/// Décode + valide une sauvegarde, SANS AUCUNE ÉCRITURE.
///
/// Pipeline : parse JSON -> structure -> schemaVersion (futur = refus) ->
/// migrations en mémoire -> reconstruction domaine (invariants revalidés)
/// -> références et duplications.
BackupContent decodeBackup(String raw) {
  Object? parsed;
  try {
    parsed = jsonDecode(raw);
  } on FormatException {
    throw BackupFormatException(
        'Ce fichier n’est pas une sauvegarde Mes Km lisible.');
  }
  if (parsed is! Map<String, Object?>) {
    throw BackupFormatException(
        'Ce fichier n’est pas une sauvegarde Mes Km.');
  }

  final version = parsed['schemaVersion'];
  if (version is! int) {
    throw BackupFormatException(
        'Sauvegarde invalide : version de format manquante.');
  }
  if (version > backupSchemaVersion) {
    throw BackupTooRecentException();
  }

  var envelope = parsed;
  for (var v = version + 1; v <= backupSchemaVersion; v++) {
    final migrate = backupMigrators[v];
    if (migrate == null) {
      throw BackupFormatException(
          'Sauvegarde invalide : migration v$v indisponible.');
    }
    envelope = migrate(envelope);
  }

  final exportedAtRaw = envelope['exportedAt'];
  final exportedAt =
      exportedAtRaw is String ? DateTime.tryParse(exportedAtRaw) : null;
  if (exportedAt == null) {
    throw BackupFormatException(
        'Sauvegarde invalide : date d’export manquante.');
  }

  final data = envelope['data'];
  if (data is! Map<String, Object?>) {
    throw BackupFormatException('Sauvegarde invalide : données manquantes.');
  }

  List<Map<String, Object?>> section(String name) {
    final value = data[name];
    if (value is! List) {
      throw BackupFormatException(
          'Sauvegarde invalide : section "$name" manquante.');
    }
    return [
      for (final item in value)
        if (item is Map<String, Object?>)
          item
        else
          throw BackupFormatException(
              'Sauvegarde invalide : entrée illisible dans "$name".'),
    ];
  }

  String requireId(Map<String, Object?> map, String sectionName) {
    final id = map['id'];
    if (id is! String || id.trim().isEmpty) {
      throw BackupFormatException(
          'Sauvegarde invalide : identifiant manquant dans "$sectionName".');
    }
    return id;
  }

  T rebuild<T>(String sectionName, T Function() build) {
    try {
      return build();
    } on BackupFormatException {
      rethrow;
    } catch (error) {
      throw BackupFormatException(
          'Sauvegarde invalide ($sectionName) : $error');
    }
  }

  void checkNoDuplicates(Iterable<String> keys, String sectionName) {
    final seen = <String>{};
    for (final key in keys) {
      if (!seen.add(key)) {
        throw BackupFormatException(
            'Sauvegarde invalide : doublon "$key" dans "$sectionName".');
      }
    }
  }

  final vehicles = [
    for (final map in section('vehicles'))
      rebuild('véhicules', () => vehicleFromDb(requireId(map, 'vehicles'), map)),
  ];
  checkNoDuplicates(vehicles.map((v) => v.id), 'vehicles');
  final vehicleIds = {for (final v in vehicles) v.id};

  void checkVehicleRef(String? vehicleId, String sectionName) {
    // Politique : vehicleId nullable (trajet sans véhicule), mais une
    // référence présente doit exister dans la sauvegarde.
    if (vehicleId != null && !vehicleIds.contains(vehicleId)) {
      throw BackupFormatException(
          'Sauvegarde invalide : véhicule inconnu "$vehicleId" '
          'référencé dans "$sectionName".');
    }
  }

  final trips = [
    for (final map in section('trips'))
      rebuild('trajets', () => tripFromDb(requireId(map, 'trips'), map)),
  ];
  checkNoDuplicates(trips.map((t) => t.id), 'trips');
  for (final trip in trips) {
    checkVehicleRef(trip.vehicleId, 'trips');
  }

  final dayExtras = [
    for (final map in section('dayExtras'))
      rebuild('kilomètres non détaillés', () {
        final date = map['date'];
        if (date is! String) {
          throw BackupFormatException(
              'Sauvegarde invalide : date manquante dans "dayExtras".');
        }
        return dayExtraFromDb(date, map);
      }),
  ];
  checkNoDuplicates(
      dayExtras.map((e) => e.date.toIso8601()), 'dayExtras');
  for (final extra in dayExtras) {
    checkVehicleRef(extra.vehicleId, 'dayExtras');
  }

  final favorites = [
    for (final map in section('favoriteTrips'))
      rebuild('favoris',
          () => favoriteTripFromDb(requireId(map, 'favoriteTrips'), map)),
  ];
  checkNoDuplicates(favorites.map((f) => f.id), 'favoriteTrips');
  for (final favorite in favorites) {
    checkVehicleRef(favorite.vehicleId, 'favoriteTrips');
  }

  final vacationPeriods = [
    for (final map in section('vacationPeriods'))
      rebuild('congés',
          () => vacationPeriodFromDb(requireId(map, 'vacationPeriods'), map)),
  ];
  checkNoDuplicates(vacationPeriods.map((p) => p.id), 'vacationPeriods');

  final settingsMap = data['settings'];
  if (settingsMap is! Map<String, Object?>) {
    throw BackupFormatException(
        'Sauvegarde invalide : réglages manquants.');
  }
  final settings =
      rebuild('réglages', () => appSettingsFromDb(settingsMap));
  checkVehicleRef(settings.mainVehicleId, 'settings');

  return BackupContent(
    exportedAt: exportedAt,
    trips: trips,
    dayExtras: dayExtras,
    favorites: favorites,
    vehicles: vehicles,
    vacationPeriods: vacationPeriods,
    settings: settings,
  );
}
