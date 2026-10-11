import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../domain/models/trip.dart';
import '../../theme/tokens.dart';
import '../../widgets/km_format.dart';
import '../../widgets/placeholder_card.dart';
import 'editable_day_total.dart';
import 'today_controller.dart';
import 'trip_form_sheet.dart';

class TodayScreen extends ConsumerWidget {
  const TodayScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(todayControllerProvider);

    return state.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, _) => _ErrorView(
        message: '$error',
        onRetry: () => ref.invalidate(todayControllerProvider),
      ),
      data: (today) => _TodayView(today: today),
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

class _TodayView extends ConsumerWidget {
  const _TodayView({required this.today});

  final TodayState today;

  Future<void> _addTrip(BuildContext context, WidgetRef ref) async {
    final controller = ref.read(todayControllerProvider.notifier);
    final result = await showTripFormSheet(context);
    if (result == null) return;
    await controller.addTrip(
      distanceKm: result.distanceKm,
      isRoundTrip: result.isRoundTrip,
      origin: result.origin,
      destination: result.destination,
      purpose: result.purpose,
    );
  }

  Future<void> _editTrip(BuildContext context, WidgetRef ref, Trip trip) async {
    final controller = ref.read(todayControllerProvider.notifier);
    final result = await showTripFormSheet(context, initial: trip);
    if (result == null) return;
    await controller.updateTrip(
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
    final controller = ref.read(todayControllerProvider.notifier);
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
      await controller.deleteTrip(trip.id);
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
    final dateText = DateFormat('EEEE d MMMM yyyy', 'fr_FR')
        .format(today.date.toDateTime());

    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.l),
      children: [
        const ScreenTitle('Aujourd’hui'),
        Text(
          dateText[0].toUpperCase() + dateText.substring(1),
          style: theme.textTheme.titleMedium?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: AppSpacing.xl),

        // Total du jour, toujours dérivé du domaine, directement éditable.
        EditableDayTotal(totalKm: today.totalKm),
        const SizedBox(height: AppSpacing.l),

        FilledButton.tonalIcon(
          onPressed: () => _addTrip(context, ref),
          icon: const Icon(Icons.add),
          label: const Text('Ajouter un trajet'),
          style: FilledButton.styleFrom(
            minimumSize: const Size.fromHeight(AppSizes.minTouchTarget + 8),
          ),
        ),
        const SizedBox(height: AppSpacing.xl),

        if (today.isEmpty)
          Text(
            'Aucun kilomètre enregistré aujourd’hui.',
            textAlign: TextAlign.center,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),

        if (today.trips.isNotEmpty) ...[
          Text('Trajets détaillés', style: theme.textTheme.titleMedium),
          const SizedBox(height: AppSpacing.s),
          Card(
            child: Column(
              children: [
                for (final trip in today.trips)
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

        if (today.extra != null) ...[
          Text('Autres kilomètres', style: theme.textTheme.titleMedium),
          const SizedBox(height: AppSpacing.s),
          Card(
            child: ListTile(
              minTileHeight: AppSizes.minTouchTarget + 8,
              title: Text(
                formatKm(today.extraKm),
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
