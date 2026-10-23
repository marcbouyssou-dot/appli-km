import 'dart:js_interop';

import 'package:flutter/material.dart';
import 'package:web/web.dart' as web;

import 'prepared_pdf.dart';

/// Iframe même origine : moteur PDF local précaché, une seule page en mémoire.
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
  web.HTMLIFrameElement? _frame;
  late final JSFunction _listener;

  @override
  void initState() {
    super.initState();
    _listener = ((web.MessageEvent event) {
      final frame = _frame;
      if (!mounted ||
          frame == null ||
          event.origin != web.window.location.origin ||
          event.source != frame.contentWindow) {
        return;
      }
      final data = event.data.dartify();
      if (data is! Map || data['type'] is! String) return;
      if (data['type'] == 'meskm-pdf-ready') {
        frame.contentWindow?.postMessage(
          {
            'type': 'meskm-pdf-document',
            'bytes': widget.document.bytes,
          }.jsify(),
          web.window.location.origin.toJS,
        );
      } else if (data['type'] == 'meskm-pdf-rendered') {
        widget.onReady();
      }
    }).toJS;
    web.window.addEventListener('message', _listener);
  }

  @override
  void dispose() {
    web.window.removeEventListener('message', _listener);
    _frame?.src = 'about:blank';
    _frame = null;
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => HtmlElementView.fromTagName(
    tagName: 'iframe',
    onElementCreated: (element) {
      final frame = element as web.HTMLIFrameElement;
      _frame = frame;
      frame
        ..title = 'Aperçu du relevé PDF'
        ..src = Uri.base.resolve('/pdf_preview/index.html').toString();
      frame.style
        ..border = '0'
        ..width = '100%'
        ..height = '100%';
    },
  );
}
