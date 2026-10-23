@TestOn('browser')
library;

// Test navigateur réel (KM-012) : génération des documents annuels depuis
// IndexedDB — le PDF (dart:typed_data, deflate) et le CSV UTF-8 doivent se
// construire dans un vrai moteur web, sans réseau.
// Exécution : flutter test --platform chrome test/web

import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:mes_km/data/local/sembast_settings_repository.dart';
import 'package:mes_km/data/local/sembast_trip_repository.dart';
import 'package:mes_km/data/local/sembast_vehicle_repository.dart';
import 'package:mes_km/data/local/web_database.dart';
import 'package:mes_km/domain/models/app_settings.dart';
import 'package:mes_km/domain/models/accountant_contact.dart';
import 'package:mes_km/domain/models/civil_date.dart';
import 'package:mes_km/domain/models/trip.dart';
import 'package:mes_km/domain/models/vehicle.dart';
import 'package:mes_km/features/documents/csv_builder.dart';
import 'package:mes_km/features/documents/pdf_builder.dart';
import 'package:mes_km/features/documents/report_data.dart';

void main() {
  test('PDF et CSV réels générés depuis IndexedDB', () async {
    final database = await openMesKmDatabaseWeb(
      name: 'mes_km_docs_browser_test.db',
    );
    addTearDown(database.close);

    await SembastVehicleRepository(database.db).put(
      Vehicle(
        id: 'v1',
        name: 'Peugeot 208',
        category: VehicleCategory.car,
        registration: 'AB-123-CD',
      ),
    );
    await SembastTripRepository(database.db).put(
      Trip(
        id: 'doc-1',
        date: CivilDate(2026, 10, 11),
        distanceKm: 42.5,
        vehicleId: 'v1',
        origin: 'Maison',
        destination: 'Hôpital de Tulle',
        createdAt: DateTime.utc(2026, 10, 11, 9),
      ),
    );
    await SembastSettingsRepository(database.db).save(
      AppSettings(
        displayName: 'Test Navigateur',
        accountant: AccountantContact(
          name: 'Cabinet Équilibre',
          email: 'recette@example.fr',
        ),
      ),
    );

    final trips = await SembastTripRepository(
      database.db,
    ).getBetween(CivilDate(2026, 1, 1), CivilDate(2026, 12, 31));
    final report = buildAnnualReportData(
      year: 2026,
      generatedAt: DateTime(2026, 10, 11),
      trips: trips,
      extras: const [],
      vehicles: await SembastVehicleRepository(database.db).getAll(),
      vacations: const [],
      settings: await SembastSettingsRepository(database.db).get(),
    );
    expect(report.totalKm, 42.5);

    expect(report.accountant!.name, 'Cabinet Équilibre');
    final pdfBytes = await buildAnnualPdf(report);
    expect(pdfBytes.length, greaterThan(500));
    expect(ascii.decode(pdfBytes.sublist(0, 5)), '%PDF-');
    expect(latin1.decode(pdfBytes), contains('%%EOF'));

    final csv = buildAnnualCsv(report);
    expect(csv, startsWith('Date;Type;Distance_km;'));
    expect(
      csv,
      contains(
        '2026-10-11;Trajet;42,5;Maison;Hôpital de Tulle;;Non;'
        'Peugeot 208;AB-123-CD',
      ),
    );
    // Aller-retour UTF-8 : les octets encodés redonnent les accents.
    expect(utf8.decode(utf8.encode(csv)), contains('Hôpital de Tulle'));
  });
}
