import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/models/favorite_trip.dart';
import '../../theme/tokens.dart';
import '../../widgets/km_format.dart';
import '../../domain/models/civil_date.dart';
import '../day/day_controller.dart';
import 'favorite_form_sheet.dart';
import 'favorites_controller.dart';
import 'manage_favorites_screen.dart';

/// Section « Trajets favoris », disponible sur TOUTE journée éditable
/// (aujourd'hui comme journée passée).
///
/// Un SEUL tap sur toute la ligne d'un favori ajoute immédiatement ses
/// kilomètres à la journée [date] — explicitement celle-ci, jamais la date
/// courante implicite. La liste des favoris reste GLOBALE : la gestion
/// (créer/modifier/supprimer/réordonner) n'est jamais rattachée à la date
/// consultée.
class FavoritesSection extends ConsumerWidget {
  const FavoritesSection({super.key, required this.date});

  /// Journée cible des taps : le Trip créé porte cette date.
  final CivilDate date;

  Future<void> _useFavorite(
    BuildContext context,
    WidgetRef ref,
    FavoriteTrip favorite,
  ) async {
    await ref
        .read(dayControllerProvider(date).notifier)
        .addTripFromFavorite(favorite);
    if (!context.mounted) return;
    // Feedback bref, remplacé au tap suivant : n'empile jamais.
    ScaffoldMessenger.of(context)
      ..clearSnackBars()
      ..showSnackBar(SnackBar(
        content: Text('+ ${formatKm(favorite.distanceKm)}'),
        duration: const Duration(milliseconds: 800),
        behavior: SnackBarBehavior.floating,
      ));
  }

  Future<void> _createFavorite(BuildContext context, WidgetRef ref) async {
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

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final favoritesState = ref.watch(favoritesControllerProvider);
    final favorites = favoritesState.value ?? const <FavoriteTrip>[];

    if (favoritesState.isLoading && favorites.isEmpty) {
      return const SizedBox.shrink();
    }

    // Aucun favori : invitation discrète, pas de section lourde.
    if (favorites.isEmpty) {
      return Padding(
        padding: const EdgeInsets.only(bottom: AppSpacing.m),
        child: TextButton.icon(
          onPressed: () => _createFavorite(context, ref),
          icon: const Icon(Icons.star_outline),
          label: const Text('Créer un trajet favori'),
          style: TextButton.styleFrom(
            minimumSize: const Size.fromHeight(AppSizes.minTouchTarget),
          ),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                'Trajets favoris',
                style: theme.textTheme.titleMedium,
              ),
            ),
            TextButton(
              onPressed: () {
                Navigator.of(context).push(MaterialPageRoute<void>(
                  builder: (_) => const ManageFavoritesScreen(),
                ));
              },
              child: const Text('Gérer'),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.s),
        Card(
          child: Column(
            children: [
              for (final favorite in favorites)
                // Toute la ligne est la cible tactile : aucun petit « + »
                // à viser (règle produit KM-004C).
                ListTile(
                  key: Key('favorite-${favorite.id}'),
                  onTap: () => _useFavorite(context, ref, favorite),
                  minTileHeight: AppSizes.minTouchTarget + 12,
                  title: Text(
                    favorite.label,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  subtitle: _subtitle(favorite),
                  trailing: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.m,
                      vertical: AppSpacing.s,
                    ),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.primaryContainer,
                      borderRadius: BorderRadius.circular(AppRadius.m),
                    ),
                    child: Text(
                      '+${formatKm(favorite.distanceKm)}',
                      style: theme.textTheme.titleSmall?.copyWith(
                        color: theme.colorScheme.onPrimaryContainer,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.l),
      ],
    );
  }

  Widget? _subtitle(FavoriteTrip favorite) {
    final parts = [
      formatKm(favorite.distanceKm),
      if (favorite.defaultRoundTrip) 'A/R',
      [favorite.origin, favorite.destination]
          .whereType<String>()
          .join(' → '),
    ].where((part) => part.isNotEmpty).join(' · ');
    return Text(parts);
  }
}
