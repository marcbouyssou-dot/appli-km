import 'km.dart';
import 'text.dart';

/// Modèle de saisie en un toucher.
///
/// Sémantique des distances (règle produit V2, à ne jamais réinterpréter) :
/// - [distanceKm] est EXACTEMENT la distance comptabilisée qui sera copiée
///   telle quelle dans `Trip.distanceKm` à chaque utilisation — déjà totale
///   si le trajet est un aller-retour. AUCUN doublement, nulle part ;
/// - [defaultRoundTrip] est une pure métadonnée, copiée dans
///   `Trip.isRoundTrip`, sans effet sur les calculs.
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

  /// Distance comptabilisée ajoutée à chaque utilisation, en km,
  /// canonisée au dixième. Déjà totale si aller-retour.
  final double distanceKm;

  /// Métadonnée copiée dans `Trip.isRoundTrip` ; jamais utilisée pour
  /// doubler une distance.
  final bool defaultRoundTrip;

  final String? origin;
  final String? destination;
  final String? purpose;
  final String? vehicleId;

  /// Position dans la liste des favoris (réorganisable), >= 0.
  final int sortOrder;
}
