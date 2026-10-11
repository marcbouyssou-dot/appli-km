import 'package:flutter/material.dart';

import '../../theme/tokens.dart';
import '../../widgets/placeholder_card.dart';

class StatisticsScreen extends StatelessWidget {
  const StatisticsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.l),
      children: const [
        ScreenTitle('Statistiques'),
        PlaceholderCard(
          icon: Icons.bar_chart,
          title: 'Vos statistiques kilométriques',
          subtitle:
              'Totaux, moyennes et graphiques par mois et par année arriveront ici.',
        ),
      ],
    );
  }
}
