import '../models/civil_date.dart';
import '../models/day_extra.dart';
import '../models/km.dart';
import '../models/trip.dart';

/// Agrégations pures sur les kilomètres.
///
/// Toutes les fonctions prennent les collections en entrée et retournent de
/// nouvelles valeurs : aucune mutation, aucune dépendance au stockage.
/// Les totaux incluent trajets détaillés ET kilomètres non détaillés.

double totalForDay(
  CivilDate date, {
  required Iterable<Trip> trips,
  Iterable<DayExtra> extras = const [],
}) {
  return sumKm([
    ...trips.where((t) => t.date == date).map((t) => t.distanceKm),
    ...extras.where((e) => e.date == date).map((e) => e.extraKm),
  ]);
}

double totalForMonth(
  int year,
  int month, {
  required Iterable<Trip> trips,
  Iterable<DayExtra> extras = const [],
}) {
  bool inMonth(CivilDate d) => d.year == year && d.month == month;
  return sumKm([
    ...trips.where((t) => inMonth(t.date)).map((t) => t.distanceKm),
    ...extras.where((e) => inMonth(e.date)).map((e) => e.extraKm),
  ]);
}

double totalForYear(
  int year, {
  required Iterable<Trip> trips,
  Iterable<DayExtra> extras = const [],
}) {
  return sumKm([
    ...trips.where((t) => t.date.year == year).map((t) => t.distanceKm),
    ...extras.where((e) => e.date.year == year).map((e) => e.extraKm),
  ]);
}

/// Nombre de jours distincts dont le total dérivé est > 0 km.
int activeDayCount({
  required Iterable<Trip> trips,
  Iterable<DayExtra> extras = const [],
}) {
  return _totalsByDay(trips, extras).values.where((km) => km > 0).length;
}

/// Moyenne de kilomètres par jour actif (0 si aucun jour actif).
double averageKmPerActiveDay({
  required Iterable<Trip> trips,
  Iterable<DayExtra> extras = const [],
}) {
  final activeTotals =
      _totalsByDay(trips, extras).values.where((km) => km > 0).toList();
  if (activeTotals.isEmpty) return 0;
  final total = sumKm(activeTotals);
  return normalizeKm(total / activeTotals.length);
}

/// Répartition des kilomètres DÉTAILLÉS par véhicule.
/// Clé `null` : trajets sans véhicule renseigné.
/// Les kilomètres non détaillés ne sont pas attribuables à un véhicule et
/// sont volontairement exclus de cette répartition.
Map<String?, double> detailedTotalByVehicle(Iterable<Trip> trips) {
  final sums = <String?, double>{};
  for (final trip in trips) {
    sums.update(
      trip.vehicleId,
      (value) => value + trip.distanceKm,
      ifAbsent: () => trip.distanceKm,
    );
  }
  return {
    for (final entry in sums.entries) entry.key: normalizeKm(entry.value),
  };
}

/// Total dérivé par date civile (trajets + kilomètres non détaillés).
/// Les dates sans kilomètres n'apparaissent pas dans la map.
Map<CivilDate, double> totalsByDay({
  required Iterable<Trip> trips,
  Iterable<DayExtra> extras = const [],
}) =>
    _totalsByDay(trips, extras);

Map<CivilDate, double> _totalsByDay(
  Iterable<Trip> trips,
  Iterable<DayExtra> extras,
) {
  final byDay = <CivilDate, List<double>>{};
  for (final trip in trips) {
    byDay.putIfAbsent(trip.date, () => []).add(trip.distanceKm);
  }
  for (final extra in extras) {
    byDay.putIfAbsent(extra.date, () => []).add(extra.extraKm);
  }
  return {
    for (final entry in byDay.entries) entry.key: sumKm(entry.value),
  };
}
