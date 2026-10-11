import 'package:flutter/material.dart';

import '../../theme/tokens.dart';
import '../../widgets/placeholder_card.dart';

class MoreScreen extends StatelessWidget {
  const MoreScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.l),
      children: const [
        ScreenTitle('Plus'),
        _UpcomingTile(
          icon: Icons.directions_car_outlined,
          title: 'Véhicules',
        ),
        _UpcomingTile(
          icon: Icons.description_outlined,
          title: 'Documents',
        ),
        _UpcomingTile(
          icon: Icons.save_alt_outlined,
          title: 'Sauvegarde',
        ),
        _UpcomingTile(
          icon: Icons.settings_outlined,
          title: 'Réglages',
        ),
        SizedBox(height: AppSpacing.l),
        PlaceholderCard(
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
