import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/models/vehicle.dart';
import '../../widgets/empty_state.dart';
import '../../widgets/section_header.dart';
import '../../theme/tokens.dart';
import 'vehicle_form_sheet.dart';
import 'vehicles_controller.dart';

/// Gestion des véhicules : liste, principal, archivage/réactivation.
/// Grandes zones tactiles, actions textuelles explicites — pas de « … ».
/// [initialVehicleId] : ouvre directement la fiche de ce véhicule
/// (raccourci « Compléter le véhicule » depuis l'estimation — KM-013).
class VehiclesScreen extends ConsumerStatefulWidget {
  const VehiclesScreen({super.key, this.initialVehicleId});

  final String? initialVehicleId;

  @override
  ConsumerState<VehiclesScreen> createState() => _VehiclesScreenState();
}

class _VehiclesScreenState extends ConsumerState<VehiclesScreen> {
  @override
  void initState() {
    super.initState();
    final initialId = widget.initialVehicleId;
    if (initialId != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) async {
        final state = await ref.read(vehiclesControllerProvider.future);
        final vehicle = state.byId(initialId);
        if (vehicle != null && mounted) {
          await _edit(context, ref, vehicle);
        }
      });
    }
  }

  Future<void> _create(BuildContext context, WidgetRef ref) async {
    final result = await showVehicleFormSheet(context);
    if (result == null) return;
    await ref.read(vehiclesControllerProvider.notifier).create(
          name: result.name,
          category: result.category,
          fiscalPowerCv: result.fiscalPowerCv,
          registration: result.registration,
          motorization: result.motorization,
          twoWheelerClass: result.twoWheelerClass,
        );
  }

  Future<void> _edit(
      BuildContext context, WidgetRef ref, Vehicle vehicle) async {
    final result = await showVehicleFormSheet(context, initial: vehicle);
    if (result == null) return;
    await ref.read(vehiclesControllerProvider.notifier).updateVehicle(
          vehicle,
          name: result.name,
          category: result.category,
          fiscalPowerCv: result.fiscalPowerCv,
          registration: result.registration,
          motorization: result.motorization,
          twoWheelerClass: result.twoWheelerClass,
        );
  }

  Future<void> _archive(
      BuildContext context, WidgetRef ref, Vehicle vehicle) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Archiver ce véhicule ?'),
        content: Text(
          '${vehicle.name}\n\n'
          'Il ne sera plus proposé pour les nouvelles saisies, mais les '
          'kilomètres déjà enregistrés lui restent attribués.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Annuler'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Archiver'),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      await ref
          .read(vehiclesControllerProvider.notifier)
          .archive(vehicle.id);
    }
  }

  String _subtitle(Vehicle vehicle) {
    final parts = [
      switch (vehicle.category) {
        VehicleCategory.car => 'Voiture',
        VehicleCategory.twoWheeler => switch (vehicle.twoWheelerClass) {
            null => 'Deux-roues (type à préciser)',
            TwoWheelerFiscalClass.motorcycle => 'Moto',
            TwoWheelerFiscalClass.moped => 'Cyclomoteur',
          },
      },
      if (vehicle.fiscalPowerCv != null) '${vehicle.fiscalPowerCv} CV',
      switch (vehicle.motorization) {
        Motorization.electric => 'Électrique',
        Motorization.other => 'Autre motorisation',
        Motorization.unspecified => 'Motorisation non renseignée',
      },
      if (vehicle.registration != null) vehicle.registration!,
    ];
    return parts.join(' · ');
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final state = ref.watch(vehiclesControllerProvider).value;
    final active = state?.active ?? const <Vehicle>[];
    final archived = state?.archived ?? const <Vehicle>[];

    return Scaffold(
      appBar: AppBar(title: const Text('Véhicules')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(AppSpacing.l),
          children: [
            if (active.isEmpty && archived.isEmpty)
              const EmptyState('Aucun véhicule pour le moment.',
                  icon: Icons.directions_car_outlined),
            for (final vehicle in active)
              Card(
                margin: const EdgeInsets.only(bottom: AppSpacing.m),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    ListTile(
                      key: Key('vehicle-${vehicle.id}'),
                      onTap: () => _edit(context, ref, vehicle),
                      minTileHeight: AppSizes.minTouchTarget + 8,
                      title: Row(
                        children: [
                          Flexible(
                            child: Text(
                              vehicle.name,
                              style: theme.textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          if (state?.isMain(vehicle.id) ?? false) ...[
                            const SizedBox(width: AppSpacing.s),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: AppSpacing.s,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: theme.colorScheme.primaryContainer,
                                borderRadius:
                                    BorderRadius.circular(AppRadius.m),
                              ),
                              child: Text(
                                'Principal',
                                style: theme.textTheme.labelSmall?.copyWith(
                                  color:
                                      theme.colorScheme.onPrimaryContainer,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                      subtitle: Text(_subtitle(vehicle)),
                      trailing: const Icon(Icons.edit_outlined),
                    ),
                    Padding(
                      padding: const EdgeInsets.only(
                        left: AppSpacing.s,
                        right: AppSpacing.s,
                        bottom: AppSpacing.s,
                      ),
                      child: Row(
                        children: [
                          if (!(state?.isMain(vehicle.id) ?? false))
                            Expanded(
                              child: Align(
                                alignment: Alignment.centerLeft,
                                child: TextButton(
                                  key: Key('set-main-${vehicle.id}'),
                                  onPressed: () => ref
                                      .read(vehiclesControllerProvider
                                          .notifier)
                                      .setMain(vehicle.id),
                                  style: TextButton.styleFrom(
                                    minimumSize: const Size(
                                        0, AppSizes.minTouchTarget),
                                  ),
                                  child: const Text(
                                    'Définir comme véhicule principal',
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ),
                            )
                          else
                            const Spacer(),
                          TextButton(
                            key: Key('archive-${vehicle.id}'),
                            onPressed: () =>
                                _archive(context, ref, vehicle),
                            style: TextButton.styleFrom(
                              foregroundColor:
                                  theme.colorScheme.onSurfaceVariant,
                              minimumSize:
                                  const Size(0, AppSizes.minTouchTarget),
                            ),
                            child: const Text('Archiver'),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            const SizedBox(height: AppSpacing.s),
            FilledButton.tonalIcon(
              key: const Key('add-vehicle-button'),
              onPressed: () => _create(context, ref),
              icon: const Icon(Icons.add),
              label: const Text('Ajouter un véhicule'),
              style: FilledButton.styleFrom(
                minimumSize:
                    const Size.fromHeight(AppSizes.minTouchTarget + 8),
              ),
            ),
            if (archived.isNotEmpty) ...[
              const SizedBox(height: AppSpacing.xl),
              const SectionHeader('Véhicules archivés', topSpacing: 0),
              for (final vehicle in archived)
                ListTile(
                  key: Key('archived-${vehicle.id}'),
                  minTileHeight: AppSizes.minTouchTarget,
                  leading: Icon(
                    Icons.inventory_2_outlined,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                  title: Text(vehicle.name),
                  subtitle: Text(_subtitle(vehicle)),
                  trailing: TextButton(
                    key: Key('unarchive-${vehicle.id}'),
                    onPressed: () => ref
                        .read(vehiclesControllerProvider.notifier)
                        .unarchive(vehicle.id),
                    child: const Text('Réactiver'),
                  ),
                ),
            ],
          ],
        ),
      ),
    );
  }
}
