import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../app/providers.dart';
import '../../data/backup/backup_codec.dart';
import '../../data/backup/backup_file_gateway.dart';
import '../calendar/calendar_controller.dart';
import '../day/day_controller.dart';
import '../today/favorites_controller.dart';
import '../vacations/vacations_controller.dart';

/// Contrôleur de l'écran Sauvegarde.
/// État : date du dernier export réussi généré PAR Mes Km (jamais une
/// prétention sur ce qui existe encore dans Fichiers/iCloud).
class BackupController extends AsyncNotifier<DateTime?> {
  @override
  Future<DateTime?> build() =>
      ref.read(backupMetaRepositoryProvider).lastExportAt();

  /// Crée une sauvegarde complète (snapshot cohérent) et la propose à
  /// l'utilisateur (partage si supporté, sinon téléchargement).
  /// Une annulation volontaire n'enregistre pas de « dernier export ».
  Future<BackupSaveOutcome> createBackup() async {
    final snapshot = await ref.read(backupServiceProvider).snapshot();
    final now = DateTime.now();

    final json = encodeBackup(
      exportedAt: now,
      trips: snapshot.trips,
      dayExtras: snapshot.dayExtras,
      favorites: snapshot.favorites,
      vehicles: snapshot.vehicles,
      vacationPeriods: snapshot.vacationPeriods,
      settings: snapshot.settings,
    );
    final fileName =
        'MesKm-Sauvegarde-${DateFormat('yyyy-MM-dd').format(now)}.kmbackup';

    final outcome = await ref
        .read(backupFileGatewayProvider)
        .saveBackupFile(fileName: fileName, content: json);
    if (outcome == BackupSaveOutcome.cancelled) return outcome;

    await ref.read(backupMetaRepositoryProvider).setLastExportAt(now);
    state = await AsyncValue.guard(
      () => ref.read(backupMetaRepositoryProvider).lastExportAt(),
    );
    return outcome;
  }

  /// Choisit un fichier puis l'analyse SANS AUCUNE ÉCRITURE.
  /// Retourne null si l'utilisateur annule ; lève BackupFormatException /
  /// BackupTooRecentException si le fichier est invalide.
  Future<BackupContent?> pickAndAnalyze() async {
    final raw = await ref.read(backupFileGatewayProvider).pickBackupFile();
    if (raw == null) return null;
    return decodeBackup(raw);
  }

  /// Restauration ATOMIQUE puis rafraîchissement de toute l'application
  /// (aucune donnée UI stale, pas de rechargement de page).
  Future<void> restore(BackupContent content) async {
    await ref.read(backupServiceProvider).restore(content);

    ref.read(dayDataVersionProvider.notifier).bump();
    ref.invalidate(dayControllerProvider); // toutes les journées (family)
    ref.invalidate(favoritesControllerProvider);
    ref.invalidate(vacationsControllerProvider);
    ref.invalidate(calendarControllerProvider);
  }
}

final backupControllerProvider =
    AsyncNotifierProvider<BackupController, DateTime?>(BackupController.new);
