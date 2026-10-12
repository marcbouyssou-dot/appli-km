import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../domain/models/civil_date.dart';
import '../../theme/tokens.dart';
import '../../widgets/app_buttons.dart';
import '../../widgets/brand_header.dart';
import '../../widgets/road_watermark.dart';
import '../../widgets/km_format.dart';
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

  static const _weekdayLabels = ['L', 'Ma', 'Me', 'J', 'V', 'S', 'D'];

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

    return MesKmRoadWatermark(
      variant: RoadWatermarkVariant.top,
      child: ListView(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.l),
      children: [
        const MesKmBrandHeader(),
        const SizedBox(height: AppSpacing.s),

        // UX-004B : « Calendrier » est porté par l'onglet actif — le mois
        // est le premier titre fonctionnel. Navigation : sélecteur partagé.
        PeriodSelector(
          label: _monthLabel,
          onPrevious: controller.previousMonth,
          onNext: controller.nextMonth,
          previousKey: const Key('cal-prev'),
          nextKey: const Key('cal-next'),
          previousTooltip: 'Mois précédent',
          nextTooltip: 'Mois suivant',
        ),

        // Total du mois, dérivé des données — héros DONNÉE : encre,
        // milliers groupés (le bleu reste réservé aux actions).
        Center(
          child: Text(
            formatKmGrouped(calendar.monthTotal),
            style: theme.textTheme.headlineMedium?.copyWith(
              fontWeight: FontWeight.w800,
              color: theme.colorScheme.onSurface,
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

        // Action rare, déplacée SOUS la grille (UX-004B) : la grille est
        // le centre visuel de l'écran. Même action, même feuille.
        const SizedBox(height: AppSpacing.s),
        Center(
          child: QuietButton(
            key: const Key('cal-vacations-button'),
            onPressed: () => showVacationsSheet(context),
            icon: Icons.beach_access_outlined,
            label: 'Ajouter des congés',
          ),
        ),
        const SizedBox(height: AppSpacing.xxl),
      ],
      ),
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

  /// Libellé VoiceOver : la cellule s'annonce comme UNE unité actionnable
  /// (date complète + contenu), sans doublons (UX-007B).
  String _semanticsLabel() {
    final dateText = DateFormat('EEEE d MMMM yyyy', 'fr_FR')
        .format(date.toDateTime());
    final buffer = StringBuffer(
        dateText[0].toUpperCase() + dateText.substring(1));
    if (isToday) buffer.write(', aujourd’hui');
    final km = totalKm;
    if (km != null && km > 0) {
      buffer.write(', ${formatKm(km)}');
    } else if (isVacation) {
      buffer.write(', congé');
    }
    return buffer.toString();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final hasKm = totalKm != null && totalKm! > 0;

    // UX-007B : hauteur adaptative BORNÉE — identique (58) à l'échelle 1,
    // grandit jusqu'à 84 aux grandes tailles de texte ; au-delà, le
    // FittedBox global réduit le contenu plutôt que de déborder (limite
    // 2.0 documentée : contenu légèrement réduit, grille préservée).
    final textScale = MediaQuery.textScalerOf(context).scale(14) / 14;
    final cellHeight = (58.0 * textScale).clamp(58.0, 84.0);

    // Toute la cellule est tactile, hauteur confortable.
    // Priorités : numéro, km s'il y en a, congé.
    // Le congé n'est jamais indiqué par la seule couleur : libellé textuel.
    return InkWell(
      key: Key('cal-cell-${date.toIso8601()}'),
      onTap: () => onTap(context, date),
      borderRadius: BorderRadius.circular(AppRadius.m),
      child: Semantics(
        button: true,
        label: _semanticsLabel(),
        excludeSemantics: true,
        child: Container(
        height: cellHeight,
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
        child: FittedBox(
          fit: BoxFit.scaleDown,
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
              FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  formatKm(totalKm!),
                  maxLines: 1,
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: theme.colorScheme.primary,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              )
            else if (isVacation)
              FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  'Congé',
                  maxLines: 1,
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: theme.colorScheme.tertiary,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
          ],
          ),
        ),
        ),
      ),
    );
  }
}
