import 'dart:convert';

import 'package:sembast/sembast.dart';

import '../../domain/logic/vacations.dart';
import '../../domain/models/civil_date.dart';
import '../../domain/models/trip_template.dart';
import '../../domain/models/trip.dart';
import 'app_database.dart';
import 'codecs.dart';

/// Provenance du trajet : référence persistée relue, ou saisie immuable.
/// Aucun favori temporaire n'est enregistré pour un nouveau trajet.
class TripBatchSource {
  const TripBatchSource.favorite(String id)
    : favoriteId = id,
      tripId = null,
      draft = null;
  const TripBatchSource.existingTrip(String id)
    : tripId = id,
      favoriteId = null,
      draft = null;
  const TripBatchSource.draft(TripTemplate value)
    : draft = value,
      favoriteId = null,
      tripId = null;
  final String? favoriteId, tripId;
  final TripTemplate? draft;
}

/// Aperçu immuable : aucun trajet n'est écrit avant confirmation.
class TripBatchPlan {
  TripBatchPlan({
    required this.source,
    required this.template,
    required this.label,
    required this.sourceDate,
    required this.vehicleId,
    required this.vehicleLabel,
    required List<CivilDate> requested,
    required List<CivilDate> additions,
    required List<CivilDate> duplicates,
    required List<CivilDate> vacations,
    required this.today,
    required this.vehicleConfirmed,
    required this.signature,
  }) : requested = List.unmodifiable(requested),
       additions = List.unmodifiable(additions),
       duplicates = List.unmodifiable(duplicates),
       vacations = List.unmodifiable(vacations);

  final TripBatchSource source;
  final TripTemplate template;
  final String label;
  final CivilDate? sourceDate;
  final String? vehicleId;
  final String vehicleLabel;
  final List<CivilDate> requested, additions, duplicates, vacations;
  final CivilDate today;
  final bool vehicleConfirmed;
  final String signature;
}

/// Une seule transaction Sembast, y compris la revérification anti-doublon.
/// Aucun extra, favori, véhicule ou congé existant n'est modifié.
class TripBatchService {
  TripBatchService(this._db, {required String Function() newId})
    : _newId = newId;
  final Database _db;
  final String Function() _newId;

  Future<TripBatchPlan> preview({
    required TripBatchSource source,
    required Iterable<CivilDate> dates,
    required String? vehicleId,
    required CivilDate today,
    required bool vehicleConfirmed,
  }) => _db.transaction(
    (txn) => _plan(
      txn,
      source: source,
      dates: dates,
      vehicleId: vehicleId,
      today: today,
      vehicleConfirmed: vehicleConfirmed,
    ),
  );

  Future<int> apply(TripBatchPlan approved) => _db.transaction((txn) async {
    final fresh = await _plan(
      txn,
      source: approved.source,
      dates: approved.requested,
      vehicleId: approved.vehicleId,
      today: approved.today,
      vehicleConfirmed: approved.vehicleConfirmed,
    );
    if (fresh.signature != approved.signature) {
      throw StateError(
        'Les données ont changé. Vérifiez à nouveau les jours avant de confirmer.',
      );
    }
    final now = DateTime.now();
    for (final date in fresh.additions) {
      final id = _newId();
      if (await tripsStore.record(id).exists(txn)) {
        throw StateError(
          'Identifiant de trajet déjà utilisé. Aucun trajet ajouté.',
        );
      }
      await tripsStore
          .record(id)
          .put(
            txn,
            tripToDb(
              fresh.template.createTrip(
                id: id,
                date: date,
                createdAt: now,
                vehicleId: fresh.vehicleId,
              ),
            ),
          );
    }
    return fresh.additions.length;
  });

  Future<TripBatchPlan> _plan(
    Transaction txn, {
    required TripBatchSource source,
    required Iterable<CivilDate> dates,
    required String? vehicleId,
    required CivilDate today,
    required bool vehicleConfirmed,
  }) async {
    final sorted = dates.toSet().toList()..sort();
    if (sorted.isEmpty) throw ArgumentError('Choisissez au moins un jour.');
    if (sorted.any((d) => d.isAfter(today))) {
      throw ArgumentError(
        'Choisissez uniquement des jours passés ou aujourd’hui.',
      );
    }
    // Il n'existe pas d'historique des changements de véhicule principal.
    // Une attribution passée doit donc être explicitement confirmée, jamais devinée.
    if (sorted.any((d) => d.isBefore(today)) && !vehicleConfirmed) {
      throw ArgumentError(
        'Confirmez le véhicule réellement utilisé pour ces dates.',
      );
    }
    late final TripTemplate template;
    late final String sourceLabel;
    late final Object sourceFingerprint;
    CivilDate? sourceDate;
    if (source.favoriteId case final id?) {
      final map = await favoriteTripsStore.record(id).get(txn);
      if (map == null) throw StateError('Ce favori n’existe plus.');
      final favorite = favoriteTripFromDb(id, map);
      template = TripTemplate.fromFavorite(favorite);
      sourceLabel = favorite.label;
      sourceFingerprint = [id, favoriteTripToDb(favorite)];
    } else if (source.tripId case final id?) {
      final map = await tripsStore.record(id).get(txn);
      if (map == null) throw StateError('Le trajet d’origine n’existe plus.');
      final trip = tripFromDb(id, map);
      template = TripTemplate.fromTrip(trip);
      sourceDate = trip.date;
      sourceLabel = 'Trajet d’origine';
      sourceFingerprint = [id, tripToDb(trip)];
    } else {
      template = source.draft!;
      sourceLabel = 'Nouveau trajet';
      sourceFingerprint = [
        template.distanceKm,
        template.isRoundTrip,
        template.origin,
        template.destination,
        template.purpose,
        template.vehicleId,
      ];
    }
    String label = 'Sans véhicule renseigné';
    CivilDate? archivedDate;
    if (vehicleId != null) {
      final value = await vehiclesStore.record(vehicleId).get(txn);
      if (value == null) throw StateError('Ce véhicule n’existe plus.');
      final vehicle = vehicleFromDb(vehicleId, value);
      label = vehicle.name;
      if (vehicle.archivedAt != null) {
        archivedDate = CivilDate.fromDateTime(vehicle.archivedAt!.toLocal());
      }
    }
    final periods = [
      for (final s in await vacationPeriodsStore.find(txn))
        vacationPeriodFromDb(s.key, s.value),
    ];
    final existing = [
      for (final s in await tripsStore.find(
        txn,
        finder: Finder(
          filter: Filter.and([
            Filter.greaterThanOrEquals('date', sorted.first.toIso8601()),
            Filter.lessThanOrEquals('date', sorted.last.toIso8601()),
          ]),
        ),
      ))
        tripFromDb(s.key, s.value),
    ];
    String normalized(String? text) =>
        (text ?? '').trim().replaceAll(RegExp(r'\s+'), ' ').toLowerCase();
    bool matches(Trip t) =>
        t.vehicleId == vehicleId &&
        t.distanceKm == template.distanceKm &&
        t.isRoundTrip == template.isRoundTrip &&
        normalized(t.origin) == normalized(template.origin) &&
        normalized(t.destination) == normalized(template.destination) &&
        normalized(t.purpose) == normalized(template.purpose);
    final additions = <CivilDate>[],
        duplicates = <CivilDate>[],
        vacations = <CivilDate>[];
    for (final date in sorted) {
      // La date source est déjà présente, même si le véhicule de copie a changé.
      if (date == sourceDate) {
        duplicates.add(date);
        continue;
      }
      if (isVacationDate(periods, date)) {
        vacations.add(date);
        continue;
      }
      if (archivedDate != null && !date.isBefore(archivedDate)) {
        throw StateError(
          'Le véhicule était archivé le ${archivedDate.toIso8601()}. Choisissez le véhicule utilisé pour ces jours.',
        );
      }
      if (existing.any((t) => t.date == date && matches(t))) {
        duplicates.add(date);
      } else {
        additions.add(date);
      }
    }
    final signature = jsonEncode([
      sourceFingerprint,
      vehicleId,
      label,
      archivedDate?.toIso8601(),
      for (final list in [sorted, additions, duplicates, vacations])
        list.map((d) => d.toIso8601()).toList(),
    ]);
    return TripBatchPlan(
      source: source,
      template: template,
      label: sourceLabel,
      sourceDate: sourceDate,
      vehicleId: vehicleId,
      vehicleLabel: label,
      requested: sorted,
      additions: additions,
      duplicates: duplicates,
      vacations: vacations,
      today: today,
      vehicleConfirmed: vehicleConfirmed,
      signature: signature,
    );
  }
}
