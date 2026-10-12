import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../../domain/models/favorite_trip.dart';
import '../../theme/app_typography.dart';
import '../../theme/mes_km_colors.dart';
import '../../theme/tokens.dart';
import '../../widgets/km_format.dart';
import '../../widgets/section_header.dart';
import '../../domain/models/civil_date.dart';
import '../day/day_controller.dart';
import '../vacations/vacation_guard.dart';
import '../vehicles/vehicles_controller.dart';
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
    // Jamais congé + kilomètres : confirmation puis retrait du jour.
    if (!await ensureDayNotVacation(context, ref, date)) return;
    if (!context.mounted) return;
    final archivedFallback = await ref
        .read(dayControllerProvider(date).notifier)
        .addTripFromFavorite(favorite);
    if (!context.mounted) return;
    // Feedback bref, remplacé au tap suivant : n'empile jamais.
    // Si le favori référençait un véhicule archivé, le principal a été
    // utilisé — on le dit (favori à corriger).
    ScaffoldMessenger.of(context)
      ..clearSnackBars()
      ..showSnackBar(SnackBar(
        content: Text(archivedFallback
            ? '+ ${formatKm(favorite.distanceKm)} — véhicule principal '
                'utilisé (le véhicule du favori est archivé)'
            : '+ ${formatKm(favorite.distanceKm)}'),
        duration: Duration(milliseconds: archivedFallback ? 3500 : 800),
        behavior: SnackBarBehavior.floating,
      ));
  }

  /// Raccourci « Modifier » : ouvre la gestion globale directement sur la
  /// fiche de CE favori (les favoris sont globaux — la date consultée n'a
  /// aucun effet sur le modèle).
  void _editFavorite(BuildContext context, FavoriteTrip favorite) {
    Navigator.of(context).push(MaterialPageRoute<void>(
      builder: (_) =>
          ManageFavoritesScreen(initialFavoriteId: favorite.id),
    ));
  }

  Future<void> _createFavorite(BuildContext context, WidgetRef ref) async {
    final vehicles =
        ref.read(vehiclesControllerProvider).value?.active ?? const [];
    final result = await showFavoriteFormSheet(
      context,
      vehicles: vehicles,
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

    // Ici on UTILISE les favoris (tap = ajout d'un Trip à cette journée).
    // La gestion globale (créer/modifier/supprimer/réordonner) vit dans
    // l'onglet Plus, hors du contexte d'une journée : supprimer un favori
    // ici était ambigu (il disparaissait de toutes les journées).
    // Signature Mes Km (UX-001B) : la donnée domine — libellé, trajet,
    // et un « +km » très lisible. Pas de carte, des filets fins.
    // Deux intentions, deux zones nettement séparées (invariant KM-008C) :
    // toute la ligne = AJOUTER ; « Modifier » = zone distincte explicite.
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // UX-002B : la création (geste rare) vit dans l'en-tête de
        // section — toujours visible, 1 tap, même formulaire global.
        Row(
          children: [
            const Expanded(
              child: SectionHeader('Trajets favoris',
                  topSpacing: 0, bottomSpacing: 0),
            ),
            TextButton.icon(
              key: const Key('create-favorite-row'),
              onPressed: () => _createFavorite(context, ref),
              icon: const Icon(Icons.add, size: 18),
              label: const Text('Nouveau favori'),
              style: TextButton.styleFrom(
                foregroundColor: theme.mesKm.favorite,
                minimumSize: const Size(0, AppSizes.minTouchTarget),
                padding:
                    const EdgeInsets.symmetric(horizontal: AppSpacing.s),
              ),
            ),
          ],
        ),
        for (final favorite in favorites) ...[
          Row(
            children: [
              Expanded(
                child: InkWell(
                  key: Key('favorite-${favorite.id}'),
                  onTap: () => _useFavorite(context, ref, favorite),
                  borderRadius: BorderRadius.circular(AppRadius.s),
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(
                      minHeight: AppSizes.minTouchTarget + 8,
                    ),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        vertical: AppSpacing.s,
                      ),
                      child: Row(
                        children: [
                          // Repère favori (récurrence = orange chaud) —
                          // il appartient à la grande zone d'ajout, ce
                          // n'est pas une cible distincte.
                          Container(
                            width: 36,
                            height: 36,
                            decoration: BoxDecoration(
                              color: theme.mesKm.favoriteContainer,
                              borderRadius:
                                  BorderRadius.circular(AppRadius.s),
                            ),
                            child: Icon(
                              Icons.route_outlined,
                              size: 19,
                              color: theme.mesKm.onFavoriteContainer,
                            ),
                          ),
                          const SizedBox(width: AppSpacing.m),
                          Expanded(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  favorite.label,
                                  style:
                                      theme.textTheme.titleMedium?.copyWith(
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                DefaultTextStyle(
                                  style: AppTypography.caption.copyWith(
                                    color:
                                        theme.colorScheme.onSurfaceVariant,
                                  ),
                                  child: _subtitle(favorite) ??
                                      const SizedBox.shrink(),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: AppSpacing.s),
                          // Le « + » : la valeur ajoutée, très lisible,
                          // sur une teinte d'action légère (pas de
                          // capsule Material).
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: AppSpacing.s,
                              vertical: 3,
                            ),
                            decoration: BoxDecoration(
                              color: theme.colorScheme.primaryContainer
                                  .withValues(alpha: 0.45),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              '+${formatKm(favorite.distanceKm)}',
                              style: AppTypography.value.copyWith(
                                fontSize: 20,
                                color: theme.colorScheme.primary,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.only(left: AppSpacing.s),
                child: TextButton(
                  key: Key('edit-favorite-${favorite.id}'),
                  onPressed: () => _editFavorite(context, favorite),
                  style: TextButton.styleFrom(
                    foregroundColor: theme.colorScheme.onSurfaceVariant,
                    minimumSize: const Size(0, AppSizes.minTouchTarget),
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.m,
                    ),
                  ),
                  child: const Text('Modifier'),
                ),
              ),
            ],
          ),
          Divider(height: 1, color: theme.colorScheme.outlineVariant),
        ],
        const SizedBox(height: AppSpacing.m),
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
