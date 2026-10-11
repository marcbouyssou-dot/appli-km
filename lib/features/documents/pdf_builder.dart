import 'dart:typed_data';

import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../../widgets/km_format.dart';
import 'report_data.dart';

const _monthNames = [
  'Janvier', 'Février', 'Mars', 'Avril', 'Mai', 'Juin', //
  'Juillet', 'Août', 'Septembre', 'Octobre', 'Novembre', 'Décembre',
];

/// Kilomètres groupés, restreints à WinAnsi : l'espace fine insécable
/// (U+202F) d'intl n'a pas de glyphe en Helvetica — remplacée par une
/// insécable classique (U+00A0), sinon le chiffre des milliers disparaît.
String _km(double value) =>
    formatKmGrouped(value).replaceAll('\u202f', '\u00a0');

String _formatDate(DateTime date) =>
    '${date.day.toString().padLeft(2, '0')}/'
    '${date.month.toString().padLeft(2, '0')}/${date.year}';

String _formatCivil((int, int, int) ymd) =>
    '${ymd.$3.toString().padLeft(2, '0')}/'
    '${ymd.$2.toString().padLeft(2, '0')}/${ymd.$1}';

/// Relevé annuel PDF : SYNTHÈSE sobre, A4, paginée (le détail exhaustif
/// est le rôle du CSV). Généré entièrement localement ; les polices de
/// base (Helvetica, WinAnsi) couvrent les accents français.
/// Ce document n'est pas une attestation officielle et ne calcule aucun
/// montant fiscal.
Future<Uint8List> buildAnnualPdf(AnnualReportData report,
    {bool compress = true}) async {
  final document = pw.Document(compress: compress);

  final titleStyle =
      pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold);
  final sectionStyle =
      pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold);
  const bodyStyle = pw.TextStyle(fontSize: 10);
  final mutedStyle =
      pw.TextStyle(fontSize: 8, color: PdfColors.grey600);

  pw.Widget section(String title, List<pw.Widget> children) =>
      pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
        pw.SizedBox(height: 14),
        pw.Text(title.toUpperCase(), style: sectionStyle),
        pw.Divider(thickness: 0.5, color: PdfColors.grey500),
        ...children,
      ]);

  pw.Widget keyValue(String label, String value) => pw.Padding(
        padding: const pw.EdgeInsets.only(bottom: 3),
        child: pw.Row(children: [
          pw.Expanded(child: pw.Text(label, style: bodyStyle)),
          pw.Text(value,
              style:
                  pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold)),
        ]),
      );

  document.addPage(pw.MultiPage(
    pageFormat: PdfPageFormat.a4,
    margin: const pw.EdgeInsets.all(48),
    footer: (context) => pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Divider(thickness: 0.5, color: PdfColors.grey400),
        pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          children: [
            pw.Text(
              'Document généré à partir des données enregistrées dans '
              'Mes Km.',
              style: mutedStyle,
            ),
            pw.Text(
              'Page ${context.pageNumber}/${context.pagesCount}',
              style: mutedStyle,
            ),
          ],
        ),
      ],
    ),
    build: (context) => [
      pw.Text('RELEVÉ ANNUEL DES KILOMÈTRES PROFESSIONNELS',
          style: titleStyle),
      pw.SizedBox(height: 4),
      pw.Text('Année ${report.year}',
          style: pw.TextStyle(
              fontSize: 13, fontWeight: pw.FontWeight.bold)),
      pw.SizedBox(height: 2),
      pw.Text('Généré le ${_formatDate(report.generatedAt)}',
          style: mutedStyle),
      if (report.displayName != null ||
          report.address != null ||
          report.city != null)
        pw.Padding(
          padding: const pw.EdgeInsets.only(top: 10),
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              if (report.displayName != null)
                pw.Text(report.displayName!,
                    style: pw.TextStyle(
                        fontSize: 11, fontWeight: pw.FontWeight.bold)),
              if (report.address != null)
                pw.Text(report.address!, style: bodyStyle),
              if (report.city != null)
                pw.Text(report.city!, style: bodyStyle),
            ],
          ),
        ),

      section('Synthèse', [
        keyValue('Total annuel', _km(report.totalKm)),
        keyValue('Jours avec kilomètres', '${report.activeDays}'),
        keyValue('Moyenne par jour actif',
            formatKm(report.averagePerActiveDay)),
      ]),

      if (report.vehicles.isNotEmpty)
        section('Par véhicule', [
          for (final vehicle in report.vehicles)
            pw.Padding(
              padding: const pw.EdgeInsets.only(bottom: 6),
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Row(children: [
                    pw.Expanded(
                        child: pw.Text(vehicle.label,
                            style: pw.TextStyle(
                                fontSize: 10,
                                fontWeight: pw.FontWeight.bold))),
                    pw.Text(_km(vehicle.totalKm),
                        style: pw.TextStyle(
                            fontSize: 10,
                            fontWeight: pw.FontWeight.bold)),
                  ]),
                  if (vehicle.registration != null)
                    pw.Text('Immatriculation : ${vehicle.registration}',
                        style: bodyStyle),
                  if (vehicle.fiscalPowerCv != null)
                    pw.Text(
                        'Puissance fiscale : ${vehicle.fiscalPowerCv} CV',
                        style: bodyStyle),
                ],
              ),
            ),
        ]),

      section('Répartition mensuelle', [
        for (var m = 0; m < 12; m++)
          keyValue(_monthNames[m],
              _km(report.monthlyTotals[m])),
      ]),

      if (report.vacationPeriods.isNotEmpty)
        section('Congés', [
          for (final (start, end) in report.vacationPeriods)
            pw.Padding(
              padding: const pw.EdgeInsets.only(bottom: 3),
              child: pw.Text(
                start == end
                    ? _formatCivil((start.year, start.month, start.day))
                    : '${_formatCivil((start.year, start.month, start.day))}'
                        ' au '
                        '${_formatCivil((end.year, end.month, end.day))}',
                style: bodyStyle,
              ),
            ),
        ]),

      if (report.isEmpty)
        pw.Padding(
          padding: const pw.EdgeInsets.only(top: 16),
          child: pw.Text(
            'Aucun kilomètre enregistré pour cette année.',
            style: bodyStyle,
          ),
        ),
    ],
  ));

  return document.save();
}
