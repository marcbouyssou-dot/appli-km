import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../app/providers.dart';
import '../../domain/models/civil_date.dart';
import '../../data/local/trip_batch_service.dart';
import '../../domain/models/trip_template.dart';
import '../../domain/models/vehicle.dart';
import '../../widgets/km_format.dart';
import '../../widgets/period_selector.dart';
import '../day/day_controller.dart';

class TripDaysScreen extends ConsumerStatefulWidget {
  const TripDaysScreen({
    super.key,
    required this.source,
    required this.template,
    required this.label,
    this.initialDate,
    this.preselectDate = false,
  });
  final TripBatchSource source;
  final TripTemplate template;
  final String label;
  final CivilDate? initialDate;
  final bool preselectDate;
  @override
  ConsumerState<TripDaysScreen> createState() => _TripDaysScreenState();
}

class _TripDaysScreenState extends ConsumerState<TripDaysScreen> {
  final _selected = <CivilDate>{};
  late CivilDate _today, _month;
  List<Vehicle> _vehicles = [];
  String? _vehicleId, _error;
  bool _loaded = false,
      _busy = false,
      _confirmedVehicle = false,
      _missingVehicle = false;

  @override
  void initState() {
    super.initState();
    _today = ref.read(todayDateProvider)();
    final candidate = widget.initialDate ?? _today;
    final initial = candidate.isAfter(_today) ? _today : candidate;
    _month = CivilDate(initial.year, initial.month, 1);
    if (widget.preselectDate && !initial.isAfter(_today)) {
      _selected.add(initial);
    }
    _load();
  }

  Future<void> _load() async {
    try {
      final vehicles = await ref.read(vehicleRepositoryProvider).getAll();
      // Principal actuel proposé uniquement pour les favoris historiques.
      // Une saisie ou une copie conserve son choix explicite, même null.
      final settings = widget.source.favoriteId == null
          ? null
          : await ref.read(settingsRepositoryProvider).get();
      if (!mounted) return;
      setState(() {
        _vehicles = vehicles;
        final suggested = widget.template.vehicleId ?? settings?.mainVehicleId;
        _missingVehicle =
            suggested != null && !vehicles.any((v) => v.id == suggested);
        _vehicleId = vehicles.any((v) => v.id == suggested) ? suggested : null;
        _loaded = true;
      });
    } catch (_) {
      if (mounted) {
        setState(() => _error = 'Impossible de lire les véhicules. Réessayez.');
      }
    }
  }

  String dates(Iterable<CivilDate> list) => list
      .map((d) => DateFormat('dd/MM/yyyy').format(d.toDateTime()))
      .join(', ');

  Future<void> _review() async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final service = ref.read(tripBatchServiceProvider);
      final plan = await service.preview(
        source: widget.source,
        dates: _selected,
        vehicleId: _vehicleId,
        today: _today,
        vehicleConfirmed: _confirmedVehicle,
      );
      if (!mounted) return;
      final n = plan.additions.length;
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Vérifier les trajets'),
          scrollable: true,
          content: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(plan.label, style: Theme.of(context).textTheme.titleMedium),
              Text(
                '${formatKm(plan.template.distanceKm)}${plan.template.isRoundTrip ? ' · Aller-retour' : ''}',
              ),
              if (plan.template.purpose != null) Text(plan.template.purpose!),
              if (plan.sourceDate != null)
                Text(
                  'Origine : ${dates([plan.sourceDate!])}. Le trajet d’origine sera conservé.',
                ),
              if (plan.template.origin != null ||
                  plan.template.destination != null)
                Text(
                  [
                    plan.template.origin,
                    plan.template.destination,
                  ].whereType<String>().join(' → '),
                ),
              const SizedBox(height: 12),
              Text('Véhicule : ${plan.vehicleLabel}'),
              Text('${plan.requested.length} jour(s) sélectionné(s)'),
              Text('Trajets à ajouter : $n'),
              const Text(
                'Ces kilomètres s’ajoutent aux données existantes. Les autres kilomètres restent inchangés.',
              ),
              if (n > 0)
                Padding(
                  padding: const EdgeInsets.only(top: 12),
                  child: Text('À ajouter : ${dates(plan.additions)}'),
                ),
              if (plan.duplicates.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 12),
                  child: Text(
                    '${plan.duplicates.length} trajet(s) déjà présent(s) ne seront pas ajoutés : ${dates(plan.duplicates)}.',
                  ),
                ),
              if (plan.vacations.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 12),
                  child: Text(
                    '${plan.vacations.length} jour(s) de congé exclus : ${dates(plan.vacations)}.',
                  ),
                ),
              if (n == 0)
                const Padding(
                  padding: EdgeInsets.only(top: 12),
                  child: Text('Aucun nouveau trajet à ajouter.'),
                ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Annuler'),
            ),
            if (n > 0)
              FilledButton(
                key: const Key('confirm-favorite-days'),
                onPressed: () => Navigator.pop(context, true),
                child: Text('Ajouter $n trajet${n > 1 ? 's' : ''}'),
              ),
          ],
        ),
      );
      if (confirmed != true) {
        return;
      }
      final added = await service.apply(plan);
      for (final date in plan.additions) {
        ref.invalidate(dayControllerProvider(date));
      }
      ref.read(dayDataVersionProvider.notifier).bump();
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('$added trajet(s) ajouté(s).')));
      if (widget.source.favoriteId != null) {
        Navigator.pop(context);
      } else {
        Navigator.pop(context, true);
      }
    } catch (error) {
      if (mounted) {
        setState(
          () => _error = error is ArgumentError
              ? '${error.message}'
              : error is StateError
              ? error.message
              : 'Aucun trajet ajouté. Vérifiez les jours et réessayez.',
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final first = DateTime.utc(_month.year, _month.month, 1);
    final count = DateTime.utc(_month.year, _month.month + 1, 0).day;
    final label = DateFormat('MMMM yyyy', 'fr_FR').format(first);
    final past = _selected.any((d) => d.isBefore(_today));
    return PopScope(
      canPop: !_busy,
      child: Scaffold(
        appBar: AppBar(
          title: Text(
            widget.source.tripId != null
                ? 'Reporter sur d’autres jours'
                : widget.source.draft != null
                ? 'Choisir plusieurs jours'
                : 'Autres jours',
          ),
        ),
        body: SafeArea(
          child: !_loaded
              ? Center(
                  child: _error == null
                      ? const CircularProgressIndicator()
                      : TextButton(onPressed: _load, child: Text(_error!)),
                )
              : Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 600),
                    child: ListView(
                      children: [
                        Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                widget.label,
                                style: theme.textTheme.titleLarge,
                              ),
                              Text(
                                '${formatKm(widget.template.distanceKm)} par jour choisi',
                              ),
                              const SizedBox(height: 8),
                              const Text(
                                'Seuls les jours sélectionnés et confirmés recevront le trajet. Les congés et trajets déjà présents seront exclus.',
                              ),
                            ],
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 8),
                          child: PeriodSelector(
                            label: label[0].toUpperCase() + label.substring(1),
                            previousTooltip: 'Mois précédent',
                            nextTooltip: 'Mois suivant',
                            onPrevious:
                                _busy || _month.year == 1 && _month.month == 1
                                ? null
                                : () => setState(() {
                                    final d = DateTime.utc(
                                      _month.year,
                                      _month.month - 1,
                                      1,
                                    );
                                    _month = CivilDate(d.year, d.month, 1);
                                  }),
                            onNext:
                                _busy ||
                                    (_month.year == _today.year &&
                                        _month.month == _today.month)
                                ? null
                                : () => setState(() {
                                    final d = DateTime.utc(
                                      _month.year,
                                      _month.month + 1,
                                      1,
                                    );
                                    _month = CivilDate(d.year, d.month, 1);
                                  }),
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 4),
                          child: Column(
                            children: [
                              Row(
                                children: [
                                  for (final name in [
                                    'L',
                                    'Ma',
                                    'Me',
                                    'J',
                                    'V',
                                    'S',
                                    'D',
                                  ])
                                    Expanded(child: Center(child: Text(name))),
                                ],
                              ),
                              GridView.count(
                                crossAxisCount: 7,
                                shrinkWrap: true,
                                physics: const NeverScrollableScrollPhysics(),
                                children: [
                                  for (var i = 1; i < first.weekday; i++)
                                    const SizedBox(),
                                  for (var day = 1; day <= count; day++)
                                    Builder(
                                      builder: (context) {
                                        final d = CivilDate(
                                          _month.year,
                                          _month.month,
                                          day,
                                        );
                                        final selected = _selected.contains(d);
                                        return Semantics(
                                          selected: selected,
                                          label: dates([d]),
                                          child: Padding(
                                            padding: const EdgeInsets.all(1),
                                            child: TextButton(
                                              key: Key(
                                                'batch-day-${d.toIso8601()}',
                                              ),
                                              onPressed:
                                                  _busy || d.isAfter(_today)
                                                  ? null
                                                  : () => setState(() {
                                                      if (!_selected.add(d)) {
                                                        _selected.remove(d);
                                                      }
                                                      _confirmedVehicle = false;
                                                    }),
                                              style: TextButton.styleFrom(
                                                padding: EdgeInsets.zero,
                                                backgroundColor: selected
                                                    ? theme.colorScheme.primary
                                                    : null,
                                                foregroundColor: selected
                                                    ? theme
                                                          .colorScheme
                                                          .onPrimary
                                                    : null,
                                                shape: RoundedRectangleBorder(
                                                  borderRadius:
                                                      BorderRadius.circular(12),
                                                ),
                                              ),
                                              child: Text('$day'),
                                            ),
                                          ),
                                        );
                                      },
                                    ),
                                ],
                              ),
                            ],
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      '${_selected.length} jour(s) sélectionné(s)',
                                      style: theme.textTheme.titleMedium,
                                    ),
                                  ),
                                  TextButton(
                                    onPressed: _selected.isEmpty || _busy
                                        ? null
                                        : () => setState(() {
                                            _selected.clear();
                                            _confirmedVehicle = false;
                                          }),
                                    child: const Text('Tout retirer'),
                                  ),
                                ],
                              ),
                              if (_selected.isNotEmpty)
                                ExpansionTile(
                                  tilePadding: EdgeInsets.zero,
                                  title: const Text('Voir les dates choisies'),
                                  children: [
                                    Text(dates(_selected.toList()..sort())),
                                  ],
                                ),
                              const SizedBox(height: 12),
                              DropdownButtonFormField<String>(
                                key: ValueKey('batch-vehicle-$_vehicleId'),
                                initialValue: _vehicleId ?? '',
                                isExpanded: true,
                                decoration: const InputDecoration(
                                  labelText: 'Véhicule utilisé',
                                  border: OutlineInputBorder(),
                                ),
                                items: [
                                  const DropdownMenuItem(
                                    value: '',
                                    child: Text('Sans véhicule renseigné'),
                                  ),
                                  for (final v in _vehicles)
                                    DropdownMenuItem(
                                      value: v.id,
                                      child: Text(
                                        '${v.name}${v.isArchived ? ' (archivé)' : ''}',
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                ],
                                onChanged: _busy
                                    ? null
                                    : (v) => setState(() {
                                        _vehicleId = v == '' ? null : v;
                                        _confirmedVehicle = false;
                                      }),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                _missingVehicle
                                    ? 'Le véhicule d’origine n’est plus disponible. Choisissez et confirmez celui réellement utilisé, ou Sans véhicule renseigné.'
                                    : widget.source.favoriteId != null
                                    ? 'Le véhicule proposé vient du favori, sinon du principal actuel. Pour des jours passés, vérifiez celui réellement utilisé. Vous pouvez faire plusieurs ajouts avec des véhicules différents.'
                                    : widget.source.tripId != null
                                    ? 'Le véhicule proposé est celui du trajet d’origine. Il n’est jamais remplacé par le principal actuel. Confirmez celui réellement utilisé pour les dates passées.'
                                    : 'Le véhicule choisi dans le formulaire est conservé. Pour les dates passées, confirmez celui réellement utilisé.',
                                style: theme.textTheme.bodySmall,
                              ),
                              if (past || _missingVehicle)
                                CheckboxListTile(
                                  contentPadding: EdgeInsets.zero,
                                  title: const Text(
                                    'Je confirme le véhicule pour les dates choisies.',
                                  ),
                                  value: _confirmedVehicle,
                                  onChanged: _busy
                                      ? null
                                      : (v) => setState(
                                          () => _confirmedVehicle = v ?? false,
                                        ),
                                ),
                              if (_error != null)
                                Padding(
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 12,
                                  ),
                                  child: Text(
                                    _error!,
                                    style: TextStyle(
                                      color: theme.colorScheme.error,
                                    ),
                                  ),
                                ),
                              const SizedBox(height: 12),
                              FilledButton.icon(
                                key: const Key('review-favorite-days'),
                                onPressed:
                                    _busy ||
                                        _selected.isEmpty ||
                                        (past || _missingVehicle) &&
                                            !_confirmedVehicle
                                    ? null
                                    : _review,
                                icon: const Icon(Icons.playlist_add_check),
                                label: Text(
                                  _busy
                                      ? 'Vérification…'
                                      : 'Vérifier les jours',
                                ),
                              ),
                              const SizedBox(height: 24),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
        ),
      ),
    );
  }
}
