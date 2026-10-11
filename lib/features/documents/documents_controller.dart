import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../../data/backup/backup_file_gateway.dart';
import '../../domain/logic/statistics.dart';
import '../../domain/models/civil_date.dart';
import '../../domain/models/day_extra.dart';
import '../../domain/models/trip.dart';
import 'csv_builder.dart';
import 'pdf_builder.dart';
import 'report_data.dart';

class DocumentsState {
  DocumentsState({
    required this.year,
    required this.today,
    required this.yearTotal,
  });

  final int year;
  final CivilDate today;
  final double yearTotal;

  bool get hasData => yearTotal > 0;

  bool get isCurrentYear => year == today.year;
}

/// Documents annuels : générés ENTIÈREMENT localement (aucun réseau),
/// à partir d'un AnnualReportData assemblé une seule fois — PDF et CSV
/// consomment le même relevé. Chargements bornés à l'année (pas de N+1).
class DocumentsController extends AsyncNotifier<DocumentsState> {
  int? _year;

  @override
  Future<DocumentsState> build() {
    ref.watch(dayDataVersionProvider);
    final today = ref.read(todayDateProvider)();
    _year ??= today.year;
    return _load(today);
  }

  Future<(List<Trip>, List<DayExtra>)> _loadYearData(int year) async {
    final first = CivilDate(year, 1, 1);
    final last = CivilDate(year, 12, 31);
    final trips =
        await ref.read(tripRepositoryProvider).getBetween(first, last);
    final extras =
        await ref.read(dayExtraRepositoryProvider).getBetween(first, last);
    return (trips, extras);
  }

  Future<DocumentsState> _load(CivilDate today) async {
    final year = _year!;
    final (trips, extras) = await _loadYearData(year);
    return DocumentsState(
      year: year,
      today: today,
      yearTotal: totalForYear(year, trips: trips, extras: extras),
    );
  }

  Future<void> _show(int year) async {
    _year = year;
    state = const AsyncLoading();
    state =
        await AsyncValue.guard(() => _load(ref.read(todayDateProvider)()));
  }

  Future<void> previousYear() => _show(_year! - 1);

  Future<void> nextYear() => _show(_year! + 1);

  Future<void> goToCurrentYear() =>
      _show(ref.read(todayDateProvider)().year);

  /// Assemble le relevé — une seule passe, requêtes bornées.
  Future<AnnualReportData> buildReport() async {
    final year = _year!;
    final (trips, extras) = await _loadYearData(year);
    final vehicles = await ref.read(vehicleRepositoryProvider).getAll();
    final vacations = await ref.read(vacationRepositoryProvider).getAll();
    final settings = await ref.read(settingsRepositoryProvider).get();

    return buildAnnualReportData(
      year: year,
      generatedAt: DateTime.now(),
      trips: trips,
      extras: extras,
      vehicles: vehicles,
      vacations: vacations,
      settings: settings,
    );
  }

  Future<BackupSaveOutcome> createPdf() async {
    final report = await buildReport();
    final bytes = await buildAnnualPdf(report);
    return ref.read(backupFileGatewayProvider).saveFile(
          fileName: 'MesKm-Releve-${report.year}.pdf',
          bytes: bytes,
          mimeType: 'application/pdf',
        );
  }

  Future<BackupSaveOutcome> createCsv() async {
    final report = await buildReport();
    // Octet-stream : leçon KM-008B — Safari prévisualise les types texte
    // et peut altérer le nom ; Fichiers/Numbers s'appuient sur l'extension.
    return ref.read(backupFileGatewayProvider).saveFile(
          fileName: 'MesKm-Detail-${report.year}.csv',
          bytes: utf8.encode(buildAnnualCsv(report)),
          mimeType: 'application/octet-stream',
        );
  }
}

final documentsControllerProvider =
    AsyncNotifierProvider<DocumentsController, DocumentsState>(
  DocumentsController.new,
);
