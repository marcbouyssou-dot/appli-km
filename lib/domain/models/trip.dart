import 'civil_date.dart';
import 'km.dart';
import 'text.dart';

/// Un trajet détaillé, rattaché à une date civile.
///
/// [distanceKm] est TOUJOURS la distance réellement comptée pour la journée :
/// pour un aller-retour, elle est déjà la distance totale. [isRoundTrip] est
/// une pure métadonnée d'affichage/édition et ne provoque jamais de
/// doublement dans les calculs.
///
/// Un Trip est immuable : aucune opération de total journalier ne le modifie
/// ni ne le supprime implicitement.
class Trip {
  Trip({
    required this.id,
    required this.date,
    required double distanceKm,
    this.isRoundTrip = false,
    String? origin,
    String? destination,
    String? purpose,
    String? vehicleId,
    required this.createdAt,
  })  : distanceKm = normalizeKm(distanceKm),
        origin = cleanText(origin),
        destination = cleanText(destination),
        purpose = cleanText(purpose),
        vehicleId = cleanText(vehicleId) {
    if (id.trim().isEmpty) {
      throw ArgumentError('Trip.id ne doit pas être vide.');
    }
    if (this.distanceKm <= 0) {
      throw ArgumentError(
        'Trip.distanceKm doit être strictement positive (reçu : $distanceKm).',
      );
    }
  }

  final String id;
  final CivilDate date;

  /// Distance comptée, en km, canonisée au dixième. Déjà totale si A/R.
  final double distanceKm;

  /// Métadonnée : le trajet a été saisi comme un aller-retour.
  final bool isRoundTrip;

  final String? origin;
  final String? destination;
  final String? purpose;

  /// Véhicule utilisé. Résolu à la création (le véhicule principal du moment
  /// y est figé) ; `null` si réellement inconnu.
  final String? vehicleId;

  final DateTime createdAt;
}
