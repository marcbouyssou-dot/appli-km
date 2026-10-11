import 'package:flutter/material.dart';

import '../../theme/tokens.dart';
import '../../widgets/placeholder_card.dart';

class CalendarScreen extends StatelessWidget {
  const CalendarScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.l),
      children: const [
        ScreenTitle('Calendrier'),
        PlaceholderCard(
          icon: Icons.calendar_month,
          title: 'Le calendrier de vos kilomètres',
          subtitle:
              'Vue mensuelle, détail par journée et congés arriveront ici.',
        ),
      ],
    );
  }
}
