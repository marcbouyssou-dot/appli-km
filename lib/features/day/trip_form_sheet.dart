import 'package:flutter/material.dart';

import '../../data/network/route_distance_service.dart';
import '../../domain/models/trip.dart';
import '../../domain/models/vehicle.dart';
import '../../widgets/form_sheet_scaffold.dart';
import '../../theme/tokens.dart';
import '../../widgets/km_format.dart';
import 'route_calc_section.dart';

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
  RouteDistanceService? routeService,
  String singleDayLabel = 'Jour sélectionné',
  Future<bool> Function(BuildContext, TripFormResult)? onMultiDay,
}) {
  return showModalBottomSheet<TripFormResult>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (context) => _TripFormSheet(
      initial: initial,
      vehicles: vehicles,
      defaultVehicleId: defaultVehicleId,
      routeService: routeService,
      singleDayLabel: singleDayLabel,
      onMultiDay: onMultiDay,
    ),
  );
}

class _TripFormSheet extends StatefulWidget {
  const _TripFormSheet({
    this.initial,
    this.vehicles = const [],
    this.defaultVehicleId,
    this.routeService,
    required this.singleDayLabel,
    this.onMultiDay,
  });

  final Trip? initial;
  final List<Vehicle> vehicles;
  final String? defaultVehicleId;
  final RouteDistanceService? routeService;
  final String singleDayLabel;
  final Future<bool> Function(BuildContext, TripFormResult)? onMultiDay;

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
  bool _choosingDays = false;
  bool _multipleDays = false;

  @override
  void initState() {
    super.initState();
    final initial = widget.initial;
    // Garde UX précoce (UX-003B1) : l'état du bouton suit la saisie.
    _distanceListener = () => setState(() {});
    _vehicleId = initial != null ? initial.vehicleId : widget.defaultVehicleId;
    _distanceController = TextEditingController(
      text: initial == null
          ? ''
          : formatKm(initial.distanceKm).replaceAll(' km', ''),
    );
    _originController = TextEditingController(text: initial?.origin ?? '');
    _destinationController = TextEditingController(
      text: initial?.destination ?? '',
    );
    _purposeController = TextEditingController(text: initial?.purpose ?? '');
    _isRoundTrip = initial?.isRoundTrip ?? false;
    _distanceController.addListener(_distanceListener);
  }

  late final VoidCallback _distanceListener;

  /// Même critère syntaxique que le submit — aucune règle métier dupliquée.
  bool get _canSubmit {
    final distance = parseKmInput(_distanceController.text);
    return distance != null && distance > 0;
  }

  @override
  void dispose() {
    _distanceController.removeListener(_distanceListener);
    _distanceController.dispose();
    _originController.dispose();
    _destinationController.dispose();
    _purposeController.dispose();
    super.dispose();
  }

  TripFormResult? _values() {
    final distance = parseKmInput(_distanceController.text);
    if (distance == null || distance <= 0) {
      setState(() {
        _distanceError = 'Saisissez une distance en kilomètres (> 0).';
      });
      return null;
    }

    return TripFormResult(
      distanceKm: distance,
      isRoundTrip: _isRoundTrip,
      origin: _originController.text,
      destination: _destinationController.text,
      purpose: _purposeController.text,
      vehicleId: _vehicleId,
    );
  }

  void _submit() {
    final values = _values();
    if (values != null) Navigator.of(context).pop(values);
  }

  Future<void> _multiDay() async {
    final values = _values();
    if (values == null || _choosingDays) return;
    FocusScope.of(context).unfocus();
    setState(() => _choosingDays = true);
    try {
      final added = await widget.onMultiDay!(context, values);
      if (!mounted) return;
      setState(() => _choosingDays = false);
      // null ferme la saisie sans déclencher l'ajout journalier de l'appelant.
      if (added) Navigator.of(context).pop();
    } catch (_) {
      if (mounted) {
        setState(() => _choosingDays = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Impossible d’ouvrir les jours. Réessayez.'),
          ),
        );
      }
    }
  }

  /// La section facultative s'ouvre d'elle-même en édition quand elle
  /// contient déjà des valeurs.
  bool get _hasOptionalValues {
    final initial = widget.initial;
    return initial != null &&
        (initial.origin != null ||
            initial.destination != null ||
            initial.purpose != null);
  }

  @override
  Widget build(BuildContext context) {
    final isEditing = widget.initial != null;

    // CAS COURANT D'ABORD (UX-003B) : distance + A/R immédiatement, le
    // reste dans « Itinéraire et détails », action principale épinglée.
    return FormSheetScaffold(
      title: isEditing ? 'Modifier le trajet' : 'Ajouter un trajet',
      primaryLabel: isEditing ? 'Enregistrer' : 'Enregistrer le trajet',
      onPrimary: _canSubmit && !_choosingDays
          ? (_multipleDays ? _multiDay : _submit)
          : null,
      beforePrimary: !isEditing && widget.onMultiDay != null
          ? RadioGroup<bool>(
              groupValue: _multipleDays,
              onChanged: (value) {
                if (!_choosingDays && value != null) {
                  setState(() => _multipleDays = value);
                }
              },
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    'Quand effectuer ce trajet ?',
                    style: Theme.of(context).textTheme.labelMedium,
                  ),
                  for (final (value, label, key) in [
                    (false, widget.singleDayLabel, 'new-trip-single-day'),
                    (true, 'Choisir plusieurs jours…', 'new-trip-multi-day'),
                  ])
                    InkWell(
                      key: Key(key),
                      onTap: _choosingDays
                          ? null
                          : () => setState(() => _multipleDays = value),
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(minHeight: 48),
                        child: Row(
                          children: [
                            SizedBox(
                              width: 40,
                              child: Radio<bool>(
                                value: value,
                                enabled: !_choosingDays,
                              ),
                            ),
                            Expanded(
                              child: Text(
                                label,
                                style: Theme.of(context).textTheme.bodyMedium,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  const SizedBox(height: AppSpacing.s),
                ],
              ),
            )
          : null,
      children: [
        TextField(
          controller: _distanceController,
          autofocus: !isEditing,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          textInputAction: TextInputAction.done,
          decoration: InputDecoration(
            labelText: 'Distance comptabilisée (km)',
            helperText: 'Distance totale réellement parcourue, A/R inclus.',
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
          // Une distance déjà saisie n'est jamais doublée
          // automatiquement ; seul le calcul d'itinéraire en tient compte.
          subtitle: Text(
            _isRoundTrip
                ? 'Le calcul d\u2019itinéraire proposera la distance '
                      'aller-retour.'
                : 'Le calcul d\u2019itinéraire proposera la distance '
                      'aller.',
          ),
          contentPadding: EdgeInsets.zero,
        ),
        const SizedBox(height: AppSpacing.s),
        FormOptionalSection(
          title: 'Itinéraire et détails',
          initiallyExpanded: _hasOptionalValues,
          children: [
            TextField(
              controller: _originController,
              textCapitalization: TextCapitalization.sentences,
              textInputAction: TextInputAction.next,
              decoration: const InputDecoration(
                labelText: 'Départ',
                isDense: true,
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: AppSpacing.m),
            TextField(
              controller: _destinationController,
              textCapitalization: TextCapitalization.sentences,
              textInputAction: TextInputAction.next,
              decoration: const InputDecoration(
                labelText: 'Destination',
                isDense: true,
                border: OutlineInputBorder(),
              ),
            ),
            // Calcul optionnel : visible seulement si départ + destination.
            RouteCalcSection(
              service: widget.routeService,
              originController: _originController,
              destinationController: _destinationController,
              isRoundTrip: () => _isRoundTrip,
              onUseDistance: (totalKm) => setState(() {
                _distanceController.text = formatKmValue(totalKm);
                _distanceError = null;
              }),
            ),
            const SizedBox(height: AppSpacing.m),
            TextField(
              controller: _purposeController,
              textCapitalization: TextCapitalization.sentences,
              textInputAction: TextInputAction.done,
              decoration: const InputDecoration(
                labelText: 'Motif',
                isDense: true,
                border: OutlineInputBorder(),
              ),
            ),
          ],
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
                  child: Text(
                    vehicle.isArchived
                        ? '${vehicle.name} (archivé)'
                        : vehicle.name,
                  ),
                ),
            ],
            onChanged: (value) => setState(() => _vehicleId = value),
          ),
        ],
        const SizedBox(height: AppSpacing.s),
      ],
    );
  }
}
