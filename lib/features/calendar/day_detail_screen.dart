import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../domain/models/civil_date.dart';
import '../day/day_view.dart';

/// Détail d'une journée (passée ou courante) ouvert depuis le calendrier.
/// Réutilise la vue de journée partagée — même compteur, mêmes trajets,
/// même effacement qu'Aujourd'hui. Pas de favoris ici (geste quotidien).
class DayDetailScreen extends StatelessWidget {
  const DayDetailScreen({super.key, required this.date});

  final CivilDate date;

  @override
  Widget build(BuildContext context) {
    final dateText =
        DateFormat('EEEE d MMMM yyyy', 'fr_FR').format(date.toDateTime());

    return Scaffold(
      appBar: AppBar(
        title: Text(dateText[0].toUpperCase() + dateText.substring(1)),
      ),
      body: SafeArea(
        child: DayView(
          date: date,
          header: const [SizedBox(height: 8)],
        ),
      ),
    );
  }
}
