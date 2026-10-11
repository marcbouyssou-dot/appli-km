import 'package:flutter/material.dart';

import '../../theme/tokens.dart';
import '../../widgets/km_format.dart';

/// Évolution mensuelle : 12 barres, construction maison.
///
/// Choix délibéré plutôt que fl_chart : un seul graphique à barres sans
/// interaction (aucune précision tactile requise), rendu identique
/// clair/sombre via le thème, ~80 lignes et zéro dépendance — fl_chart
/// (maintenu) resterait pertinent si des graphiques riches arrivaient.
/// Le graphique illustre ; les chiffres exacts restent lisibles ailleurs
/// (il n'est pas indispensable à la compréhension).
class MonthlyBarChart extends StatelessWidget {
  const MonthlyBarChart({super.key, required this.monthlyTotals});

  /// 12 totaux, index 0 = janvier.
  final List<double> monthlyTotals;

  static const _labels = [
    'J', 'F', 'M', 'A', 'M', 'J', 'J', 'A', 'S', 'O', 'N', 'D', //
  ];

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    var max = 0.0;
    var maxIndex = -1;
    for (var i = 0; i < monthlyTotals.length; i++) {
      if (monthlyTotals[i] > max) {
        max = monthlyTotals[i];
        maxIndex = i;
      }
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          height: 120,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              for (var i = 0; i < 12; i++)
                Expanded(
                  child: Padding(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 2),
                    child: Container(
                      height: max == 0
                          ? 2
                          : 2 + (monthlyTotals[i] / max) * 110,
                      decoration: BoxDecoration(
                        color: monthlyTotals[i] > 0
                            ? theme.colorScheme.primary
                            : theme.colorScheme.surfaceContainerHighest,
                        borderRadius: const BorderRadius.vertical(
                          top: Radius.circular(4),
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.xs),
        Row(
          children: [
            for (var i = 0; i < 12; i++)
              Expanded(
                child: Text(
                  _labels[i],
                  textAlign: TextAlign.center,
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
          ],
        ),
        if (maxIndex >= 0) ...[
          const SizedBox(height: AppSpacing.s),
          Text(
            'Maximum : ${_monthName(maxIndex)} — ${formatKmGrouped(max)}',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ],
    );
  }

  static String _monthName(int index) => const [
        'janvier', 'février', 'mars', 'avril', 'mai', 'juin', //
        'juillet', 'août', 'septembre', 'octobre', 'novembre', 'décembre',
      ][index];
}
