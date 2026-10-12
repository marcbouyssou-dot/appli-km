import 'package:flutter/material.dart';

import '../theme/tokens.dart';

/// Carte neutre annonçant une fonctionnalité à venir.
/// Utilisée par les écrans coquille de KM-001.
class PlaceholderCard extends StatelessWidget {
  const PlaceholderCard({
    super.key,
    required this.icon,
    required this.title,
    this.subtitle,
  });

  final IconData icon;
  final String title;
  final String? subtitle;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: Column(
          children: [
            Icon(
              icon,
              size: 44,
              color: theme.colorScheme.primary,
            ),
            const SizedBox(height: AppSpacing.l),
            Text(
              title,
              textAlign: TextAlign.center,
              style: theme.textTheme.titleMedium,
            ),
            if (subtitle != null) ...[
              const SizedBox(height: AppSpacing.s),
              Text(
                subtitle!,
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// En-tête de page commun : grand titre iOS, aligné à gauche.
class ScreenTitle extends StatelessWidget {
  const ScreenTitle(
    this.title, {
    super.key,
    this.topSpacing = AppSpacing.l,
    this.bottomSpacing = AppSpacing.xl,
  });

  final String title;
  final double topSpacing;
  final double bottomSpacing;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        top: topSpacing,
        bottom: bottomSpacing,
      ),
      child: Text(
        title,
        style: Theme.of(context).textTheme.headlineLarge?.copyWith(
              fontWeight: FontWeight.bold,
            ),
      ),
    );
  }
}
