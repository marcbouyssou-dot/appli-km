import 'km.dart';
import 'text.dart';

/// Modèle de saisie en un toucher.
///
/// Sémantique des distances, à ne jamais réinterpréter ailleurs :
/// - [distanceKm] est la distance d'un ALLER SIMPLE ;
/// - [defaultRoundTrip] indique seulement ce qui sera proposé par défaut au
///   moment de l'utilisation ;
/// - la distance réellement comptée se calcule via [countedDistanceKm] au
///   moment où le favori est utilisé, et c'est cette valeur qui alimente le
///   `Trip.distanceKm` créé.
///
/// Un favori utilisé crée un Trip indépendant : modifier ou supprimer un
/// favori ne touche jamais l'historique.
class FavoriteTrip {
  FavoriteTrip({
    required this.id,
    required String label,
    required double distanceKm,
    this.defaultRoundTrip = false,
    String? origin,
    String? destination,
    String? purpose,
    String? vehicleId,
    required this.sortOrder,
  })  : label = label.trim(),
        distanceKm = normalizeKm(distanceKm),
        origin = cleanText(origin),
        destination = cleanText(destination),
        purpose = cleanText(purpose),
        vehicleId = cleanText(vehicleId) {
    if (id.trim().isEmpty) {
      throw ArgumentError('FavoriteTrip.id ne doit pas être vide.');
    }
    if (this.label.isEmpty) {
      throw ArgumentError('FavoriteTrip.label ne doit pas être vide.');
    }
    if (this.distanceKm <= 0) {
      throw ArgumentError(
        'FavoriteTrip.distanceKm doit être strictement positive '
        '(reçu : $distanceKm).',
      );
    }
    if (sortOrder < 0) {
      throw ArgumentError(
        'FavoriteTrip.sortOrder doit être >= 0 (reçu : $sortOrder).',
      );
    }
  }

  final String id;
  final String label;

  /// Distance d'un aller simple, en km, canonisée au dixième.
  final double distanceKm;

  /// Proposition par défaut à l'utilisation (aller-retour ou non).
  final bool defaultRoundTrip;

  final String? origin;
  final String? destination;
  final String? purpose;
  final String? vehicleId;

  /// Position dans la liste des favoris (réorganisable), >= 0.
  final int sortOrder;

  /// Distance comptée si ce favori est utilisé maintenant.
  /// [roundTrip] permet de surcharger le choix par défaut au moment du tap.
  double countedDistanceKm({bool? roundTrip}) {
    final isRoundTrip = roundTrip ?? defaultRoundTrip;
    return isRoundTrip ? normalizeKm(distanceKm * 2) : distanceKm;
  }
}
