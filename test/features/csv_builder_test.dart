import 'package:flutter_test/flutter_test.dart';
import 'package:mes_km/domain/models/app_settings.dart';
import 'package:mes_km/domain/models/civil_date.dart';
import 'package:mes_km/domain/models/day_extra.dart';
import 'package:mes_km/domain/models/trip.dart';
import 'package:mes_km/domain/models/vehicle.dart';
import 'package:mes_km/features/documents/csv_builder.dart';
import 'package:mes_km/features/documents/report_data.dart';

// CSV annuel (KM-012) : format tableur français — `;`, décimale `,`,
// échappement exact, et invariant somme = total annuel.
void main() {
  AnnualReportData build({
    List<Trip> trips = const [],
    List<DayExtra> extras = const [],
    List<Vehicle> vehicles = const [],
  }) =>
      buildAnnualReportData(
        year: 2026,
        generatedAt: DateTime(2026, 10, 11),
        trips: trips,
        extras: extras,
        vehicles: vehicles,
        vacations: const [],
        settings: AppSettings(),
      );

  List<String> rows(String csv) =>
      csv.trimRight().split('\n').map((l) => l.trimRight()).toList();

  test('en-tête exact, dans l’ordre spécifié', () {
    final csv = buildAnnualCsv(build());
    expect(
      rows(csv).first,
      'Date;Type;Distance_km;Départ;Destination;Motif;Aller_retour;'
      'Véhicule;Immatriculation',
    );
    expect(rows(csv), hasLength(1), reason: 'année vide : en-tête seul');
  });

  test('ligne Trajet : ISO date, décimale virgule, Oui/Non, accents UTF-8',
      () {
    final csv = buildAnnualCsv(build(
      vehicles: [
        Vehicle(
            id: 'v1',
            name: 'Citroën Ami',
            category: VehicleCategory.car,
            registration: 'ÉZ-987-ŒU'),
      ],
      trips: [
        Trip(
          id: 't1',
          date: CivilDate(2026, 3, 7),
          distanceKm: 24.5,
          origin: 'Domicile',
          destination: 'Hôpital de Tulle',
          purpose: 'Tournée patients',
          isRoundTrip: true,
          vehicleId: 'v1',
          createdAt: DateTime.utc(2026, 3, 7, 9),
        ),
      ],
    ));
    expect(
      rows(csv)[1],
      '2026-03-07;Trajet;24,5;Domicile;Hôpital de Tulle;'
      'Tournée patients;Oui;Citroën Ami;ÉZ-987-ŒU',
    );
  });

  test('ligne Non détaillé : colonnes trajet vides, A/R vide, entier sans '
      'virgule', () {
    final csv = buildAnnualCsv(build(
      extras: [DayExtra(date: CivilDate(2026, 6, 1), extraKm: 42)],
    ));
    expect(rows(csv)[1], '2026-06-01;Non détaillé;42;;;;;;');
  });

  test('échappement : `;`, guillemets doublés, retour à la ligne', () {
    final csv = buildAnnualCsv(build(
      trips: [
        Trip(
          id: 't1',
          date: CivilDate(2026, 4, 2),
          distanceKm: 10,
          origin: 'Brive; La Gaillarde',
          destination: 'Le "Central"',
          purpose: 'Ligne 1\nLigne 2',
          createdAt: DateTime.utc(2026, 4, 2, 9),
        ),
      ],
    ));
    expect(
      rows(csv.replaceFirst('Ligne 1\nLigne 2', 'Ligne 1⏎Ligne 2'))[1],
      '2026-04-02;Trajet;10;"Brive; La Gaillarde";"Le ""Central""";'
      '"Ligne 1⏎Ligne 2";Non;;',
    );
  });

  test('ordre chronologique et INVARIANT : somme CSV = total annuel EXACT',
      () {
    final report = build(
      trips: [
        for (var d = 1; d <= 30; d++)
          Trip(
            id: 't$d',
            date: CivilDate(2026, 9, d),
            distanceKm: 7.7 + d * 0.3,
            createdAt: DateTime.utc(2026, 9, d, 9),
          ),
      ],
      extras: [
        DayExtra(date: CivilDate(2026, 1, 15), extraKm: 12.4),
        DayExtra(date: CivilDate(2026, 9, 10), extraKm: 3.3),
      ],
    );
    final csv = buildAnnualCsv(report);
    final dataRows = rows(csv).skip(1).toList();
    expect(dataRows, hasLength(32),
        reason: 'une ligne par trajet + une par journée non détaillée');

    final dates = dataRows.map((r) => r.split(';').first).toList();
    expect(dates, List.of(dates)..sort(),
        reason: 'lignes en ordre chronologique');

    // Somme de la colonne Distance_km, re-parsée comme le ferait un tableur.
    var sum = 0.0;
    for (final row in dataRows) {
      sum += double.parse(row.split(';')[2].replaceAll(',', '.'));
    }
    // Chaque valeur est canonisée au dixième : la somme arrondie au dixième
    // doit être EXACTEMENT le total annuel affiché dans l'app et le PDF.
    expect((sum * 10).roundToDouble() / 10, report.totalKm);
  });
}
