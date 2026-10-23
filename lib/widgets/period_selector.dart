import 'package:flutter/material.dart';

import '../theme/tokens.dart';

/// Sélecteur de période partagé (UX-001) : chevrons larges + libellé
/// central. Remplace les trois constructions dupliquées (année des
/// statistiques, année des documents, mois du calendrier).
/// Les [Key] de test sont portées par les chevrons, comme avant.
class PeriodSelector extends StatelessWidget {
  const PeriodSelector({
    super.key,
    required this.label,
    required this.onPrevious,
    required this.onNext,
    required this.previousTooltip,
    required this.nextTooltip,
    this.previousKey,
    this.nextKey,
  });

  final String label;
  final VoidCallback? onPrevious;
  final VoidCallback? onNext;
  final String previousTooltip;
  final String nextTooltip;
  final Key? previousKey;
  final Key? nextKey;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      children: [
        IconButton(
          key: previousKey,
          onPressed: onPrevious,
          icon: const Icon(Icons.chevron_left),
          iconSize: 28,
          tooltip: previousTooltip,
          style: IconButton.styleFrom(
            minimumSize: const Size(
              AppSizes.minTouchTarget + 8,
              AppSizes.minTouchTarget + 8,
            ),
          ),
        ),
        Expanded(
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: theme.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        IconButton(
          key: nextKey,
          onPressed: onNext,
          icon: const Icon(Icons.chevron_right),
          iconSize: 28,
          tooltip: nextTooltip,
          style: IconButton.styleFrom(
            minimumSize: const Size(
              AppSizes.minTouchTarget + 8,
              AppSizes.minTouchTarget + 8,
            ),
          ),
        ),
      ],
    );
  }
}
