import 'dart:async';
import 'dart:js_interop';

import 'package:web/web.dart' as web;

import 'backup_file_gateway.dart';

/// Passerelle fichier Web/PWA.
///
/// Export : Web Share API avec fichier quand la plateforme l'accepte
/// (feuille de partage iOS : Fichiers, iCloud Drive, AirDrop…), sinon
/// repli standard sur un téléchargement Blob. Import : sélecteur de
/// fichier natif. Aucun réseau, aucune autre API.
class WebBackupFileGateway implements BackupFileGateway {
  const WebBackupFileGateway();

  @override
  Future<void> saveBackupFile({
    required String fileName,
    required String content,
  }) async {
    final file = web.File(
      [content.toJS].toJS,
      fileName,
      web.FilePropertyBag(type: 'application/json'),
    );

    final navigator = web.window.navigator;
    final shareData = web.ShareData(files: [file].toJS);
    if (navigator.canShare(shareData)) {
      try {
        await navigator.share(shareData).toDart;
        return;
      } catch (_) {
        // Partage annulé ou refusé : on retombe sur le téléchargement.
      }
    }

    final url = web.URL.createObjectURL(file);
    final anchor = web.HTMLAnchorElement()
      ..href = url
      ..download = fileName;
    anchor.click();
    web.URL.revokeObjectURL(url);
  }

  @override
  Future<String?> pickBackupFile() async {
    final input = web.HTMLInputElement()
      ..type = 'file'
      ..accept = '.kmbackup,.json,application/json';

    final completer = Completer<String?>();

    input.onchange = (web.Event _) {
      final file = input.files?.item(0);
      if (file == null) {
        completer.complete(null);
        return;
      }
      file.text().toDart.then(
            (text) => completer.complete(text.toDart),
            onError: (Object error) => completer.completeError(error),
          );
    }.toJS;

    // Annulation du sélecteur (événement standard récent).
    input.oncancel = (web.Event _) {
      if (!completer.isCompleted) completer.complete(null);
    }.toJS;

    input.click();
    return completer.future;
  }
}

BackupFileGateway createBackupFileGateway() => const WebBackupFileGateway();
