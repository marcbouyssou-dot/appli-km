import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../theme/tokens.dart';
import '../../widgets/placeholder_card.dart';

class TodayScreen extends StatelessWidget {
  const TodayScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final today = DateFormat('EEEE d MMMM yyyy', 'fr_FR').format(
      DateTime.now(),
    );

    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.l),
      children: [
        const ScreenTitle('Aujourd’hui'),
        Text(
          _capitalize(today),
          style: theme.textTheme.titleMedium?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: AppSpacing.xl),
        Card(
          child: Padding(
            padding: const EdgeInsets.symmetric(
              vertical: AppSpacing.xxl,
              horizontal: AppSpacing.xl,
            ),
            child: Column(
              children: [
                Text(
                  '0 km',
                  style: theme.textTheme.displayLarge?.copyWith(
                    fontWeight: FontWeight.w800,
                    color: theme.colorScheme.primary,
                  ),
                ),
                const SizedBox(height: AppSpacing.s),
                Text(
                  'aujourd’hui',
                  style: theme.textTheme.titleMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.l),
        const PlaceholderCard(
          icon: Icons.add_road,
          title: 'La saisie des kilomètres arrive bientôt',
          subtitle: 'Elle sera disponible dans le prochain lot fonctionnel.',
        ),
      ],
    );
  }

  String _capitalize(String value) =>
      value.isEmpty ? value : value[0].toUpperCase() + value.substring(1);
}
