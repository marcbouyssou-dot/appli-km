import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/backup/backup_file_gateway.dart';
import 'documents_controller.dart';
import 'pdf_preview_surface.dart';
import 'prepared_pdf.dart';

class PdfPreviewScreen extends ConsumerStatefulWidget {
  const PdfPreviewScreen({super.key, required this.document});
  final PreparedAnnualPdf document;
  @override
  ConsumerState<PdfPreviewScreen> createState() => _PdfPreviewScreenState();
}

class _PdfPreviewScreenState extends ConsumerState<PdfPreviewScreen> {
  bool _sharing = false;
  bool _ready = false;

  Future<void> _share() async {
    setState(() => _sharing = true);
    try {
      // Appel immédiat depuis le geste : activation utilisateur iOS conservée.
      final outcome = await ref
          .read(documentsControllerProvider.notifier)
          .sharePdf(widget.document);
      if (!mounted || outcome == BackupSaveOutcome.cancelled) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('PDF partagé ou enregistré.')),
      );
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Impossible de partager le PDF. Réessayez.'),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _sharing = false);
    }
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: !_sharing,
    child: Scaffold(
      appBar: AppBar(
        leading: IconButton(
          tooltip: 'Retour',
          icon: const Icon(Icons.arrow_back),
          onPressed: _sharing ? null : () => Navigator.of(context).pop(),
        ),
        title: const Text('Aperçu PDF'),
        actions: [
          TextButton.icon(
            key: const Key('share-preview-pdf'),
            onPressed: _ready && !_sharing ? _share : null,
            icon: _sharing
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.ios_share_outlined, size: 20),
            label: const Text('Partager'),
          ),
        ],
      ),
      body: SafeArea(
        child: PdfPreviewSurface(
          document: widget.document,
          onReady: () {
            if (mounted && !_ready) setState(() => _ready = true);
          },
        ),
      ),
    ),
  );
}
