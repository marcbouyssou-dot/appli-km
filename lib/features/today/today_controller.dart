import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../../domain/logic/day_total.dart';
import '../../domain/models/civil_date.dart';
import '../../domain/models/day_extra.dart';
import '../../domain/models/trip.dart';

/// État de l'écran Aujourd'hui : les données du jour, totaux dérivés.
class TodayState {
  TodayState({required this.date, required this.trips, required this.extra});

  final CivilDate date;
  final List<Trip> trips;
  final DayExtra? extra;

  double get detailedKm => detailedTotalKm(trips);
  double get extraKm => extra?.extraKm ?? 0;

  /// Total dérivé du domaine : jamais stocké indépendamment.
  double get totalKm => dayTotalKm(trips, extra);

  bool get isEmpty => trips.isEmpty && extra == null;
}

/// Contrôleur de l'écran Aujourd'hui.
///
/// Toute action suit le flux : domaine -> repository -> rechargement.
/// Aucune logique métier n'est réimplémentée ici : l'invariant du total
/// journalier vient de `applyDeclaredDayTotal` (domaine).
class TodayController extends AsyncNotifier<TodayState> {
  @override
  Future<TodayState> build() => _load();

  Future<TodayState> _load() async {
    final date = ref.read(todayDateProvider)();
    final trips = await ref.read(tripRepositoryProvider).getByDate(date);
    final extra = await ref.read(dayExtraRepositoryProvider).getForDate(date);
    return TodayState(date: date, trips: trips, extra: extra);
  }

  Future<void> _refresh() async {
    state = await AsyncValue.guard(_load);
  }

  /// Applique un total journalier déclaré. Retourne le résultat métier typé :
  /// l'UI affiche le refus éventuel, rien n'est modifié dans ce cas.
  Future<DailyTotalAdjustment> declareTotal(double declaredTotalKm) async {
    final current = await future;

    final result = applyDeclaredDayTotal(
      date: current.date,
      tripsOfDay: current.trips,
      declaredTotalKm: declaredTotalKm,
    );

    if (result is DailyTotalAdjusted) {
      final repo = ref.read(dayExtraRepositoryProvider);
      final dayExtra = result.dayExtra;
      if (dayExtra == null) {
        await repo.deleteForDate(current.date);
      } else {
        await repo.set(dayExtra);
      }
      await _refresh();
    }

    return result;
  }

  Future<void> addTrip({
    required double distanceKm,
    required bool isRoundTrip,
    String? origin,
    String? destination,
    String? purpose,
  }) async {
    final current = await future;
    final trip = Trip(
      id: ref.read(idGeneratorProvider).newId(),
      date: current.date,
      distanceKm: distanceKm,
      isRoundTrip: isRoundTrip,
      origin: origin,
      destination: destination,
      purpose: purpose,
      createdAt: DateTime.now(),
    );
    await ref.read(tripRepositoryProvider).put(trip);
    await _refresh();
  }

  /// Remplace le trajet [original] (même id, même createdAt).
  Future<void> updateTrip(
    Trip original, {
    required double distanceKm,
    required bool isRoundTrip,
    String? origin,
    String? destination,
    String? purpose,
  }) async {
    final updated = Trip(
      id: original.id,
      date: original.date,
      distanceKm: distanceKm,
      isRoundTrip: isRoundTrip,
      origin: origin,
      destination: destination,
      purpose: purpose,
      createdAt: original.createdAt,
    );
    await ref.read(tripRepositoryProvider).put(updated);
    await _refresh();
  }

  /// Supprime un trajet. Le DayExtra du jour n'est PAS modifié :
  /// le total dérivé diminue, c'est le comportement honnête.
  Future<void> deleteTrip(String id) async {
    await ref.read(tripRepositoryProvider).delete(id);
    await _refresh();
  }
}

final todayControllerProvider =
    AsyncNotifierProvider<TodayController, TodayState>(TodayController.new);
