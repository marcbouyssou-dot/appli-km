import 'package:flutter/material.dart';

import '../../domain/models/vehicle.dart';
import '../../widgets/form_sheet_scaffold.dart';
import '../../theme/tokens.dart';

/// Valeurs saisies dans le formulaire de véhicule.
class VehicleFormResult {
  VehicleFormResult({
    required this.name,
    required this.category,
    this.fiscalPowerCv,
    this.registration,
    this.motorization = Motorization.unspecified,
    this.twoWheelerClass,
  });

  final String name;
  final VehicleCategory category;
  final int? fiscalPowerCv;
  final String? registration;
  final Motorization motorization;
  final TwoWheelerFiscalClass? twoWheelerClass;
}

/// Feuille de création/modification d'un véhicule.
/// Pas de compteur kilométrique (hors périmètre produit).
Future<VehicleFormResult?> showVehicleFormSheet(
  BuildContext context, {
  Vehicle? initial,
}) {
  return showModalBottomSheet<VehicleFormResult>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (context) => _VehicleFormSheet(initial: initial),
  );
}

class _VehicleFormSheet extends StatefulWidget {
  const _VehicleFormSheet({this.initial});

  final Vehicle? initial;

  @override
  State<_VehicleFormSheet> createState() => _VehicleFormSheetState();
}

class _VehicleFormSheetState extends State<_VehicleFormSheet> {
  late final TextEditingController _nameController;
  late final TextEditingController _cvController;
  late final TextEditingController _registrationController;
  late VehicleCategory _category;
  late Motorization _motorization;
  TwoWheelerFiscalClass? _twoWheelerClass;
  String? _nameError;
  String? _cvError;

  @override
  void initState() {
    super.initState();
    final initial = widget.initial;
    _nameController = TextEditingController(text: initial?.name ?? '');
    _cvController = TextEditingController(
        text: initial?.fiscalPowerCv?.toString() ?? '');
    _registrationController =
        TextEditingController(text: initial?.registration ?? '');
    _category = initial?.category ?? VehicleCategory.car;
    _motorization = initial?.motorization ?? Motorization.unspecified;
    _twoWheelerClass = initial?.twoWheelerClass;
    // Garde UX précoce (grammaire UX-003B1) : l'état du bouton suit la
    // saisie — mêmes critères syntaxiques que le submit, rien de métier.
    _requiredListener = () => setState(() {});
    _nameController.addListener(_requiredListener);
    _cvController.addListener(_requiredListener);
  }

  late final VoidCallback _requiredListener;

  bool get _canSubmit {
    if (_nameController.text.trim().isEmpty) return false;
    final cvText = _cvController.text.trim();
    if (cvText.isEmpty) return true; // CV facultatif
    final cv = int.tryParse(cvText);
    return cv != null && cv > 0;
  }

  @override
  void dispose() {
    _nameController.removeListener(_requiredListener);
    _cvController.removeListener(_requiredListener);
    _nameController.dispose();
    _cvController.dispose();
    _registrationController.dispose();
    super.dispose();
  }

  void _submit() {
    final name = _nameController.text.trim();
    final cvText = _cvController.text.trim();
    final cv = cvText.isEmpty ? null : int.tryParse(cvText);

    setState(() {
      _nameError = name.isEmpty ? 'Donnez un nom à ce véhicule.' : null;
      _cvError = (cvText.isNotEmpty && (cv == null || cv <= 0))
          ? 'Puissance fiscale invalide.'
          : null;
    });
    if (_nameError != null || _cvError != null) return;

    Navigator.of(context).pop(VehicleFormResult(
      name: name,
      category: _category,
      fiscalPowerCv: cv,
      registration: _registrationController.text,
      motorization: _motorization,
      // La classe fiscale n'a de sens que pour un deux-roues.
      twoWheelerClass:
          _category == VehicleCategory.twoWheeler ? _twoWheelerClass : null,
    ));
  }

  @override
  Widget build(BuildContext context) {
    final isEditing = widget.initial != null;

    // Grammaire V1 (UX-003C) : formulaire rare et COMPLET par nature —
    // tous les champs visibles, pas d'accordéon, action épinglée.
    return FormSheetScaffold(
      title: isEditing ? 'Modifier le véhicule' : 'Nouveau véhicule',
      primaryLabel: isEditing ? 'Enregistrer' : 'Ajouter le véhicule',
      onPrimary: _canSubmit ? _submit : null,
      children: [
            TextField(
              controller: _nameController,
              autofocus: !isEditing,
              textCapitalization: TextCapitalization.sentences,
              textInputAction: TextInputAction.next,
              decoration: InputDecoration(
                labelText: 'Nom',
                hintText: 'Ex. : Peugeot 3008',
                border: const OutlineInputBorder(),
                errorText: _nameError,
              ),
            ),
            const SizedBox(height: AppSpacing.m),
            SegmentedButton<VehicleCategory>(
              segments: const [
                ButtonSegment(
                  value: VehicleCategory.car,
                  label: Text('Voiture'),
                  icon: Icon(Icons.directions_car_outlined),
                ),
                ButtonSegment(
                  value: VehicleCategory.twoWheeler,
                  label: Text('Deux-roues'),
                  icon: Icon(Icons.two_wheeler_outlined),
                ),
              ],
              selected: {_category},
              onSelectionChanged: (selection) =>
                  setState(() => _category = selection.first),
            ),
            if (_category == VehicleCategory.twoWheeler) ...[
              const SizedBox(height: AppSpacing.m),
              DropdownButtonFormField<TwoWheelerFiscalClass?>(
                key: const Key('two-wheeler-class-field'),
                initialValue: _twoWheelerClass,
                isExpanded: true,
                decoration: const InputDecoration(
                  labelText: 'Type de deux-roues',
                  helperText:
                      'Les barèmes moto et cyclomoteur sont distincts.',
                  border: OutlineInputBorder(),
                ),
                items: const [
                  DropdownMenuItem(
                    value: null,
                    child: Text('Non renseigné'),
                  ),
                  DropdownMenuItem(
                    value: TwoWheelerFiscalClass.motorcycle,
                    child: Text('Moto (plus de 50 cm³)'),
                  ),
                  DropdownMenuItem(
                    value: TwoWheelerFiscalClass.moped,
                    child: Text('Cyclomoteur (50 cm³ au plus)'),
                  ),
                ],
                onChanged: (value) =>
                    setState(() => _twoWheelerClass = value),
              ),
            ],
            const SizedBox(height: AppSpacing.m),
            DropdownButtonFormField<Motorization>(
              key: const Key('motorization-field'),
              initialValue: _motorization,
              isExpanded: true,
              decoration: const InputDecoration(
                labelText: 'Motorisation',
                helperText:
                    'Nécessaire pour l’estimation kilométrique indicative.',
                border: OutlineInputBorder(),
              ),
              items: const [
                DropdownMenuItem(
                  value: Motorization.unspecified,
                  child: Text('Non renseignée'),
                ),
                DropdownMenuItem(
                  value: Motorization.electric,
                  child: Text('Électrique 100 %'),
                ),
                DropdownMenuItem(
                  value: Motorization.other,
                  child: Text('Autre motorisation'),
                ),
              ],
              onChanged: (value) => setState(
                  () => _motorization = value ?? Motorization.unspecified),
            ),
            const SizedBox(height: AppSpacing.m),
            TextField(
              controller: _cvController,
              keyboardType: TextInputType.number,
              textInputAction: TextInputAction.next,
              decoration: InputDecoration(
                labelText: 'Puissance fiscale (CV, facultatif)',
                helperText: 'Utile pour la future estimation fiscale.',
                border: const OutlineInputBorder(),
                errorText: _cvError,
              ),
            ),
            const SizedBox(height: AppSpacing.m),
            TextField(
              controller: _registrationController,
              textCapitalization: TextCapitalization.characters,
              textInputAction: TextInputAction.done,
              decoration: const InputDecoration(
                labelText: 'Immatriculation (facultatif)',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: AppSpacing.s),
      ],
    );
  }
}
