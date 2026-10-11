import 'package:flutter/material.dart';

import '../../theme/tokens.dart';
import '../../widgets/grouped_list.dart';
import '../../widgets/placeholder_card.dart';
import '../backup/backup_screen.dart';
import '../documents/documents_screen.dart';
import '../settings/settings_screen.dart';
import '../today/manage_favorites_screen.dart';
import '../vehicles/vehicles_screen.dart';

class MoreScreen extends StatelessWidget {
  const MoreScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    Widget tile({
      required IconData icon,
      required String title,
      required String subtitle,
      required Widget Function() screen,
    }) {
      return ListTile(
        leading: Icon(icon, color: theme.colorScheme.primary),
        title: Text(title),
        subtitle: Text(subtitle),
        trailing: const Icon(Icons.chevron_right),
        minTileHeight: AppSizes.minTouchTarget + 8,
        onTap: () {
          Navigator.of(context).push(MaterialPageRoute<void>(
            builder: (_) => screen(),
          ));
        },
      );
    }

    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.l),
      children: [
        const ScreenTitle('Plus'),
        // Une seule surface groupée (UX-001) : mêmes cinq entrées, même
        // ordre — seule la présentation change.
        GroupedList(
          children: [
        // Gestion GLOBALE des trajets favoris (créer/modifier/supprimer/
        // réordonner) — volontairement hors du contexte d'une journée.
        tile(
          icon: Icons.star_outline,
          title: 'Trajets favoris',
          subtitle: 'Favoris proposés sur toutes les journées',
          screen: () => const ManageFavoritesScreen(),
        ),
        tile(
          icon: Icons.directions_car_outlined,
          title: 'Véhicules',
          subtitle: 'Gérer vos véhicules et le principal',
          screen: () => const VehiclesScreen(),
        ),
        tile(
          icon: Icons.description_outlined,
          title: 'Documents',
          subtitle: 'Relevé annuel PDF et détail CSV',
          screen: () => const DocumentsScreen(),
        ),
        tile(
          icon: Icons.save_alt_outlined,
          title: 'Sauvegarde',
          subtitle: 'Exporter ou restaurer vos données',
          screen: () => const BackupScreen(),
        ),
        tile(
          icon: Icons.settings_outlined,
          title: 'Réglages',
          subtitle: 'Informations pour les documents',
          screen: () => const SettingsScreen(),
        ),
          ],
        ),
      ],
    );
  }
}
