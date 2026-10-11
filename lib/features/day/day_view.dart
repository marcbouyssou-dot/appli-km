import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/models/civil_date.dart';
import '../../domain/models/trip.dart';
import '../../theme/tokens.dart';
import '../../widgets/km_format.dart';
import 'day_controller.dart';
import 'editable_day_total.dart';
import 'trip_form_sheet.dart';

/// Vue complète d'une journée (aujourd'hui ou passée) :
/// compteur éditable, ajout/édition/suppression de trajets, décomposition,
/// effacement explicite. Paramétrée par [date] — aucune opération n'utilise
/// implicitement « maintenant ».
///
/// [header] : widgets affichés en tête de liste (titre, date…).
/// [afterTotal] : contenu optionnel inséré sous le compteur (ex. favoris
/// sur Aujourd'hui — volontairement absent des journées passées).
class DayView extends ConsumerWidget {
  const DayView({
    super.key,
    required this.date,
    this.header = const <Widget>[],
    this.afterTotal,
  });

  final CivilDate date;
  final List<Widget> header;
  final Widget? afterTotal;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(dayControllerProvider(date));

    return state.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, _) => _ErrorView(
        message: '$error',
        onRetry: () => ref.invalidate(dayControllerProvider(date)),
      ),
      data: (day) => _DayContent(
        day: day,
        header: header,
        afterTotal: afterTotal,
      ),
    );
  }
}

class _ErrorView extends StatelessWidget {
  const _ErrorView({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, size: 44),
            const SizedBox(height: AppSpacing.l),
            const Text(
              'Impossible de lire les données du jour.',
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppSpacing.s),
            Text(
              message,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: AppSpacing.l),
            FilledButton(onPressed: onRetry, child: const Text('Réessayer')),
          ],
        ),
      ),
    );
  }
}

class _DayContent extends ConsumerWidget {
  const _DayContent({
    required this.day,
    required this.header,
    required this.afterTotal,
  });

  final DayState day;
  final List<Widget> header;
  final Widget? afterTotal;

  DayController _controller(WidgetRef ref) =>
      ref.read(dayControllerProvider(day.date).notifier);

  Future<void> _addTrip(BuildContext context, WidgetRef ref) async {
    final result = await showTripFormSheet(context);
    if (result == null) return;
    await _controller(ref).addTrip(
      distanceKm: result.distanceKm,
      isRoundTrip: result.isRoundTrip,
      origin: result.origin,
      destination: result.destination,
      purpose: result.purpose,
    );
  }

  Future<void> _editTrip(
    BuildContext context,
    WidgetRef ref,
    Trip trip,
  ) async {
    final result = await showTripFormSheet(context, initial: trip);
    if (result == null) return;
    await _controller(ref).updateTrip(
      trip,
      distanceKm: result.distanceKm,
      isRoundTrip: result.isRoundTrip,
      origin: result.origin,
      destination: result.destination,
      purpose: result.purpose,
    );
  }

  Future<void> _deleteTrip(
    BuildContext context,
    WidgetRef ref,
    Trip trip,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Supprimer ce trajet ?'),
        content: Text(_tripLabel(trip)),
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
      await _controller(ref).deleteTrip(trip.id);
    }
  }

  Future<void> _confirmClearDay(BuildContext context, WidgetRef ref) async {
    final controller = _controller(ref);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Effacer cette journée ?'),
        content: const Text(
          'Tous les trajets et kilomètres enregistrés ce jour-là seront '
          'supprimés. Les favoris sont conservés.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Annuler'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
              foregroundColor: Theme.of(context).colorScheme.onError,
            ),
            child: const Text('Effacer'),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      await controller.clearDay();
    }
  }

  String _tripLabel(Trip trip) {
    final route = [
      trip.origin,
      trip.destination,
    ].whereType<String>().join(' → ');
    return route.isEmpty
        ? formatKm(trip.distanceKm)
        : '${formatKm(trip.distanceKm)} — $route';
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);

    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.l),
      children: [
        ...header,

        // Total du jour, toujours dérivé du domaine, directement éditable.
        EditableDayTotal(date: day.date, totalKm: day.totalKm),
        const SizedBox(height: AppSpacing.l),

        ?afterTotal,

        FilledButton.tonalIcon(
          onPressed: () => _addTrip(context, ref),
          icon: const Icon(Icons.add),
          label: const Text('Ajouter un trajet'),
          style: FilledButton.styleFrom(
            minimumSize: const Size.fromHeight(AppSizes.minTouchTarget + 8),
          ),
        ),
        const SizedBox(height: AppSpacing.xl),

        if (day.isEmpty)
          Text(
            'Aucun kilomètre enregistré ce jour-là.',
            textAlign: TextAlign.center,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),

        if (day.trips.isNotEmpty) ...[
          Text('Trajets détaillés', style: theme.textTheme.titleMedium),
          const SizedBox(height: AppSpacing.s),
          Card(
            child: Column(
              children: [
                for (final trip in day.trips)
                  ListTile(
                    onTap: () => _editTrip(context, ref, trip),
                    minTileHeight: AppSizes.minTouchTarget + 8,
                    title: Row(
                      children: [
                        Text(
                          formatKm(trip.distanceKm),
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        if (trip.isRoundTrip) ...[
                          const SizedBox(width: AppSpacing.s),
                          Text(
                            'A/R',
                            style: theme.textTheme.labelSmall?.copyWith(
                              color: theme.colorScheme.primary,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ],
                    ),
                    subtitle: _tripSubtitle(trip),
                    trailing: IconButton(
                      icon: const Icon(Icons.delete_outline),
                      tooltip: 'Supprimer',
                      onPressed: () => _deleteTrip(context, ref, trip),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.l),
        ],

        if (day.extra != null) ...[
          Text('Autres kilomètres', style: theme.textTheme.titleMedium),
          const SizedBox(height: AppSpacing.s),
          Card(
            child: ListTile(
              minTileHeight: AppSizes.minTouchTarget + 8,
              title: Text(
                formatKm(day.extraKm),
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              subtitle: const Text(
                'Kilomètres non détaillés — s’ajustent en modifiant '
                'le total du jour.',
              ),
            ),
          ),
        ],

        // Action secondaire explicite : effacer toute la journée.
        if (!day.isEmpty) ...[
          const SizedBox(height: AppSpacing.l),
          Center(
            child: TextButton.icon(
              key: const Key('clear-day-button'),
              onPressed: () => _confirmClearDay(context, ref),
              icon: const Icon(Icons.restart_alt),
              label: const Text('Effacer la journée'),
              style: TextButton.styleFrom(
                foregroundColor: theme.colorScheme.onSurfaceVariant,
                minimumSize: const Size(
                  AppSizes.minTouchTarget * 3,
                  AppSizes.minTouchTarget,
                ),
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.xl,
                ),
              ),
            ),
          ),
        ],
        const SizedBox(height: AppSpacing.xxl),
      ],
    );
  }

  Widget? _tripSubtitle(Trip trip) {
    final parts = [
      [trip.origin, trip.destination].whereType<String>().join(' → '),
      if (trip.purpose != null) trip.purpose!,
    ].where((part) => part.isNotEmpty).join(' · ');
    return parts.isEmpty ? null : Text(parts);
  }
}
