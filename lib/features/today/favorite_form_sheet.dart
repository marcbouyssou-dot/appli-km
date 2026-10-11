import 'package:flutter/material.dart';

import '../../domain/models/favorite_trip.dart';
import '../../theme/tokens.dart';
import '../../widgets/km_format.dart';

/// Valeurs saisies dans le formulaire de favori.
class FavoriteFormResult {
  FavoriteFormResult({
    required this.label,
    required this.distanceKm,
    required this.defaultRoundTrip,
    this.origin,
    this.destination,
    this.purpose,
  });

  final String label;
  final double distanceKm;
  final bool defaultRoundTrip;
  final String? origin;
  final String? destination;
  final String? purpose;
}

/// Feuille de création/modification d'un favori.
/// La distance saisie est la distance COMPTABILISÉE ajoutée à chaque
/// utilisation (déjà totale si A/R) — même sémantique que les trajets.
///
/// [onDeleteRequested] (édition seulement) : la fiche propose aussi
/// « Supprimer le favori » ; le callback mène la confirmation et retourne
/// true si la suppression a eu lieu — la feuille se ferme alors.
Future<FavoriteFormResult?> showFavoriteFormSheet(
  BuildContext context, {
  FavoriteTrip? initial,
  Future<bool> Function()? onDeleteRequested,
}) {
  return showModalBottomSheet<FavoriteFormResult>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (context) => _FavoriteFormSheet(
      initial: initial,
      onDeleteRequested: onDeleteRequested,
    ),
  );
}

class _FavoriteFormSheet extends StatefulWidget {
  const _FavoriteFormSheet({this.initial, this.onDeleteRequested});

  final FavoriteTrip? initial;
  final Future<bool> Function()? onDeleteRequested;

  @override
  State<_FavoriteFormSheet> createState() => _FavoriteFormSheetState();
}

class _FavoriteFormSheetState extends State<_FavoriteFormSheet> {
  late final TextEditingController _labelController;
  late final TextEditingController _distanceController;
  late final TextEditingController _originController;
  late final TextEditingController _destinationController;
  late final TextEditingController _purposeController;
  late bool _defaultRoundTrip;
  String? _labelError;
  String? _distanceError;

  @override
  void initState() {
    super.initState();
    final initial = widget.initial;
    _labelController = TextEditingController(text: initial?.label ?? '');
    _distanceController = TextEditingController(
      text: initial == null ? '' : formatKmValue(initial.distanceKm),
    );
    _originController = TextEditingController(text: initial?.origin ?? '');
    _destinationController =
        TextEditingController(text: initial?.destination ?? '');
    _purposeController = TextEditingController(text: initial?.purpose ?? '');
    _defaultRoundTrip = initial?.defaultRoundTrip ?? false;
  }

  @override
  void dispose() {
    _labelController.dispose();
    _distanceController.dispose();
    _originController.dispose();
    _destinationController.dispose();
    _purposeController.dispose();
    super.dispose();
  }

  void _submit() {
    final label = _labelController.text.trim();
    final distance = parseKmInput(_distanceController.text);

    setState(() {
      _labelError = label.isEmpty ? 'Donnez un nom à ce favori.' : null;
      _distanceError = (distance == null || distance <= 0)
          ? 'Saisissez une distance en kilomètres (> 0).'
          : null;
    });
    if (_labelError != null || _distanceError != null) return;

    Navigator.of(context).pop(FavoriteFormResult(
      label: label,
      distanceKm: distance!,
      defaultRoundTrip: _defaultRoundTrip,
      origin: _originController.text,
      destination: _destinationController.text,
      purpose: _purposeController.text,
    ));
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isEditing = widget.initial != null;

    return Padding(
      padding: EdgeInsets.only(
        left: AppSpacing.xl,
        right: AppSpacing.xl,
        top: AppSpacing.s,
        bottom: MediaQuery.of(context).viewInsets.bottom + AppSpacing.xl,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              isEditing ? 'Modifier le favori' : 'Nouveau trajet favori',
              style: theme.textTheme.titleLarge,
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              'Disponible sur toutes les journées.',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: AppSpacing.l),
            TextField(
              controller: _labelController,
              autofocus: !isEditing,
              textCapitalization: TextCapitalization.sentences,
              decoration: InputDecoration(
                labelText: 'Nom du favori',
                hintText: 'Ex. : Cabinet ↔ EHPAD',
                border: const OutlineInputBorder(),
                errorText: _labelError,
              ),
            ),
            const SizedBox(height: AppSpacing.m),
            TextField(
              controller: _distanceController,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              decoration: InputDecoration(
                labelText: 'Distance comptabilisée (km)',
                helperText:
                    'Distance totale ajoutée à chaque utilisation, A/R inclus.',
                helperMaxLines: 2,
                suffixText: 'km',
                border: const OutlineInputBorder(),
                errorText: _distanceError,
                errorMaxLines: 2,
              ),
            ),
            SwitchListTile(
              value: _defaultRoundTrip,
              onChanged: (value) =>
                  setState(() => _defaultRoundTrip = value),
              title: const Text('Aller-retour'),
              subtitle:
                  const Text('Indicatif : ne modifie pas la distance saisie.'),
              contentPadding: EdgeInsets.zero,
            ),
            TextField(
              controller: _originController,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(
                labelText: 'Départ (facultatif)',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: AppSpacing.m),
            TextField(
              controller: _destinationController,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(
                labelText: 'Destination (facultatif)',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: AppSpacing.m),
            TextField(
              controller: _purposeController,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(
                labelText: 'Motif (facultatif)',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: AppSpacing.l),
            FilledButton(
              onPressed: _submit,
              style: FilledButton.styleFrom(
                minimumSize:
                    const Size.fromHeight(AppSizes.minTouchTarget + 4),
              ),
              child: Text(isEditing ? 'Enregistrer' : 'Créer le favori'),
            ),
            const SizedBox(height: AppSpacing.s),
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              style: TextButton.styleFrom(
                minimumSize: const Size.fromHeight(AppSizes.minTouchTarget),
              ),
              child: const Text('Annuler'),
            ),
            if (isEditing && widget.onDeleteRequested != null)
              TextButton.icon(
                key: const Key('delete-favorite-from-form'),
                onPressed: () async {
                  final deleted = await widget.onDeleteRequested!();
                  if (deleted && context.mounted) {
                    Navigator.of(context).pop();
                  }
                },
                icon: const Icon(Icons.delete_outline),
                label: const Text('Supprimer le favori'),
                style: TextButton.styleFrom(
                  foregroundColor: theme.colorScheme.error,
                  minimumSize:
                      const Size.fromHeight(AppSizes.minTouchTarget),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
