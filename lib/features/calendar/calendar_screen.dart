import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../domain/models/civil_date.dart';
import '../../theme/tokens.dart';
import '../../widgets/app_buttons.dart';
import '../../widgets/km_format.dart';
import '../../widgets/placeholder_card.dart';
import '../../widgets/period_selector.dart';
import 'calendar_controller.dart';
import 'day_detail_screen.dart';
import 'vacations_sheet.dart';

class CalendarScreen extends ConsumerWidget {
  const CalendarScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(calendarControllerProvider);

    return state.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, _) => Center(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.xl),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Text('Impossible de charger le calendrier.'),
              const SizedBox(height: AppSpacing.s),
              Text('$error', style: Theme.of(context).textTheme.bodySmall),
              const SizedBox(height: AppSpacing.l),
              FilledButton(
                onPressed: () => ref.invalidate(calendarControllerProvider),
                child: const Text('Réessayer'),
              ),
            ],
          ),
        ),
      ),
      data: (calendar) => _CalendarView(calendar: calendar),
    );
  }
}

class _CalendarView extends ConsumerWidget {
  const _CalendarView({required this.calendar});

  final CalendarState calendar;

  static const _weekdayLabels = ['L', 'M', 'M', 'J', 'V', 'S', 'D'];

  String get _monthLabel {
    final label = DateFormat('MMMM yyyy', 'fr_FR')
        .format(DateTime(calendar.year, calendar.month));
    return label[0].toUpperCase() + label.substring(1);
  }

  void _openDay(BuildContext context, CivilDate date) {
    Navigator.of(context).push(MaterialPageRoute<void>(
      builder: (_) => DayDetailScreen(date: date),
    ));
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final controller = ref.read(calendarControllerProvider.notifier);

    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.l),
      children: [
        const ScreenTitle('Calendrier'),

        // Navigation mensuelle : sélecteur partagé, chevrons larges.
        PeriodSelector(
          label: _monthLabel,
          onPrevious: controller.previousMonth,
          onNext: controller.nextMonth,
          previousKey: const Key('cal-prev'),
          nextKey: const Key('cal-next'),
          previousTooltip: 'Mois précédent',
          nextTooltip: 'Mois suivant',
        ),

        // Total du mois, dérivé des données.
        Center(
          child: Text(
            formatKm(calendar.monthTotal),
            style: theme.textTheme.headlineMedium?.copyWith(
              fontWeight: FontWeight.w800,
              color: theme.colorScheme.primary,
            ),
          ),
        ),
        if (!calendar.isCurrentMonth)
          Center(
            child: TextButton(
              key: const Key('cal-today-button'),
              onPressed: controller.goToCurrentMonth,
              style: TextButton.styleFrom(
                minimumSize: const Size(
                  AppSizes.minTouchTarget * 2,
                  AppSizes.minTouchTarget,
                ),
              ),
              child: const Text('Revenir à aujourd’hui'),
            ),
          ),
        Center(
          child: QuietButton(
            key: const Key('cal-vacations-button'),
            onPressed: () => showVacationsSheet(context),
            icon: Icons.beach_access_outlined,
            label: 'Ajouter des congés',
          ),
        ),
        const SizedBox(height: AppSpacing.m),

        // En-têtes de jours (lundi -> dimanche).
        Row(
          children: [
            for (final label in _weekdayLabels)
              Expanded(
                child: Text(
                  label,
                  textAlign: TextAlign.center,
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: AppSpacing.s),

        ..._buildWeeks(context, theme),
        const SizedBox(height: AppSpacing.xxl),
      ],
    );
  }

  List<Widget> _buildWeeks(BuildContext context, ThemeData theme) {
    final cells = <Widget>[
      // Cases vides avant le 1er du mois (semaine commençant lundi).
      for (var i = 1; i < calendar.firstWeekday; i++)
        const Expanded(child: SizedBox()),
      for (var day = 1; day <= calendar.daysInMonth; day++)
        Expanded(
          child: _DayCell(
            date: CivilDate(calendar.year, calendar.month, day),
            totalKm:
                calendar.dayTotals[CivilDate(calendar.year, calendar.month, day)],
            isToday: calendar.today == CivilDate(calendar.year, calendar.month, day),
            isVacation: calendar.vacationDays
                .contains(CivilDate(calendar.year, calendar.month, day)),
            onTap: _openDay,
          ),
        ),
    ];
    // Complète la dernière semaine.
    while (cells.length % 7 != 0) {
      cells.add(const Expanded(child: SizedBox()));
    }

    return [
      for (var week = 0; week < cells.length ~/ 7; week++)
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: cells.sublist(week * 7, week * 7 + 7),
        ),
    ];
  }
}

class _DayCell extends StatelessWidget {
  const _DayCell({
    required this.date,
    required this.totalKm,
    required this.isToday,
    required this.isVacation,
    required this.onTap,
  });

  final CivilDate date;
  final double? totalKm;
  final bool isToday;
  final bool isVacation;
  final void Function(BuildContext context, CivilDate date) onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final hasKm = totalKm != null && totalKm! > 0;

    // Toute la cellule est tactile, hauteur confortable.
    // Priorités : numéro, km s'il y en a, congé.
    // Le congé n'est jamais indiqué par la seule couleur : libellé textuel.
    return InkWell(
      key: Key('cal-cell-${date.toIso8601()}'),
      onTap: () => onTap(context, date),
      borderRadius: BorderRadius.circular(AppRadius.m),
      child: Container(
        height: 58,
        margin: const EdgeInsets.all(1),
        decoration: BoxDecoration(
          color: hasKm
              ? theme.colorScheme.primaryContainer.withValues(alpha: 0.55)
              : isVacation
                  ? theme.colorScheme.tertiaryContainer.withValues(alpha: 0.5)
                  : null,
          border: isToday
              ? Border.all(color: theme.colorScheme.primary, width: 2)
              : null,
          borderRadius: BorderRadius.circular(AppRadius.m),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              '${date.day}',
              style: theme.textTheme.bodyMedium?.copyWith(
                fontWeight: hasKm || isToday || isVacation
                    ? FontWeight.bold
                    : FontWeight.normal,
              ),
            ),
            if (hasKm)
              Text(
                formatKm(totalKm!),
                maxLines: 1,
                overflow: TextOverflow.clip,
                style: theme.textTheme.labelSmall?.copyWith(
                  fontSize: 10,
                  color: theme.colorScheme.primary,
                  fontWeight: FontWeight.bold,
                ),
              )
            else if (isVacation)
              Text(
                'Congé',
                maxLines: 1,
                overflow: TextOverflow.clip,
                style: theme.textTheme.labelSmall?.copyWith(
                  fontSize: 9,
                  color: theme.colorScheme.tertiary,
                  fontWeight: FontWeight.bold,
                ),
              ),
          ],
        ),
      ),
    );
  }
}
