import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../../domain/models/favorite_trip.dart';

/// Contrôleur des trajets favoris (liste ordonnée + CRUD + réorganisation).
/// Aucune logique de stockage : tout passe par FavoriteTripRepository.
class FavoritesController extends AsyncNotifier<List<FavoriteTrip>> {
  @override
  Future<List<FavoriteTrip>> build() =>
      ref.read(favoriteTripRepositoryProvider).getAllOrdered();

  Future<void> _refresh() async {
    state = await AsyncValue.guard(
      () => ref.read(favoriteTripRepositoryProvider).getAllOrdered(),
    );
  }

  Future<void> create({
    required String label,
    required double distanceKm,
    bool defaultRoundTrip = false,
    String? origin,
    String? destination,
    String? purpose,
  }) async {
    final favorites = await future;
    final favorite = FavoriteTrip(
      id: ref.read(idGeneratorProvider).newId(),
      label: label,
      distanceKm: distanceKm,
      defaultRoundTrip: defaultRoundTrip,
      origin: origin,
      destination: destination,
      purpose: purpose,
      sortOrder: favorites.length,
    );
    await ref.read(favoriteTripRepositoryProvider).put(favorite);
    await _refresh();
  }

  /// Remplace le favori [original] (même id, même position).
  /// Les Trips déjà créés depuis ce favori ne sont jamais modifiés.
  Future<void> updateFavorite(
    FavoriteTrip original, {
    required String label,
    required double distanceKm,
    required bool defaultRoundTrip,
    String? origin,
    String? destination,
    String? purpose,
  }) async {
    final updated = FavoriteTrip(
      id: original.id,
      label: label,
      distanceKm: distanceKm,
      defaultRoundTrip: defaultRoundTrip,
      origin: origin,
      destination: destination,
      purpose: purpose,
      sortOrder: original.sortOrder,
    );
    await ref.read(favoriteTripRepositoryProvider).put(updated);
    await _refresh();
  }

  Future<void> deleteFavorite(String id) async {
    await ref.read(favoriteTripRepositoryProvider).delete(id);
    await _refresh();
  }

  /// Déplace un favori d'une position ([delta] = -1 vers le haut, +1 vers
  /// le bas) et réécrit l'ordre complet atomiquement.
  Future<void> move(String id, int delta) async {
    final favorites = [...await future];
    final index = favorites.indexWhere((f) => f.id == id);
    if (index < 0) return;
    final newIndex = (index + delta).clamp(0, favorites.length - 1);
    if (newIndex == index) return;

    final moved = favorites.removeAt(index);
    favorites.insert(newIndex, moved);
    await ref
        .read(favoriteTripRepositoryProvider)
        .reorder([for (final f in favorites) f.id]);
    await _refresh();
  }
}

final favoritesControllerProvider =
    AsyncNotifierProvider<FavoritesController, List<FavoriteTrip>>(
  FavoritesController.new,
);
