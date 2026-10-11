import '../../domain/models/app_settings.dart';
import '../../domain/models/civil_date.dart';
import '../../domain/models/day_extra.dart';
import '../../domain/models/favorite_trip.dart';
import '../../domain/models/trip.dart';
import '../../domain/models/vacation_period.dart';
import '../../domain/models/vehicle.dart';

/// Représentation persistée des modèles du domaine (schéma v1).
///
/// Principes :
/// - les dates civiles sont stockées en `yyyy-MM-dd` (stable, triable) ;
/// - les instants (createdAt, archivedAt) en ISO 8601 UTC ;
/// - les kilomètres en double, déjà canonisés par le domaine (round-trip
///   sans perte) ;
/// - les enums en chaîne stable (versionnable : une valeur inconnue est
///   refusée explicitement, à migrer le cas échéant) ;
/// - les champs optionnels absents de la map quand ils sont null.
///
/// Cette représentation n'est PAS le modèle domaine : toute relecture passe
/// par les constructeurs du domaine, qui revalident les invariants. Une
/// donnée stockée invalide est donc refusée avec une erreur explicite.

String _requireString(Map<String, Object?> map, String field) {
  final value = map[field];
  if (value is! String) {
    throw FormatException('Champ "$field" manquant ou invalide : $map');
  }
  return value;
}

double _requireDouble(Map<String, Object?> map, String field) {
  final value = map[field];
  if (value is! num) {
    throw FormatException('Champ "$field" manquant ou invalide : $map');
  }
  return value.toDouble();
}

DateTime _requireUtcInstant(Map<String, Object?> map, String field) =>
    DateTime.parse(_requireString(map, field));

// ---------------------------------------------------------------------------
// Trip
// ---------------------------------------------------------------------------

Map<String, Object?> tripToDb(Trip trip) => {
      'date': trip.date.toIso8601(),
      'distanceKm': trip.distanceKm,
      'isRoundTrip': trip.isRoundTrip,
      if (trip.origin != null) 'origin': trip.origin,
      if (trip.destination != null) 'destination': trip.destination,
      if (trip.purpose != null) 'purpose': trip.purpose,
      if (trip.vehicleId != null) 'vehicleId': trip.vehicleId,
      'createdAt': trip.createdAt.toUtc().toIso8601String(),
    };

Trip tripFromDb(String id, Map<String, Object?> map) => Trip(
      id: id,
      date: CivilDate.parse(_requireString(map, 'date')),
      distanceKm: _requireDouble(map, 'distanceKm'),
      isRoundTrip: map['isRoundTrip'] == true,
      origin: map['origin'] as String?,
      destination: map['destination'] as String?,
      purpose: map['purpose'] as String?,
      vehicleId: map['vehicleId'] as String?,
      createdAt: _requireUtcInstant(map, 'createdAt'),
    );

// ---------------------------------------------------------------------------
// DayExtra (clé du store = date yyyy-MM-dd)
// ---------------------------------------------------------------------------

Map<String, Object?> dayExtraToDb(DayExtra extra) => {
      'extraKm': extra.extraKm,
      if (extra.vehicleId != null) 'vehicleId': extra.vehicleId,
      if (extra.note != null) 'note': extra.note,
    };

/// Les enregistrements antérieurs à KM-009 n'ont pas de champ vehicleId :
/// l'absence vaut null — aucune migration de base nécessaire (lecture
/// compatible, schéma sembast inchangé en v1).
DayExtra dayExtraFromDb(String dateKey, Map<String, Object?> map) => DayExtra(
      date: CivilDate.parse(dateKey),
      extraKm: _requireDouble(map, 'extraKm'),
      vehicleId: map['vehicleId'] as String?,
      note: map['note'] as String?,
    );

// ---------------------------------------------------------------------------
// FavoriteTrip
// ---------------------------------------------------------------------------

Map<String, Object?> favoriteTripToDb(FavoriteTrip favorite) => {
      'label': favorite.label,
      'distanceKm': favorite.distanceKm,
      'defaultRoundTrip': favorite.defaultRoundTrip,
      if (favorite.origin != null) 'origin': favorite.origin,
      if (favorite.destination != null) 'destination': favorite.destination,
      if (favorite.purpose != null) 'purpose': favorite.purpose,
      if (favorite.vehicleId != null) 'vehicleId': favorite.vehicleId,
      'sortOrder': favorite.sortOrder,
    };

FavoriteTrip favoriteTripFromDb(String id, Map<String, Object?> map) {
  final sortOrder = map['sortOrder'];
  if (sortOrder is! int) {
    throw FormatException('Champ "sortOrder" manquant ou invalide : $map');
  }
  return FavoriteTrip(
    id: id,
    label: _requireString(map, 'label'),
    distanceKm: _requireDouble(map, 'distanceKm'),
    defaultRoundTrip: map['defaultRoundTrip'] == true,
    origin: map['origin'] as String?,
    destination: map['destination'] as String?,
    purpose: map['purpose'] as String?,
    vehicleId: map['vehicleId'] as String?,
    sortOrder: sortOrder,
  );
}

// ---------------------------------------------------------------------------
// Vehicle
// ---------------------------------------------------------------------------

String vehicleCategoryToDb(VehicleCategory category) => switch (category) {
      VehicleCategory.car => 'car',
      VehicleCategory.twoWheeler => 'twoWheeler',
    };

VehicleCategory vehicleCategoryFromDb(String value) => switch (value) {
      'car' => VehicleCategory.car,
      'twoWheeler' => VehicleCategory.twoWheeler,
      _ => throw FormatException('Catégorie de véhicule inconnue : "$value"'),
    };

String? motorizationToDb(Motorization motorization) => switch (motorization) {
      Motorization.electric => 'electric',
      Motorization.other => 'other',
      Motorization.unspecified => null,
    };

/// Champ absent (véhicules d'avant KM-013) = motorisation NON RENSEIGNÉE :
/// on ne suppose jamais qu'un ancien véhicule est thermique.
Motorization motorizationFromDb(Object? value) => switch (value) {
      null => Motorization.unspecified,
      'electric' => Motorization.electric,
      'other' => Motorization.other,
      _ => throw FormatException('Motorisation inconnue : "$value"'),
    };

String? twoWheelerClassToDb(TwoWheelerFiscalClass? twoWheelerClass) =>
    switch (twoWheelerClass) {
      null => null,
      TwoWheelerFiscalClass.motorcycle => 'motorcycle',
      TwoWheelerFiscalClass.moped => 'moped',
    };

TwoWheelerFiscalClass? twoWheelerClassFromDb(Object? value) => switch (value) {
      null => null,
      'motorcycle' => TwoWheelerFiscalClass.motorcycle,
      'moped' => TwoWheelerFiscalClass.moped,
      _ => throw FormatException('Classe deux-roues inconnue : "$value"'),
    };

Map<String, Object?> vehicleToDb(Vehicle vehicle) => {
      'name': vehicle.name,
      'category': vehicleCategoryToDb(vehicle.category),
      if (vehicle.fiscalPowerCv != null)
        'fiscalPowerCv': vehicle.fiscalPowerCv,
      if (vehicle.registration != null) 'registration': vehicle.registration,
      if (motorizationToDb(vehicle.motorization) != null)
        'motorization': motorizationToDb(vehicle.motorization),
      if (vehicle.twoWheelerClass != null)
        'twoWheelerClass': twoWheelerClassToDb(vehicle.twoWheelerClass),
      if (vehicle.archivedAt != null)
        'archivedAt': vehicle.archivedAt!.toUtc().toIso8601String(),
    };

Vehicle vehicleFromDb(String id, Map<String, Object?> map) => Vehicle(
      id: id,
      name: _requireString(map, 'name'),
      category: vehicleCategoryFromDb(_requireString(map, 'category')),
      fiscalPowerCv: map['fiscalPowerCv'] as int?,
      registration: map['registration'] as String?,
      motorization: motorizationFromDb(map['motorization']),
      twoWheelerClass: twoWheelerClassFromDb(map['twoWheelerClass']),
      archivedAt: map['archivedAt'] is String
          ? DateTime.parse(map['archivedAt'] as String)
          : null,
    );

// ---------------------------------------------------------------------------
// VacationPeriod
// ---------------------------------------------------------------------------

Map<String, Object?> vacationPeriodToDb(VacationPeriod period) => {
      'startDate': period.startDate.toIso8601(),
      'endDate': period.endDate.toIso8601(),
      if (period.label != null) 'label': period.label,
    };

VacationPeriod vacationPeriodFromDb(String id, Map<String, Object?> map) =>
    VacationPeriod(
      id: id,
      startDate: CivilDate.parse(_requireString(map, 'startDate')),
      endDate: CivilDate.parse(_requireString(map, 'endDate')),
      label: map['label'] as String?,
    );

// ---------------------------------------------------------------------------
// AppSettings
// ---------------------------------------------------------------------------

String themePreferenceToDb(ThemePreference preference) =>
    switch (preference) {
      ThemePreference.system => 'system',
      ThemePreference.light => 'light',
      ThemePreference.dark => 'dark',
    };

ThemePreference themePreferenceFromDb(String value) => switch (value) {
      'system' => ThemePreference.system,
      'light' => ThemePreference.light,
      'dark' => ThemePreference.dark,
      _ => throw FormatException('Préférence de thème inconnue : "$value"'),
    };

Map<String, Object?> appSettingsToDb(AppSettings settings) => {
      if (settings.displayName != null) 'displayName': settings.displayName,
      if (settings.address != null) 'address': settings.address,
      if (settings.city != null) 'city': settings.city,
      if (settings.documentRecipientName != null)
        'documentRecipientName': settings.documentRecipientName,
      if (settings.documentRecipientAddress != null)
        'documentRecipientAddress': settings.documentRecipientAddress,
      if (settings.mainVehicleId != null)
        'mainVehicleId': settings.mainVehicleId,
      'themePreference': themePreferenceToDb(settings.themePreference),
    };

AppSettings appSettingsFromDb(Map<String, Object?> map) => AppSettings(
      displayName: map['displayName'] as String?,
      address: map['address'] as String?,
      city: map['city'] as String?,
      documentRecipientName: map['documentRecipientName'] as String?,
      documentRecipientAddress: map['documentRecipientAddress'] as String?,
      mainVehicleId: map['mainVehicleId'] as String?,
      themePreference: map['themePreference'] is String
          ? themePreferenceFromDb(map['themePreference'] as String)
          : ThemePreference.system,
    );
