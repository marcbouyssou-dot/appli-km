import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/logic/vacations.dart';
import '../../domain/models/civil_date.dart';
import 'vacations_controller.dart';

/// Garde « congé + kilomètres » : jamais les deux états silencieusement.
///
/// Si [date] est en congé, demande confirmation puis retire LE JOUR du
/// statut congé (le reste de la période est préservé, découpe incluse)
/// AVANT l'action kilométrique. Séquence la plus sûre : si l'étape
/// kilométrique échoue ensuite, l'état reste cohérent (journée simplement
/// plus en congé, aucun mélange congé+km).
///
/// Retourne true si l'action kilométrique peut continuer.
Future<bool> ensureDayNotVacation(
  BuildContext context,
  WidgetRef ref,
  CivilDate date,
) async {
  final periods = await ref.read(vacationsControllerProvider.future);
  if (!isVacationDate(periods, date)) return true;
  if (!context.mounted) return false;

  final confirmed = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('Cette journée est marquée comme congé.'),
      content: const Text('Retirer le congé et ajouter les kilomètres ?'),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: const Text('Annuler'),
        ),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(true),
          child: const Text('Retirer le congé et continuer'),
        ),
      ],
    ),
  );
  if (confirmed != true) return false;

  await ref.read(vacationsControllerProvider.notifier).removeDay(date);
  return true;
}
