import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../app/providers.dart';
import '../../theme/tokens.dart';
import '../../widgets/brand_header.dart';
import '../../widgets/road_watermark.dart';
import '../day/day_view.dart';

/// Aujourd'hui : la vue de journée partagée, datée du jour courant,
/// enrichie des favoris (geste quotidien rapide).
class TodayScreen extends ConsumerWidget {
  const TodayScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final today = ref.watch(todayDateProvider)();
    final dateText = DateFormat('EEEE d MMMM yyyy', 'fr_FR')
        .format(today.toDateTime());

    return MesKmRoadWatermark(
      child: DayView(
        date: today,
        header: [
          const MesKmBrandHeader(),
          // UX-002B : « Aujourd'hui » est déjà porté par l'onglet actif —
          // la date complète est la seule ligne de contexte.
          Text(
            dateText[0].toUpperCase() + dateText.substring(1),
            style: theme.textTheme.titleMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: AppSpacing.m),
        ],
      ),
    );
  }
}
