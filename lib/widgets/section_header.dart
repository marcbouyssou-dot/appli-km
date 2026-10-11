import 'package:flutter/material.dart';

import '../theme/app_typography.dart';
import '../theme/tokens.dart';

/// Titre de section partagé (UX-001) : petit, semi-gras, légèrement espacé,
/// couleur secondaire. Le TEXTE n'est jamais transformé (les tests et les
/// libellés validés ciblent la chaîne exacte).
class SectionHeader extends StatelessWidget {
  const SectionHeader(
    this.title, {
    super.key,
    this.topSpacing = AppSpacing.xl,
    this.bottomSpacing = AppSpacing.s,
  });

  final String title;
  final double topSpacing;
  final double bottomSpacing;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: EdgeInsets.only(top: topSpacing, bottom: bottomSpacing),
      child: Text(
        title,
        style: AppTypography.sectionTitle.copyWith(
          color: theme.colorScheme.onSurfaceVariant,
        ),
      ),
    );
  }
}
