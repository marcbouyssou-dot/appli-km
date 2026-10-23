import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../../domain/models/favorite_trip.dart';
import '../../domain/models/vehicle.dart';
import '../../widgets/empty_state.dart';
import '../../theme/mes_km_colors.dart';
import '../../theme/tokens.dart';
import '../../widgets/km_format.dart';
import '../vehicles/vehicles_controller.dart';
import 'favorite_form_sheet.dart';
import 'favorites_controller.dart';
import 'favorite_days_screen.dart';

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

class _ManageFavoritesScreenState extends ConsumerState<ManageFavoritesScreen> {
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
    await ref
        .read(favoritesControllerProvider.notifier)
        .create(
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
    await ref
        .read(favoritesControllerProvider.notifier)
        .updateFavorite(
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
              padding: const EdgeInsets.only(bottom: AppSpacing.m),
              // UX-006B : une seule ligne — le dialogue de suppression
              // explique déjà qu'aucun trajet enregistré n'est touché.
              child: Text(
                'Proposés sur toutes les journées, en un toucher.',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ),
            if (favorites.isEmpty)
              const EmptyState(
                'Aucun favori pour le moment.',
                icon: Icons.star_outline,
              ),
            // UX-006B : plus de carte par favori — lignes à filets fins.
            // Réordonner (groupe neutre) et Supprimer (rouge) sont
            // visuellement SÉPARÉS par un filet vertical.
            for (var index = 0; index < favorites.length; index++) ...[
              ListTile(
                key: Key('manage-favorite-${favorites[index].id}'),
                onTap: () => _edit(favorites[index]),
                contentPadding: EdgeInsets.zero,
                minTileHeight: AppSizes.minTouchTarget + 8,
                title: Text(
                  favorites[index].label,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                subtitle: Text(formatKm(favorites[index].distanceKm)),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.arrow_upward),
                      tooltip: 'Monter',
                      color: theme.colorScheme.onSurfaceVariant,
                      onPressed: index == 0
                          ? null
                          : () => ref
                                .read(favoritesControllerProvider.notifier)
                                .move(favorites[index].id, -1),
                    ),
                    IconButton(
                      icon: const Icon(Icons.arrow_downward),
                      tooltip: 'Descendre',
                      color: theme.colorScheme.onSurfaceVariant,
                      onPressed: index == favorites.length - 1
                          ? null
                          : () => ref
                                .read(favoritesControllerProvider.notifier)
                                .move(favorites[index].id, 1),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.s,
                      ),
                      child: SizedBox(
                        height: 24,
                        child: VerticalDivider(
                          width: 1,
                          color: theme.colorScheme.outlineVariant,
                        ),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.delete_outline),
                      tooltip: 'Supprimer',
                      color: theme.colorScheme.error,
                      onPressed: () => _delete(favorites[index]),
                    ),
                  ],
                ),
              ),
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton.icon(
                  key: Key('favorite-days-${favorites[index].id}'),
                  onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) =>
                          FavoriteDaysScreen(favorite: favorites[index]),
                    ),
                  ),
                  icon: const Icon(Icons.calendar_month_outlined, size: 20),
                  label: const Text('Autres jours'),
                ),
              ),
              Divider(height: 1, color: theme.colorScheme.outlineVariant),
            ],
            const SizedBox(height: AppSpacing.s),
            // Création : même présentation que l'action validée
            // d'Aujourd'hui (couleur de la récurrence), un seul toucher.
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                onPressed: _create,
                icon: const Icon(Icons.add, size: 18),
                label: const Text('Nouveau favori'),
                style: TextButton.styleFrom(
                  foregroundColor: theme.mesKm.favorite,
                  minimumSize: const Size(0, AppSizes.minTouchTarget),
                  padding: const EdgeInsets.symmetric(horizontal: AppSpacing.s),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
