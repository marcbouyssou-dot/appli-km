import 'package:flutter/material.dart';

import '../theme/mes_km_colors.dart';
import '../theme/tokens.dart';

enum StatusBannerKind { info, success, warning, error }

/// Bandeau d'état partagé (UX-001). L'information n'est JAMAIS portée par la
/// seule couleur : le texte (et une icône) disent toujours la même chose.
/// warning = provisoire / à compléter (dont la simulation fiscale).
class StatusBanner extends StatelessWidget {
  const StatusBanner({
    super.key,
    required this.kind,
    required this.text,
  });

  final StatusBannerKind kind;
  final String text;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final semantic = theme.mesKm;
    final scheme = theme.colorScheme;

    final (background, foreground, icon) = switch (kind) {
      StatusBannerKind.info => (
          scheme.primaryContainer,
          scheme.onPrimaryContainer,
          Icons.info_outline,
        ),
      StatusBannerKind.success => (
          semantic.successContainer,
          semantic.onSuccessContainer,
          Icons.check_circle_outline,
        ),
      StatusBannerKind.warning => (
          semantic.warningContainer,
          semantic.onWarningContainer,
          Icons.schedule_outlined,
        ),
      StatusBannerKind.error => (
          scheme.errorContainer,
          scheme.onErrorContainer,
          Icons.error_outline,
        ),
    };

    return Container(
      padding: const EdgeInsets.all(AppSpacing.m),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(AppRadius.s),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 20, color: foreground),
          const SizedBox(width: AppSpacing.s),
          Expanded(
            child: Text(
              text,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: foreground,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
