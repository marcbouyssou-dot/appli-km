import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../domain/models/civil_date.dart';
import '../../domain/models/vacation_period.dart';
import '../../widgets/form_sheet_scaffold.dart';
import '../../widgets/section_header.dart';
import '../../theme/tokens.dart';
import '../vacations/vacations_controller.dart';

/// Feuille « Congés » : ajout d'une période (Du/Au) + liste minimale des
/// périodes existantes avec suppression confirmée. Pas de gestionnaire
/// complexe : tout le reste (retrait d'un jour) se fait depuis la journée.
Future<void> showVacationsSheet(BuildContext context) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (context) => const _VacationsSheet(),
  );
}

class _VacationsSheet extends ConsumerStatefulWidget {
  const _VacationsSheet();

  @override
  ConsumerState<_VacationsSheet> createState() => _VacationsSheetState();
}

class _VacationsSheetState extends ConsumerState<_VacationsSheet> {
  CivilDate? _start;
  CivilDate? _end;
  String? _error;

  String _format(CivilDate date) =>
      DateFormat('d MMM yyyy', 'fr_FR').format(date.toDateTime());

  Future<void> _pickDate({required bool isStart}) async {
    final initial = (isStart ? _start : _end) ?? CivilDate.today();
    final picked = await showDatePicker(
      context: context,
      initialDate: initial.toDateTime(),
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );
    if (picked == null) return;
    setState(() {
      final date = CivilDate.fromDateTime(picked);
      if (isStart) {
        _start = date;
        _end ??= date;
      } else {
        _end = date;
        _start ??= date;
      }
      _error = null;
    });
  }

  bool get _canSubmit {
    final start = _start;
    final end = _end;
    return start != null && end != null && !start.isAfter(end);
  }

  Future<void> _submit() async {
    final start = _start;
    final end = _end;
    if (start == null || end == null) {
      setState(() => _error = 'Choisissez les deux dates.');
      return;
    }
    if (start.isAfter(end)) {
      setState(() => _error = 'Le début doit être avant la fin.');
      return;
    }
    await ref.read(vacationsControllerProvider.notifier).addPeriod(start, end);
    setState(() {
      _start = null;
      _end = null;
      _error = null;
    });
  }

  Future<void> _deletePeriod(VacationPeriod period) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Supprimer cette période de congés ?'),
        content: Text('${_format(period.startDate)} → '
            '${_format(period.endDate)}'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Annuler'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Supprimer'),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      await ref
          .read(vacationsControllerProvider.notifier)
          .deletePeriod(period.id);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final periods =
        ref.watch(vacationsControllerProvider).value ??
            const <VacationPeriod>[];

    // Grammaire V1 (UX-003C) : feuille très simple, action épinglée.
    // « Fermer » (pas « Annuler ») : les périodes listées sont déjà
    // enregistrées.
    return FormSheetScaffold(
      title: 'Congés',
      cancelLabel: 'Fermer',
      primaryKey: const Key('vacation-add'),
      primaryLabel: 'Ajouter ces congés',
      onPrimary: _canSubmit ? _submit : null,
      children: [
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    key: const Key('vacation-start'),
                    onPressed: () => _pickDate(isStart: true),
                    style: OutlinedButton.styleFrom(
                      minimumSize:
                          const Size.fromHeight(AppSizes.minTouchTarget + 4),
                    ),
                    child: Text(
                        _start == null ? 'Du…' : 'Du ${_format(_start!)}'),
                  ),
                ),
                const SizedBox(width: AppSpacing.m),
                Expanded(
                  child: OutlinedButton(
                    key: const Key('vacation-end'),
                    onPressed: () => _pickDate(isStart: false),
                    style: OutlinedButton.styleFrom(
                      minimumSize:
                          const Size.fromHeight(AppSizes.minTouchTarget + 4),
                    ),
                    child: Text(
                        _end == null ? 'Au…' : 'Au ${_format(_end!)}'),
                  ),
                ),
              ],
            ),
            if (_error != null) ...[
              const SizedBox(height: AppSpacing.s),
              Text(
                _error!,
                style: TextStyle(color: theme.colorScheme.error),
              ),
            ],
            const SizedBox(height: AppSpacing.l),
            if (periods.isNotEmpty) ...[
              const SectionHeader('Périodes existantes', topSpacing: 0),
              for (final period in periods)
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  minTileHeight: AppSizes.minTouchTarget,
                  leading: Icon(
                    Icons.beach_access,
                    color: theme.colorScheme.tertiary,
                  ),
                  title: Text(
                    '${_format(period.startDate)} → '
                    '${_format(period.endDate)}',
                  ),
                  trailing: IconButton(
                    icon: const Icon(Icons.delete_outline),
                    tooltip: 'Supprimer',
                    onPressed: () => _deletePeriod(period),
                  ),
                ),
            ],
            const SizedBox(height: AppSpacing.s),
      ],
    );
  }
}
