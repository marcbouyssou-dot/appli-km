import 'package:flutter/material.dart';

import '../theme/app_typography.dart';
import '../theme/tokens.dart';

/// Pastille kilométrique (UX-001) : la valeur ajoutée par un favori
/// (« +24 km »). Chiffres tabulaires, teinte primaire contenue.
class KmBadge extends StatelessWidget {
  const KmBadge(this.text, {super.key});

  final String text;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.m,
        vertical: AppSpacing.s,
      ),
      decoration: BoxDecoration(
        color: scheme.primaryContainer,
        borderRadius: BorderRadius.circular(AppRadius.s),
      ),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w700,
          fontFeatures: AppTypography.tabularFigures,
          color: scheme.onPrimaryContainer,
        ),
      ),
    );
  }
}
