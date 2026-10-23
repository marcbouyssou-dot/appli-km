import 'civil_date.dart';
import 'favorite_trip.dart';
import 'km.dart';
import 'text.dart';
import 'trip.dart';

/// Caractéristiques à reproduire, sans identité/date ni métadonnées techniques.
/// La distance est déjà comptabilisée, même pour un aller-retour.
class TripTemplate {
  TripTemplate({
    required double distanceKm,
    this.isRoundTrip = false,
    String? origin,
    String? destination,
    String? purpose,
    String? vehicleId,
  }) : distanceKm = normalizeKm(distanceKm),
       origin = cleanText(origin),
       destination = cleanText(destination),
       purpose = cleanText(purpose),
       vehicleId = cleanText(vehicleId) {
    if (this.distanceKm <= 0) {
      throw ArgumentError('La distance doit être positive.');
    }
  }

  TripTemplate.fromTrip(Trip trip)
    : this(
        distanceKm: trip.distanceKm,
        isRoundTrip: trip.isRoundTrip,
        origin: trip.origin,
        destination: trip.destination,
        purpose: trip.purpose,
        vehicleId: trip.vehicleId,
      );
  TripTemplate.fromFavorite(FavoriteTrip favorite)
    : this(
        distanceKm: favorite.distanceKm,
        isRoundTrip: favorite.defaultRoundTrip,
        origin: favorite.origin,
        destination: favorite.destination,
        purpose: favorite.purpose,
        vehicleId: favorite.vehicleId,
      );

  final double distanceKm;
  final bool isRoundTrip;
  final String? origin, destination, purpose, vehicleId;

  Trip createTrip({
    required String id,
    required CivilDate date,
    required DateTime createdAt,
    required String? vehicleId,
  }) => Trip(
    id: id,
    date: date,
    createdAt: createdAt,
    distanceKm: distanceKm,
    isRoundTrip: isRoundTrip,
    origin: origin,
    destination: destination,
    purpose: purpose,
    vehicleId: vehicleId,
  );
}
