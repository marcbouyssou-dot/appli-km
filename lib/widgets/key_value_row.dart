import 'package:flutter/material.dart';

import '../theme/app_typography.dart';
import '../theme/tokens.dart';

/// Ligne libellé/valeur partagée (UX-001) — aperçu de sauvegarde, détails.
/// Le libellé s'étend (jamais d'overflow), la valeur est nette et tabulaire.
class KeyValueRow extends StatelessWidget {
  const KeyValueRow({super.key, required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.xs),
      child: Row(
        children: [
          Expanded(child: Text(label)),
          const SizedBox(width: AppSpacing.s),
          Text(
            value,
            style: const TextStyle(
              fontWeight: FontWeight.w700,
              fontFeatures: AppTypography.tabularFigures,
            ),
          ),
        ],
      ),
    );
  }
}
