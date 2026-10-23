import 'dart:math' as math;
import 'dart:typed_data';

import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../../widgets/km_format.dart';
import '../../domain/models/km.dart';
import 'pdf_brand_assets.dart';
import 'report_data.dart';

const _months = [
  'Janvier',
  'Février',
  'Mars',
  'Avril',
  'Mai',
  'Juin',
  'Juillet',
  'Août',
  'Septembre',
  'Octobre',
  'Novembre',
  'Décembre',
];
const _ink = PdfColor.fromInt(0xff172b43);
const _blue = PdfColor.fromInt(0xff1d5bd8);
const _muted = PdfColor.fromInt(0xff58677a);
const _light = PdfColor.fromInt(0xfff0f5fc);
String _km(double value) => formatKmGrouped(value).replaceAll('\u202f', ' ');
String _short(String value, int max) {
  final runes = value.replaceAll(RegExp(r'\s+'), ' ').trim().runes.toList();
  return runes.length <= max
      ? String.fromCharCodes(runes)
      : '${String.fromCharCodes(runes.take(max - 1))}…';
}

String _date(DateTime d) =>
    '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';

enum AnnualPdfMode { summaryOnly, summaryAndDetail }

/// Relevé annuel détaillé, A4 imprimable, indépendant du thème de l'app.
/// Le builder reste pur : les assets locaux sont injectés par l'appelant.
/// Sans assets (tests textuels), les polices PDF standard restent utilisables.
Future<Uint8List> buildAnnualPdf(
  AnnualReportData report, {
  bool compress = true,
  AnnualPdfMode mode = AnnualPdfMode.summaryAndDetail,
  PdfBrandAssets? brand,
}) async {
  final doc = pw.Document(
    compress: compress,
    title: 'Relevé kilométrique ${report.year}',
    author: 'Mes Km',
    creator: 'MesKm.fr',
    theme: brand == null
        ? null
        : pw.ThemeData.withFont(base: brand.regular, bold: brand.bold),
  );
  final logo = brand == null ? null : pw.MemoryImage(brand.logo);
  final body = pw.TextStyle(fontSize: 9, color: _ink);
  final small = pw.TextStyle(fontSize: 8, color: _muted);
  pw.Widget title(String text) => pw.Padding(
    padding: const pw.EdgeInsets.only(top: 20, bottom: 8),
    child: pw.Text(
      text.toUpperCase(),
      style: pw.TextStyle(
        fontSize: 10,
        fontWeight: pw.FontWeight.bold,
        color: _blue,
        letterSpacing: 1,
      ),
    ),
  );
  pw.Widget text(String value, {bool bold = false}) => pw.RichText(
    text: pw.TextSpan(
      text: value,
      style: bold ? body.copyWith(fontWeight: pw.FontWeight.bold) : body,
    ),
    hyphenation: (word) => word.length < 28
        ? [word]
        : word.runes.map(String.fromCharCode).toList(),
  );
  pw.Widget panel(String label, List<String> values) => pw.Container(
    padding: const pw.EdgeInsets.all(12),
    decoration: const pw.BoxDecoration(color: _light),
    child: pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text(label.toUpperCase(), style: small),
        pw.SizedBox(height: 6),
        for (var i = 0; i < values.length; i++)
          pw.Padding(
            padding: const pw.EdgeInsets.only(bottom: 3),
            child: text(_short(values[i], 44), bold: i == 0),
          ),
      ],
    ),
  );
  final a = report.accountant;
  final identity = [
    report.displayName,
    report.address,
    report.city,
  ].whereType<String>().toList();
  final accountant = a == null
      ? <String>[]
      : [
          a.name,
          a.contact,
          a.address,
          a.addressExtra,
          [a.postalCode, a.city].whereType<String>().join(' '),
          a.phone,
          a.email,
        ].whereType<String>().where((s) => s.isNotEmpty).toList();

  pw.Widget cell(String value, {bool header = false, bool right = false}) =>
      pw.Padding(
        padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 7),
        child: pw.RichText(
          textAlign: right ? pw.TextAlign.right : pw.TextAlign.left,
          text: pw.TextSpan(
            text: value,
            style: pw.TextStyle(
              fontSize: header ? 8 : 8.5,
              color: header ? PdfColors.white : _ink,
              fontWeight: header || right
                  ? pw.FontWeight.bold
                  : pw.FontWeight.normal,
            ),
          ),
          hyphenation: (word) => word.length < 28
              ? [word]
              : word.runes.map(String.fromCharCode).toList(),
        ),
      );
  // Des lignes de continuation conservent l'intégralité des textes longs,
  // sans ligne indivisible qui dépasserait une page. Les km figurent une fois.
  List<String> chunks(String s) {
    final result = <String>[];
    var remaining = s;
    while (remaining.isNotEmpty) {
      if (remaining.runes.length <= 160) {
        result.add(remaining);
        break;
      }
      final prefix = String.fromCharCodes(remaining.runes.take(160));
      final space = prefix.lastIndexOf(' ');
      final cut = space > 90 ? space + 1 : prefix.length;
      result.add(remaining.substring(0, cut));
      remaining = remaining.substring(cut);
    }
    return result;
  }

  pw.Widget row(
    List<String> values, {
    bool header = false,
    bool stripe = false,
  }) => pw.Container(
    color: header
        ? _ink
        : stripe
        ? _light
        : PdfColors.white,
    child: pw.Row(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.SizedBox(width: 66, child: cell(values[0], header: header)),
        for (var i = 1; i < 4; i++)
          pw.Expanded(
            flex: const [0, 26, 20, 16][i],
            child: cell(values[i], header: header),
          ),
        pw.SizedBox(
          width: 62,
          child: cell(values[4], header: header, right: true),
        ),
      ],
    ),
  );
  final rows = <pw.Widget>[];
  final tableHeader = [
    'Date',
    'Trajet',
    'Motif / note',
    'Véhicule',
    'Distance',
  ];
  for (
    var index = 0;
    mode == AnnualPdfMode.summaryAndDetail && index < report.lines.length;
    index++
  ) {
    final line = report.lines[index];
    final route = !line.isDetailedTrip
        ? 'Kilomètres non détaillés'
        : [
            if (line.origin != null) 'Départ : ${line.origin}',
            if (line.destination != null) 'Arrivée : ${line.destination}',
            if (line.origin == null && line.destination == null)
              'Trajet détaillé',
            if (line.isRoundTrip) 'Aller-retour (distance totale)',
          ].join('\n');
    final cols = [
      chunks(route),
      chunks(line.purpose ?? ''),
      chunks(
        [
          line.vehicleLabel.isEmpty ? 'Non renseigné' : line.vehicleLabel,
          if (line.registration.isNotEmpty) line.registration,
        ].join('\n'),
      ),
    ];
    final count = cols.map((c) => c.length).fold(1, math.max);
    for (var part = 0; part < count; part++) {
      rows.add(
        row([
          part == 0 ? _date(line.date.toDateTime()) : '(suite)',
          for (final c in cols) part < c.length ? c[part] : '',
          part == 0 ? _km(line.km) : '',
        ], stripe: index.isEven),
      );
    }
  }
  pw.Widget brandHeader(pw.Context ctx) => pw.Column(
    children: [
      pw.Row(
        crossAxisAlignment: pw.CrossAxisAlignment.center,
        children: [
          if (logo != null) ...[
            pw.Image(logo, width: 34, height: 34),
            pw.SizedBox(width: 10),
          ],
          pw.Expanded(
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text(
                  'Mes Km',
                  style: pw.TextStyle(
                    fontSize: 16,
                    fontWeight: pw.FontWeight.bold,
                    color: _ink,
                  ),
                ),
                pw.Text(
                  'Vos kilomètres professionnels, simplement.',
                  style: small,
                ),
              ],
            ),
          ),
          pw.Text('Année ${report.year}', style: body),
        ],
      ),
      pw.SizedBox(height: 10),
      pw.Container(height: 2, color: _blue),
      pw.SizedBox(height: 18),
    ],
  );
  pw.Widget pageFooter(pw.Context ctx) => pw.Column(
    children: [
      pw.Divider(color: PdfColors.grey300, thickness: .5),
      pw.Row(
        children: [
          pw.Expanded(
            child: pw.Text(
              'MesKm.fr - Généré le ${_date(report.generatedAt)}',
              style: small,
            ),
          ),
          pw.Text('Page ${ctx.pageNumber}/${ctx.pagesCount}', style: small),
        ],
      ),
      pw.SizedBox(height: 3),
      pw.Text(
        'Document généré à partir des données enregistrées dans Mes Km.',
        style: small,
      ),
    ],
  );
  doc.addPage(
    pw.Page(
      pageFormat: PdfPageFormat.a4,
      margin: const pw.EdgeInsets.fromLTRB(36, 28, 36, 34),
      build: (ctx) => pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          brandHeader(ctx),
          pw.Text(
            'RELEVÉ KILOMÉTRIQUE',
            style: pw.TextStyle(
              fontSize: 22,
              fontWeight: pw.FontWeight.bold,
              color: _ink,
            ),
          ),
          pw.SizedBox(height: 5),
          pw.Text(
            'Du 01/01/${report.year} au 31/12/${report.year}',
            style: body,
          ),
          if (identity.isNotEmpty || accountant.isNotEmpty)
            pw.Padding(
              padding: const pw.EdgeInsets.only(top: 12),
              child: pw.Row(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  if (identity.isNotEmpty)
                    pw.Expanded(child: panel('Établi par', identity)),
                  if (identity.isNotEmpty && accountant.isNotEmpty)
                    pw.SizedBox(width: 12),
                  if (accountant.isNotEmpty)
                    pw.Expanded(
                      child: panel('Document préparé pour', accountant),
                    ),
                ],
              ),
            ),
          title('Synthèse'),
          pw.Container(
            padding: const pw.EdgeInsets.all(16),
            decoration: const pw.BoxDecoration(color: _light),
            child: pw.Row(
              children: [
                pw.Expanded(
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      text('Total annuel', bold: true),
                      pw.SizedBox(height: 4),
                      text('Kilomètres professionnels'),
                    ],
                  ),
                ),
                pw.Text(
                  _km(report.totalKm),
                  style: pw.TextStyle(
                    fontSize: 22,
                    fontWeight: pw.FontWeight.bold,
                    color: _blue,
                  ),
                ),
              ],
            ),
          ),
          pw.SizedBox(height: 8),
          text(
            'Jours avec kilomètres : ${report.activeDays} - Moyenne par jour actif : ${_km(report.averagePerActiveDay)}',
          ),
          if (report.vehicles.isNotEmpty) title('Par véhicule'),
          for (final v in report.vehicles.take(
            report.vehicles.length > 6 ? 5 : 6,
          ))
            pw.Padding(
              padding: const pw.EdgeInsets.only(bottom: 6),
              child: pw.Row(
                children: [
                  pw.Expanded(
                    child: text(
                      _short(
                        [
                          v.label,
                          if (v.registration != null) v.registration!,
                          if (v.fiscalPowerCv != null) '${v.fiscalPowerCv} CV',
                        ].join(' - '),
                        40,
                      ),
                    ),
                  ),
                  text(_km(v.totalKm), bold: true),
                ],
              ),
            ),
          if (report.vehicles.length > 6) ...[
            pw.Row(
              children: [
                pw.Expanded(
                  child: text(
                    'Autres véhicules (${report.vehicles.length - 5})',
                  ),
                ),
                text(
                  _km(sumKm(report.vehicles.skip(5).map((v) => v.totalKm))),
                  bold: true,
                ),
              ],
            ),
            pw.SizedBox(height: 3),
            pw.Text(
              'Les véhicules supplémentaires sont regroupés sur la dernière ligne.',
              style: small,
            ),
          ],
          title('Répartition mensuelle'),
          pw.Table(
            columnWidths: {
              0: const pw.FlexColumnWidth(),
              1: const pw.FlexColumnWidth(),
              2: const pw.FlexColumnWidth(),
            },
            children: [
              for (var row = 0; row < 4; row++)
                pw.TableRow(
                  children: [
                    for (var col = 0; col < 3; col++)
                      pw.Padding(
                        padding: const pw.EdgeInsets.only(right: 12, bottom: 7),
                        child: text(
                          '${_months[row * 3 + col]}  ${_km(report.monthlyTotals[row * 3 + col])}',
                        ),
                      ),
                  ],
                ),
            ],
          ),
          if (report.isEmpty) ...[
            pw.SizedBox(height: 12),
            text('Aucun kilomètre enregistré pour cette année.'),
          ],
          pw.Spacer(),
          pageFooter(ctx),
        ],
      ),
    ),
  );
  if (mode == AnnualPdfMode.summaryAndDetail &&
      (report.fiscalEstimates.isNotEmpty ||
          report.vacationPeriods.isNotEmpty)) {
    doc.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        maxPages: 1000,
        margin: const pw.EdgeInsets.fromLTRB(36, 28, 36, 34),
        header: brandHeader,
        footer: pageFooter,
        build: (ctx) => [
          if (report.fiscalEstimates.isNotEmpty) ...[
            title('Estimation indicative'),
            text(
              'Barème des revenus ${report.fiscalReferenceYear}. Simulation par véhicule, sans validation fiscale.',
            ),
            pw.SizedBox(height: 5),
            for (final e in report.fiscalEstimates)
              pw.Row(
                children: [
                  pw.Expanded(child: text(e.$1)),
                  text(formatEurRounded(e.$2).replaceAll('\u202f', ' ')),
                ],
              ),
            if (report.fiscalIsPartial)
              text(
                'Estimation partielle : certains kilomètres ou véhicules ne sont pas estimables.',
              ),
          ],
          if (report.vacationPeriods.isNotEmpty) title('Congés'),
          for (final p in report.vacationPeriods)
            pw.Padding(
              padding: const pw.EdgeInsets.only(bottom: 3),
              child: text(
                p.$1 == p.$2
                    ? _date(p.$1.toDateTime())
                    : '${_date(p.$1.toDateTime())} au ${_date(p.$2.toDateTime())}',
              ),
            ),
        ],
      ),
    );
  }
  if (rows.isNotEmpty) {
    doc.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        maxPages: 1000,
        margin: const pw.EdgeInsets.fromLTRB(36, 28, 36, 34),
        header: (ctx) => pw.Column(
          children: [
            brandHeader(ctx),
            title('Détail des trajets'),
            row(tableHeader, header: true),
          ],
        ),
        footer: pageFooter,
        build: (ctx) => rows,
      ),
    );
  }
  return doc.save();
}
