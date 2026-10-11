import '../models/civil_date.dart';
import '../models/day_extra.dart';
import '../models/km.dart';
import '../models/trip.dart';

/// INVARIANT CENTRAL DE MES KM :
/// le total d'une journée n'est jamais stocké ; il est toujours dérivé :
///
///   totalJour = somme(Trip.distanceKm du jour) + extraKm du jour
///
/// Les Trip sont immuables : aucune opération de total ne les modifie,
/// ne les supprime, ni ne double leur distance (l'aller-retour est déjà
/// compté dans Trip.distanceKm).

/// Somme des trajets détaillés, en km canonisés.
double detailedTotalKm(Iterable<Trip> trips) =>
    sumKm(trips.map((trip) => trip.distanceKm));

/// Total dérivé d'une journée : trajets détaillés + kilomètres non détaillés.
double dayTotalKm(Iterable<Trip> trips, DayExtra? extra) =>
    sumKm([...trips.map((trip) => trip.distanceKm), extra?.extraKm ?? 0]);

/// Résultat métier typé de l'application d'un total journalier déclaré.
sealed class DailyTotalAdjustment {
  const DailyTotalAdjustment();
}

/// Le total déclaré est applicable : [dayExtra] est le DayExtra à retenir
/// pour la journée (`null` si le total déclaré égale les trajets détaillés :
/// absence logique de kilomètres non détaillés).
class DailyTotalAdjusted extends DailyTotalAdjustment {
  const DailyTotalAdjusted({required this.extraKm, required this.dayExtra});

  final double extraKm;
  final DayExtra? dayExtra;
}

/// REFUS métier : le total déclaré est inférieur à la somme des trajets
/// détaillés. Rien n'est modifié ; c'est à l'utilisateur de décider
/// (modifier/supprimer des trajets lui-même, ou abandonner).
class DailyTotalBelowDetailed extends DailyTotalAdjustment {
  const DailyTotalBelowDetailed({
    required this.detailedKm,
    required this.requestedKm,
  });

  final double detailedKm;
  final double requestedKm;
}

/// Applique un total journalier déclaré par l'utilisateur.
///
/// - total >= somme détaillée : succès, extra = total - somme (0 => absence
///   logique, dayExtra null) ;
/// - total < somme détaillée : refus typé, aucun Trip modifié, aucun calcul
///   négatif.
///
/// [tripsOfDay] doit ne contenir que des trajets de [date] ; un total déclaré
/// négatif est une erreur d'appel, pas un cas métier.
DailyTotalAdjustment applyDeclaredDayTotal({
  required CivilDate date,
  required Iterable<Trip> tripsOfDay,
  required double declaredTotalKm,
}) {
  final trips = List<Trip>.unmodifiable(tripsOfDay);
  for (final trip in trips) {
    if (trip.date != date) {
      throw ArgumentError(
        'applyDeclaredDayTotal : le trajet ${trip.id} (${trip.date}) '
        'n’appartient pas au jour $date.',
      );
    }
  }

  final declared = normalizeKm(declaredTotalKm);
  if (declared < 0) {
    throw ArgumentError(
      'Le total déclaré ne peut pas être négatif (reçu : $declaredTotalKm).',
    );
  }

  final detailed = detailedTotalKm(trips);
  if (declared < detailed) {
    return DailyTotalBelowDetailed(
      detailedKm: detailed,
      requestedKm: declared,
    );
  }

  final extra = normalizeKm(declared - detailed);
  return DailyTotalAdjusted(
    extraKm: extra,
    dayExtra: extra == 0 ? null : DayExtra(date: date, extraKm: extra),
  );
}
