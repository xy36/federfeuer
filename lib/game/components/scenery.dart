import 'dart:math';

import 'package:flame/components.dart';
import 'package:flutter/material.dart';

import '../config.dart';
import '../federfeuer_game.dart';
import 'draw.dart';

/// Himmel, Sonne und drei Parallax-Bergketten.
class Backdrop extends Component with HasGameReference<FederfeuerGame> {
  Backdrop() : super(priority: -100);

  final _sky = Paint();
  double _skyTop = double.nan, _skyH = double.nan;

  @override
  void render(Canvas c) {
    final g = game;
    final top = -g.offY - 30, h = g.viewH + 60, left = g.camX - 40, w = g.viewW + 80;
    if (top != _skyTop || h != _skyH) {
      _skyTop = top;
      _skyH = h;
      _sky.shader = const LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [Color(0xFF1D1540), Color(0xFF5E2A6B), Color(0xFFD4607A), Color(0xFFFFB86B)],
        stops: [0, 0.42, 0.72, 1],
      ).createShader(Rect.fromLTWH(0, top, 1, h));
    }
    c.drawRect(Rect.fromLTWH(left, top, w, h), _sky);

    final sunX = g.camX + g.viewW * 0.7 - g.camX * 0.04;
    drawCircle(c, sunX, 200, 90, const Color(0x40FFE2A0));
    drawCircle(c, sunX, 200, 64, const Color(0xD9FFE2A0));

    final bottom = g.viewH - g.offY + 40;
    _ridge(c, 0.15, const Color(0xFF51306F), 330, 80, 0.0035, 0.009, 1, bottom);
    _ridge(c, 0.35, const Color(0xFF3A2358), 390, 60, 0.006, 0.017, 2, bottom);
    _ridge(c, 0.6, const Color(0xFF2A1A42), 430, 40, 0.011, 0.023, 3, bottom);
  }

  void _ridge(Canvas c, double f, Color col, double base, double amp, double f1, double f2, double seed,
      double bottom) {
    final g = game;
    final path = Path()..moveTo(g.camX - 30, bottom);
    for (double sx = -30; sx <= g.viewW + 44; sx += 14) {
      final wx = sx + g.camX * f;
      path.lineTo(g.camX + sx, base - (sin(wx * f1 + seed) * 0.6 + sin(wx * f2 + seed * 2.3) * 0.4 + 0.6) * amp);
    }
    path
      ..lineTo(g.camX + g.viewW + 50, bottom)
      ..close();
    c.drawPath(path, fillOf(col));
  }
}

/// Boden, Grasbüschel und Arena-Grenzen.
class Ground extends Component with HasGameReference<FederfeuerGame> {
  Ground() : super(priority: -50);

  @override
  void render(Canvas c) {
    final g = game;
    final x0 = g.camX - 60, x1 = g.camX + g.viewW + 60;
    final bottom = g.viewH - g.offY + 40;
    drawRect(c, x0, kGround, x1 - x0, 16, const Color(0xFF3F8A5C));
    drawRect(c, x0, kGround + 16, x1 - x0, 8, const Color(0xFF2B6245));
    drawRect(c, x0, kGround + 24, x1 - x0, bottom - kGround, const Color(0xFF34202E));

    for (var i = (x0 / 37).floor(); i * 37 < x1; i++) {
      final h = 4 + (i * 7919).abs() % 6;
      drawRect(c, i * 37.0 + (i * 13).abs() % 17, kGround - h + 3, 3, h.toDouble(), const Color(0xFF57A872));
    }
    for (var i = (x0 / 53).floor(); i * 53 < x1; i++) {
      drawOval(c, i * 53.0 + (i * 31).abs() % 23, kGround + 36 + (i * 17).abs() % 30, 5, 3, const Color(0xFF4A2F40));
    }

    // Außerhalb der Arena abdunkeln, Pfosten mit Warnstreifen
    const dim = Color(0x8C0F081E);
    drawRect(c, -800, -800, 800, 2000, dim);
    drawRect(c, kWorldW, -800, 800, 2000, dim);
    for (final wx in [0.0, kWorldW]) {
      drawRect(c, wx - 5, kCeil - 10, 10, kGround - kCeil + 26, Palette.ink);
      for (double y = kCeil; y < kGround; y += 34) {
        drawRect(c, wx - 5, y, 10, 14, Palette.sun);
      }
    }
  }
}
