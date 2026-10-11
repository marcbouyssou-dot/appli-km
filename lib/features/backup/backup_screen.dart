import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../data/backup/backup_codec.dart';
import '../../theme/tokens.dart';
import '../../widgets/km_format.dart';
import 'backup_controller.dart';

/// Écran « Sauvegarde » : export et restauration locales, sans compte,
/// sans réseau. Le fichier appartient à l'utilisateur.
class BackupScreen extends ConsumerWidget {
  const BackupScreen({super.key});

  Future<void> _createBackup(BuildContext context, WidgetRef ref) async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      await ref.read(backupControllerProvider.notifier).createBackup();
      messenger.showSnackBar(
        const SnackBar(content: Text('Sauvegarde créée.')),
      );
    } catch (error) {
      messenger.showSnackBar(
        SnackBar(content: Text('Échec de la sauvegarde : $error')),
      );
    }
  }

  Future<void> _restoreFlow(BuildContext context, WidgetRef ref) async {
    final controller = ref.read(backupControllerProvider.notifier);
    final messenger = ScaffoldMessenger.of(context);

    BackupContent content;
    try {
      final picked = await controller.pickAndAnalyze();
      if (picked == null) return; // annulé
      content = picked;
    } on BackupTooRecentException catch (error) {
      if (!context.mounted) return;
      await _showErrorDialog(context, '$error');
      return;
    } on BackupFormatException catch (error) {
      if (!context.mounted) return;
      await _showErrorDialog(context, '$error');
      return;
    } catch (error) {
      if (!context.mounted) return;
      await _showErrorDialog(
          context, 'Impossible de lire ce fichier : $error');
      return;
    }

    if (!context.mounted) return;
    final confirmed = await _showPreviewDialog(context, content);
    if (confirmed != true) return;

    try {
      await controller.restore(content);
      messenger.showSnackBar(
        const SnackBar(content: Text('Données restaurées.')),
      );
    } catch (error) {
      messenger.showSnackBar(
        SnackBar(content: Text('Échec de la restauration : $error')),
      );
    }
  }

  Future<void> _showErrorDialog(BuildContext context, String message) {
    return showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Restauration impossible'),
        content: Text(message),
        actions: [
          FilledButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  Future<bool?> _showPreviewDialog(
      BuildContext context, BackupContent content) {
    final created = DateFormat('d MMMM yyyy', 'fr_FR')
        .format(content.exportedAt.toLocal());
    final range = content.yearRange;
    final period = range == null
        ? '—'
        : range.$1 == range.$2
            ? '${range.$1}'
            : '${range.$1} → ${range.$2}';

    Widget line(String label, String value) => Padding(
          padding: const EdgeInsets.only(bottom: AppSpacing.xs),
          child: Row(
            children: [
              Expanded(child: Text(label)),
              const SizedBox(width: AppSpacing.s),
              Text(value, style: const TextStyle(fontWeight: FontWeight.bold)),
            ],
          ),
        );

    return showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Sauvegarde Mes Km'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            line('Créée le', created),
            line('Période', period),
            line('Journées avec kilomètres', '${content.daysWithKm}'),
            line('Kilomètres enregistrés', formatKm(content.totalKm)),
            line('Trajets détaillés', '${content.trips.length}'),
            line('Favoris', '${content.favorites.length}'),
            line('Véhicules', '${content.vehicles.length}'),
            line('Périodes de congés', '${content.vacationPeriods.length}'),
            const SizedBox(height: AppSpacing.m),
            Text(
              'Cette restauration remplacera les données actuellement '
              'présentes sur cet appareil.',
              style: TextStyle(
                color: Theme.of(context).colorScheme.error,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Annuler'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
              foregroundColor: Theme.of(context).colorScheme.onError,
            ),
            child: const Text('Restaurer'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final lastExport = ref.watch(backupControllerProvider).value;

    return Scaffold(
      appBar: AppBar(title: const Text('Sauvegarde')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(AppSpacing.l),
          children: [
            Text('MES DONNÉES', style: theme.textTheme.labelLarge),
            const SizedBox(height: AppSpacing.s),
            Text(
              'Vos données sont enregistrées localement sur cet appareil.',
              style: theme.textTheme.bodyMedium,
            ),
            const SizedBox(height: AppSpacing.xl),
            FilledButton.icon(
              key: const Key('create-backup-button'),
              onPressed: () => _createBackup(context, ref),
              icon: const Icon(Icons.save_alt),
              label: const Text('Créer une sauvegarde'),
              style: FilledButton.styleFrom(
                minimumSize:
                    const Size.fromHeight(AppSizes.minTouchTarget + 8),
              ),
            ),
            const SizedBox(height: AppSpacing.s),
            Text(
              'Le fichier de sauvegarde contient vos données Mes Km. '
              'Conservez-le dans un emplacement sûr.',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            if (lastExport != null) ...[
              const SizedBox(height: AppSpacing.m),
              Text(
                'Dernière sauvegarde exportée : '
                '${DateFormat('d MMM yyyy HH:mm', 'fr_FR').format(lastExport.toLocal())}',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
            const SizedBox(height: AppSpacing.xl),
            FilledButton.tonalIcon(
              key: const Key('restore-backup-button'),
              onPressed: () => _restoreFlow(context, ref),
              icon: const Icon(Icons.restore),
              label: const Text('Restaurer une sauvegarde'),
              style: FilledButton.styleFrom(
                minimumSize:
                    const Size.fromHeight(AppSizes.minTouchTarget + 8),
              ),
            ),
            const SizedBox(height: AppSpacing.xl),
            Text(
              'Conservez régulièrement une sauvegarde dans Fichiers, '
              'iCloud Drive ou sur un autre appareil.',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
