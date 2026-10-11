import 'package:flutter/material.dart';

import '../../domain/models/trip.dart';
import '../../domain/models/vehicle.dart';
import '../../theme/tokens.dart';
import '../../widgets/km_format.dart';

/// Valeurs saisies dans le formulaire de trajet.
class TripFormResult {
  TripFormResult({
    required this.distanceKm,
    required this.isRoundTrip,
    this.origin,
    this.destination,
    this.purpose,
    this.vehicleId,
  });

  final double distanceKm;
  final bool isRoundTrip;
  final String? origin;
  final String? destination;
  final String? purpose;
  final String? vehicleId;
}

/// Feuille d'ajout/modification d'un trajet.
/// Sémantique assumée : l'utilisateur saisit la DISTANCE COMPTABILISÉE
/// (le total réellement parcouru, A/R inclus) ; le toggle aller-retour est
/// purement descriptif et ne double jamais la distance.
/// [vehicles] : options proposées (actifs + véhicule historique du trajet
/// même archivé, fourni par l'appelant). [defaultVehicleId] : pré-sélection
/// à la création (véhicule principal actuel) ; en édition, le véhicule
/// HISTORIQUE du trajet est affiché — jamais le principal du moment.
Future<TripFormResult?> showTripFormSheet(
  BuildContext context, {
  Trip? initial,
  List<Vehicle> vehicles = const [],
  String? defaultVehicleId,
}) {
  return showModalBottomSheet<TripFormResult>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (context) => _TripFormSheet(
      initial: initial,
      vehicles: vehicles,
      defaultVehicleId: defaultVehicleId,
    ),
  );
}

class _TripFormSheet extends StatefulWidget {
  const _TripFormSheet({
    this.initial,
    this.vehicles = const [],
    this.defaultVehicleId,
  });

  final Trip? initial;
  final List<Vehicle> vehicles;
  final String? defaultVehicleId;

  @override
  State<_TripFormSheet> createState() => _TripFormSheetState();
}

class _TripFormSheetState extends State<_TripFormSheet> {
  late final TextEditingController _distanceController;
  late final TextEditingController _originController;
  late final TextEditingController _destinationController;
  late final TextEditingController _purposeController;
  late bool _isRoundTrip;
  String? _vehicleId;
  String? _distanceError;

  @override
  void initState() {
    super.initState();
    final initial = widget.initial;
    _vehicleId =
        initial != null ? initial.vehicleId : widget.defaultVehicleId;
    _distanceController = TextEditingController(
      text: initial == null
          ? ''
          : formatKm(initial.distanceKm).replaceAll(' km', ''),
    );
    _originController = TextEditingController(text: initial?.origin ?? '');
    _destinationController =
        TextEditingController(text: initial?.destination ?? '');
    _purposeController = TextEditingController(text: initial?.purpose ?? '');
    _isRoundTrip = initial?.isRoundTrip ?? false;
  }

  @override
  void dispose() {
    _distanceController.dispose();
    _originController.dispose();
    _destinationController.dispose();
    _purposeController.dispose();
    super.dispose();
  }

  void _submit() {
    final distance = parseKmInput(_distanceController.text);
    if (distance == null || distance <= 0) {
      setState(() {
        _distanceError = 'Saisissez une distance en kilomètres (> 0).';
      });
      return;
    }

    Navigator.of(context).pop(TripFormResult(
      distanceKm: distance,
      isRoundTrip: _isRoundTrip,
      origin: _originController.text,
      destination: _destinationController.text,
      purpose: _purposeController.text,
      vehicleId: _vehicleId,
    ));
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isEditing = widget.initial != null;

    return Padding(
      padding: EdgeInsets.only(
        left: AppSpacing.xl,
        right: AppSpacing.xl,
        top: AppSpacing.s,
        bottom: MediaQuery.of(context).viewInsets.bottom + AppSpacing.xl,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              isEditing ? 'Modifier le trajet' : 'Ajouter un trajet',
              style: theme.textTheme.titleLarge,
            ),
            const SizedBox(height: AppSpacing.l),
            TextField(
              controller: _distanceController,
              autofocus: !isEditing,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              decoration: InputDecoration(
                labelText: 'Distance comptabilisée (km)',
                helperText:
                    'Distance totale réellement parcourue, A/R inclus.',
                helperMaxLines: 2,
                suffixText: 'km',
                border: const OutlineInputBorder(),
                errorText: _distanceError,
                errorMaxLines: 2,
              ),
            ),
            SwitchListTile(
              value: _isRoundTrip,
              onChanged: (value) => setState(() => _isRoundTrip = value),
              title: const Text('Aller-retour'),
              subtitle:
                  const Text('Indicatif : ne modifie pas la distance saisie.'),
              contentPadding: EdgeInsets.zero,
            ),
            TextField(
              controller: _originController,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(
                labelText: 'Départ (facultatif)',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: AppSpacing.m),
            TextField(
              controller: _destinationController,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(
                labelText: 'Destination (facultatif)',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: AppSpacing.m),
            TextField(
              controller: _purposeController,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(
                labelText: 'Motif (facultatif)',
                border: OutlineInputBorder(),
              ),
            ),
            if (widget.vehicles.isNotEmpty) ...[
              const SizedBox(height: AppSpacing.m),
              DropdownButtonFormField<String?>(
                key: const Key('trip-vehicle-field'),
                isExpanded: true,
                initialValue: _vehicleId,
                decoration: const InputDecoration(
                  labelText: 'Véhicule',
                  border: OutlineInputBorder(),
                ),
                items: [
                  const DropdownMenuItem<String?>(
                    value: null,
                    child: Text('Aucun véhicule'),
                  ),
                  for (final vehicle in widget.vehicles)
                    DropdownMenuItem<String?>(
                      value: vehicle.id,
                      child: Text(vehicle.isArchived
                          ? '${vehicle.name} (archivé)'
                          : vehicle.name),
                    ),
                ],
                onChanged: (value) => setState(() => _vehicleId = value),
              ),
            ],
            const SizedBox(height: AppSpacing.l),
            FilledButton(
              onPressed: _submit,
              style: FilledButton.styleFrom(
                minimumSize:
                    const Size.fromHeight(AppSizes.minTouchTarget + 4),
              ),
              child: Text(isEditing ? 'Enregistrer' : 'Ajouter'),
            ),
            const SizedBox(height: AppSpacing.s),
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              style: TextButton.styleFrom(
                minimumSize: const Size.fromHeight(AppSizes.minTouchTarget),
              ),
              child: const Text('Annuler'),
            ),
          ],
        ),
      ),
    );
  }
}
