import 'package:flutter_test/flutter_test.dart';
import 'package:mes_km/data/backup/backup_codec.dart';
import 'package:mes_km/data/local/codecs.dart';
import 'package:mes_km/domain/models/app_settings.dart';
import 'package:mes_km/domain/models/vehicle.dart';

// KM-013 : motorisation et classe deux-roues — compatibilité base existante
// et sauvegardes v1/v2 (champs absents = NON RENSEIGNÉ, jamais supposés).
void main() {
  test('aller-retour : motorisation et classe deux-roues conservées', () {
    final vehicle = Vehicle(
      id: 'v-1',
      name: 'BMW R80',
      category: VehicleCategory.twoWheeler,
      fiscalPowerCv: 8,
      motorization: Motorization.other,
      twoWheelerClass: TwoWheelerFiscalClass.motorcycle,
    );
    final decoded = vehicleFromDb('v-1', vehicleToDb(vehicle));
    expect(decoded.motorization, Motorization.other);
    expect(decoded.twoWheelerClass, TwoWheelerFiscalClass.motorcycle);

    final electric = vehicleFromDb(
        'v-2',
        vehicleToDb(Vehicle(
            id: 'v-2',
            name: 'Zoé',
            category: VehicleCategory.car,
            motorization: Motorization.electric)));
    expect(electric.motorization, Motorization.electric);
    expect(electric.twoWheelerClass, isNull);
  });

  test(
      'enregistrement d’avant KM-013 (champs absents) : motorisation NON '
      'RENSEIGNÉE — jamais supposée thermique', () {
    final decoded = vehicleFromDb('v-old', {
      'name': 'Ancienne voiture',
      'category': 'car',
      'fiscalPowerCv': 6,
    });
    expect(decoded.motorization, Motorization.unspecified);
    expect(decoded.twoWheelerClass, isNull);
  });

  test('motorisation non renseignée : champ absent du stockage (schéma v1 '
      'inchangé)', () {
    final map = vehicleToDb(Vehicle(
        id: 'v', name: 'Sans info', category: VehicleCategory.car));
    expect(map.containsKey('motorization'), isFalse);
    expect(map.containsKey('twoWheelerClass'), isFalse);
  });

  test('valeur inconnue : refus explicite (jamais d’à-peu-près)', () {
    expect(
        () => vehicleFromDb('v', {
              'name': 'X',
              'category': 'car',
              'motorization': 'hydrogene-fictif',
            }),
        throwsA(isA<FormatException>()));
    expect(
        () => vehicleFromDb('v', {
              'name': 'X',
              'category': 'twoWheeler',
              'twoWheelerClass': 'trottinette',
            }),
        throwsA(isA<FormatException>()));
  });

  test(
      'sauvegarde v2 (fixture synthétique KM-009) : restaurable, véhicules '
      'migrés SANS motorisation supposée', () {
    const v2Fixture = '''
{
  "schemaVersion": 2,
  "appVersion": "1.0.0",
  "exportedAt": "2026-01-15T10:00:00.000Z",
  "data": {
    "trips": [],
    "dayExtras": [
      {"date": "2026-01-10", "extraKm": 12.0, "vehicleId": "veh-1"}
    ],
    "favoriteTrips": [],
    "vehicles": [
      {"id": "veh-1", "name": "Peugeot 3008", "category": "car",
       "fiscalPowerCv": 6}
    ],
    "vacationPeriods": [],
    "settings": {"mainVehicleId": "veh-1"}
  }
}
''';
    final content = decodeBackup(v2Fixture);
    final vehicle = content.vehicles.single;
    expect(vehicle.name, 'Peugeot 3008');
    expect(vehicle.fiscalPowerCv, 6);
    expect(vehicle.motorization, Motorization.unspecified);
    expect(vehicle.twoWheelerClass, isNull);
    expect(content.dayExtras.single.vehicleId, 'veh-1');
  });

  test('sauvegarde v3 : motorisation exportée et relue', () {
    final json = encodeBackup(
      exportedAt: DateTime.utc(2026, 10, 11),
      trips: const [],
      dayExtras: const [],
      favorites: const [],
      vehicles: [
        Vehicle(
            id: 'veh-e',
            name: 'Zoé',
            category: VehicleCategory.car,
            fiscalPowerCv: 4,
            motorization: Motorization.electric),
        Vehicle(
            id: 'veh-m',
            name: 'Mob',
            category: VehicleCategory.twoWheeler,
            motorization: Motorization.other,
            twoWheelerClass: TwoWheelerFiscalClass.moped),
      ],
      vacationPeriods: const [],
      settings: AppSettings(),
    );
    expect(json, contains('"schemaVersion": 3'));
    final content = decodeBackup(json);
    expect(content.vehicles.first.motorization, Motorization.electric);
    expect(content.vehicles.last.twoWheelerClass,
        TwoWheelerFiscalClass.moped);
  });
}
