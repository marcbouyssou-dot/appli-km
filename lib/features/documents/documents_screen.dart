import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/backup/backup_file_gateway.dart';
import '../../theme/tokens.dart';
import '../../widgets/km_format.dart';
import '../../widgets/app_buttons.dart';
import '../../widgets/period_selector.dart';
import '../../widgets/section_header.dart';
import 'documents_controller.dart';

/// Plus → Documents : relevé annuel PDF et détail CSV, générés localement.
class DocumentsScreen extends ConsumerStatefulWidget {
  const DocumentsScreen({super.key});

  @override
  ConsumerState<DocumentsScreen> createState() => _DocumentsScreenState();
}

class _DocumentsScreenState extends ConsumerState<DocumentsScreen> {
  bool _generating = false;

  Future<void> _generate(
    Future<BackupSaveOutcome> Function() action,
  ) async {
    final messenger = ScaffoldMessenger.of(context);
    setState(() => _generating = true);
    try {
      final outcome = await action();
      if (outcome == BackupSaveOutcome.cancelled) return;
      messenger.showSnackBar(
        const SnackBar(content: Text('Document créé.')),
      );
    } catch (error, stackTrace) {
      if (kDebugMode) debugPrint('[documents] $error\n$stackTrace');
      messenger.showSnackBar(
        const SnackBar(
          content: Text('Impossible de créer le document. Réessayez.'),
        ),
      );
    } finally {
      if (mounted) setState(() => _generating = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final state = ref.watch(documentsControllerProvider).value;
    final controller = ref.read(documentsControllerProvider.notifier);
    final hasData = state?.hasData ?? false;

    return Scaffold(
      appBar: AppBar(title: const Text('Documents')),
      body: SafeArea(
        child: state == null
            ? const Center(child: CircularProgressIndicator())
            : ListView(
                padding: const EdgeInsets.all(AppSpacing.l),
                children: [
                  const SectionHeader('ANNÉE', topSpacing: 0),
                  PeriodSelector(
                    label: '${state.year}',
                    onPrevious: controller.previousYear,
                    onNext: controller.nextYear,
                    previousKey: const Key('docs-prev-year'),
                    nextKey: const Key('docs-next-year'),
                    previousTooltip: 'Année précédente',
                    nextTooltip: 'Année suivante',
                  ),
                  if (!state.isCurrentYear)
                    Center(
                      child: TextButton(
                        onPressed: controller.goToCurrentYear,
                        child: const Text('Revenir à cette année'),
                      ),
                    ),
                  Center(
                    child: Text(
                      hasData
                          ? '${formatKmGrouped(state.yearTotal)} enregistrés'
                          : 'Aucune donnée en ${state.year}.',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.xl),

                  const SectionHeader('RELEVÉ ANNUEL', topSpacing: 0),
                  Text(
                    'Synthèse PDF : totaux, véhicules, répartition '
                    'mensuelle, congés.',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.s),
                  PrimaryButton(
                    key: const Key('create-pdf-button'),
                    icon: Icons.picture_as_pdf_outlined,
                    label: 'Créer le PDF',
                    onPressed: hasData && !_generating
                        ? () => _generate(controller.createPdf)
                        : null,
                  ),
                  const SizedBox(height: AppSpacing.xl),

                  const SectionHeader('DONNÉES DÉTAILLÉES', topSpacing: 0),
                  Text(
                    'CSV complet de l’année : une ligne par trajet et '
                    'par journée de kilomètres non détaillés '
                    '(compatible Numbers/Excel).',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.s),
                  PrimaryButton(
                    key: const Key('create-csv-button'),
                    tonal: true,
                    icon: Icons.table_chart_outlined,
                    label: 'Créer le CSV',
                    onPressed: hasData && !_generating
                        ? () => _generate(controller.createCsv)
                        : null,
                  ),
                  const SizedBox(height: AppSpacing.xl),

                  Text(
                    'Les documents sont générés localement à partir des '
                    'données enregistrées dans Mes Km.',
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
