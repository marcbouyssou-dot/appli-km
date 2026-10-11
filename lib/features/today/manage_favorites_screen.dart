import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/models/favorite_trip.dart';
import '../../theme/tokens.dart';
import '../../widgets/km_format.dart';
import 'favorite_form_sheet.dart';
import 'favorites_controller.dart';

/// Gestion des trajets favoris : créer, modifier, supprimer, réordonner.
///
/// Réorganisation par flèches haut/bas : fiable au toucher sur iPhone
/// (le drag & drop web/Safari ne l'est pas assez), et impossible à
/// déclencher par accident.
class ManageFavoritesScreen extends ConsumerWidget {
  const ManageFavoritesScreen({super.key});

  Future<void> _create(BuildContext context, WidgetRef ref) async {
    final result = await showFavoriteFormSheet(context);
    if (result == null) return;
    await ref.read(favoritesControllerProvider.notifier).create(
          label: result.label,
          distanceKm: result.distanceKm,
          defaultRoundTrip: result.defaultRoundTrip,
          origin: result.origin,
          destination: result.destination,
          purpose: result.purpose,
        );
  }

  Future<void> _edit(
    BuildContext context,
    WidgetRef ref,
    FavoriteTrip favorite,
  ) async {
    final result = await showFavoriteFormSheet(context, initial: favorite);
    if (result == null) return;
    await ref.read(favoritesControllerProvider.notifier).updateFavorite(
          favorite,
          label: result.label,
          distanceKm: result.distanceKm,
          defaultRoundTrip: result.defaultRoundTrip,
          origin: result.origin,
          destination: result.destination,
          purpose: result.purpose,
        );
  }

  Future<void> _delete(
    BuildContext context,
    WidgetRef ref,
    FavoriteTrip favorite,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Supprimer ce favori ?'),
        content: Text(
          '${favorite.label} — ${formatKm(favorite.distanceKm)}\n'
          'Les trajets déjà enregistrés ne seront pas modifiés.',
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
    if (confirmed == true) {
      await ref
          .read(favoritesControllerProvider.notifier)
          .deleteFavorite(favorite.id);
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final favoritesState = ref.watch(favoritesControllerProvider);
    final favorites = favoritesState.value ?? const <FavoriteTrip>[];

    return Scaffold(
      appBar: AppBar(title: const Text('Trajets favoris')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(AppSpacing.l),
          children: [
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
                  onTap: () => _edit(context, ref, favorites[index]),
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
                        onPressed: () =>
                            _delete(context, ref, favorites[index]),
                      ),
                    ],
                  ),
                ),
              ),
            const SizedBox(height: AppSpacing.s),
            FilledButton.tonalIcon(
              onPressed: () => _create(context, ref),
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
