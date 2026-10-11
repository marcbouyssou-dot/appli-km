import 'package:flutter/material.dart';

import '../theme/tokens.dart';

/// Liste groupée (UX-001) : plusieurs lignes dans UNE surface, séparées par
/// des filets internes — remplace les Card>Column sans séparateurs et les
/// suites de cartes individuelles par micro-information.
class GroupedList extends StatelessWidget {
  const GroupedList({
    super.key,
    required this.children,
    this.dividerIndent = AppSpacing.l,
  });

  final List<Widget> children;
  final double dividerIndent;

  @override
  Widget build(BuildContext context) {
    return Card(
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          for (var i = 0; i < children.length; i++) ...[
            if (i > 0)
              Divider(height: 1, indent: dividerIndent, endIndent: 0),
            children[i],
          ],
        ],
      ),
    );
  }
}
