import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/logic/fiscal_estimator.dart';
import '../../domain/models/vehicle.dart';
import '../../theme/app_typography.dart';
import '../../theme/tokens.dart';
import '../../theme/vehicle_accent.dart';
import '../../widgets/brand_header.dart';
import '../../widgets/empty_state.dart';
import '../../widgets/road_watermark.dart';
import '../../widgets/km_format.dart';
import '../../widgets/period_selector.dart';
import '../../widgets/placeholder_card.dart';
import '../../widgets/section_header.dart';
import '../../widgets/status_banner.dart';
import '../vehicles/vehicles_screen.dart';
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

    return MesKmRoadWatermark(
      variant: RoadWatermarkVariant.top,
      child: ListView(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.l),
      children: [
        const MesKmBrandHeader(),
        const ScreenTitle(
          'Statistiques',
          topSpacing: AppSpacing.s,
          bottomSpacing: AppSpacing.m,
        ),

        // Navigation d'année : sélecteur partagé, chevrons larges.
        PeriodSelector(
          label: '${stats.year}',
          onPrevious: controller.previousYear,
          onNext: controller.nextYear,
          previousKey: const Key('stats-prev-year'),
          nextKey: const Key('stats-next-year'),
          previousTooltip: 'Année précédente',
          nextTooltip: 'Année suivante',
        ),
        if (!stats.isCurrentYear)
          Center(
            child: TextButton(
              key: const Key('stats-today-button'),
              onPressed: controller.goToCurrentYear,
              child: const Text('Revenir à cette année'),
            ),
          ),

        // HÉROS (UX-001B) : le total annuel vit directement dans la page.
        // Encre presque noire — le bleu est réservé aux accents.
        const SizedBox(height: AppSpacing.l),
        Text(
          formatKmGrouped(stats.yearTotal),
          textAlign: TextAlign.center,
          style: theme.textTheme.displayLarge?.copyWith(
            fontSize: 44,
            fontWeight: FontWeight.w800,
            color: theme.colorScheme.onSurface,
          ),
        ),
        const SizedBox(height: AppSpacing.xs),
        Center(
          child: Text(
            'TOTAL ANNÉE',
            style: AppTypography.sectionTitle.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
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

        // Mois sélectionné : même langage, directement dans la page.
        const SizedBox(height: AppSpacing.xl),
        Row(
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
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                  Text(
                    formatKmGrouped(stats.selectedMonthTotal),
                    style: AppTypography.value.copyWith(
                      color: theme.colorScheme.onSurface,
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

        const SizedBox(height: AppSpacing.l),
        Divider(height: 1, color: theme.colorScheme.outlineVariant),
        const SizedBox(height: AppSpacing.l),
        Row(
          children: [
            Expanded(
              child: _InlineStat(
                label: 'Jours avec km',
                value: '${stats.activeDays}',
              ),
            ),
            Expanded(
              child: _InlineStat(
                label: 'Moyenne / jour actif',
                value: formatKm(stats.averagePerActiveDay),
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.l),
        Divider(height: 1, color: theme.colorScheme.outlineVariant),

        const SectionHeader('ÉVOLUTION MENSUELLE'),
        // Le graphique garde sa surface : elle a une fonction (zone de
        // lecture distincte).
        Card(
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.l),
            child: MonthlyBarChart(monthlyTotals: stats.monthlyTotals),
          ),
        ),

        const SectionHeader('PAR VÉHICULE'),
        if (stats.vehicleStats.isEmpty)
          EmptyState(
            stats.yearTotal == 0
                ? 'Aucun kilomètre enregistré en ${stats.year}.'
                : 'Aucune attribution de véhicule.',
          )
        else
          Column(
            children: [
                for (final stat in stats.vehicleStats)
                  ListTile(
                    key: Key('vehicle-stat-${stat.vehicleId ?? 'none'}'),
                    contentPadding: EdgeInsets.zero,
                    shape: Border(
                      bottom: BorderSide(
                        color: theme.colorScheme.outlineVariant,
                      ),
                    ),
                    minTileHeight: AppSizes.minTouchTarget + 8,
                    // Repère STABLE par véhicule (déterministe sur l'id ;
                    // gris neutre pour « sans véhicule »).
                    leading: Container(
                      width: 4,
                      height: 30,
                      decoration: BoxDecoration(
                        color: vehicleAccent(theme, stat.vehicleId),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                    minLeadingWidth: AppSpacing.m,
                    title: Text(
                      stat.isArchived
                          ? '${stat.label} (archivé)'
                          : stat.label,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w600,
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

        // SIMULATEUR INDICATIF (KM-013) : jamais une déduction fiscale.
        const SectionHeader('ESTIMATION KILOMÉTRIQUE'),
        _FiscalEstimationSection(stats: stats),

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
      ),
    );
  }
}

/// Section ESTIMATION KILOMÉTRIQUE — simulateur INDICATIF (KM-013).
///
/// Barème officiel de l'année des kilomètres affichés, sinon simulation
/// provisoire avec le dernier barème connu sur action EXPLICITE uniquement.
/// Chaque véhicule est estimé séparément ; les kilomètres sans véhicule
/// sont affichés à part et jamais inclus dans le montant.
class _FiscalEstimationSection extends ConsumerWidget {
  const _FiscalEstimationSection({required this.stats});

  final StatisticsState stats;

  String _descriptor(Vehicle vehicle) {
    final parts = <String>[
      if (vehicle.category == VehicleCategory.twoWheeler)
        switch (vehicle.twoWheelerClass) {
          null => 'Deux-roues (type à préciser)',
          TwoWheelerFiscalClass.motorcycle => 'Moto',
          TwoWheelerFiscalClass.moped => 'Cyclomoteur',
        },
      if (vehicle.fiscalPowerCv != null) '${vehicle.fiscalPowerCv} CV',
      switch (vehicle.motorization) {
        Motorization.electric => 'Électrique',
        Motorization.other => 'Autre motorisation',
        Motorization.unspecified => 'Motorisation non renseignée',
      },
    ];
    return parts.join(' — ');
  }

  String _missingLabel(List<MissingVehicleInfo> missing) {
    final labels = [
      for (final info in missing)
        switch (info) {
          MissingVehicleInfo.motorization => 'motorisation',
          MissingVehicleInfo.fiscalPower => 'puissance fiscale',
          MissingVehicleInfo.twoWheelerClass => 'type de deux-roues',
        },
    ];
    return 'Informations véhicule à compléter : ${labels.join(', ')}.';
  }

  void _completeVehicle(BuildContext context, String vehicleId) {
    Navigator.of(context).push(MaterialPageRoute<void>(
      builder: (_) => VehiclesScreen(initialVehicleId: vehicleId),
    ));
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final fiscal = stats.fiscal;
    final muted = theme.textTheme.bodySmall?.copyWith(
      color: theme.colorScheme.onSurfaceVariant,
    );

    if (stats.yearTotal == 0) {
      return Text('Aucun kilomètre à estimer en ${stats.year}.',
          style: muted);
    }

    final reference = fiscal.reference;
    if (reference == null) {
      // Millésime absent : jamais de barème appliqué silencieusement.
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Barème officiel non disponible pour cette année.',
            style: theme.textTheme.bodyMedium,
          ),
          if (fiscal.latestAvailable != null) ...[
            const SizedBox(height: AppSpacing.s),
            OutlinedButton(
              key: const Key('fiscal-simulate-button'),
              onPressed: () => ref
                  .read(statisticsControllerProvider.notifier)
                  .simulateWithLatestReference(),
              style: OutlinedButton.styleFrom(
                minimumSize:
                    const Size.fromHeight(AppSizes.minTouchTarget + 4),
              ),
              child: Text(
                  'Simuler avec le barème '
                  '${fiscal.latestAvailable!.incomeYear}'),
            ),
          ],
        ],
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (fiscal.isProvisional)
          // Affiché EN PERMANENCE pendant une simulation provisoire.
          // Registre WARNING (UX-001) : provisoire = ambre, jamais la
          // couleur primaire ni celle des congés.
          StatusBanner(
            key: const Key('fiscal-provisional-banner'),
            kind: StatusBannerKind.warning,
            text: 'Simulation indicative — barème des revenus '
                '${reference.incomeYear}.',
          )
        else
          Text(
            'Kilomètres ${stats.year} · barème officiel des revenus '
            '${reference.incomeYear} (publié en '
            '${reference.publicationYear}).',
            style: muted,
          ),
        const SizedBox(height: AppSpacing.s),
        // UX-001B : plus de carte — le montant estimé domine, filets fins.
        Column(
          children: [
              for (final row in fiscal.rows)
                ListTile(
                  key: Key('fiscal-row-${row.vehicleId}'),
                  contentPadding: EdgeInsets.zero,
                  shape: Border(
                    bottom: BorderSide(
                      color: theme.colorScheme.outlineVariant,
                    ),
                  ),
                  minTileHeight: AppSizes.minTouchTarget + 8,
                  title: Text(
                    row.isArchived ? '${row.label} (archivé)' : row.label,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (row.vehicle != null)
                        Text(_descriptor(row.vehicle!)),
                      Text(formatKmGrouped(row.yearKm)),
                      switch (row.estimate) {
                        FiscalEstimateAvailable(:final amountEur) =>
                          Padding(
                            padding:
                                const EdgeInsets.only(top: AppSpacing.xs),
                            child: Text(
                              'Estimation indicative : '
                              '${formatEurRounded(amountEur)}',
                              style: theme.textTheme.titleMedium?.copyWith(
                                color: theme.colorScheme.primary,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        FiscalVehicleIncomplete(:final missing) => Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(_missingLabel(missing)),
                              Align(
                                alignment: Alignment.centerLeft,
                                child: TextButton(
                                  key: Key(
                                      'fiscal-complete-${row.vehicleId}'),
                                  onPressed: () => _completeVehicle(
                                      context, row.vehicleId),
                                  style: TextButton.styleFrom(
                                    padding: EdgeInsets.zero,
                                    minimumSize: const Size(
                                        0, AppSizes.minTouchTarget),
                                  ),
                                  child:
                                      const Text('Compléter le véhicule'),
                                ),
                              ),
                            ],
                          ),
                        FiscalScaleUnavailable() => const Text(
                            'Barème non disponible pour ce véhicule.'),
                      },
                    ],
                  ),
                ),
              if (fiscal.estimatedRows.isNotEmpty) ...[
                ListTile(
                  key: const Key('fiscal-total'),
                  contentPadding: EdgeInsets.zero,
                  minTileHeight: AppSizes.minTouchTarget,
                  title: Text(
                    // Jamais un « total » trompeur si estimation partielle.
                    fiscal.isPartial
                        ? 'Sous-total des véhicules estimables'
                        : 'TOTAL ESTIMÉ',
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  trailing: Text(
                    formatEurRounded(fiscal.estimatedTotal),
                    style: AppTypography.value.copyWith(
                      color: theme.colorScheme.onSurface,
                    ),
                  ),
                ),
              ],
          ],
        ),
        if (fiscal.unattributedKm > 0) ...[
          const SizedBox(height: AppSpacing.s),
          Text(
            'Kilomètres sans véhicule : '
            '${formatKmGrouped(fiscal.unattributedKm)} — non estimables, '
            'non inclus dans le montant.',
            style: muted,
          ),
        ],
        const SizedBox(height: AppSpacing.s),
        Text(
          'Simulateur indicatif : ne détermine pas une déduction fiscale '
          'et ne remplace pas la notice officielle.',
          style: muted,
        ),
      ],
    );
  }
}

/// Statistique secondaire inline (UX-001B) : valeur + libellé, sans carte.
class _InlineStat extends StatelessWidget {
  const _InlineStat({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      children: [
        Text(
          value,
          style: AppTypography.value.copyWith(
            color: theme.colorScheme.onSurface,
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
