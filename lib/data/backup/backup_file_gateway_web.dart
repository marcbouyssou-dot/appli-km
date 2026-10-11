import 'dart:async';
import 'dart:typed_data';
import 'dart:js_interop';
import 'dart:js_interop_unsafe';

import 'package:web/web.dart' as web;

import 'backup_file_gateway.dart';
import 'share_policy.dart';

/// Passerelle fichier Web/PWA.
///
/// Export : Web Share API avec fichier quand la plateforme l'accepte
/// (feuille de partage iOS : Fichiers, iCloud Drive, AirDrop…), sinon
/// repli standard sur un téléchargement Blob. Import : sélecteur de
/// fichier natif. Aucun réseau, aucune autre API.
class WebBackupFileGateway implements BackupFileGateway {
  const WebBackupFileGateway();

  /// Construit le FICHIER utilisateur de sauvegarde.
  ///
  /// FORMAT INTERNE = JSON versionné ; FORMAT UTILISATEUR = .kmbackup.
  /// MIME `application/octet-stream` et non `application/json` : Safari iOS
  /// traite un blob JSON comme un document à PRÉVISUALISER et ajoute
  /// « .json » au nom (bug recette KM-008B : « .kmbackup.json », écran
  /// « Ouvrir dans… ») ; en octet-stream, c'est un fichier à
  /// enregistrer/partager et le nom reste exact. L'import, lui, analyse le
  /// contenu sans jamais dépendre du MIME ni de l'extension.
  static web.File buildBackupFile({
    required String fileName,
    required String content,
  }) {
    return web.File(
      [content.toJS].toJS,
      fileName,
      web.FilePropertyBag(type: 'application/octet-stream'),
    );
  }

  @override
  Future<BackupSaveOutcome> saveBackupFile({
    required String fileName,
    required String content,
  }) {
    final file = buildBackupFile(fileName: fileName, content: content);
    return _offerFile(file, fileName);
  }

  @override
  Future<BackupSaveOutcome> saveFile({
    required String fileName,
    required List<int> bytes,
    required String mimeType,
  }) {
    final file = web.File(
      [Uint8List.fromList(bytes).toJS].toJS,
      fileName,
      web.FilePropertyBag(type: mimeType),
    );
    return _offerFile(file, fileName);
  }

  Future<BackupSaveOutcome> _offerFile(web.File file, String fileName) async {

    final navigator = web.window.navigator;
    final shareData = web.ShareData(files: [file].toJS);

    // DÉTECTION DE CAPACITÉS AVANT APPEL : sur Safari/PWA iPhone,
    // navigator.canShare peut être absent — l'appeler directement lève
    // « canShare is not a function » et le repli n'est jamais atteint
    // (bug recette KM-008). has() interroge l'objet JS réel.
    final path = chooseBackupSavePath(
      hasShare: navigator.has('share'),
      hasCanShare: navigator.has('canShare'),
      canShareFiles: () => navigator.canShare(shareData),
    );

    if (path == BackupSavePath.share) {
      try {
        await navigator.share(shareData).toDart;
        return BackupSaveOutcome.completed;
      } catch (error) {
        if (_isUserAbort(error)) {
          // Annulation volontaire : pas une erreur, pas de repli forcé.
          return BackupSaveOutcome.cancelled;
        }
        // Vraie erreur de partage : repli sûr sur le téléchargement.
      }
    }

    _downloadFile(file, fileName);
    return BackupSaveOutcome.completed;
  }

  static bool _isUserAbort(Object error) => '$error'.contains('AbortError');

  static void _downloadFile(web.File file, String fileName) {
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
      // Filtre indicatif seulement : la validation est TOUJOURS faite sur
      // le contenu, jamais sur l'extension ou le MIME.
      ..accept = '.kmbackup,.json,application/json,application/octet-stream';

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
