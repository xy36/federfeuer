import 'dart:math';

import 'package:flame/components.dart';
import 'package:flutter/material.dart';

import '../config.dart';
import '../federfeuer_game.dart';
import 'draw.dart';

/// Pseudozufall pro Index – gleiche Welt sieht bei jedem Besuch gleich aus.
double hash01(int i, int salt) {
  var x = (i * 374761393 + salt * 668265263) & 0x7fffffff;
  x = ((x ^ (x >> 13)) * 1274126177) & 0x7fffffff;
  return (x % 10007) / 10007;
}

/// Himmel, Sonne/Mond, Sterne und drei Parallax-Bergketten der aktuellen Welt.
class Backdrop extends Component with HasGameReference<FederfeuerGame> {
  Backdrop() : super(priority: -100);

  final _sky = Paint();
  final _star = Paint();
  double _skyTop = double.nan, _skyH = double.nan;
  Biome? _skyBiome;

  @override
  void render(Canvas c) {
    final g = game, b = g.biomeDef;
    final top = -g.offY - 30, h = g.viewH + 60, left = g.camX - 40, w = g.viewW + 80;
    if (top != _skyTop || h != _skyH || g.biome != _skyBiome) {
      _skyTop = top;
      _skyH = h;
      _skyBiome = g.biome;
      _sky.shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: b.sky,
        stops: const [0, 0.42, 0.72, 1],
      ).createShader(Rect.fromLTWH(0, top, 1, h));
    }
    c.drawRect(Rect.fromLTWH(left, top, w, h), _sky);

    if (b.stars) _stars(c, top, h);

    final sunX = g.camX + g.viewW * 0.7 - g.camX * 0.04;
    drawCircle(c, sunX, 200, 90, b.sun.withAlpha(0x40));
    drawCircle(c, sunX, 200, 64, b.sun.withAlpha(0xD9));

    final bottom = g.viewH - g.offY + 40;
    const params = [
      (0.15, 330.0, 80.0, 0.0035, 0.009, 1.0),
      (0.35, 390.0, 60.0, 0.006, 0.017, 2.0),
      (0.6, 430.0, 40.0, 0.011, 0.023, 3.0),
    ];
    for (var i = 0; i < 3; i++) {
      final (f, base, amp, f1, f2, seed) = params[i];
      _ridge(c, b, i, f, base + b.ridgeDrop, amp * b.ridgeAmp, f1, f2, seed, bottom);
    }
  }

  void _stars(Canvas c, double top, double h) {
    final g = game;
    final span = g.viewW + 40;
    for (var i = 0; i < 70; i++) {
      final sx = (hash01(i, 1) * span * 3 - g.camX * 0.02) % span;
      final sy = top + hash01(i, 2) * h * 0.55;
      final tw = 0.55 + 0.45 * sin(g.clock * (1 + hash01(i, 3) * 2) + i);
      _star.color = Color.fromRGBO(255, 255, 255, 0.8 * tw);
      c.drawCircle(Offset(g.camX - 20 + sx, sy), 0.8 + hash01(i, 4) * 1.2, _star);
    }
  }

  /// Dreieckswelle: 0 bei ganzen Zahlen, 1 dazwischen.
  static double _tri(double t) => 1 - (2 * (t - t.floorToDouble()) - 1).abs();

  void _ridge(Canvas c, BiomeDef b, int index, double f, double base, double amp, double f1, double f2,
      double seed, double bottom) {
    final g = game;
    final path = Path()..moveTo(g.camX - 30, bottom);
    for (double sx = -30; sx <= g.viewW + 44; sx += 10) {
      final wx = sx + g.camX * f;
      final double k;
      if (b.jagged) {
        // Überlagerte Dreieckswellen: gerade Flanken, spitze Gipfel.
        k = (_tri(wx * f1 / pi + seed) * 0.65 + _tri(wx * f2 / pi + seed * 2.3) * 0.35) * 1.6;
      } else {
        k = sin(wx * f1 + seed) * 0.6 + sin(wx * f2 + seed * 2.3) * 0.4 + 0.6;
      }
      path.lineTo(g.camX + sx, base - k * amp);
    }
    path
      ..lineTo(g.camX + g.viewW + 50, bottom)
      ..close();
    final col = b.ridges[index];
    c.drawPath(path, fillOf(col));

    if (index < b.snowCaps) {
      c.save();
      c.clipRect(Rect.fromLTRB(g.camX - 40, -2000, g.camX + g.viewW + 60, base - amp * 1.0));
      c.drawPath(path, fillOf(Color.lerp(col, Colors.white, 0.75)!));
      c.restore();
    }
  }
}

/// Boden, Grasbüschel, Fluss und Weltgrenzen.
class Ground extends Component with HasGameReference<FederfeuerGame> {
  Ground() : super(priority: -50);

  final _shimmer = Paint()
    ..strokeWidth = 2
    ..strokeCap = StrokeCap.round;

  @override
  void render(Canvas c) {
    final g = game, b = g.biomeDef;
    final x0 = g.camX - 60, x1 = g.camX + g.viewW + 60;
    final bottom = g.viewH - g.offY + 40;
    drawRect(c, x0, kGround, x1 - x0, 16, b.grass);
    drawRect(c, x0, kGround + 16, x1 - x0, 8, b.grassDark);
    drawRect(c, x0, kGround + 24, x1 - x0, bottom - kGround, b.soil);

    for (var i = (x0 / 37).floor(); i * 37 < x1; i++) {
      final h = 4 + (i * 7919).abs() % 6;
      drawRect(c, i * 37.0 + (i * 13).abs() % 17, kGround - h + 3, 3, h.toDouble(), b.tuft);
    }
    if (b.river) {
      _river(c, x0, x1);
    } else {
      for (var i = (x0 / 53).floor(); i * 53 < x1; i++) {
        drawOval(c, i * 53.0 + (i * 31).abs() % 23, kGround + 36 + (i * 17).abs() % 30, 5, 3, b.pebble);
      }
    }

    // Außerhalb der Welt abdunkeln, Pfosten mit Warnstreifen
    const dim = Color(0x8C0F081E);
    drawRect(c, -800, -800, 800, 2000, dim);
    drawRect(c, g.worldW, -800, 800, 2000, dim);
    for (final wx in [0.0, g.worldW]) {
      drawRect(c, wx - 5, kCeil - 10, 10, kGround - kCeil + 26, Palette.ink);
      for (double y = kCeil; y < kGround; y += 34) {
        drawRect(c, wx - 5, y, 10, 14, Palette.sun);
      }
    }
  }

  /// Fluss im Vordergrund unter der Grasnarbe, Glitzern treibt nach rechts.
  void _river(Canvas c, double x0, double x1) {
    const top = kGround + 32, h = 26.0;
    drawRect(c, x0, top - 3, x1 - x0, h + 6, const Color(0xFF3A5A5A));
    drawRect(c, x0, top, x1 - x0, h, const Color(0xFF2E5E8A));
    drawRect(c, x0, top, x1 - x0, 4, const Color(0xFF5A8AB8));
    final drift = game.clock * 24;
    for (var i = ((x0 - drift) / 47).floor(); i * 47 + drift < x1; i++) {
      final x = i * 47 + drift + hash01(i, 7) * 20;
      final y = top + 8 + hash01(i, 8) * (h - 12);
      _shimmer.color = Color.fromRGBO(200, 225, 255, 0.35 + 0.3 * hash01(i, 9));
      c.drawLine(Offset(x, y), Offset(x + 8 + hash01(i, 10) * 10, y), _shimmer);
    }
  }
}
