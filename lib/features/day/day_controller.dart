import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../../domain/logic/day_total.dart';
import '../../domain/models/civil_date.dart';
import '../../domain/models/day_extra.dart';
import '../../domain/models/favorite_trip.dart';
import '../../domain/models/trip.dart';

/// État d'une journée : ses données, totaux dérivés.
class DayState {
  DayState({required this.date, required this.trips, required this.extra});

  final CivilDate date;
  final List<Trip> trips;
  final DayExtra? extra;

  double get detailedKm => detailedTotalKm(trips);
  double get extraKm => extra?.extraKm ?? 0;

  /// Total dérivé du domaine : jamais stocké indépendamment.
  double get totalKm => dayTotalKm(trips, extra);

  bool get isEmpty => trips.isEmpty && extra == null;
}

/// Contrôleur d'UNE journée (aujourd'hui ou passée), paramétré par sa
/// [CivilDate] via le family provider : toutes les opérations utilisent
/// explicitement cette date — jamais `DateTime.now()` côté métier.
///
/// Toute action suit le flux : domaine -> repository -> rechargement,
/// puis incrémente la version des données pour les vues agrégées.
/// L'invariant du total journalier vient de `applyDeclaredDayTotal`.
class DayController extends AsyncNotifier<DayState> {
  DayController(this.date);

  final CivilDate date;

  @override
  Future<DayState> build() => _load();

  Future<DayState> _load() async {
    final trips = await ref.read(tripRepositoryProvider).getByDate(date);
    final extra = await ref.read(dayExtraRepositoryProvider).getForDate(date);
    return DayState(date: date, trips: trips, extra: extra);
  }

  Future<void> _refresh() async {
    state = await AsyncValue.guard(_load);
    ref.read(dayDataVersionProvider.notifier).bump();
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
        // Attribution FIGÉE : un extra existant conserve son véhicule (et sa
        // note) lors d'une modification du total ; un nouvel extra fige le
        // véhicule principal ACTUEL (null si aucun). Changer de principal
        // plus tard ne réattribue jamais l'historique.
        final existing = current.extra;
        final vehicleId =
            existing?.vehicleId ?? await _currentMainVehicleId();
        await repo.set(DayExtra(
          date: dayExtra.date,
          extraKm: dayExtra.extraKm,
          vehicleId: vehicleId,
          note: existing?.note,
        ));
      }
      await _refresh();
    }

    return result;
  }

  Future<String?> _currentMainVehicleId() async =>
      (await ref.read(settingsRepositoryProvider).get()).mainVehicleId;

  /// Correction explicite de l'attribution des kilomètres non détaillés :
  /// change UNIQUEMENT le véhicule, jamais le kilométrage.
  Future<void> setDayExtraVehicle(String? vehicleId) async {
    final current = await future;
    final extra = current.extra;
    if (extra == null) return;
    await ref.read(dayExtraRepositoryProvider).set(DayExtra(
          date: extra.date,
          extraKm: extra.extraKm,
          vehicleId: vehicleId,
          note: extra.note,
        ));
    await _refresh();
  }

  /// [vehicleId] : choisi dans le formulaire (pré-sélectionné sur le
  /// principal actuel) ; null si aucun véhicule. Figé dans le Trip.
  Future<void> addTrip({
    required double distanceKm,
    required bool isRoundTrip,
    String? origin,
    String? destination,
    String? purpose,
    String? vehicleId,
  }) async {
    final trip = Trip(
      id: ref.read(idGeneratorProvider).newId(),
      date: date,
      distanceKm: distanceKm,
      isRoundTrip: isRoundTrip,
      origin: origin,
      destination: destination,
      purpose: purpose,
      vehicleId: vehicleId,
      createdAt: DateTime.now(),
    );
    await ref.read(tripRepositoryProvider).put(trip);
    await _refresh();
  }

  /// Un toucher sur un favori : crée immédiatement un Trip indépendant.
  ///
  /// La distance du favori est copiée TELLE QUELLE (aucun doublement,
  /// `defaultRoundTrip` n'est qu'une métadonnée), le DayExtra du jour n'est
  /// jamais recalculé : le favori AJOUTE des kilomètres. Deux taps créent
  /// deux Trips distincts — aucune déduplication.
  ///
  /// Véhicule : vehicleId explicite du favori, sinon (« Automatique ») le
  /// principal ACTUEL, résolu au moment du tap et figé dans le Trip.
  /// Un favori lié à un véhicule ARCHIVÉ ne produit jamais silencieusement
  /// un Trip archivé : repli sur le principal actuel, et retour `true`
  /// pour que l'UI informe l'utilisateur (favori à corriger).
  Future<bool> addTripFromFavorite(FavoriteTrip favorite) async {
    var archivedFallback = false;
    String? vehicleId = favorite.vehicleId;
    if (vehicleId != null) {
      final vehicle =
          await ref.read(vehicleRepositoryProvider).getById(vehicleId);
      if (vehicle == null || vehicle.isArchived) {
        archivedFallback = true;
        vehicleId = null;
      }
    }
    vehicleId ??= await _currentMainVehicleId();

    final trip = Trip(
      id: ref.read(idGeneratorProvider).newId(),
      date: date,
      distanceKm: favorite.distanceKm,
      isRoundTrip: favorite.defaultRoundTrip,
      origin: favorite.origin,
      destination: favorite.destination,
      purpose: favorite.purpose,
      vehicleId: vehicleId,
      createdAt: DateTime.now(),
    );
    await ref.read(tripRepositoryProvider).put(trip);
    await _refresh();
    return archivedFallback;
  }

  /// Remplace le trajet [original] (même id, même createdAt, même date).
  /// [vehicleId] : par défaut le véhicule HISTORIQUE du trajet — jamais
  /// le principal du moment.
  Future<void> updateTrip(
    Trip original, {
    required double distanceKm,
    required bool isRoundTrip,
    String? origin,
    String? destination,
    String? purpose,
    String? vehicleId,
  }) async {
    final updated = Trip(
      id: original.id,
      date: original.date,
      distanceKm: distanceKm,
      isRoundTrip: isRoundTrip,
      origin: origin,
      destination: destination,
      purpose: purpose,
      vehicleId: vehicleId,
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

  /// Efface TOUTE la journée (trajets + extra), atomiquement.
  ///
  /// Opération destructive EXPLICITE, déclenchée après confirmation UI —
  /// l'édition directe du total à 0 avec des trajets reste refusée, c'est
  /// la protection contre la suppression accidentelle. Les favoris et les
  /// autres journées ne sont jamais touchés.
  Future<void> clearDay() async {
    await ref.read(dayClearRepositoryProvider).clearDay(date);
    await _refresh();
  }
}

/// Contrôleur par date : la même date partage la même instance — l'écran
/// Aujourd'hui et le détail calendrier du même jour restent synchrones.
final dayControllerProvider =
    AsyncNotifierProvider.family<DayController, DayState, CivilDate>(
  DayController.new,
);
