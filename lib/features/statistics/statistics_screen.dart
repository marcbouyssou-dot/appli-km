import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../theme/tokens.dart';
import '../../widgets/km_format.dart';
import '../../widgets/placeholder_card.dart';
import 'monthly_bar_chart.dart';
import 'statistics_controller.dart';

class StatisticsScreen extends ConsumerWidget {
  const StatisticsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(statisticsControllerProvider);

    return state.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, _) => Center(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.xl),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Text('Impossible de charger les statistiques.'),
              const SizedBox(height: AppSpacing.l),
              FilledButton(
                onPressed: () =>
                    ref.invalidate(statisticsControllerProvider),
                child: const Text('Réessayer'),
              ),
            ],
          ),
        ),
      ),
      data: (stats) => _StatisticsView(stats: stats),
    );
  }
}

class _StatisticsView extends ConsumerWidget {
  const _StatisticsView({required this.stats});

  final StatisticsState stats;

  String _percentText(double percent) {
    final rounded = (percent * 10).round() / 10;
    final text = rounded
        .toStringAsFixed(rounded == rounded.roundToDouble() ? 0 : 1)
        .replaceAll('.', ',');
    return '${rounded >= 0 ? '+' : ''}$text %';
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final controller = ref.read(statisticsControllerProvider.notifier);
    final delta = stats.previousYearDelta;
    final percent = stats.previousYearPercent;

    Widget sectionTitle(String text) => Padding(
          padding: const EdgeInsets.only(
            top: AppSpacing.xl,
            bottom: AppSpacing.s,
          ),
          child: Text(
            text,
            style: theme.textTheme.labelLarge?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
              letterSpacing: 1.1,
            ),
          ),
        );

    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.l),
      children: [
        const ScreenTitle('Statistiques'),

        // Navigation d'année : chevrons larges.
        Row(
          children: [
            IconButton(
              key: const Key('stats-prev-year'),
              onPressed: controller.previousYear,
              icon: const Icon(Icons.chevron_left),
              iconSize: 30,
              tooltip: 'Année précédente',
            ),
            Expanded(
              child: Text(
                '${stats.year}',
                textAlign: TextAlign.center,
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            IconButton(
              key: const Key('stats-next-year'),
              onPressed: controller.nextYear,
              icon: const Icon(Icons.chevron_right),
              iconSize: 30,
              tooltip: 'Année suivante',
            ),
          ],
        ),
        if (!stats.isCurrentYear)
          Center(
            child: TextButton(
              key: const Key('stats-today-button'),
              onPressed: controller.goToCurrentYear,
              child: const Text('Revenir à cette année'),
            ),
          ),

        // TOTAL ANNÉE — le chiffre le plus important, en grand.
        sectionTitle('TOTAL ANNÉE'),
        Card(
          child: Padding(
            padding: const EdgeInsets.symmetric(
              vertical: AppSpacing.xl,
              horizontal: AppSpacing.xl,
            ),
            child: Column(
              children: [
                Text(
                  formatKmGrouped(stats.yearTotal),
                  textAlign: TextAlign.center,
                  style: theme.textTheme.headlineLarge?.copyWith(
                    fontWeight: FontWeight.w800,
                    color: theme.colorScheme.primary,
                  ),
                ),
                if (delta != null) ...[
                  const SizedBox(height: AppSpacing.s),
                  Text(
                    'vs ${stats.year - 1} : '
                    '${formatKmGrouped(stats.previousYearTotal!)} · '
                    '${delta >= 0 ? '+' : '−'}'
                    '${formatKmGrouped(delta.abs())}'
                    '${percent == null ? '' : ' (${_percentText(percent)})'}',
                    textAlign: TextAlign.center,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),

        // Mois sélectionné (indépendant du calendrier principal).
        sectionTitle('MOIS'),
        Card(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: AppSpacing.s),
            child: Row(
              children: [
                IconButton(
                  key: const Key('stats-prev-month'),
                  onPressed: controller.previousMonth,
                  icon: const Icon(Icons.chevron_left),
                  tooltip: 'Mois précédent',
                ),
                Expanded(
                  child: Column(
                    children: [
                      Text(
                        _StatisticsScreenNames
                            .monthLabel(stats.month, stats.year),
                        style: theme.textTheme.titleMedium,
                      ),
                      Text(
                        formatKmGrouped(stats.selectedMonthTotal),
                        style: theme.textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: theme.colorScheme.primary,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  key: const Key('stats-next-month'),
                  onPressed: controller.nextMonth,
                  icon: const Icon(Icons.chevron_right),
                  tooltip: 'Mois suivant',
                ),
              ],
            ),
          ),
        ),

        const SizedBox(height: AppSpacing.m),
        Row(
          children: [
            Expanded(
              child: _SmallStat(
                label: 'Jours avec km',
                value: '${stats.activeDays}',
              ),
            ),
            const SizedBox(width: AppSpacing.m),
            Expanded(
              child: _SmallStat(
                label: 'Moyenne / jour actif',
                value: formatKm(stats.averagePerActiveDay),
              ),
            ),
          ],
        ),

        sectionTitle('ÉVOLUTION MENSUELLE'),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.l),
            child: MonthlyBarChart(monthlyTotals: stats.monthlyTotals),
          ),
        ),

        sectionTitle('PAR VÉHICULE'),
        if (stats.vehicleStats.isEmpty)
          Text(
            stats.yearTotal == 0
                ? 'Aucun kilomètre enregistré en ${stats.year}.'
                : 'Aucune attribution de véhicule.',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          )
        else
          Card(
            child: Column(
              children: [
                for (final stat in stats.vehicleStats)
                  ListTile(
                    key: Key('vehicle-stat-${stat.vehicleId ?? 'none'}'),
                    minTileHeight: AppSizes.minTouchTarget + 8,
                    title: Text(
                      stat.isArchived
                          ? '${stat.label} (archivé)'
                          : stat.label,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    subtitle: Text(
                      '${_StatisticsScreenNames.shortMonth(stats.month)} : '
                      '${formatKmGrouped(stat.monthKm)} · '
                      '${stats.year} : ${formatKmGrouped(stat.yearKm)}',
                    ),
                  ),
              ],
            ),
          ),

        if (stats.vacationDays > 0) ...[
          const SizedBox(height: AppSpacing.l),
          Text(
            'Jours de congé : ${stats.vacationDays}',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
        const SizedBox(height: AppSpacing.xxl),
      ],
    );
  }
}

class _SmallStat extends StatelessWidget {
  const _SmallStat({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.l),
        child: Column(
          children: [
            Text(
              value,
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
                color: theme.colorScheme.primary,
              ),
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              label,
              textAlign: TextAlign.center,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

abstract final class _StatisticsScreenNames {
  static const _months = [
    'Janvier', 'Février', 'Mars', 'Avril', 'Mai', 'Juin', //
    'Juillet', 'Août', 'Septembre', 'Octobre', 'Novembre', 'Décembre',
  ];

  static String monthLabel(int month, int year) =>
      '${_months[month - 1]} $year';

  static String shortMonth(int month) => _months[month - 1];
}
