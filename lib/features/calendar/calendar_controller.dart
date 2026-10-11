import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../../domain/logic/statistics.dart';
import '../../domain/models/civil_date.dart';
import '../../domain/models/km.dart';
import '../../domain/models/vacation_period.dart';

/// État du calendrier : le mois affiché et ses totaux dérivés.
class CalendarState {
  CalendarState({
    required this.year,
    required this.month,
    required this.dayTotals,
    required this.monthTotal,
    required this.today,
    required this.vacationDays,
  });

  final int year;
  final int month;

  /// Totaux par date (uniquement les jours ayant des kilomètres).
  final Map<CivilDate, double> dayTotals;

  /// Total du mois, toujours dérivé — jamais stocké.
  final double monthTotal;

  final CivilDate today;

  /// Jours du mois affiché marqués congé (statut explicite uniquement).
  final Set<CivilDate> vacationDays;

  bool get isCurrentMonth => year == today.year && month == today.month;

  int get daysInMonth => DateTime.utc(year, month + 1, 0).day;

  /// Jour de semaine du 1er du mois (1 = lundi … 7 = dimanche).
  int get firstWeekday => DateTime.utc(year, month, 1).weekday;
}

/// Contrôleur du calendrier : mois visible + données de ce mois.
/// Ne charge que la plage de dates du mois affiché, et se recharge
/// automatiquement quand une journée est modifiée (version des données).
class CalendarController extends AsyncNotifier<CalendarState> {
  int? _year;
  int? _month;

  @override
  Future<CalendarState> build() {
    // Recharge sur toute mutation d'une journée (pas de données UI stale).
    ref.watch(dayDataVersionProvider);

    final today = ref.read(todayDateProvider)();
    _year ??= today.year;
    _month ??= today.month;
    return _load(today);
  }

  Future<CalendarState> _load(CivilDate today) async {
    final year = _year!;
    final month = _month!;
    final first = CivilDate(year, month, 1);
    final last =
        CivilDate.fromDateTime(DateTime.utc(year, month + 1, 0));

    final trips =
        await ref.read(tripRepositoryProvider).getBetween(first, last);
    final extras =
        await ref.read(dayExtraRepositoryProvider).getBetween(first, last);
    final vacations = await ref.read(vacationRepositoryProvider).getAll();

    final dayTotals = totalsByDay(trips: trips, extras: extras);
    return CalendarState(
      year: year,
      month: month,
      dayTotals: dayTotals,
      monthTotal: sumKm(dayTotals.values),
      today: today,
      vacationDays: _vacationDaysInMonth(vacations, first, last),
    );
  }

  static Set<CivilDate> _vacationDaysInMonth(
    List<VacationPeriod> periods,
    CivilDate first,
    CivilDate last,
  ) {
    final days = <CivilDate>{};
    for (var date = first;
        !date.isAfter(last);
        date = date.addDays(1)) {
      if (periods.any((p) => p.contains(date))) {
        days.add(date);
      }
    }
    return days;
  }

  Future<void> _showMonth(int year, int month) async {
    _year = year;
    _month = month;
    state = const AsyncLoading();
    state = await AsyncValue.guard(
      () => _load(ref.read(todayDateProvider)()),
    );
  }

  Future<void> previousMonth() {
    final shifted = DateTime.utc(_year!, _month! - 1, 1);
    return _showMonth(shifted.year, shifted.month);
  }

  Future<void> nextMonth() {
    final shifted = DateTime.utc(_year!, _month! + 1, 1);
    return _showMonth(shifted.year, shifted.month);
  }

  Future<void> goToCurrentMonth() {
    final today = ref.read(todayDateProvider)();
    return _showMonth(today.year, today.month);
  }
}

final calendarControllerProvider =
    AsyncNotifierProvider<CalendarController, CalendarState>(
  CalendarController.new,
);
