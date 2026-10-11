import '../../domain/logic/statistics.dart';
import '../../domain/models/app_settings.dart';
import '../../domain/models/civil_date.dart';
import '../../domain/models/day_extra.dart';
import '../../domain/models/km.dart';
import '../../domain/models/trip.dart';
import '../../domain/models/vacation_period.dart';
import '../../domain/models/vehicle.dart';

/// Kilométrage d'un véhicule sur l'année du relevé (archivés inclus s'ils
/// portent des kilomètres ; vehicleId null = « Sans véhicule renseigné »).
class ReportVehicle {
  ReportVehicle({
    required this.vehicleId,
    required this.label,
    required this.registration,
    required this.fiscalPowerCv,
    required this.totalKm,
  });

  final String? vehicleId;
  final String label;
  final String? registration;
  final int? fiscalPowerCv;
  final double totalKm;
}

/// Une ligne de données kilométriques (pour le CSV) : un Trip OU les
/// kilomètres non détaillés d'une journée — chaque kilomètre de l'année
/// apparaît exactement UNE fois.
class ReportLine {
  ReportLine({
    required this.date,
    required this.isDetailedTrip,
    required this.km,
    this.origin,
    this.destination,
    this.purpose,
    this.isRoundTrip = false,
    required this.vehicleLabel,
    required this.registration,
  });

  final CivilDate date;
  final bool isDetailedTrip; // false = « Non détaillé » (DayExtra)
  final double km;
  final String? origin;
  final String? destination;
  final String? purpose;
  final bool isRoundTrip;
  final String vehicleLabel; // '' si aucun véhicule
  final String registration; // '' si inconnue
}

/// Modèle intermédiaire PUR consommé par les builders PDF et CSV.
/// Construit UNE fois depuis les données chargées ; les builders ne
/// touchent jamais à la base.
class AnnualReportData {
  AnnualReportData({
    required this.year,
    required this.generatedAt,
    required this.displayName,
    required this.address,
    required this.city,
    required this.totalKm,
    required this.monthlyTotals,
    required this.activeDays,
    required this.averagePerActiveDay,
    required this.vehicles,
    required this.vacationPeriods,
    required this.lines,
  });

  final int year;
  final DateTime generatedAt;
  final String? displayName;
  final String? address;
  final String? city;
  final double totalKm;
  final List<double> monthlyTotals; // index 0 = janvier
  final int activeDays;
  final double averagePerActiveDay;
  final List<ReportVehicle> vehicles;

  /// Périodes de congés ROGNÉES aux bornes de l'année.
  final List<(CivilDate, CivilDate)> vacationPeriods;

  /// Détail chronologique (trajets puis non-détaillé par journée).
  final List<ReportLine> lines;

  bool get isEmpty => lines.isEmpty;
}

/// Assemble le relevé annuel — fonction PURE (entrées déjà chargées,
/// bornées à l'année par l'appelant pour trips/extras).
AnnualReportData buildAnnualReportData({
  required int year,
  required DateTime generatedAt,
  required List<Trip> trips,
  required List<DayExtra> extras,
  required List<Vehicle> vehicles,
  required List<VacationPeriod> vacations,
  required AppSettings settings,
}) {
  Vehicle? vehicleById(String? id) {
    if (id == null) return null;
    for (final v in vehicles) {
      if (v.id == id) return v;
    }
    return null;
  }

  String vehicleLabel(String? id) {
    final vehicle = vehicleById(id);
    if (vehicle == null) return id == null ? '' : 'Véhicule inconnu';
    return vehicle.name;
  }

  // Totaux par véhicule : attribution HISTORIQUE figée uniquement,
  // archivés inclus, zéro masqué.
  final byVehicle = totalKmByVehicle(trips: trips, extras: extras);
  final reportVehicles = <ReportVehicle>[];
  for (final entry in byVehicle.entries) {
    if (entry.value <= 0) continue;
    final vehicle = vehicleById(entry.key);
    reportVehicles.add(ReportVehicle(
      vehicleId: entry.key,
      label: entry.key == null
          ? 'Sans véhicule renseigné'
          : vehicle?.name ?? 'Véhicule inconnu',
      registration: vehicle?.registration,
      fiscalPowerCv: vehicle?.fiscalPowerCv,
      totalKm: entry.value,
    ));
  }
  reportVehicles.sort((a, b) {
    if (a.vehicleId == null) return 1;
    if (b.vehicleId == null) return -1;
    return b.totalKm.compareTo(a.totalKm);
  });

  // Congés rognés aux bornes de l'année, triés.
  final firstDay = CivilDate(year, 1, 1);
  final lastDay = CivilDate(year, 12, 31);
  final clippedVacations = <(CivilDate, CivilDate)>[];
  for (final period in vacations) {
    final start =
        period.startDate.isBefore(firstDay) ? firstDay : period.startDate;
    final end = period.endDate.isAfter(lastDay) ? lastDay : period.endDate;
    if (!start.isAfter(end)) clippedVacations.add((start, end));
  }
  clippedVacations.sort((a, b) => a.$1.compareTo(b.$1));

  // Détail chronologique : par date croissante, les trajets (ordre de
  // création) puis la ligne « Non détaillé » de la journée.
  final tripsByDate = <CivilDate, List<Trip>>{};
  for (final trip in trips) {
    tripsByDate.putIfAbsent(trip.date, () => []).add(trip);
  }
  final extraByDate = {for (final e in extras) e.date: e};
  final allDates = {...tripsByDate.keys, ...extraByDate.keys}.toList()
    ..sort();

  final lines = <ReportLine>[];
  for (final date in allDates) {
    final dayTrips = (tripsByDate[date] ?? const <Trip>[]).toList()
      ..sort((a, b) => a.createdAt.compareTo(b.createdAt));
    for (final trip in dayTrips) {
      final vehicle = vehicleById(trip.vehicleId);
      lines.add(ReportLine(
        date: trip.date,
        isDetailedTrip: true,
        km: trip.distanceKm,
        origin: trip.origin,
        destination: trip.destination,
        purpose: trip.purpose,
        isRoundTrip: trip.isRoundTrip,
        vehicleLabel: vehicleLabel(trip.vehicleId),
        registration: vehicle?.registration ?? '',
      ));
    }
    final extra = extraByDate[date];
    if (extra != null) {
      final vehicle = vehicleById(extra.vehicleId);
      lines.add(ReportLine(
        date: extra.date,
        isDetailedTrip: false,
        km: extra.extraKm,
        vehicleLabel: vehicleLabel(extra.vehicleId),
        registration: vehicle?.registration ?? '',
      ));
    }
  }

  return AnnualReportData(
    year: year,
    generatedAt: generatedAt,
    displayName: settings.displayName,
    address: settings.address,
    city: settings.city,
    totalKm: totalForYear(year, trips: trips, extras: extras),
    monthlyTotals: [
      for (var m = 1; m <= 12; m++)
        totalForMonth(year, m, trips: trips, extras: extras),
    ],
    activeDays: activeDayCount(trips: trips, extras: extras),
    averagePerActiveDay:
        averageKmPerActiveDay(trips: trips, extras: extras),
    vehicles: reportVehicles,
    vacationPeriods: clippedVacations,
    lines: lines,
  );
}

/// Somme des lignes du détail — doit TOUJOURS égaler [AnnualReportData.totalKm].
double reportLinesTotalKm(AnnualReportData report) =>
    sumKm(report.lines.map((line) => line.km));
