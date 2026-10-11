import 'package:flutter_test/flutter_test.dart';
import 'package:mes_km/domain/models/civil_date.dart';
import 'package:mes_km/domain/models/day_extra.dart';
import 'package:mes_km/domain/models/favorite_trip.dart';
import 'package:mes_km/domain/models/trip.dart';
import 'package:mes_km/domain/models/vacation_period.dart';
import 'package:mes_km/domain/models/vehicle.dart';

import 'helpers.dart';

void main() {
  final day = CivilDate(2026, 10, 11);

  group('Trip', () {
    test('distance 0 refusée', () {
      expect(() => makeTrip(km: 0), throwsArgumentError);
    });

    test('distance négative refusée', () {
      expect(() => makeTrip(km: -5), throwsArgumentError);
    });

    test('distance arrondie à 0 au dixième refusée', () {
      expect(() => makeTrip(km: 0.04), throwsArgumentError);
    });

    test('id vide refusé', () {
      expect(() => makeTrip(id: '  '), throwsArgumentError);
    });

    test('textes facultatifs nettoyés (trim, vide => null)', () {
      final trip = Trip(
        id: 't',
        date: day,
        distanceKm: 10,
        origin: '  Maison  ',
        destination: '   ',
        createdAt: DateTime(2026, 1, 1),
      );
      expect(trip.origin, 'Maison');
      expect(trip.destination, isNull);
    });

    test('distance canonisée au dixième', () {
      expect(makeTrip(km: 12.34).distanceKm, 12.3);
      expect(makeTrip(km: 12.35).distanceKm, 12.4);
    });
  });

  group('DayExtra', () {
    test('valeur négative refusée', () {
      expect(
        () => DayExtra(date: day, extraKm: -0.1),
        throwsArgumentError,
      );
    });

    test('vehicleId nullable, nettoyé (attribution figée)', () {
      final withVehicle =
          DayExtra(date: day, extraKm: 33, vehicleId: '  peugeot  ');
      expect(withVehicle.vehicleId, 'peugeot');
      expect(DayExtra(date: day, extraKm: 33).vehicleId, isNull);
      expect(DayExtra(date: day, extraKm: 33, vehicleId: '  ').vehicleId,
          isNull);
    });

    test('0 = absence logique', () {
      expect(DayExtra(date: day, extraKm: 0).isNone, isTrue);
      expect(DayExtra(date: day, extraKm: 5).isNone, isFalse);
    });
  });

  group('FavoriteTrip', () {
    FavoriteTrip makeFavorite({
      String label = 'Bureau',
      double km = 24,
      bool defaultRoundTrip = false,
      int sortOrder = 0,
    }) {
      return FavoriteTrip(
        id: 'fav-1',
        label: label,
        distanceKm: km,
        defaultRoundTrip: defaultRoundTrip,
        sortOrder: sortOrder,
      );
    }

    test('label vide après trim refusé', () {
      expect(() => makeFavorite(label: '   '), throwsArgumentError);
    });

    test('distance invalide refusée', () {
      expect(() => makeFavorite(km: 0), throwsArgumentError);
      expect(() => makeFavorite(km: -3), throwsArgumentError);
    });

    test('sortOrder négatif refusé', () {
      expect(() => makeFavorite(sortOrder: -1), throwsArgumentError);
    });

    test(
        'sémantique V2 : distanceKm EST la distance comptabilisée ; '
        'defaultRoundTrip est une métadonnée sans doublement', () {
      final favorite = makeFavorite(km: 24, defaultRoundTrip: true);

      // 24 est la distance totale ajoutée à chaque utilisation, A/R ou non.
      expect(favorite.distanceKm, 24);
      expect(favorite.defaultRoundTrip, isTrue);
      expect(makeFavorite(km: 24).distanceKm, 24);
    });
  });

  group('Vehicle', () {
    test('name vide refusé', () {
      expect(
        () => Vehicle(id: 'v', name: '  ', category: VehicleCategory.car),
        throwsArgumentError,
      );
    });

    test('fiscalPowerCv invalide refusé', () {
      expect(
        () => Vehicle(
          id: 'v',
          name: 'Clio',
          category: VehicleCategory.car,
          fiscalPowerCv: 0,
        ),
        throwsArgumentError,
      );
      expect(
        () => Vehicle(
          id: 'v',
          name: 'Clio',
          category: VehicleCategory.car,
          fiscalPowerCv: -4,
        ),
        throwsArgumentError,
      );
    });

    test('fiscalPowerCv facultatif accepté', () {
      final vehicle =
          Vehicle(id: 'v', name: 'Clio', category: VehicleCategory.car);
      expect(vehicle.fiscalPowerCv, isNull);
    });

    test('archivage : copie archivée, id et références intacts', () {
      final vehicle = Vehicle(
        id: 'v-1',
        name: 'Clio',
        category: VehicleCategory.car,
        fiscalPowerCv: 5,
      );
      final archived = vehicle.archived(DateTime(2026, 6, 1));

      expect(vehicle.isArchived, isFalse);
      expect(archived.isArchived, isTrue);
      expect(archived.id, 'v-1');
      expect(archived.name, 'Clio');
      expect(archived.fiscalPowerCv, 5);
    });
  });

  group('VacationPeriod', () {
    test('période inversée refusée', () {
      expect(
        () => VacationPeriod(
          id: 'p',
          startDate: CivilDate(2026, 8, 10),
          endDate: CivilDate(2026, 8, 1),
        ),
        throwsArgumentError,
      );
    });

    test('jour unique valide, bornes incluses', () {
      final period = VacationPeriod(
        id: 'p',
        startDate: CivilDate(2026, 8, 5),
        endDate: CivilDate(2026, 8, 5),
      );
      expect(period.contains(CivilDate(2026, 8, 5)), isTrue);
      expect(period.contains(CivilDate(2026, 8, 4)), isFalse);
      expect(period.contains(CivilDate(2026, 8, 6)), isFalse);
    });
  });
}
