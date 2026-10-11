/// Frontière plateforme pour les fichiers de sauvegarde.
///
/// Les features/domain ne touchent jamais aux APIs navigateur : seule
/// l'implémentation web (package:web) les connaît. Un futur adaptateur iOS
/// natif fournira la sienne (share sheet / document picker).
abstract interface class BackupFileGateway {
  /// Propose [content] à l'utilisateur sous le nom [fileName]
  /// (feuille de partage si disponible, sinon téléchargement).
  Future<void> saveBackupFile({
    required String fileName,
    required String content,
  });

  /// Ouvre un sélecteur de fichier et retourne le contenu texte,
  /// ou null si l'utilisateur annule.
  Future<String?> pickBackupFile();
}
