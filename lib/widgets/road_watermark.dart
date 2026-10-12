import 'package:flutter/material.dart';

import '../theme/mes_km_colors.dart';

/// Variante de composition du filigrane.
/// [full] : route haute + seconde courbe basse + arbres (Aujourd'hui, Plus).
/// [top] : uniquement la portion haute — pour les écrans denses en données
/// (Calendrier, Statistiques), où le décor ne doit jamais traverser les
/// chiffres avec une intensité perceptible.
enum RoadWatermarkVariant { full, top }

/// Filigrane « route » Mes Km (UX-001D).
///
/// Décor strictement DÉCORATIF : à peine perceptible (≈ 5 % de présence en
/// clair, moins en sombre), jamais porteur d'information, exclu de
/// Semantics, et inerte au pointeur (IgnorePointer) — le premier toucher
/// reste immédiat. Peint une fois (RepaintBoundary, painter statique) :
/// aucune animation, aucun repaint au scroll.
class MesKmRoadWatermark extends StatelessWidget {
  const MesKmRoadWatermark({
    super.key,
    required this.child,
    this.variant = RoadWatermarkVariant.full,
  });

  final Widget child;
  final RoadWatermarkVariant variant;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final dark = theme.brightness == Brightness.dark;
    // Teinte bleu/turquoise, extrêmement faible ; encore plus en sombre.
    // Adouci après recette iPhone (UX-001D final polish) : perceptible
    // quand on le cherche, jamais en concurrence avec le contenu.
    final ink = Color.lerp(
      theme.colorScheme.primary,
      theme.mesKm.mobility,
      0.55,
    )!
        .withValues(alpha: dark ? 0.03 : 0.04);

    return Stack(
      children: [
        Positioned.fill(
          child: ExcludeSemantics(
            child: IgnorePointer(
              child: RepaintBoundary(
                child: CustomPaint(
                  painter: _RoadPainter(ink: ink, variant: variant),
                ),
              ),
            ),
          ),
        ),
        child,
      ],
    );
  }
}

/// Route courbe douce + 2-3 arbres stylisés. Formes simples, aucune
/// voiture, aucun texte, aucun motif répété en wallpaper : une composition
/// verticale unique avec de grandes zones vides.
class _RoadPainter extends CustomPainter {
  const _RoadPainter({required this.ink, required this.variant});

  final Color ink;
  final RoadWatermarkVariant variant;

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

    final road = Paint()
      ..color = ink
      ..style = PaintingStyle.stroke
      ..strokeWidth = w * 0.085
      ..strokeCap = StrokeCap.round;

    final dash = Paint()
      ..color = ink
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round;

    // Route principale : une courbe en S très douce dans le tiers haut,
    // entrant par la droite et s'échappant par la gauche.
    final top = Path()
      ..moveTo(w * 1.02, h * 0.055)
      ..cubicTo(w * 0.72, h * 0.10, w * 0.62, h * 0.21, w * 0.34, h * 0.235)
      ..cubicTo(w * 0.16, h * 0.25, w * 0.06, h * 0.30, w * -0.02, h * 0.36);
    canvas.drawPath(top, road);
    _dashAlong(canvas, top, dash);

    _tree(canvas, Offset(w * 0.82, h * 0.195), w * 0.034);
    _tree(canvas, Offset(w * 0.16, h * 0.175), w * 0.026);

    if (variant == RoadWatermarkVariant.full) {
      // Seconde courbe, encore plus légère, dans le bas de page.
      final low = Paint()
        ..color = ink.withValues(alpha: ink.a * 0.7)
        ..style = PaintingStyle.stroke
        ..strokeWidth = w * 0.07
        ..strokeCap = StrokeCap.round;
      final bottom = Path()
        ..moveTo(w * -0.02, h * 0.78)
        ..cubicTo(w * 0.30, h * 0.74, w * 0.52, h * 0.86, w * 1.02, h * 0.82);
      canvas.drawPath(bottom, low);
      _tree(canvas, Offset(w * 0.68, h * 0.74), w * 0.028);
    }
  }

  /// Pointillés centraux : quelques traits espacés le long du chemin.
  void _dashAlong(Canvas canvas, Path path, Paint paint) {
    for (final metric in path.computeMetrics()) {
      var distance = metric.length * 0.08;
      while (distance < metric.length * 0.92) {
        final extract = metric.extractPath(distance, distance + 10);
        canvas.drawPath(extract, paint);
        distance += 34;
      }
    }
  }

  /// Arbre stylisé : un disque sur un petit tronc. Rien de réaliste.
  void _tree(Canvas canvas, Offset base, double radius) {
    final fill = Paint()..color = ink;
    canvas.drawLine(
      base,
      base.translate(0, -radius * 1.6),
      Paint()
        ..color = ink
        ..strokeWidth = 2
        ..strokeCap = StrokeCap.round,
    );
    canvas.drawCircle(base.translate(0, -radius * 2.2), radius, fill);
  }

  @override
  bool shouldRepaint(_RoadPainter oldDelegate) =>
      oldDelegate.ink != ink || oldDelegate.variant != variant;
}
