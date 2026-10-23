import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:mes_km/domain/models/app_settings.dart';
import 'package:mes_km/domain/models/civil_date.dart';
import 'package:mes_km/domain/models/day_extra.dart';
import 'package:mes_km/domain/models/trip.dart';
import 'package:mes_km/domain/models/vacation_period.dart';
import 'package:mes_km/domain/models/vehicle.dart';
import 'package:mes_km/features/documents/pdf_builder.dart';
import 'package:mes_km/features/documents/report_data.dart';

// PDF annuel (KM-012). `compress: false` rend les flux de contenu lisibles :
// on vérifie la présence réelle des textes (WinAnsi ≈ latin1 pour le
// français) sans dépendre d'un rendu visuel.

/// Reconstruit le texte des flux de contenu : chaque mot est émis comme un
/// segment `[(mot)] TJ` distinct, on les rejoint par des espaces.
String extractPdfText(List<int> bytes) {
  final raw = latin1.decode(bytes);
  return RegExp(r'\[\((.*?)\)\]\s*TJ')
      .allMatches(raw)
      .map(
        (m) => m
            .group(1)!
            .replaceAll(r'\(', '(')
            .replaceAll(r'\)', ')')
            .replaceAll(r'\\', r'\'),
      )
      .join(' ');
}

void main() {
  AnnualReportData report({
    List<Trip> trips = const [],
    List<DayExtra> extras = const [],
    List<Vehicle> vehicles = const [],
    List<VacationPeriod> vacations = const [],
    AppSettings? settings,
  }) => buildAnnualReportData(
    year: 2026,
    generatedAt: DateTime(2026, 10, 11),
    trips: trips,
    extras: extras,
    vehicles: vehicles,
    vacations: vacations,
    settings: settings ?? AppSettings(),
  );

  test('les octets produits sont un PDF (%PDF, EOF)', () async {
    final bytes = await buildAnnualPdf(
      report(
        trips: [
          Trip(
            id: 't1',
            date: CivilDate(2026, 5, 2),
            distanceKm: 42,
            createdAt: DateTime.utc(2026, 5, 2, 9),
          ),
        ],
      ),
    );
    expect(ascii.decode(bytes.sublist(0, 5)), '%PDF-');
    expect(latin1.decode(bytes), contains('%%EOF'));
  });

  test('contenu : titre, année, identité, totaux, véhicules, mois, congés, '
      'mention de bas de page', () async {
    final bytes = await buildAnnualPdf(
      report(
        settings: AppSettings(
          displayName: 'Marc Infirmier',
          address: '12 rue des Lilas',
          city: '19700 Seilhac',
        ),
        vehicles: [
          Vehicle(
            id: 'v1',
            name: 'Peugeot 208',
            category: VehicleCategory.car,
            registration: 'AB-123-CD',
            fiscalPowerCv: 5,
          ),
        ],
        trips: [
          Trip(
            id: 't1',
            date: CivilDate(2026, 2, 10),
            distanceKm: 1642,
            vehicleId: 'v1',
            createdAt: DateTime.utc(2026, 2, 10, 9),
          ),
        ],
        vacations: [
          VacationPeriod(
            id: 'p1',
            startDate: CivilDate(2026, 8, 3),
            endDate: CivilDate(2026, 8, 10),
          ),
        ],
      ),
      compress: false,
    );
    final text = extractPdfText(bytes);
    expect(text, contains('RELEVÉ KILOMÉTRIQUE'));
    expect(text, contains('Année 2026'));
    expect(text, contains('Généré le 11/10/2026'));
    expect(text, contains('Marc Infirmier'));
    expect(text, contains('19700 Seilhac'));
    expect(text, contains('SYNTHÈSE'));
    // Milliers groupés et réellement rendus : l'espace fine U+202F d'intl
    // n'a pas de glyphe Helvetica/WinAnsi (le PDF afficherait « 1642 ») —
    // le builder la remplace par une insécable U+00A0.
    expect(text, contains('1 642 km'));
    expect(text, contains('Total annuel'));
    expect(text, contains('Peugeot 208'));
    expect(text, contains('AB-123-CD'));
    expect(text, contains('5 CV'));
    expect(text, contains('Janvier'));
    expect(text, contains('Décembre'));
    // Séparateur « au » : la flèche U+2192 n'existe pas en WinAnsi.
    expect(text, contains('03/08/2026 au 10/08/2026'));
    expect(text, contains('données enregistrées dans Mes Km'));
    // Jamais d'attestation ni de montant fiscal : document de synthèse.
    expect(text.toUpperCase(), isNot(contains('ATTESTATION')));
    expect(text, isNot(contains('€')));
  });

  test(
    'pagination : le contenu long produit plusieurs pages numérotées',
    () async {
      final bytes = await buildAnnualPdf(
        report(
          trips: [
            Trip(
              id: 't1',
              date: CivilDate(2026, 1, 2),
              distanceKm: 10,
              createdAt: DateTime.utc(2026, 1, 2, 9),
            ),
          ],
          // Assez de périodes pour déborder sur une deuxième page A4.
          vacations: [
            for (var d = 1; d <= 28; d++)
              VacationPeriod(
                id: 'p$d',
                startDate: CivilDate(2026, 2, d),
                endDate: CivilDate(2026, 2, d),
              ),
            for (var d = 1; d <= 28; d++)
              VacationPeriod(
                id: 'q$d',
                startDate: CivilDate(2026, 4, d),
                endDate: CivilDate(2026, 4, d),
              ),
          ],
        ),
        compress: false,
      );
      final text = extractPdfText(bytes);
      final pages = RegExp(
        r'/Type\s*/Page\b',
      ).allMatches(latin1.decode(bytes)).length;
      expect(pages, greaterThan(1));
      expect(text, contains('Page 1/$pages'));
      expect(text, contains('Page $pages/$pages'));
    },
  );

  test('année vide : PDF propre avec message explicite', () async {
    final bytes = await buildAnnualPdf(report(), compress: false);
    final text = extractPdfText(bytes);
    expect(ascii.decode(bytes.sublist(0, 5)), '%PDF-');
    expect(text, contains('Aucun kilomètre enregistré pour cette année.'));
    expect(text, contains('Page 1/1'));
  });
}
