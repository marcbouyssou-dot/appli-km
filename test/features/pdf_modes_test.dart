import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:mes_km/domain/models/accountant_contact.dart';
import 'package:mes_km/domain/models/app_settings.dart';
import 'package:mes_km/domain/models/civil_date.dart';
import 'package:mes_km/domain/models/trip.dart';
import 'package:mes_km/domain/models/vehicle.dart';
import 'package:mes_km/features/documents/pdf_brand_assets.dart';
import 'package:mes_km/features/documents/pdf_builder.dart';
import 'package:mes_km/features/documents/report_data.dart';

import 'pdf_builder_test.dart' show extractPdfText;

int pages(List<int> bytes) =>
    RegExp(r'/Type\s*/Page\b').allMatches(latin1.decode(bytes)).length;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final longText = List.filled(
    30,
    'Coordonnées professionnelles très longues',
  ).join(' ');
  AnnualReportData report(
    int vehicles, {
    bool cabinet = true,
    bool long = false,
    int trips = 2,
    String? content,
  }) => buildAnnualReportData(
    year: 2026,
    generatedAt: DateTime(2026, 10, 23),
    trips: [
      for (var i = 0; i < trips; i++)
        Trip(
          id: 't$i',
          date: CivilDate(2026, i % 12 + 1, i % 28 + 1),
          distanceKm: 70,
          vehicleId: vehicles == 0 ? null : 'v${i % vehicles}',
          origin: 'Maison',
          destination: 'Cabinet',
          purpose: 'Visite professionnelle $i',
          createdAt: DateTime.utc(2026, 1, 1, i % 24),
        ),
    ],
    extras: [],
    vehicles: [
      for (var i = 0; i < vehicles; i++)
        Vehicle(
          id: 'v$i',
          name: long ? '$i ${content ?? longText}' : 'Véhicule $i',
          registration: 'AB-123-CD',
          fiscalPowerCv: 5,
          category: VehicleCategory.car,
        ),
    ],
    vacations: [],
    settings: AppSettings(
      displayName: long ? content ?? longText : 'Camille Noël',
      address: long ? content ?? longText : '12 rue des Écoles',
      city: long ? content ?? longText : 'Seilhac',
      accountant: !cabinet
          ? null
          : AccountantContact(
              name: long ? content ?? longText : 'Cabinet Équilibre',
              contact: long ? content ?? longText : 'Élodie François',
              address: long ? content ?? longText : '8 avenue de la République',
              addressExtra: long ? content ?? longText : 'Bâtiment A',
              postalCode: '19000',
              city: long ? content ?? longText : 'Tulle',
              phone: long ? content ?? longText : '+33 5 00 00 00 00',
              email: 'cabinet@example.fr',
            ),
    ),
  );

  for (final (count, cabinet, long) in [
    (0, false, false),
    (1, true, false),
    (6, true, true),
    (7, true, true),
    (25, true, true),
  ]) {
    test(
      'synthèse 1 A4 : $count véhicules, cabinet=$cabinet, champs longs=$long',
      () async {
        final data = report(count, cabinet: cabinet, long: long, trips: 50);
        final bytes = await buildAnnualPdf(
          data,
          mode: AnnualPdfMode.summaryOnly,
          compress: false,
        );
        expect(pages(bytes), 1);
        final text = extractPdfText(bytes);
        expect(text, contains('Page 1/1'));
        expect(text, contains('3 500 km'));
        expect(text, contains('Janvier'));
        expect(text, contains('Décembre'));
        expect(text, isNot(contains('DÉTAIL DES TRAJETS')));
        expect(
          text,
          cabinet
              ? contains('DOCUMENT PRÉPARÉ POUR')
              : isNot(contains('DOCUMENT PRÉPARÉ POUR')),
        );
        if (count > 6) expect(text, contains('Autres véhicules'));
      },
    );
  }

  test(
    'les deux formats partagent les mêmes totaux ; détail complet multipage',
    () async {
      final data = report(3, trips: 180);
      final summary = await buildAnnualPdf(
        data,
        mode: AnnualPdfMode.summaryOnly,
        compress: false,
      );
      final full = await buildAnnualPdf(
        data,
        mode: AnnualPdfMode.summaryAndDetail,
        compress: false,
      );
      expect(pages(summary), 1);
      expect(pages(full), greaterThan(3));
      for (final bytes in [summary, full]) {
        expect(extractPdfText(bytes), contains('12 600 km'));
        expect(extractPdfText(bytes), contains('Cabinet Équilibre'));
      }
      expect(extractPdfText(full), contains('Visite professionnelle 179'));
    },
  );

  test('synthèse vide 1 page, aucune identité vide', () async {
    final bytes = await buildAnnualPdf(
      report(0, cabinet: false, trips: 0),
      mode: AnnualPdfMode.summaryOnly,
      compress: false,
    );
    expect(pages(bytes), 1);
    expect(extractPdfText(bytes), contains('Aucun kilomètre enregistré'));
  });

  test(
    'PDF brandés pour contrôle visuel : cas normal et bornes extrêmes',
    () async {
      final brand = await loadPdfBrandAssets();
      final out = Directory('build/ux005a-qa/pdf')..createSync(recursive: true);
      for (final (name, data) in [
        ('normal', report(2, trips: 30)),
        ('long-6', report(6, long: true, trips: 50)),
        ('long-25', report(25, long: true, trips: 50)),
        (
          'wide-6',
          report(
            6,
            long: true,
            trips: 50,
            content: List.filled(200, 'W').join(),
          ),
        ),
        ('empty', report(0, cabinet: false, trips: 0)),
      ]) {
        final bytes = await buildAnnualPdf(
          data,
          brand: brand,
          mode: AnnualPdfMode.summaryOnly,
        );
        expect(pages(bytes), 1);
        File('${out.path}/summary-$name.pdf').writeAsBytesSync(bytes);
      }
    },
  );
}
