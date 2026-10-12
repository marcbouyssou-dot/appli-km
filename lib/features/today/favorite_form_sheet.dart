import 'package:flutter/material.dart';

import '../../data/network/route_distance_service.dart';
import '../../domain/models/favorite_trip.dart';
import '../../domain/models/vehicle.dart';
import '../../widgets/app_buttons.dart';
import '../../widgets/form_sheet_scaffold.dart';
import '../../theme/tokens.dart';
import '../../widgets/km_format.dart';
import '../day/route_calc_section.dart';

/// Valeurs saisies dans le formulaire de favori.
class FavoriteFormResult {
  FavoriteFormResult({
    required this.label,
    required this.distanceKm,
    required this.defaultRoundTrip,
    this.origin,
    this.destination,
    this.purpose,
    this.vehicleId,
  });

  final String label;
  final double distanceKm;
  final bool defaultRoundTrip;
  final String? origin;
  final String? destination;
  final String? purpose;

  /// Véhicule par défaut : null = « Automatique » (principal résolu au tap).
  final String? vehicleId;
}

/// Feuille de création/modification d'un favori.
/// La distance saisie est la distance COMPTABILISÉE ajoutée à chaque
/// utilisation (déjà totale si A/R) — même sémantique que les trajets.
///
/// [onDeleteRequested] (édition seulement) : la fiche propose aussi
/// « Supprimer le favori » ; le callback mène la confirmation et retourne
/// true si la suppression a eu lieu — la feuille se ferme alors.
Future<FavoriteFormResult?> showFavoriteFormSheet(
  BuildContext context, {
  FavoriteTrip? initial,
  List<Vehicle> vehicles = const [],
  RouteDistanceService? routeService,
  Future<bool> Function()? onDeleteRequested,
}) {
  return showModalBottomSheet<FavoriteFormResult>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (context) => _FavoriteFormSheet(
      initial: initial,
      vehicles: vehicles,
      routeService: routeService,
      onDeleteRequested: onDeleteRequested,
    ),
  );
}

class _FavoriteFormSheet extends StatefulWidget {
  const _FavoriteFormSheet({
    this.initial,
    this.vehicles = const [],
    this.routeService,
    this.onDeleteRequested,
  });

  final FavoriteTrip? initial;
  final List<Vehicle> vehicles;
  final RouteDistanceService? routeService;
  final Future<bool> Function()? onDeleteRequested;

  @override
  State<_FavoriteFormSheet> createState() => _FavoriteFormSheetState();
}

class _FavoriteFormSheetState extends State<_FavoriteFormSheet> {
  late final TextEditingController _labelController;
  late final TextEditingController _distanceController;
  late final TextEditingController _originController;
  late final TextEditingController _destinationController;
  late final TextEditingController _purposeController;
  late bool _defaultRoundTrip;
  String? _vehicleId;
  String? _labelError;
  String? _distanceError;

  @override
  void initState() {
    super.initState();
    final initial = widget.initial;
    // Garde UX précoce (UX-003B1) : l'état du bouton suit la saisie.
    _requiredListener = () => setState(() {});
    _vehicleId = initial?.vehicleId;
    // Véhicule archivé référencé : on revient à « Automatique » et
    // l'utilisateur corrige explicitement (jamais de Trip archivé caché).
    if (_vehicleId != null &&
        !widget.vehicles.any((v) => v.id == _vehicleId && !v.isArchived)) {
      _vehicleId = null;
    }
    _labelController = TextEditingController(text: initial?.label ?? '');
    _distanceController = TextEditingController(
      text: initial == null ? '' : formatKmValue(initial.distanceKm),
    );
    _originController = TextEditingController(text: initial?.origin ?? '');
    _destinationController =
        TextEditingController(text: initial?.destination ?? '');
    _purposeController = TextEditingController(text: initial?.purpose ?? '');
    _defaultRoundTrip = initial?.defaultRoundTrip ?? false;
    _labelController.addListener(_requiredListener);
    _distanceController.addListener(_requiredListener);
  }

  late final VoidCallback _requiredListener;

  /// Mêmes critères syntaxiques que le submit — rien de métier dupliqué.
  bool get _canSubmit {
    if (_labelController.text.trim().isEmpty) return false;
    final distance = parseKmInput(_distanceController.text);
    return distance != null && distance > 0;
  }

  @override
  void dispose() {
    _labelController.removeListener(_requiredListener);
    _distanceController.removeListener(_requiredListener);
    _labelController.dispose();
    _distanceController.dispose();
    _originController.dispose();
    _destinationController.dispose();
    _purposeController.dispose();
    super.dispose();
  }

  void _submit() {
    final label = _labelController.text.trim();
    final distance = parseKmInput(_distanceController.text);

    setState(() {
      _labelError = label.isEmpty ? 'Donnez un nom à ce favori.' : null;
      _distanceError = (distance == null || distance <= 0)
          ? 'Saisissez une distance en kilomètres (> 0).'
          : null;
    });
    if (_labelError != null || _distanceError != null) return;

    Navigator.of(context).pop(FavoriteFormResult(
      label: label,
      distanceKm: distance!,
      defaultRoundTrip: _defaultRoundTrip,
      origin: _originController.text,
      destination: _destinationController.text,
      purpose: _purposeController.text,
      vehicleId: _vehicleId,
    ));
  }

  /// Section facultative dépliée d'office en édition quand renseignée.
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

    // CAS COURANT D'ABORD (UX-003B) : nom + distance + A/R, le reste dans
    // « Itinéraire et détails », action principale épinglée.
    return FormSheetScaffold(
      title: isEditing ? 'Modifier le favori' : 'Nouveau trajet favori',
      help: 'Disponible sur toutes les journées.',
      primaryLabel: isEditing ? 'Enregistrer' : 'Créer le favori',
      onPrimary: _canSubmit ? _submit : null,
      children: [
            TextField(
              controller: _labelController,
              autofocus: !isEditing,
              textCapitalization: TextCapitalization.sentences,
              textInputAction: TextInputAction.next,
              decoration: InputDecoration(
                labelText: 'Nom du favori',
                hintText: 'Ex. : Cabinet ↔ EHPAD',
                border: const OutlineInputBorder(),
                errorText: _labelError,
              ),
            ),
            const SizedBox(height: AppSpacing.m),
            TextField(
              controller: _distanceController,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              textInputAction: TextInputAction.done,
              decoration: InputDecoration(
                labelText: 'Distance comptabilisée (km)',
                helperText:
                    'Distance totale ajoutée à chaque utilisation, A/R inclus.',
                helperMaxLines: 2,
                suffixText: 'km',
                border: const OutlineInputBorder(),
                errorText: _distanceError,
                errorMaxLines: 2,
              ),
            ),
            SwitchListTile(
              value: _defaultRoundTrip,
              onChanged: (value) =>
                  setState(() => _defaultRoundTrip = value),
              title: const Text('Aller-retour'),
              // Une distance déjà saisie n'est jamais doublée
              // automatiquement ; seul le calcul d'itinéraire en tient compte.
              subtitle: Text(_defaultRoundTrip
                  ? 'Le calcul d\u2019itinéraire proposera la distance '
                      'aller-retour.'
                  : 'Le calcul d\u2019itinéraire proposera la distance '
                      'aller.'),
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
                // Le calcul réseau sert uniquement à CONFIGURER le favori :
                // chaque futur tap réutilisera la distance SANS réseau.
                RouteCalcSection(
                  service: widget.routeService,
                  originController: _originController,
                  destinationController: _destinationController,
                  isRoundTrip: () => _defaultRoundTrip,
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
            if (widget.vehicles.any((v) => !v.isArchived)) ...[
              const SizedBox(height: AppSpacing.m),
              DropdownButtonFormField<String?>(
                key: const Key('favorite-vehicle-field'),
                isExpanded: true,
                initialValue: _vehicleId,
                decoration: const InputDecoration(
                  labelText: 'Véhicule par défaut',
                  border: OutlineInputBorder(),
                ),
                items: [
                  const DropdownMenuItem<String?>(
                    value: null,
                    child: Text('Automatique (véhicule principal)'),
                  ),
                  for (final vehicle in widget.vehicles)
                    if (!vehicle.isArchived)
                      DropdownMenuItem<String?>(
                        value: vehicle.id,
                        child: Text(vehicle.name),
                      ),
                ],
                onChanged: (value) => setState(() => _vehicleId = value),
              ),
            ],
            if (isEditing && widget.onDeleteRequested != null) ...[
              const SizedBox(height: AppSpacing.m),
              DestructiveTextButton(
                key: const Key('delete-favorite-from-form'),
                icon: Icons.delete_outline,
                label: 'Supprimer le favori',
                onPressed: () async {
                  final deleted = await widget.onDeleteRequested!();
                  if (deleted && context.mounted) {
                    Navigator.of(context).pop();
                  }
                },
              ),
            ],
            const SizedBox(height: AppSpacing.s),
      ],
    );
  }
}
