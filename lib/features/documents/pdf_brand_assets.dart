import 'package:flutter/services.dart';
import 'package:pdf/widgets.dart' as pw;

/// Dépendances graphiques injectées dans le builder pur. Aucun chargement réseau.
class PdfBrandAssets {
  PdfBrandAssets({
    required this.regular,
    required this.bold,
    required this.logo,
  });
  final pw.Font regular, bold;
  final Uint8List logo;
}

PdfBrandAssets? _cached;
Future<PdfBrandAssets> loadPdfBrandAssets() async {
  if (_cached case final assets?) return assets;
  final assets = await _load();
  _cached = assets;
  return assets;
}

Future<PdfBrandAssets> _load() async {
  final regular = await rootBundle.load('assets/fonts/Inter-Regular.ttf');
  final bold = await rootBundle.load('assets/fonts/Inter-Bold.ttf');
  final logo = await rootBundle.load('assets/brand/meskm-logo.png');
  return PdfBrandAssets(
    regular: pw.Font.ttf(regular),
    bold: pw.Font.ttf(bold),
    logo: logo.buffer.asUint8List(logo.offsetInBytes, logo.lengthInBytes),
  );
}
