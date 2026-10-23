import 'package:flutter/material.dart';
import 'prepared_pdf.dart';

/// Les tests natifs vérifient le parcours ; le rendu réel est qualifié sur Web.
class PdfPreviewSurface extends StatefulWidget {
  const PdfPreviewSurface({
    super.key,
    required this.document,
    required this.onReady,
  });
  final PreparedAnnualPdf document;
  final VoidCallback onReady;
  @override
  State<PdfPreviewSurface> createState() => _PdfPreviewSurfaceState();
}

class _PdfPreviewSurfaceState extends State<PdfPreviewSurface> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) widget.onReady();
    });
  }

  @override
  Widget build(BuildContext context) => const Center(
    child: Text('Aperçu PDF disponible dans l’application Web.'),
  );
}
