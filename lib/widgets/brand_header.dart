import 'package:flutter/material.dart';

import '../theme/app_typography.dart';
import '../theme/tokens.dart';

/// En-tête de marque Mes Km (UX-001D) — direction humaine finale.
///
/// [petite voiture]  Mes Km
///                   Vos kilomètres professionnels, simplement.
///
/// Le pictogramme est la petite voiture rouge dessinée à la main dans son
/// cadre vert (asset validé humainement — JAMAIS remplacé par une icône
/// Material ou un dessin « professionnalisé »). Rouge et vert sont des
/// couleurs DE MARQUE du logo : elles ne rejoignent pas le design system.
///
/// Compact, directement sur le fond : pas de Card, pas d'ombre, pas de
/// capsule, pas de route ici (la route vit en filigrane des écrans).
class MesKmBrandHeader extends StatelessWidget {
  const MesKmBrandHeader({super.key});

  /// Slogan validé — texte EXACT, jamais reformulé.
  static const slogan = 'Vos kilomètres professionnels, simplement.';

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(
        top: AppSpacing.m,
        bottom: AppSpacing.s,
      ),
      child: Row(
        children: [
          // Fond clair du dessin conservé tel quel, même en sombre
          // (couleurs du logo jamais inversées : voiture rouge, cadre vert).
          ClipRRect(
            borderRadius: BorderRadius.circular(AppRadius.s),
            child: Image.asset(
              'assets/brand/meskm-logo.png',
              width: 40,
              height: 40,
              filterQuality: FilterQuality.medium,
              // Décoratif pour VoiceOver : le nom est porté par le texte
              // adjacent — jamais lu deux fois.
              excludeFromSemantics: true,
            ),
          ),
          const SizedBox(width: AppSpacing.m),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Mes Km',
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.3,
                  ),
                ),
                const SizedBox(height: 1),
                Text(
                  slogan,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: AppTypography.caption.copyWith(
                    fontSize: 12,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
