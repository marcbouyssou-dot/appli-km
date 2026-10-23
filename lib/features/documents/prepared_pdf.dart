import 'dart:typed_data';

import 'pdf_builder.dart';

/// Le fichier prévisualisé est exactement celui proposé au partage.
/// Aucune régénération ni lecture de données entre l'aperçu et le geste Partager.
class PreparedAnnualPdf {
  const PreparedAnnualPdf({
    required this.bytes,
    required this.fileName,
    required this.mode,
  });
  final Uint8List bytes;
  final String fileName;
  final AnnualPdfMode mode;
}
