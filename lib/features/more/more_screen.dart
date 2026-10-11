import 'package:flutter/material.dart';

import '../../theme/tokens.dart';
import '../../widgets/placeholder_card.dart';
import '../../widgets/section_header.dart';
import '../backup/backup_screen.dart';
import '../documents/documents_screen.dart';
import '../settings/settings_screen.dart';
import '../today/manage_favorites_screen.dart';
import '../vehicles/vehicles_screen.dart';

/// Plus (UX-001B) : trois groupes légers — pas de « réglages Material ».
/// Mêmes cinq destinations, mêmes libellés, mêmes navigations.
class MoreScreen extends StatelessWidget {
  const MoreScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    Widget row({
      required IconData icon,
      required String title,
      required String subtitle,
      required Widget Function() screen,
    }) {
      return InkWell(
        onTap: () {
          Navigator.of(context).push(MaterialPageRoute<void>(
            builder: (_) => screen(),
          ));
        },
        borderRadius: BorderRadius.circular(AppRadius.s),
        child: ConstrainedBox(
          constraints: const BoxConstraints(
            minHeight: AppSizes.minTouchTarget + 8,
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: AppSpacing.s),
            child: Row(
              children: [
                // Traitement signature : icône contour dans un cercle
                // léger, une seule teinte (jamais cinq couleurs).
                Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: theme.colorScheme.primaryContainer
                        .withValues(alpha: 0.55),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    icon,
                    size: 20,
                    color: theme.colorScheme.primary,
                  ),
                ),
                const SizedBox(width: AppSpacing.l),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 1),
                      Text(
                        subtitle,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(
                  Icons.chevron_right,
                  size: 20,
                  color: theme.colorScheme.outline,
                ),
              ],
            ),
          ),
        ),
      );
    }

    Widget hairline() =>
        Divider(height: 1, color: theme.colorScheme.outlineVariant);

    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.l),
      children: [
        const ScreenTitle('Plus'),

        const SectionHeader('MES TRAJETS', topSpacing: 0),
        // Gestion GLOBALE des trajets favoris (créer/modifier/supprimer/
        // réordonner) — volontairement hors du contexte d'une journée.
        row(
          icon: Icons.star_outline,
          title: 'Trajets favoris',
          subtitle: 'Favoris proposés sur toutes les journées',
          screen: () => const ManageFavoritesScreen(),
        ),
        hairline(),
        row(
          icon: Icons.directions_car_outlined,
          title: 'Véhicules',
          subtitle: 'Gérer vos véhicules et le principal',
          screen: () => const VehiclesScreen(),
        ),

        const SectionHeader('MES DONNÉES'),
        row(
          icon: Icons.description_outlined,
          title: 'Documents',
          subtitle: 'Relevé annuel PDF et détail CSV',
          screen: () => const DocumentsScreen(),
        ),
        hairline(),
        row(
          icon: Icons.save_alt_outlined,
          title: 'Sauvegarde',
          subtitle: 'Exporter ou restaurer vos données',
          screen: () => const BackupScreen(),
        ),

        const SectionHeader('APPLICATION'),
        row(
          icon: Icons.settings_outlined,
          title: 'Réglages',
          subtitle: 'Informations pour les documents',
          screen: () => const SettingsScreen(),
        ),
        const SizedBox(height: AppSpacing.xxl),
      ],
    );
  }
}
