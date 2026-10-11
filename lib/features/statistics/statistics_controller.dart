import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../../domain/logic/statistics.dart';
import '../../domain/models/civil_date.dart';
import '../../domain/models/day_extra.dart';
import '../../domain/models/km.dart';
import '../../domain/models/trip.dart';
import '../../domain/models/vacation_period.dart';
import '../../domain/models/vehicle.dart';

/// Kilométrage d'un véhicule sur la période affichée — toujours DÉRIVÉ des
/// données enregistrées (aucun compteur, aucune remise à zéro stockée).
class VehicleStat {
  VehicleStat({
    required this.vehicleId,
    required this.label,
    required this.isArchived,
    required this.monthKm,
    required this.yearKm,
  });

  /// null = kilomètres sans véhicule renseigné.
  final String? vehicleId;
  final String label;
  final bool isArchived;
  final double monthKm;
  final double yearKm;
}

class StatisticsState {
  StatisticsState({
    required this.year,
    required this.month,
    required this.today,
    required this.yearTotal,
    required this.monthlyTotals,
    required this.activeDays,
    required this.averagePerActiveDay,
    required this.previousYearTotal,
    required this.vehicleStats,
    required this.vacationDays,
  });

  final int year;

  /// Mois sélectionné (1-12), indépendant du calendrier principal.
  final int month;
  final CivilDate today;

  final double yearTotal;
  final List<double> monthlyTotals; // index 0 = janvier
  final int activeDays;
  final double averagePerActiveDay;

  /// Total de l'année précédente, null si elle ne contient AUCUNE donnée.
  final double? previousYearTotal;

  final List<VehicleStat> vehicleStats;
  final int vacationDays;

  bool get isCurrentYear => year == today.year;

  double get selectedMonthTotal => monthlyTotals[month - 1];

  double? get previousYearDelta =>
      previousYearTotal == null ? null : normalizeKm(yearTotal - previousYearTotal!);

  /// Variation en %, null si année précédente vide ou nulle.
  double? get previousYearPercent {
    final previous = previousYearTotal;
    if (previous == null || previous == 0) return null;
    return (yearTotal - previous) / previous * 100;
  }
}

/// Contrôleur des statistiques : requêtes BORNÉES à l'année affichée
/// (+ l'année précédente pour la comparaison), agrégations par le domaine,
/// rechargement automatique à chaque mutation (version des données).
class StatisticsController extends AsyncNotifier<StatisticsState> {
  int? _year;
  int? _month;

  @override
  Future<StatisticsState> build() {
    ref.watch(dayDataVersionProvider); // jamais de stats stale

    final today = ref.read(todayDateProvider)();
    _year ??= today.year;
    _month ??= today.month;
    return _load(today);
  }

  Future<(List<Trip>, List<DayExtra>)> _loadYear(int year) async {
    final first = CivilDate(year, 1, 1);
    final last = CivilDate(year, 12, 31);
    final trips =
        await ref.read(tripRepositoryProvider).getBetween(first, last);
    final extras =
        await ref.read(dayExtraRepositoryProvider).getBetween(first, last);
    return (trips, extras);
  }

  Future<StatisticsState> _load(CivilDate today) async {
    final year = _year!;
    final month = _month!;

    final (trips, extras) = await _loadYear(year);
    final (previousTrips, previousExtras) = await _loadYear(year - 1);
    final vehicles = await ref.read(vehicleRepositoryProvider).getAll();
    final vacations = await ref.read(vacationRepositoryProvider).getAll();

    final monthlyTotals = [
      for (var m = 1; m <= 12; m++)
        totalForMonth(year, m, trips: trips, extras: extras),
    ];

    final yearByVehicle = totalKmByVehicle(trips: trips, extras: extras);
    final monthByVehicle = totalKmByVehicle(
      trips: trips.where((t) => t.date.month == month),
      extras: extras.where((e) => e.date.month == month),
    );

    final vehicleStats = <VehicleStat>[];
    for (final entry in yearByVehicle.entries) {
      if (entry.value <= 0) continue;
      Vehicle? vehicle;
      for (final v in vehicles) {
        if (v.id == entry.key) vehicle = v;
      }
      vehicleStats.add(VehicleStat(
        vehicleId: entry.key,
        label: entry.key == null
            ? 'Sans véhicule renseigné'
            : vehicle?.name ?? 'Véhicule inconnu',
        isArchived: vehicle?.isArchived ?? false,
        monthKm: monthByVehicle[entry.key] ?? 0,
        yearKm: entry.value,
      ));
    }
    // Plus gros kilométrage d'abord, « sans véhicule » en dernier.
    vehicleStats.sort((a, b) {
      if (a.vehicleId == null) return 1;
      if (b.vehicleId == null) return -1;
      return b.yearKm.compareTo(a.yearKm);
    });

    final previousTotal =
        totalForYear(year - 1, trips: previousTrips, extras: previousExtras);

    return StatisticsState(
      year: year,
      month: month,
      today: today,
      yearTotal: totalForYear(year, trips: trips, extras: extras),
      monthlyTotals: monthlyTotals,
      activeDays: activeDayCount(trips: trips, extras: extras),
      averagePerActiveDay:
          averageKmPerActiveDay(trips: trips, extras: extras),
      previousYearTotal:
          (previousTrips.isEmpty && previousExtras.isEmpty)
              ? null
              : previousTotal,
      vehicleStats: vehicleStats,
      vacationDays: _vacationDaysInYear(vacations, year),
    );
  }

  /// Jours de congé de l'année (périodes rognées aux bornes de l'année).
  static int _vacationDaysInYear(List<VacationPeriod> periods, int year) {
    final first = CivilDate(year, 1, 1);
    final last = CivilDate(year, 12, 31);
    var days = 0;
    for (final period in periods) {
      final start =
          period.startDate.isBefore(first) ? first : period.startDate;
      final end = period.endDate.isAfter(last) ? last : period.endDate;
      for (var d = start; !d.isAfter(end); d = d.addDays(1)) {
        days++;
      }
    }
    return days;
  }

  Future<void> _show(int year, int month) async {
    _year = year;
    _month = month;
    state = const AsyncLoading();
    state = await AsyncValue.guard(
      () => _load(ref.read(todayDateProvider)()),
    );
  }

  Future<void> previousYear() => _show(_year! - 1, _month!);

  Future<void> nextYear() => _show(_year! + 1, _month!);

  Future<void> goToCurrentYear() {
    final today = ref.read(todayDateProvider)();
    return _show(today.year, today.month);
  }

  Future<void> previousMonth() =>
      _show(_year!, _month! == 1 ? 12 : _month! - 1);

  Future<void> nextMonth() =>
      _show(_year!, _month! == 12 ? 1 : _month! + 1);
}

final statisticsControllerProvider =
    AsyncNotifierProvider<StatisticsController, StatisticsState>(
  StatisticsController.new,
);
