import 'package:mes_km/domain/models/civil_date.dart';
import 'package:mes_km/domain/models/trip.dart';

/// Fabrique de Trip pour les tests, avec des valeurs par défaut sûres.
Trip makeTrip({
  String id = 'trip-1',
  CivilDate? date,
  double km = 10,
  bool isRoundTrip = false,
  String? vehicleId,
}) {
  return Trip(
    id: id,
    date: date ?? CivilDate(2026, 10, 11),
    distanceKm: km,
    isRoundTrip: isRoundTrip,
    vehicleId: vehicleId,
    createdAt: DateTime(2026, 10, 11, 12, 0),
  );
}
