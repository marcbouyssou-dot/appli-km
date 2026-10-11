import 'package:flutter/material.dart';

import '../../theme/tokens.dart';
import '../../widgets/km_format.dart';

/// Feuille de saisie du total du jour.
///
/// [onSubmit] applique le total et retourne un message d'erreur métier
/// (ex. refus car inférieur aux trajets détaillés) ou null en cas de succès.
/// La feuille reste ouverte tant que la saisie n'est pas acceptée.
Future<void> showTotalEntrySheet(
  BuildContext context, {
  required double currentTotalKm,
  required Future<String?> Function(double totalKm) onSubmit,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (context) => _TotalEntrySheet(
      currentTotalKm: currentTotalKm,
      onSubmit: onSubmit,
    ),
  );
}

class _TotalEntrySheet extends StatefulWidget {
  const _TotalEntrySheet({
    required this.currentTotalKm,
    required this.onSubmit,
  });

  final double currentTotalKm;
  final Future<String?> Function(double totalKm) onSubmit;

  @override
  State<_TotalEntrySheet> createState() => _TotalEntrySheetState();
}

class _TotalEntrySheetState extends State<_TotalEntrySheet> {
  late final TextEditingController _controller;
  String? _errorText;
  bool _submitting = false;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final value = parseKmInput(_controller.text);
    if (value == null || value < 0) {
      setState(() => _errorText = 'Saisissez un nombre de kilomètres valide.');
      return;
    }

    setState(() {
      _submitting = true;
      _errorText = null;
    });

    final error = await widget.onSubmit(value);

    if (!mounted) return;
    if (error != null) {
      setState(() {
        _submitting = false;
        _errorText = error;
      });
      return;
    }
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        left: AppSpacing.xl,
        right: AppSpacing.xl,
        top: AppSpacing.s,
        bottom: MediaQuery.of(context).viewInsets.bottom + AppSpacing.xl,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Total du jour',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: AppSpacing.s),
          Text(
            'Actuellement : ${formatKm(widget.currentTotalKm)}. '
            'Les trajets détaillés sont toujours conservés.',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
          ),
          const SizedBox(height: AppSpacing.l),
          TextField(
            controller: _controller,
            autofocus: true,
            keyboardType:
                const TextInputType.numberWithOptions(decimal: true),
            textInputAction: TextInputAction.done,
            onSubmitted: (_) => _submit(),
            decoration: InputDecoration(
              labelText: 'Total (km)',
              suffixText: 'km',
              border: const OutlineInputBorder(),
              errorText: _errorText,
              errorMaxLines: 3,
            ),
          ),
          const SizedBox(height: AppSpacing.l),
          FilledButton(
            onPressed: _submitting ? null : _submit,
            style: FilledButton.styleFrom(
              minimumSize: const Size.fromHeight(AppSizes.minTouchTarget + 4),
            ),
            child: const Text('Valider'),
          ),
          const SizedBox(height: AppSpacing.s),
          TextButton(
            onPressed:
                _submitting ? null : () => Navigator.of(context).pop(),
            style: TextButton.styleFrom(
              minimumSize: const Size.fromHeight(AppSizes.minTouchTarget),
            ),
            child: const Text('Annuler'),
          ),
        ],
      ),
    );
  }
}
