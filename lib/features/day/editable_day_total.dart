import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/logic/day_total.dart';
import '../../domain/models/civil_date.dart';
import '../../domain/models/km.dart';
import '../../theme/tokens.dart';
import '../../widgets/km_format.dart';
import 'day_controller.dart';

/// Clé du champ du total du jour (ciblage dans les tests).
const dayTotalFieldKey = Key('day-total-field');

/// Clé de la carte tactile entière du total du jour.
const dayTotalCardKey = Key('day-total-card');

/// La grande valeur du jour, directement éditable :
/// toucher → clavier décimal → saisir → terminé (focus perdu ou « OK »).
///
/// Aucune logique métier ici : la validation passe par
/// `TodayController.declareTotal` (domaine). La persistance n'a lieu qu'à la
/// fin de l'édition, jamais à chaque touche. Un refus métier (total inférieur
/// aux trajets détaillés) restaure la dernière valeur valide et s'explique
/// par une snackbar.
class EditableDayTotal extends ConsumerStatefulWidget {
  const EditableDayTotal({
    super.key,
    required this.date,
    required this.totalKm,
  });

  /// Journée éditée : toutes les opérations métier utilisent cette date.
  final CivilDate date;
  final double totalKm;

  @override
  ConsumerState<EditableDayTotal> createState() => _EditableDayTotalState();
}

class _EditableDayTotalState extends ConsumerState<EditableDayTotal> {
  late final TextEditingController _controller =
      TextEditingController(text: formatKmValue(widget.totalKm));
  final FocusNode _focusNode = FocusNode();
  bool _committing = false;

  @override
  void initState() {
    super.initState();
    _focusNode.addListener(_onFocusChanged);
  }

  @override
  void didUpdateWidget(EditableDayTotal oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!_focusNode.hasFocus && oldWidget.totalKm != widget.totalKm) {
      _controller.text = formatKmValue(widget.totalKm);
    }
  }

  @override
  void dispose() {
    _focusNode.removeListener(_onFocusChanged);
    _focusNode.dispose();
    _controller.dispose();
    super.dispose();
  }

  void _onFocusChanged() {
    if (_focusNode.hasFocus) {
      // Effet « compteur » : le champ se vide au focus, l'ancienne valeur
      // reste visible en filigrane (hint) et la première frappe la remplace
      // naturellement — sans sélection bleue ni poignées iOS.
      _controller.clear();
    } else {
      _commit();
    }
  }

  void _restore() {
    _controller.text = formatKmValue(widget.totalKm);
  }

  Future<void> _commit() async {
    if (_committing) return;
    _committing = true;
    try {
      final value = parseKmInput(_controller.text);
      if (value == null || value < 0) {
        // Édition abandonnée (champ vide) ou saisie invalide :
        // on restaure la valeur courante, sans rien écrire.
        _restore();
        return;
      }
      if (normalizeKm(value) == normalizeKm(widget.totalKm)) {
        _restore(); // inchangé : pas d'écriture inutile
        return;
      }

      final result = await ref
          .read(dayControllerProvider(widget.date).notifier)
          .declareTotal(value);

      if (!mounted) return;
      if (result is DailyTotalBelowDetailed) {
        _restore();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Les trajets détaillés totalisent déjà '
              '${formatKm(result.detailedKm)}.',
            ),
          ),
        );
      }
      // Succès : le rebuild (nouveau totalKm) resynchronise le texte.
    } finally {
      _committing = false;
    }
  }

  /// Entrée en édition depuis n'importe quel point de la carte :
  /// focus immédiat (la sélection intégrale suit via _onFocusChanged).
  void _activateEditing() {
    if (!_focusNode.hasFocus) {
      _focusNode.requestFocus();
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final valueStyle = theme.textTheme.displayLarge?.copyWith(
      fontWeight: FontWeight.w800,
      color: theme.colorScheme.primary,
    );

    // TOUTE la carte est tactile : pas besoin de viser les chiffres.
    return Card(
      key: dayTotalCardKey,
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: _activateEditing,
        child: Padding(
          padding: const EdgeInsets.symmetric(
            vertical: AppSpacing.xxl,
            horizontal: AppSpacing.xl,
          ),
          child: Column(
            children: [
              TextField(
                key: dayTotalFieldKey,
                controller: _controller,
                focusNode: _focusNode,
                textAlign: TextAlign.center,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                textInputAction: TextInputAction.done,
                onSubmitted: (_) => _focusNode.unfocus(),
                // Aspect compteur : pas de sélection interactive (donc pas
                // de poignées ni de surlignage), pas de suggestions.
                enableInteractiveSelection: false,
                autocorrect: false,
                enableSuggestions: false,
                // Compteur : pas de curseur clignotant (la frappe reste
                // visible, le contrôle reste un vrai champ accessible).
                showCursor: false,
                style: valueStyle,
                decoration: InputDecoration(
                  isCollapsed: true,
                  border: InputBorder.none,
                  // Pendant l'édition (champ vidé), l'ancienne valeur reste
                  // affichée en filigrane, même taille, même place.
                  hintText: formatKmValue(widget.totalKm),
                  hintStyle: valueStyle?.copyWith(
                    color: theme.colorScheme.primary
                        .withValues(alpha: 0.30),
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.s),
              Text(
                'km aujourd’hui',
                style: theme.textTheme.titleMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: AppSpacing.s),
              Text(
                'Touchez la carte pour modifier le total',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
