import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../../domain/logic/fiscal_estimator.dart';
import '../../domain/logic/statistics.dart';
import '../../domain/models/civil_date.dart';
import '../../domain/models/day_extra.dart';
import '../../domain/models/fiscal_reference.dart';
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

/// Ligne d'estimation d'un véhicule (SIMULATEUR INDICATIF — KM-013).
class FiscalEstimateRow {
  FiscalEstimateRow({
    required this.vehicleId,
    required this.label,
    required this.isArchived,
    required this.vehicle,
    required this.yearKm,
    required this.estimate,
  });

  final String vehicleId;
  final String label;
  final bool isArchived;

  /// null si le véhicule référencé n'existe plus (aucune navigation).
  final Vehicle? vehicle;
  final double yearKm;
  final FiscalVehicleEstimate estimate;
}

/// Section « Estimation kilométrique » d'une année de kilomètres.
class FiscalEstimationState {
  FiscalEstimationState({
    required this.reference,
    required this.isProvisional,
    required this.latestAvailable,
    required this.rows,
    required this.unattributedKm,
  });

  /// Barème appliqué (officiel de l'année, ou dernier connu si simulation
  /// provisoire EXPLICITEMENT demandée) ; null = aucune estimation.
  final FiscalReference? reference;
  final bool isProvisional;

  /// Dernier barème officiel connu — proposé pour une simulation provisoire.
  final FiscalReference? latestAvailable;
  final List<FiscalEstimateRow> rows;

  /// Kilomètres sans véhicule : affichés à part, JAMAIS estimés ni inclus.
  final double unattributedKm;

  List<FiscalEstimateRow> get estimatedRows =>
      [for (final r in rows) if (r.estimate is FiscalEstimateAvailable) r];

  /// Somme des estimations disponibles — chaque véhicule calculé séparément.
  double get estimatedTotal {
    var total = 0.0;
    for (final row in estimatedRows) {
      total += (row.estimate as FiscalEstimateAvailable).amountEur;
    }
    return total;
  }

  /// true si au moins un véhicule n'a pas pu être estimé : le total affiché
  /// devient un « sous-total » pour ne jamais être trompeur.
  bool get isPartial =>
      estimatedRows.length < rows.length || unattributedKm > 0;
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
    required this.fiscal,
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

  /// Estimation kilométrique indicative de l'année affichée.
  final FiscalEstimationState fiscal;

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

  /// Année pour laquelle une simulation PROVISOIRE (dernier barème connu)
  /// a été explicitement demandée. Jamais implicite, jamais persistée ;
  /// changer d'année exige une nouvelle demande explicite.
  int? _provisionalForYear;

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

    // Estimation kilométrique indicative : barème officiel de l'année des
    // kilomètres affichés, sinon — uniquement sur demande explicite —
    // simulation provisoire avec le dernier barème officiel connu.
    // Valeur synchrone injectée au bootstrap (voir fiscalReferenceStoreProvider).
    final store = ref.read(fiscalReferenceStoreProvider);
    final official = store.forIncomeYear(year);
    final provisional = (official == null && _provisionalForYear == year)
        ? store.latest
        : null;
    final used = official ?? provisional;

    final fiscalRows = <FiscalEstimateRow>[];
    if (used != null) {
      for (final stat in vehicleStats) {
        final vehicleId = stat.vehicleId;
        if (vehicleId == null) continue; // affichés à part, jamais estimés
        Vehicle? vehicle;
        for (final v in vehicles) {
          if (v.id == vehicleId) vehicle = v;
        }
        fiscalRows.add(FiscalEstimateRow(
          vehicleId: vehicleId,
          label: stat.label,
          isArchived: stat.isArchived,
          vehicle: vehicle,
          yearKm: stat.yearKm,
          estimate: vehicle == null
              // Véhicule référencé mais absent : rien à compléter, pas
              // d'estimation approximative.
              ? const FiscalScaleUnavailable()
              : estimateVehicleFiscal(
                  vehicle: vehicle,
                  annualKm: stat.yearKm,
                  reference: used,
                ),
        ));
      }
    }

    final fiscal = FiscalEstimationState(
      reference: used,
      isProvisional: provisional != null,
      latestAvailable: store.latest,
      rows: fiscalRows,
      unattributedKm: yearByVehicle[null] ?? 0,
    );

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
      fiscal: fiscal,
    );
  }

  /// Simulation provisoire avec le dernier barème officiel connu —
  /// uniquement sur action explicite, pour l'année affichée seulement.
  Future<void> simulateWithLatestReference() {
    _provisionalForYear = _year;
    return _show(_year!, _month!);
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
    // Quitter l'année annule la simulation provisoire : elle doit être
    // redemandée explicitement à chaque retour.
    if (year != _year) _provisionalForYear = null;
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
