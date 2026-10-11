import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../../domain/models/favorite_trip.dart';
import '../../domain/models/vehicle.dart';
import '../../theme/tokens.dart';
import '../../widgets/km_format.dart';
import '../vehicles/vehicles_controller.dart';
import 'favorite_form_sheet.dart';
import 'favorites_controller.dart';

/// Gestion des trajets favoris : créer, modifier, supprimer, réordonner.
///
/// Réorganisation par flèches haut/bas : fiable au toucher sur iPhone
/// (le drag & drop web/Safari ne l'est pas assez), et impossible à
/// déclencher par accident.
///
/// [initialFavoriteId] : ouvre directement la fiche d'édition de ce favori
/// (raccourci « Modifier » depuis une journée) — même écran, même
/// formulaire, aucune logique dupliquée.
class ManageFavoritesScreen extends ConsumerStatefulWidget {
  const ManageFavoritesScreen({super.key, this.initialFavoriteId});

  final String? initialFavoriteId;

  @override
  ConsumerState<ManageFavoritesScreen> createState() =>
      _ManageFavoritesScreenState();
}

class _ManageFavoritesScreenState
    extends ConsumerState<ManageFavoritesScreen> {
  bool _autoOpenHandled = false;

  List<Vehicle> _activeVehicles() =>
      ref.read(vehiclesControllerProvider).value?.active ?? const [];

  Future<void> _create() async {
    final result = await showFavoriteFormSheet(
      context,
      vehicles: _activeVehicles(),
      routeService: ref.read(routeDistanceServiceProvider),
    );
    if (result == null) return;
    await ref.read(favoritesControllerProvider.notifier).create(
          label: result.label,
          distanceKm: result.distanceKm,
          defaultRoundTrip: result.defaultRoundTrip,
          origin: result.origin,
          destination: result.destination,
          purpose: result.purpose,
          vehicleId: result.vehicleId,
        );
  }

  Future<void> _edit(FavoriteTrip favorite) async {
    final result = await showFavoriteFormSheet(
      context,
      initial: favorite,
      vehicles: _activeVehicles(),
      routeService: ref.read(routeDistanceServiceProvider),
      onDeleteRequested: () => _delete(favorite),
    );
    if (result == null) return;
    await ref.read(favoritesControllerProvider.notifier).updateFavorite(
          favorite,
          label: result.label,
          distanceKm: result.distanceKm,
          defaultRoundTrip: result.defaultRoundTrip,
          origin: result.origin,
          destination: result.destination,
          purpose: result.purpose,
          vehicleId: result.vehicleId,
        );
  }

  /// Confirmation + suppression. Retourne true si supprimé.
  Future<bool> _delete(FavoriteTrip favorite) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Supprimer ce favori ?'),
        content: Text(
          '${favorite.label} — ${formatKm(favorite.distanceKm)}\n\n'
          'Il ne sera plus proposé dans vos trajets favoris.\n'
          'Les trajets déjà enregistrés ne seront pas supprimés.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Annuler'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Supprimer'),
          ),
        ],
      ),
    );
    if (confirmed != true) return false;
    await ref
        .read(favoritesControllerProvider.notifier)
        .deleteFavorite(favorite.id);
    return true;
  }

  void _maybeAutoOpen(List<FavoriteTrip> favorites) {
    if (_autoOpenHandled || widget.initialFavoriteId == null) return;
    _autoOpenHandled = true;

    FavoriteTrip? target;
    for (final favorite in favorites) {
      if (favorite.id == widget.initialFavoriteId) {
        target = favorite;
        break;
      }
    }
    if (target == null) return;

    final favorite = target;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _edit(favorite);
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final favoritesState = ref.watch(favoritesControllerProvider);
    final favorites = favoritesState.value ?? const <FavoriteTrip>[];

    if (favoritesState.hasValue) {
      _maybeAutoOpen(favorites);
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Trajets favoris')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(AppSpacing.l),
          children: [
            Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.l),
              child: Text(
                'Ces favoris sont proposés sur toutes les journées. '
                'Les supprimer ne supprime aucun trajet déjà enregistré.',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ),
            if (favorites.isEmpty)
              Padding(
                padding: const EdgeInsets.all(AppSpacing.xl),
                child: Text(
                  'Aucun favori pour le moment.',
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
            for (var index = 0; index < favorites.length; index++)
              Card(
                margin: const EdgeInsets.only(bottom: AppSpacing.m),
                child: ListTile(
                  key: Key('manage-favorite-${favorites[index].id}'),
                  onTap: () => _edit(favorites[index]),
                  minTileHeight: AppSizes.minTouchTarget + 8,
                  title: Text(
                    favorites[index].label,
                    style: theme.textTheme.titleMedium
                        ?.copyWith(fontWeight: FontWeight.bold),
                  ),
                  subtitle: Text(formatKm(favorites[index].distanceKm)),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.arrow_upward),
                        tooltip: 'Monter',
                        onPressed: index == 0
                            ? null
                            : () => ref
                                .read(favoritesControllerProvider.notifier)
                                .move(favorites[index].id, -1),
                      ),
                      IconButton(
                        icon: const Icon(Icons.arrow_downward),
                        tooltip: 'Descendre',
                        onPressed: index == favorites.length - 1
                            ? null
                            : () => ref
                                .read(favoritesControllerProvider.notifier)
                                .move(favorites[index].id, 1),
                      ),
                      IconButton(
                        icon: const Icon(Icons.delete_outline),
                        tooltip: 'Supprimer',
                        onPressed: () => _delete(favorites[index]),
                      ),
                    ],
                  ),
                ),
              ),
            const SizedBox(height: AppSpacing.s),
            FilledButton.tonalIcon(
              onPressed: _create,
              icon: const Icon(Icons.add),
              label: const Text('Nouveau favori'),
              style: FilledButton.styleFrom(
                minimumSize:
                    const Size.fromHeight(AppSizes.minTouchTarget + 8),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
