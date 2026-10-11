import 'package:flutter/material.dart';

import '../theme/tokens.dart';

/// État vide partagé (UX-001) : texte calme, centré, couleur secondaire.
/// Le libellé reste la chaîne exacte attendue par les tests.
class EmptyState extends StatelessWidget {
  const EmptyState(this.message, {super.key, this.icon});

  final String message;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(
        vertical: AppSpacing.xl,
        horizontal: AppSpacing.l,
      ),
      child: Column(
        children: [
          if (icon != null) ...[
            Icon(icon, size: 32, color: theme.colorScheme.onSurfaceVariant),
            const SizedBox(height: AppSpacing.s),
          ],
          Text(
            message,
            textAlign: TextAlign.center,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}
