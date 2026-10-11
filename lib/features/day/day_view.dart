import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../../domain/logic/vacations.dart';
import '../../domain/models/civil_date.dart';
import '../../domain/models/trip.dart';
import '../../domain/models/vacation_period.dart';
import '../../theme/tokens.dart';
import '../../widgets/app_buttons.dart';
import '../../widgets/empty_state.dart';
import '../../widgets/grouped_list.dart';
import '../../widgets/km_format.dart';
import '../../widgets/section_header.dart';
import '../../domain/models/vehicle.dart';
import '../today/favorites_section.dart';
import '../vacations/vacation_guard.dart';
import '../vacations/vacations_controller.dart';
import '../vehicles/vehicles_controller.dart';
import 'day_controller.dart';
import 'editable_day_total.dart';
import 'trip_form_sheet.dart';

/// Vue complète d'une journée (aujourd'hui ou passée) :
/// compteur éditable, ajout/édition/suppression de trajets, décomposition,
/// effacement explicite. Paramétrée par [date] — aucune opération n'utilise
/// implicitement « maintenant ».
///
/// [header] : widgets affichés en tête de liste (titre, date…).
/// Les trajets favoris (liste globale) sont proposés sur TOUTE journée :
/// un tap crée un Trip daté de [date].
class DayView extends ConsumerWidget {
  const DayView({
    super.key,
    required this.date,
    this.header = const <Widget>[],
  });

  final CivilDate date;
  final List<Widget> header;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(dayControllerProvider(date));

    final vacations =
        ref.watch(vacationsControllerProvider).value ??
            const <VacationPeriod>[];

    return state.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, _) => _ErrorView(
        message: '$error',
        onRetry: () => ref.invalidate(dayControllerProvider(date)),
      ),
      data: (day) => _DayContent(
        day: day,
        header: header,
        isVacation: isVacationDate(vacations, date),
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

/// Choix de véhicule retourné par le dialogue (permet de distinguer
/// « Aucun véhicule » (null choisi) de l'annulation du dialogue).
class _VehicleChoice {
  const _VehicleChoice(this.vehicleId);

  final String? vehicleId;
}

class _DayContent extends ConsumerWidget {
  const _DayContent({
    required this.day,
    required this.header,
    required this.isVacation,
  });

  final DayState day;
  final List<Widget> header;
  final bool isVacation;

  DayController _controller(WidgetRef ref) =>
      ref.read(dayControllerProvider(day.date).notifier);

  /// Options véhicule pour un formulaire : actifs + le véhicule historique
  /// du trajet édité (même archivé, pour ne jamais le perdre à l'édition).
  List<Vehicle> _vehicleOptions(VehiclesState? vehicles, Trip? editing) {
    final options = [...?vehicles?.active];
    final historical = vehicles?.byId(editing?.vehicleId);
    if (historical != null && historical.isArchived) {
      options.add(historical);
    }
    return options;
  }

  Future<void> _addTrip(BuildContext context, WidgetRef ref) async {
    // Jamais congé + kilomètres : confirmation puis retrait du jour.
    if (!await ensureDayNotVacation(context, ref, day.date)) return;
    if (!context.mounted) return;
    final vehicles = ref.read(vehiclesControllerProvider).value;
    final result = await showTripFormSheet(
      context,
      vehicles: _vehicleOptions(vehicles, null),
      routeService: ref.read(routeDistanceServiceProvider),
      // Pré-sélection : véhicule principal ACTUEL (figé dans le Trip).
      defaultVehicleId: vehicles?.mainVehicleId,
    );
    if (result == null) return;
    await _controller(ref).addTrip(
      distanceKm: result.distanceKm,
      isRoundTrip: result.isRoundTrip,
      origin: result.origin,
      destination: result.destination,
      purpose: result.purpose,
      vehicleId: result.vehicleId,
    );
  }

  Future<void> _editTrip(
    BuildContext context,
    WidgetRef ref,
    Trip trip,
  ) async {
    final vehicles = ref.read(vehiclesControllerProvider).value;
    final result = await showTripFormSheet(
      context,
      initial: trip,
      vehicles: _vehicleOptions(vehicles, trip),
      routeService: ref.read(routeDistanceServiceProvider),
    );
    if (result == null) return;
    await _controller(ref).updateTrip(
      trip,
      distanceKm: result.distanceKm,
      isRoundTrip: result.isRoundTrip,
      origin: result.origin,
      destination: result.destination,
      purpose: result.purpose,
      vehicleId: result.vehicleId,
    );
  }

  /// Correction explicite du véhicule des kilomètres non détaillés :
  /// uniquement l'attribution, jamais le kilométrage.
  Future<void> _editExtraVehicle(BuildContext context, WidgetRef ref) async {
    final vehicles = ref.read(vehiclesControllerProvider).value;
    final extra = day.extra;
    if (extra == null) return;

    final options = [...?vehicles?.active];
    final current = vehicles?.byId(extra.vehicleId);
    if (current != null && current.isArchived) options.add(current);

    final choice = await showDialog<_VehicleChoice>(
      context: context,
      builder: (context) => SimpleDialog(
        title: const Text('Véhicule des kilomètres non détaillés'),
        children: [
          SimpleDialogOption(
            onPressed: () =>
                Navigator.of(context).pop(const _VehicleChoice(null)),
            child: const Padding(
              padding: EdgeInsets.symmetric(vertical: AppSpacing.m),
              child: Text('Aucun véhicule'),
            ),
          ),
          for (final vehicle in options)
            SimpleDialogOption(
              onPressed: () =>
                  Navigator.of(context).pop(_VehicleChoice(vehicle.id)),
              child: Padding(
                padding:
                    const EdgeInsets.symmetric(vertical: AppSpacing.m),
                child: Text(vehicle.isArchived
                    ? '${vehicle.name} (archivé)'
                    : vehicle.name),
              ),
            ),
        ],
      ),
    );
    if (choice == null) return;
    await _controller(ref).setDayExtraVehicle(choice.vehicleId);
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

  /// « Marquer comme congé » : refusé tant que la journée contient des
  /// kilomètres (aucune suppression automatique, jamais).
  Future<void> _markVacation(BuildContext context, WidgetRef ref) async {
    if (!day.isEmpty) {
      await showDialog<void>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Journée non vide'),
          content: Text(
            'Cette journée contient déjà ${formatKm(day.totalKm)}.\n'
            'Effacez d’abord les kilomètres pour la marquer comme congé.',
          ),
          actions: [
            FilledButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('OK'),
            ),
          ],
        ),
      );
      return;
    }
    await ref.read(vacationsControllerProvider.notifier).markDay(day.date);
  }

  Future<void> _removeVacation(WidgetRef ref) =>
      ref.read(vacationsControllerProvider.notifier).removeDay(day.date);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final vehicles = ref.watch(vehiclesControllerProvider).value;

    String? vehicleName(String? vehicleId) {
      final vehicle = vehicles?.byId(vehicleId);
      if (vehicle == null) return null;
      return vehicle.isArchived ? '${vehicle.name} (archivé)' : vehicle.name;
    }

    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.l),
      children: [
        ...header,

        // Journée en congé : état clair A LA PLACE du compteur — pas de
        // faux total « normal ». Retirer le congé fait revenir le compteur.
        if (isVacation)
          Card(
            key: const Key('vacation-card'),
            child: Padding(
              padding: const EdgeInsets.symmetric(
                vertical: AppSpacing.xxl,
                horizontal: AppSpacing.xl,
              ),
              child: Column(
                children: [
                  Icon(
                    Icons.beach_access,
                    size: 44,
                    color: theme.colorScheme.tertiary,
                  ),
                  const SizedBox(height: AppSpacing.m),
                  Text(
                    'Congé',
                    style: theme.textTheme.headlineMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                      color: theme.colorScheme.tertiary,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.l),
                  TextButton.icon(
                    key: const Key('remove-vacation-button'),
                    onPressed: () => _removeVacation(ref),
                    icon: const Icon(Icons.close),
                    label: const Text('Retirer le congé'),
                    style: TextButton.styleFrom(
                      minimumSize: const Size(
                        AppSizes.minTouchTarget * 3,
                        AppSizes.minTouchTarget,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          )
        else
          // Total du jour, toujours dérivé du domaine, directement éditable.
          EditableDayTotal(date: day.date, totalKm: day.totalKm),
        const SizedBox(height: AppSpacing.l),

        // Favoris : ajout en un toucher, Trip daté de CETTE journée.
        FavoritesSection(date: day.date),

        PrimaryButton(
          tonal: true,
          icon: Icons.add,
          label: 'Ajouter un trajet',
          onPressed: () => _addTrip(context, ref),
        ),
        const SizedBox(height: AppSpacing.xl),

        if (day.isEmpty)
          const EmptyState('Aucun kilomètre enregistré ce jour-là.'),

        if (day.trips.isNotEmpty) ...[
          const SectionHeader('Trajets détaillés', topSpacing: 0),
          GroupedList(
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
                    subtitle: _tripSubtitle(trip, vehicleName),
                    trailing: IconButton(
                      icon: const Icon(Icons.delete_outline),
                      tooltip: 'Supprimer',
                      onPressed: () => _deleteTrip(context, ref, trip),
                    ),
                  ),
            ],
          ),
          const SizedBox(height: AppSpacing.l),
        ],

        if (day.extra != null) ...[
          const SectionHeader('Autres kilomètres', topSpacing: 0),
          Card(
            child: ListTile(
              key: const Key('day-extra-tile'),
              // Correction explicite de l'attribution véhicule (jamais le
              // kilométrage).
              onTap: () => _editExtraVehicle(context, ref),
              minTileHeight: AppSizes.minTouchTarget + 8,
              title: Text(
                formatKm(day.extraKm),
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              subtitle: Text(
                '${vehicleName(day.extra!.vehicleId) ?? 'Véhicule non renseigné'}'
                '\nKilomètres non détaillés — s’ajustent en modifiant '
                'le total du jour.',
              ),
              trailing: const Icon(Icons.edit_outlined),
            ),
          ),
        ],

        // Marquage congé : action explicite, refusée si la journée a des
        // kilomètres. (JOUR VIDE ≠ CONGÉ : rien n'est jamais automatique.)
        if (!isVacation) ...[
          const SizedBox(height: AppSpacing.l),
          Center(
            child: QuietButton(
              key: const Key('mark-vacation-button'),
              onPressed: () => _markVacation(context, ref),
              icon: Icons.beach_access_outlined,
              label: 'Marquer comme congé',
            ),
          ),
        ],

        // Action secondaire explicite : effacer toute la journée.
        if (!day.isEmpty) ...[
          const SizedBox(height: AppSpacing.l),
          Center(
            child: QuietButton(
              key: const Key('clear-day-button'),
              onPressed: () => _confirmClearDay(context, ref),
              icon: Icons.restart_alt,
              label: 'Effacer la journée',
            ),
          ),
        ],
        const SizedBox(height: AppSpacing.xxl),
      ],
    );
  }

  Widget? _tripSubtitle(Trip trip, String? Function(String?) vehicleName) {
    final name = vehicleName(trip.vehicleId);
    final parts = [
      [trip.origin, trip.destination].whereType<String>().join(' → '),
      if (trip.purpose != null) trip.purpose!,
      // Affichage discret du véhicule attribué (figé à la saisie).
      ?name,
    ].where((part) => part.isNotEmpty).join(' · ');
    return parts.isEmpty ? null : Text(parts);
  }
}
