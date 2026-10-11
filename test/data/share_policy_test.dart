import 'package:flutter_test/flutter_test.dart';
import 'package:mes_km/data/backup/share_policy.dart';

/// Politique d'export : CAPABILITY DETECTION AVANT APPEL.
/// Reproduit le cas observé sur Safari/PWA iPhone (KM-008) :
/// `navigator.canShare === undefined`.
void main() {
  bool mustNotBeCalled() =>
      fail('canShare ne doit JAMAIS être appelé quand l’API est absente');

  test('canShare existe + fichiers partageables => Web Share API', () {
    expect(
      chooseBackupSavePath(
        hasShare: true,
        hasCanShare: true,
        canShareFiles: () => true,
      ),
      BackupSavePath.share,
    );
  });

  test(
      'CAS IPHONE : canShare ABSENT => aucun appel à canShare, '
      'repli téléchargement', () {
    expect(
      chooseBackupSavePath(
        hasShare: true,
        hasCanShare: false, // navigator.canShare === undefined
        canShareFiles: mustNotBeCalled,
      ),
      BackupSavePath.download,
    );
  });

  test('share ABSENT => repli téléchargement, canShare jamais appelé', () {
    expect(
      chooseBackupSavePath(
        hasShare: false,
        hasCanShare: false,
        canShareFiles: mustNotBeCalled,
      ),
      BackupSavePath.download,
    );
  });

  test('canShare retourne false (fichiers non partageables) => repli', () {
    expect(
      chooseBackupSavePath(
        hasShare: true,
        hasCanShare: true,
        canShareFiles: () => false,
      ),
      BackupSavePath.download,
    );
  });
}
