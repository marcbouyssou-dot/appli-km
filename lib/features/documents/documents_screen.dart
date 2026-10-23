import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/backup/backup_file_gateway.dart';
import '../../theme/tokens.dart';
import '../../widgets/km_format.dart';
import '../../widgets/app_buttons.dart';
import '../../widgets/period_selector.dart';
import '../../widgets/section_header.dart';
import '../settings/settings_screen.dart';
import 'documents_controller.dart';
import 'pdf_builder.dart';
import 'pdf_preview_screen.dart';

/// Plus → Documents : relevé annuel PDF et détail CSV, générés localement.
class DocumentsScreen extends ConsumerStatefulWidget {
  const DocumentsScreen({super.key});

  @override
  ConsumerState<DocumentsScreen> createState() => _DocumentsScreenState();
}

class _DocumentsScreenState extends ConsumerState<DocumentsScreen> {
  bool _generating = false;

  Future<void> _generate(Future<BackupSaveOutcome> Function() action) async {
    final messenger = ScaffoldMessenger.of(context);
    setState(() => _generating = true);
    try {
      final outcome = await action();
      if (outcome == BackupSaveOutcome.cancelled) return;
      messenger.showSnackBar(const SnackBar(content: Text('Document créé.')));
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

  Future<void> _previewPdf() async {
    final mode = await showDialog<AnnualPdfMode>(
      context: context,
      builder: (context) => const _PdfModeDialog(),
    );
    if (mode == null || !mounted) return;
    setState(() => _generating = true);
    try {
      final document = await ref
          .read(documentsControllerProvider.notifier)
          .preparePdf(mode);
      if (!mounted) {
        return;
      }
      await Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => PdfPreviewScreen(document: document),
        ),
      );
    } catch (error, stackTrace) {
      if (kDebugMode) debugPrint('[pdf preview] $error\n$stackTrace');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Impossible de créer le PDF. Réessayez.'),
          ),
        );
      }
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
                    'Choisissez une synthèse ou un relevé détaillé, puis '
                    'visualisez le PDF avant de le partager.',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                  // UX-006B : liaison explicite — l'identité du PDF vient
                  // de Plus → Réglages (navigation directe, même écran).
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          'L’en-tête du PDF utilise vos informations de',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ),
                      TextButton(
                        key: const Key('docs-open-settings'),
                        onPressed: () {
                          Navigator.of(context).push(
                            MaterialPageRoute<void>(
                              builder: (_) => const SettingsScreen(),
                            ),
                          );
                        },
                        style: TextButton.styleFrom(
                          minimumSize: const Size(0, AppSizes.minTouchTarget),
                          padding: const EdgeInsets.symmetric(
                            horizontal: AppSpacing.xs,
                          ),
                        ),
                        child: const Text('Réglages'),
                      ),
                    ],
                  ),
                  PrimaryButton(
                    key: const Key('create-pdf-button'),
                    icon: Icons.picture_as_pdf_outlined,
                    label: 'Exporter le PDF',
                    onPressed: hasData && !_generating ? _previewPdf : null,
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
                ],
              ),
      ),
    );
  }
}

class _PdfModeDialog extends StatefulWidget {
  const _PdfModeDialog();
  @override
  State<_PdfModeDialog> createState() => _PdfModeDialogState();
}

class _PdfModeDialogState extends State<_PdfModeDialog> {
  AnnualPdfMode _mode = AnnualPdfMode.summaryOnly;
  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('Choisir le PDF'),
    scrollable: true,
    content: RadioGroup<AnnualPdfMode>(
      groupValue: _mode,
      onChanged: (value) {
        if (value != null) setState(() => _mode = value);
      },
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          RadioListTile<AnnualPdfMode>(
            contentPadding: EdgeInsets.zero,
            value: AnnualPdfMode.summaryOnly,
            title: const Text('Synthèse uniquement'),
            subtitle: const Text(
              '1 page A4. Total, mois et véhicules, sans le détail des trajets.',
            ),
          ),
          RadioListTile<AnnualPdfMode>(
            contentPadding: EdgeInsets.zero,
            value: AnnualPdfMode.summaryAndDetail,
            title: const Text('Synthèse + détail'),
            subtitle: const Text(
              'Ajoute la liste complète des trajets et kilomètres enregistrés.',
            ),
          ),
        ],
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('Annuler'),
      ),
      FilledButton(
        key: const Key('preview-pdf-button'),
        onPressed: () => Navigator.pop(context, _mode),
        child: const Text('Voir le PDF'),
      ),
    ],
  );
}
