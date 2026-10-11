import 'package:flutter/material.dart';

import '../theme/tokens.dart';

/// Boutons partagés (UX-001).
///
/// PARTICULARITÉ : la [Key] passée à ces widgets est posée sur le BOUTON
/// Material interne (pas sur le wrapper), pour que les tests existants qui
/// font `tester.widget<FilledButton>(find.byKey(...))` ou tapent par clé
/// continuent de viser le vrai bouton.

/// Action principale pleine largeur (56 px). [tonal] : variante secondaire.
class PrimaryButton extends StatelessWidget {
  const PrimaryButton({
    Key? key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.tonal = false,
  })  : buttonKey = key,
        super(key: null);

  final Key? buttonKey;
  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final bool tonal;

  @override
  Widget build(BuildContext context) {
    final style = FilledButton.styleFrom(
      minimumSize: const Size.fromHeight(AppSizes.primaryActionHeight),
    );
    final labelWidget = Text(label);
    if (icon != null) {
      return tonal
          ? FilledButton.tonalIcon(
              key: buttonKey,
              onPressed: onPressed,
              icon: Icon(icon),
              label: labelWidget,
              style: style,
            )
          : FilledButton.icon(
              key: buttonKey,
              onPressed: onPressed,
              icon: Icon(icon),
              label: labelWidget,
              style: style,
            );
    }
    return tonal
        ? FilledButton.tonal(
            key: buttonKey,
            onPressed: onPressed,
            style: style,
            child: labelWidget,
          )
        : FilledButton(
            key: buttonKey,
            onPressed: onPressed,
            style: style,
            child: labelWidget,
          );
  }
}

/// Action discrète (texte gris) : « Marquer comme congé », « Effacer la
/// journée », « Ajouter des congés »… Cible >= 48 px, jamais réduite.
class QuietButton extends StatelessWidget {
  const QuietButton({
    Key? key,
    required this.label,
    required this.onPressed,
    this.icon,
  })  : buttonKey = key,
        super(key: null);

  final Key? buttonKey;
  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final style = TextButton.styleFrom(
      foregroundColor: Theme.of(context).colorScheme.onSurfaceVariant,
      minimumSize: const Size(
        AppSizes.minTouchTarget * 3,
        AppSizes.minTouchTarget,
      ),
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xl),
    );
    if (icon != null) {
      return TextButton.icon(
        key: buttonKey,
        onPressed: onPressed,
        icon: Icon(icon),
        label: Text(label),
        style: style,
      );
    }
    return TextButton(
      key: buttonKey,
      onPressed: onPressed,
      style: style,
      child: Text(label),
    );
  }
}

/// Action destructive textuelle (rouge), toujours accompagnée d'une
/// confirmation en aval — le style ne remplace jamais le dialogue.
class DestructiveTextButton extends StatelessWidget {
  const DestructiveTextButton({
    Key? key,
    required this.label,
    required this.onPressed,
    this.icon,
  })  : buttonKey = key,
        super(key: null);

  final Key? buttonKey;
  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final style = TextButton.styleFrom(
      foregroundColor: Theme.of(context).colorScheme.error,
      minimumSize: const Size.fromHeight(AppSizes.minTouchTarget),
    );
    if (icon != null) {
      return TextButton.icon(
        key: buttonKey,
        onPressed: onPressed,
        icon: Icon(icon),
        label: Text(label),
        style: style,
      );
    }
    return TextButton(
      key: buttonKey,
      onPressed: onPressed,
      style: style,
      child: Text(label),
    );
  }
}
