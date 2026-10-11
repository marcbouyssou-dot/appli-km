import 'package:flutter_test/flutter_test.dart';
import 'package:mes_km/domain/models/app_settings.dart';
import 'package:mes_km/domain/models/civil_date.dart';
import 'package:mes_km/domain/models/day_extra.dart';
import 'package:mes_km/domain/models/trip.dart';
import 'package:mes_km/domain/models/vacation_period.dart';
import 'package:mes_km/domain/models/vehicle.dart';
import 'package:mes_km/features/documents/report_data.dart';

// Relevé annuel : modèle intermédiaire PUR (KM-012).
// Fixtures 100 % synthétiques — aucune donnée réelle.
void main() {
  final generatedAt = DateTime(2026, 10, 11, 14, 30);
  final settings = AppSettings(
    displayName: 'Marc Infirmier',
    address: '12 rue des Lilas',
    city: '19700 Seilhac',
  );

  Trip trip(
    String id,
    CivilDate date,
    double km, {
    String? vehicleId,
    String? origin,
    String? destination,
    String? purpose,
    bool isRoundTrip = false,
    int hour = 9,
  }) =>
      Trip(
        id: id,
        date: date,
        distanceKm: km,
        vehicleId: vehicleId,
        origin: origin,
        destination: destination,
        purpose: purpose,
        isRoundTrip: isRoundTrip,
        createdAt:
            DateTime.utc(date.year, date.month, date.day, hour),
      );

  final peugeot = Vehicle(
    id: 'peugeot',
    name: 'Peugeot 208',
    category: VehicleCategory.car,
    registration: 'AB-123-CD',
    fiscalPowerCv: 5,
  );
  final clio = Vehicle(
    id: 'clio',
    name: 'Clio (archivée)',
    category: VehicleCategory.car,
    archivedAt: DateTime.utc(2026, 6, 1),
  );

  AnnualReportData build({
    List<Trip> trips = const [],
    List<DayExtra> extras = const [],
    List<Vehicle> vehicles = const [],
    List<VacationPeriod> vacations = const [],
  }) =>
      buildAnnualReportData(
        year: 2026,
        generatedAt: generatedAt,
        trips: trips,
        extras: extras,
        vehicles: vehicles,
        vacations: vacations,
        settings: settings,
      );

  test('année vide : relevé propre, aucun total fantôme', () {
    final report = build();
    expect(report.isEmpty, isTrue);
    expect(report.totalKm, 0);
    expect(report.monthlyTotals, List.filled(12, 0.0));
    expect(report.activeDays, 0);
    expect(report.averagePerActiveDay, 0);
    expect(report.vehicles, isEmpty);
    expect(report.vacationPeriods, isEmpty);
    expect(report.lines, isEmpty);
  });

  test('identité : reprise des réglages existants', () {
    final report = build();
    expect(report.year, 2026);
    expect(report.displayName, 'Marc Infirmier');
    expect(report.address, '12 rue des Lilas');
    expect(report.city, '19700 Seilhac');
    expect(report.generatedAt, generatedAt);
  });

  test('totaux : annuel, 12 mois, jours actifs, moyenne', () {
    final report = build(
      trips: [
        trip('t1', CivilDate(2026, 1, 5), 42),
        trip('t2', CivilDate(2026, 1, 5), 8, hour: 11),
        trip('t3', CivilDate(2026, 3, 17), 87),
      ],
      extras: [
        DayExtra(date: CivilDate(2026, 1, 5), extraKm: 10),
        DayExtra(date: CivilDate(2026, 12, 31), extraKm: 33),
      ],
    );
    expect(report.totalKm, 180);
    expect(report.monthlyTotals, hasLength(12));
    expect(report.monthlyTotals[0], 60); // janvier
    expect(report.monthlyTotals[2], 87); // mars
    expect(report.monthlyTotals[11], 33); // décembre
    expect(report.monthlyTotals[5], 0);
    expect(report.activeDays, 3);
    expect(report.averagePerActiveDay, 60);
  });

  test(
      'véhicules : tri décroissant, archivé inclus, « sans véhicule » en '
      'dernier, zéro masqué', () {
    final report = build(
      vehicles: [peugeot, clio],
      trips: [
        trip('t1', CivilDate(2026, 2, 1), 50, vehicleId: 'clio'),
        trip('t2', CivilDate(2026, 2, 2), 200, vehicleId: 'peugeot'),
        trip('t3', CivilDate(2026, 2, 3), 12), // sans véhicule
      ],
      extras: [
        DayExtra(
            date: CivilDate(2026, 2, 4), extraKm: 30, vehicleId: 'peugeot'),
      ],
    );
    expect(report.vehicles.map((v) => v.label).toList(), [
      'Peugeot 208',
      'Clio (archivée)',
      'Sans véhicule renseigné',
    ]);
    expect(report.vehicles[0].totalKm, 230);
    expect(report.vehicles[0].registration, 'AB-123-CD');
    expect(report.vehicles[0].fiscalPowerCv, 5);
    expect(report.vehicles[1].totalKm, 50);
    expect(report.vehicles[2].vehicleId, isNull);
    expect(report.vehicles[2].totalKm, 12);
  });

  test('véhicule référencé mais absent : « Véhicule inconnu », km conservés',
      () {
    final report = build(
      trips: [trip('t1', CivilDate(2026, 4, 1), 25, vehicleId: 'fantome')],
    );
    expect(report.vehicles.single.label, 'Véhicule inconnu');
    expect(report.vehicles.single.totalKm, 25);
    expect(report.lines.single.vehicleLabel, 'Véhicule inconnu');
  });

  test('congés : rognés aux bornes de l’année, triés, hors-année exclus',
      () {
    final report = build(
      trips: [trip('t1', CivilDate(2026, 7, 1), 10)],
      vacations: [
        // Chevauche le nouvel an : rognée au 1er janvier.
        VacationPeriod(
            id: 'p1',
            startDate: CivilDate(2025, 12, 28),
            endDate: CivilDate(2026, 1, 4)),
        VacationPeriod(
            id: 'p2',
            startDate: CivilDate(2026, 8, 3),
            endDate: CivilDate(2026, 8, 10)),
        // Chevauche la fin d'année : rognée au 31 décembre.
        VacationPeriod(
            id: 'p3',
            startDate: CivilDate(2026, 12, 30),
            endDate: CivilDate(2027, 1, 5)),
        // Entièrement hors année : exclue.
        VacationPeriod(
            id: 'p4',
            startDate: CivilDate(2025, 2, 1),
            endDate: CivilDate(2025, 2, 10)),
      ],
    );
    expect(report.vacationPeriods, [
      (CivilDate(2026, 1, 1), CivilDate(2026, 1, 4)),
      (CivilDate(2026, 8, 3), CivilDate(2026, 8, 10)),
      (CivilDate(2026, 12, 30), CivilDate(2026, 12, 31)),
    ]);
  });

  test(
      'détail : ordre chronologique strict, trajets par création puis '
      '« non détaillé » de la journée', () {
    final report = build(
      trips: [
        trip('t-mars', CivilDate(2026, 3, 1), 30),
        trip('t-jan-tard', CivilDate(2026, 1, 10), 20, hour: 15,
            origin: 'Maison', destination: 'Cabinet'),
        trip('t-jan-tot', CivilDate(2026, 1, 10), 10, hour: 8),
      ],
      extras: [
        DayExtra(date: CivilDate(2026, 1, 10), extraKm: 5),
        DayExtra(date: CivilDate(2026, 2, 2), extraKm: 7),
      ],
    );
    expect(
      report.lines
          .map((l) => '${l.date.toIso8601()}:${l.km}:${l.isDetailedTrip}')
          .toList(),
      [
        '2026-01-10:10.0:true',
        '2026-01-10:20.0:true',
        '2026-01-10:5.0:false',
        '2026-02-02:7.0:false',
        '2026-03-01:30.0:true',
      ],
    );
    expect(report.lines[1].origin, 'Maison');
    expect(report.lines[1].destination, 'Cabinet');
    expect(report.lines[2].origin, isNull, reason: 'non détaillé : pas d’adresse');
  });

  test('INVARIANT : somme des lignes = total annuel (valeurs à 0,1 près)',
      () {
    final report = build(
      trips: [
        for (var d = 1; d <= 28; d++)
          trip('t$d', CivilDate(2026, 5, d), 10.3 + d * 0.1),
      ],
      extras: [
        DayExtra(date: CivilDate(2026, 5, 3), extraKm: 4.7),
        DayExtra(date: CivilDate(2026, 11, 20), extraKm: 0.1),
      ],
    );
    expect(reportLinesTotalKm(report), report.totalKm,
        reason: 'chaque kilomètre doit apparaître exactement une fois');
    expect(report.totalKm, greaterThan(0));
  });
}
