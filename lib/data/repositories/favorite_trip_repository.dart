import '../../domain/models/favorite_trip.dart';

/// Accès aux trajets favoris.
abstract interface class FavoriteTripRepository {
  /// Favoris triés par [FavoriteTrip.sortOrder] (puis label à égalité).
  Future<List<FavoriteTrip>> getAllOrdered();

  /// Crée ou remplace (même id) un favori.
  Future<void> put(FavoriteTrip favorite);

  Future<void> delete(String id);

  /// Réécrit atomiquement l'ordre complet : sortOrder = position dans la
  /// liste. Refuse (ArgumentError) un id inconnu.
  Future<void> reorder(List<String> orderedIds);
}
