/// Choix du chemin d'export — logique PURE, testable hors navigateur.
///
/// Règle absolue (bug iPhone KM-008A) : CAPABILITY DETECTION AVANT APPEL.
/// `canShareFiles` n'est invoqué QUE si `navigator.canShare` existe
/// réellement ; sans Web Share API complète, repli téléchargement.
enum BackupSavePath { share, download }

BackupSavePath chooseBackupSavePath({
  required bool hasShare,
  required bool hasCanShare,
  required bool Function() canShareFiles,
}) {
  if (!hasShare || !hasCanShare) return BackupSavePath.download;
  return canShareFiles() ? BackupSavePath.share : BackupSavePath.download;
}
