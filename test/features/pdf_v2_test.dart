import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:mes_km/domain/models/accountant_contact.dart';
import 'package:mes_km/domain/models/app_settings.dart';
import 'package:mes_km/domain/models/civil_date.dart';
import 'package:mes_km/domain/models/day_extra.dart';
import 'package:mes_km/domain/models/trip.dart';
import 'package:mes_km/domain/models/vehicle.dart';
import 'package:mes_km/features/documents/pdf_brand_assets.dart';
import 'package:mes_km/features/documents/pdf_builder.dart';
import 'package:mes_km/features/documents/report_data.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test(
    'PDF V2 imprimable : cabinet, français, plusieurs véhicules, textes longs, pagination et année vide',
    () async {
      final brand = await loadPdfBrandAssets();
      for (final count in [0, 4, 90]) {
        final trips = [
          for (var i = 0; i < count; i++)
            Trip(
              id: 't$i',
              date: CivilDate(2026, 10, 1).addDays(i % 22),
              distanceKm: 12.5,
              vehicleId: i.isEven ? 'v1' : 'v2',
              origin: 'Cabinet infirmier à Seilhac',
              destination: 'Clinique de l’Équilibre – cœur de ville',
              purpose: i == 1
                  ? List.filled(
                      16,
                      'Visite professionnelle, suivi et coordination des soins.',
                    ).join(' ')
                  : 'Tournée de soins à domicile',
              createdAt: DateTime(2026, 10, 1, i % 24),
            ),
        ];
        final report = buildAnnualReportData(
          year: 2026,
          generatedAt: DateTime(2026, 10, 22),
          trips: trips,
          extras: count == 0
              ? []
              : [DayExtra(date: CivilDate(2026, 10, 22), extraKm: 33)],
          vehicles: [
            Vehicle(
              id: 'v1',
              name: 'Peugeot 208',
              registration: 'AB-123-CD',
              category: VehicleCategory.car,
            ),
            Vehicle(
              id: 'v2',
              name: 'Renault Clio',
              registration: 'EF-456-GH',
              category: VehicleCategory.car,
            ),
          ],
          vacations: [],
          settings: AppSettings(
            displayName: 'Camille Noël',
            address: '12 rue des Écoles',
            city: '19700 Seilhac',
            accountant: count == 0
                ? null
                : AccountantContact(
                    name: 'Cabinet Équilibre',
                    contact: 'Élodie François',
                    address: '8 avenue de la République',
                    postalCode: '19000',
                    city: 'Tulle',
                    email: 'cabinet@example.fr',
                  ),
          ),
        );
        final pdf = await buildAnnualPdf(report, brand: brand);
        expect(ascii.decode(pdf.sublist(0, 5)), '%PDF-');
        expect(
          reportLinesTotalKm(report),
          count * 12.5 + (count == 0 ? 0 : 33),
        );
        final pages = RegExp(
          r'/Type\s*/Page\b',
        ).allMatches(latin1.decode(pdf)).length;
        expect(pages, count == 90 ? greaterThan(2) : greaterThanOrEqualTo(1));
        final dir = Directory('build/ux005-qa/pdf')
          ..createSync(recursive: true);
        File('${dir.path}/meskm-v2-$count.pdf').writeAsBytesSync(pdf);
      }
    },
  );
}
