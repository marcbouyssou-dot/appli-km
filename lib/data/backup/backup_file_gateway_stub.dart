import 'backup_file_gateway.dart';

/// Plateformes sans passerelle fichier (iOS/desktop natifs : lot futur).
class UnsupportedBackupFileGateway implements BackupFileGateway {
  const UnsupportedBackupFileGateway();

  Never _unsupported() => throw UnsupportedError(
      'Sauvegarde fichier non disponible sur cette plateforme.');

  @override
  Future<BackupSaveOutcome> saveBackupFile({
    required String fileName,
    required String content,
  }) async =>
      _unsupported();

  @override
  Future<BackupSaveOutcome> saveFile({
    required String fileName,
    required List<int> bytes,
    required String mimeType,
  }) async =>
      _unsupported();

  @override
  Future<String?> pickBackupFile() async => _unsupported();
}

BackupFileGateway createBackupFileGateway() =>
    const UnsupportedBackupFileGateway();
