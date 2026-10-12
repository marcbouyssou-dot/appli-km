import 'package:flutter/material.dart';

import '../../theme/mes_km_colors.dart';
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

    // VoiceOver (UX-007B) : UN résumé concis pour tout le graphique —
    // les barres restent purement visuelles (données déjà disponibles,
    // aucun nouveau calcul).
    final semanticsSummary = max == 0
        ? 'Évolution mensuelle des kilomètres. '
            'Aucun kilomètre enregistré.'
        : 'Évolution mensuelle des kilomètres. '
            'Maximum : ${_monthName(maxIndex)}, ${formatKmGrouped(max)}.';

    return Semantics(
      label: semanticsSummary,
      container: true,
      child: ExcludeSemantics(
        child: Column(
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
                        // UX-001C : le maximum porte le bleu Mes Km franc
                        // (dégradé vers le turquoise, cohérent avec le
                        // héros) ; les autres mois restent bleu-turquoise
                        // très clair. Jamais 12 couleurs.
                        color: monthlyTotals[i] > 0 && i != maxIndex
                            ? Color.lerp(
                                theme.colorScheme.primary,
                                theme.mesKm.mobility,
                                0.35,
                              )!
                                .withValues(alpha: 0.30)
                            : monthlyTotals[i] > 0
                                ? null
                                : theme
                                    .colorScheme.surfaceContainerHighest,
                        gradient: monthlyTotals[i] > 0 && i == maxIndex
                            ? LinearGradient(
                                begin: Alignment.bottomCenter,
                                end: Alignment.topCenter,
                                colors: [
                                  theme.colorScheme.primary,
                                  Color.lerp(
                                    theme.colorScheme.primary,
                                    theme.mesKm.mobility,
                                    0.55,
                                  )!,
                                ],
                              )
                            : null,
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
        ),
      ),
    );
  }

  static String _monthName(int index) => const [
        'janvier', 'février', 'mars', 'avril', 'mai', 'juin', //
        'juillet', 'août', 'septembre', 'octobre', 'novembre', 'décembre',
      ][index];
}
