import 'package:flutter/material.dart';

import '../../data/network/route_distance_service.dart';
import '../../domain/models/km.dart';
import '../../theme/tokens.dart';
import '../../widgets/km_format.dart';

/// Section « Calculer la distance » partagée par les formulaires de trajet
/// et de favori.
///
/// CONFIDENTIALITÉ : aucune adresse n'est envoyée tant que l'utilisateur
/// n'appuie pas sur « Calculer la distance » ; rien n'est journalisé.
/// Le calcul PROPOSE une distance — l'utilisateur reste maître du champ
/// et peut la modifier avant d'enregistrer. Aucun retry automatique.
class RouteCalcSection extends StatefulWidget {
  const RouteCalcSection({
    super.key,
    required this.service,
    required this.originController,
    required this.destinationController,
    required this.isRoundTrip,
    required this.onUseDistance,
  });

  final RouteDistanceService? service;
  final TextEditingController originController;
  final TextEditingController destinationController;

  /// Lu AU MOMENT d'« Utiliser » : A/R => 2 × aller, sinon aller.
  /// La valeur insérée est la distance comptabilisée TOTALE — elle ne sera
  /// jamais redoublée ailleurs (invariant Trip.distanceKm).
  final bool Function() isRoundTrip;

  final void Function(double totalKm) onUseDistance;

  @override
  State<RouteCalcSection> createState() => _RouteCalcSectionState();
}

class _RouteCalcSectionState extends State<RouteCalcSection> {
  bool _loading = false;
  RouteDistanceSuccess? _result;
  String? _error;

  bool get _hasAddresses =>
      widget.originController.text.trim().isNotEmpty &&
      widget.destinationController.text.trim().isNotEmpty;

  @override
  void initState() {
    super.initState();
    // Simple rafraîchissement de visibilité du bouton — aucune requête.
    widget.originController.addListener(_onAddressChanged);
    widget.destinationController.addListener(_onAddressChanged);
  }

  @override
  void dispose() {
    widget.originController.removeListener(_onAddressChanged);
    widget.destinationController.removeListener(_onAddressChanged);
    super.dispose();
  }

  void _onAddressChanged() {
    if (mounted) setState(() {});
  }

  Future<void> _calculate() async {
    final service = widget.service;
    if (service == null || _loading) return;

    setState(() {
      _loading = true;
      _error = null;
      _result = null;
    });

    final result = await service.estimate(
      origin: widget.originController.text.trim(),
      destination: widget.destinationController.text.trim(),
    );
    if (!mounted) return;

    switch (result) {
      case RouteDistanceSuccess():
        setState(() {
          _loading = false;
          _result = result;
        });
      case RouteAddressAmbiguous():
        setState(() => _loading = false);
        await _resolveAmbiguity(result);
      case RouteAddressNotFound(isOrigin: final isOrigin):
        setState(() {
          _loading = false;
          _error = 'Adresse ${isOrigin ? 'de départ' : 'de destination'} '
              'introuvable. Vérifiez l’adresse ou saisissez la '
              'distance.';
        });
      case RouteOffline():
        setState(() {
          _loading = false;
          _error = 'Calcul indisponible hors ligne. '
              'Vous pouvez saisir la distance manuellement.';
        });
      case RouteTimeout():
        setState(() {
          _loading = false;
          _error = 'Le calcul a pris trop de temps. '
              'Réessayez ou saisissez la distance manuellement.';
        });
      case RouteServiceUnavailable():
        setState(() {
          _loading = false;
          _error = 'Le calcul de distance est momentanément indisponible.';
        });
    }
  }

  /// Plusieurs lieux plausibles : choix explicite, puis relance du calcul
  /// avec le libellé précis choisi.
  Future<void> _resolveAmbiguity(RouteAddressAmbiguous ambiguous) async {
    final choice = await showDialog<String>(
      context: context,
      builder: (context) => SimpleDialog(
        title: Text(ambiguous.isOrigin
            ? 'Plusieurs lieux pour le départ'
            : 'Plusieurs lieux pour la destination'),
        children: [
          for (final suggestion in ambiguous.suggestions)
            SimpleDialogOption(
              onPressed: () => Navigator.of(context).pop(suggestion),
              child: Padding(
                padding:
                    const EdgeInsets.symmetric(vertical: AppSpacing.s),
                child: Text(suggestion),
              ),
            ),
        ],
      ),
    );
    if (choice == null || !mounted) return;

    final controller = ambiguous.isOrigin
        ? widget.originController
        : widget.destinationController;
    controller.text = choice;
    await _calculate();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    if (widget.service == null) return const SizedBox.shrink();

    final result = _result;
    final roundTripKm =
        result == null ? 0.0 : normalizeKm(result.oneWayKm * 2);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (_hasAddresses) ...[
          const SizedBox(height: AppSpacing.m),
          OutlinedButton.icon(
            key: const Key('route-calc-button'),
            onPressed: _loading ? null : _calculate,
            icon: _loading
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.route_outlined),
            label: Text(
                _loading ? 'Calcul en cours…' : 'Calculer la distance'),
            style: OutlinedButton.styleFrom(
              minimumSize: const Size.fromHeight(AppSizes.minTouchTarget),
            ),
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            'Le calcul utilise un service cartographique en ligne.',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
        if (_error != null) ...[
          const SizedBox(height: AppSpacing.s),
          Text(
            _error!,
            key: const Key('route-calc-error'),
            style: TextStyle(color: theme.colorScheme.error),
          ),
        ],
        if (result != null) ...[
          const SizedBox(height: AppSpacing.s),
          Text(
            'Aller : ${formatKm(result.oneWayKm)} · '
            'Aller-retour : ${formatKm(roundTripKm)}',
            key: const Key('route-calc-result'),
            style: theme.textTheme.bodyMedium
                ?.copyWith(fontWeight: FontWeight.bold),
          ),
          Text(
            '${result.originLabel}\n→ ${result.destinationLabel}',
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: AppSpacing.s),
          FilledButton.tonal(
            key: const Key('route-calc-use'),
            onPressed: () {
              final total = widget.isRoundTrip()
                  ? normalizeKm(result.oneWayKm * 2)
                  : result.oneWayKm;
              widget.onUseDistance(total);
            },
            style: FilledButton.styleFrom(
              minimumSize: const Size.fromHeight(AppSizes.minTouchTarget),
            ),
            child: Builder(builder: (context) {
              final total = widget.isRoundTrip()
                  ? normalizeKm(result.oneWayKm * 2)
                  : result.oneWayKm;
              return Text('Utiliser ${formatKm(total)}');
            }),
          ),
        ],
      ],
    );
  }
}
