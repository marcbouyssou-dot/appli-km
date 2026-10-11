import 'package:flutter/material.dart';

import '../../theme/tokens.dart';
import '../../widgets/placeholder_card.dart';
import '../backup/backup_screen.dart';
import '../today/manage_favorites_screen.dart';
import '../vehicles/vehicles_screen.dart';

class MoreScreen extends StatelessWidget {
  const MoreScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.l),
      children: [
        const ScreenTitle('Plus'),
        // Gestion GLOBALE des trajets favoris (créer/modifier/supprimer/
        // réordonner) — volontairement hors du contexte d'une journée.
        ListTile(
          leading: Icon(Icons.star_outline, color: theme.colorScheme.primary),
          title: const Text('Trajets favoris'),
          subtitle: const Text('Favoris proposés sur toutes les journées'),
          trailing: const Icon(Icons.chevron_right),
          minTileHeight: AppSizes.minTouchTarget + 8,
          onTap: () {
            Navigator.of(context).push(MaterialPageRoute<void>(
              builder: (_) => const ManageFavoritesScreen(),
            ));
          },
        ),
        ListTile(
          leading: Icon(Icons.directions_car_outlined,
              color: theme.colorScheme.primary),
          title: const Text('Véhicules'),
          subtitle: const Text('Gérer vos véhicules et le principal'),
          trailing: const Icon(Icons.chevron_right),
          minTileHeight: AppSizes.minTouchTarget + 8,
          onTap: () {
            Navigator.of(context).push(MaterialPageRoute<void>(
              builder: (_) => const VehiclesScreen(),
            ));
          },
        ),
        const _UpcomingTile(
          icon: Icons.description_outlined,
          title: 'Documents',
        ),
        ListTile(
          leading:
              Icon(Icons.save_alt_outlined, color: theme.colorScheme.primary),
          title: const Text('Sauvegarde'),
          subtitle: const Text('Exporter ou restaurer vos données'),
          trailing: const Icon(Icons.chevron_right),
          minTileHeight: AppSizes.minTouchTarget + 8,
          onTap: () {
            Navigator.of(context).push(MaterialPageRoute<void>(
              builder: (_) => const BackupScreen(),
            ));
          },
        ),
        const _UpcomingTile(
          icon: Icons.settings_outlined,
          title: 'Réglages',
        ),
        const SizedBox(height: AppSpacing.l),
        const PlaceholderCard(
          icon: Icons.construction_outlined,
          title: 'Ces sections seront activées dans les prochains lots',
        ),
      ],
    );
  }
}

class _UpcomingTile extends StatelessWidget {
  const _UpcomingTile({required this.icon, required this.title});

  final IconData icon;
  final String title;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return ListTile(
      leading: Icon(icon, color: theme.colorScheme.primary),
      title: Text(title),
      trailing: Text(
        'À venir',
        style: theme.textTheme.labelMedium?.copyWith(
          color: theme.colorScheme.onSurfaceVariant,
        ),
      ),
      enabled: false,
      minTileHeight: AppSizes.minTouchTarget,
    );
  }
}
