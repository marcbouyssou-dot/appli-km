import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../theme/app_typography.dart';
import '../theme/tokens.dart';
import 'app_buttons.dart';

/// Squelette des feuilles de formulaire Mes Km (UX-003B).
///
/// CAS COURANT D'ABORD : en-tête compact (titre, aide d'une ligne,
/// « Annuler » discret), corps défilant, et action principale ÉPINGLÉE en
/// pied — toujours accessible clavier ouvert, sans jamais recouvrir le champ
/// actif ni ses messages d'erreur (le corps défile au-dessus de la zone
/// d'action). Réutilise uniquement le design system existant.
class FormSheetScaffold extends StatelessWidget {
  const FormSheetScaffold({
    super.key,
    required this.title,
    this.help,
    required this.children,
    required this.primaryLabel,
    required this.onPrimary,
  });

  final String title;

  /// Aide concise (une ligne) sous le titre — jamais un paragraphe.
  final String? help;
  final List<Widget> children;
  final String primaryLabel;

  /// null = action indisponible : le bouton prend l'état désactivé du
  /// design system (garde UX précoce — les validations métier restent
  /// autoritaires au submit).
  final VoidCallback? onPrimary;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final viewInsets = MediaQuery.viewInsetsOf(context).bottom;
    final bottomSafe = MediaQuery.viewPaddingOf(context).bottom;
    final maxHeight = MediaQuery.sizeOf(context).height * 0.92;

    return Padding(
      padding: EdgeInsets.only(bottom: viewInsets),
      child: ConstrainedBox(
        constraints: BoxConstraints(maxHeight: maxHeight),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.only(
                left: AppSpacing.xl,
                right: AppSpacing.m,
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(title, style: theme.textTheme.titleLarge),
                        if (help != null)
                          Padding(
                            padding:
                                const EdgeInsets.only(top: AppSpacing.xs),
                            child: Text(
                              help!,
                              style: AppTypography.caption.copyWith(
                                color: theme.colorScheme.onSurfaceVariant,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                  // Annulation compacte : complète le geste de balayage.
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text('Annuler'),
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.s),
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.xl,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: children,
                ),
              ),
            ),
            // Zone d'action épinglée : hors défilement, au-dessus du clavier.
            Container(
              padding: EdgeInsets.fromLTRB(
                AppSpacing.xl,
                AppSpacing.m,
                AppSpacing.xl,
                viewInsets > 0
                    ? AppSpacing.m
                    : math.max(bottomSafe, AppSpacing.m),
              ),
              decoration: BoxDecoration(
                color: theme.colorScheme.surface,
                border: Border(
                  top: BorderSide(color: theme.colorScheme.outlineVariant),
                ),
              ),
              child: PrimaryButton(
                label: primaryLabel,
                onPressed: onPrimary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Section facultative repliable (UX-003B) : « Itinéraire et détails ».
///
/// Repliée à la création ; dépliée automatiquement en édition quand elle
/// contient déjà des valeurs. Le caractère facultatif est porté par la
/// section — ses champs n'ont plus de suffixe « (facultatif) ». Bascule
/// instantanée (pas d'animation : aucun saut de mise en page instable).
class FormOptionalSection extends StatefulWidget {
  const FormOptionalSection({
    super.key,
    required this.title,
    this.initiallyExpanded = false,
    required this.children,
  });

  final String title;
  final bool initiallyExpanded;
  final List<Widget> children;

  @override
  State<FormOptionalSection> createState() => _FormOptionalSectionState();
}

class _FormOptionalSectionState extends State<FormOptionalSection> {
  late bool _expanded = widget.initiallyExpanded;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        InkWell(
          key: const Key('optional-section-toggle'),
          onTap: () => setState(() => _expanded = !_expanded),
          borderRadius: BorderRadius.circular(AppRadius.s),
          child: ConstrainedBox(
            constraints:
                const BoxConstraints(minHeight: AppSizes.minTouchTarget),
            child: Row(
              children: [
                Icon(
                  _expanded ? Icons.expand_less : Icons.expand_more,
                  size: 20,
                  color: theme.colorScheme.primary,
                ),
                const SizedBox(width: AppSpacing.s),
                Expanded(
                  child: Text(
                    widget.title,
                    style: theme.textTheme.titleMedium?.copyWith(
                      color: theme.colorScheme.primary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        if (_expanded) ...[
          const SizedBox(height: AppSpacing.s),
          ...widget.children,
        ],
      ],
    );
  }
}
