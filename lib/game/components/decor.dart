import 'dart:math';

import 'package:flame/components.dart';
import 'package:flutter/material.dart';

import '../config.dart';
import '../federfeuer_game.dart';
import 'draw.dart';
import 'scenery.dart';

/// Kulissen-Objekte der aktuellen Welt, die hinter der Spielfläche auf dem Boden stehen.
/// Gezeichnet wird nur der sichtbare Ausschnitt; Position und Art hängen am Index,
/// sodass die Welt bei jedem Besuch gleich aussieht.
class Decor extends Component with HasGameReference<FederfeuerGame> {
  Decor() : super(priority: -60);

  static final _line = Paint()
    ..strokeWidth = 2
    ..color = const Color(0xFF3A2A2A);

  @override
  void render(Canvas c) {
    final g = game;
    final spacing = switch (g.biome) {
      Biome.fields => 90.0,
      Biome.village => 170.0,
      Biome.forest => 70.0,
      Biome.mountains => 120.0,
      Biome.summit => 140.0,
    };
    final x0 = g.camX - 260, x1 = g.camX + g.viewW + 260;
    for (var i = (x0 / spacing).floor(); i * spacing < x1; i++) {
      final x = i * spacing + hash01(i, 11) * spacing * 0.5;
      final r = hash01(i, 12), v = hash01(i, 13);
      switch (g.biome) {
        case Biome.fields:
          if (r < 0.55) {
            _wheat(c, x, v);
          } else if (r < 0.7) {
            _hayBale(c, x, v);
          } else if (r < 0.9) {
            _fence(c, x, v);
          } else if (r < 0.95) {
            _scarecrow(c, x);
          }
        case Biome.village:
          if (r < 0.6) {
            _house(c, x, v, hash01(i, 14));
          } else if (r < 0.8) {
            _fence(c, x, v);
          } else if (r < 0.95) {
            _lamp(c, x);
          }
        case Biome.forest:
          if (r < 0.5) {
            _pine(c, x, 120 + v * 100, const Color(0xFF1E4A3A));
          } else if (r < 0.8) {
            _leafTree(c, x, v);
          } else {
            _bush(c, x, v, const Color(0xFF235A40));
          }
        case Biome.mountains:
          if (r < 0.4) {
            _boulder(c, x, v, const Color(0xFF5E5A72), 0);
          } else if (r < 0.7) {
            _pine(c, x, 70 + v * 60, const Color(0xFF2A4A48));
          } else if (r < 0.9) {
            _spire(c, x, v);
          }
        case Biome.summit:
          if (r < 0.5) {
            _snowMound(c, x, v);
          } else if (r < 0.7) {
            _boulder(c, x, v, const Color(0xFF6A6E8E), 1);
          }
      }
    }
    if (g.biome == Biome.summit) _summitCross(c, g.worldW / 2);
  }

  // ---------------- Felder ----------------

  void _wheat(Canvas c, double x, double v) {
    final w = 40 + v * 40;
    for (double sx = 0; sx < w; sx += 5) {
      final h = 18 + hash01(sx.round(), x.round()) * 10;
      drawRect(c, x + sx, kGround - h, 2, h, const Color(0xFFC9A340));
      drawOval(c, x + sx + 1, kGround - h - 3, 2.5, 4.5, const Color(0xFFE3C55A));
    }
  }

  void _hayBale(Canvas c, double x, double v) {
    final r = 16 + v * 8;
    drawCircle(c, x, kGround - r, r, const Color(0xFFD9B25A));
    drawCircle(c, x, kGround - r, r * 0.6, const Color(0xFFC49A45));
    drawCircle(c, x, kGround - r, r * 0.25, const Color(0xFFB08838));
  }

  void _fence(Canvas c, double x, double v) {
    final n = 3 + (v * 3).floor();
    const col = Color(0xFF6E4A3A);
    for (var k = 0; k < n; k++) {
      drawRect(c, x + k * 16, kGround - 26, 4, 26, col);
    }
    drawRect(c, x - 2, kGround - 21, n * 16.0, 3, col);
    drawRect(c, x - 2, kGround - 11, n * 16.0, 3, col);
  }

  void _scarecrow(Canvas c, double x) {
    drawRect(c, x - 2, kGround - 58, 4, 58, const Color(0xFF6E4A3A));
    drawRect(c, x - 18, kGround - 46, 36, 4, const Color(0xFF6E4A3A));
    drawRect(c, x - 10, kGround - 48, 20, 22, const Color(0xFF8A5A6A));
    drawCircle(c, x, kGround - 56, 7, const Color(0xFFE3C55A));
    drawTri(c, x - 11, kGround - 60, x + 11, kGround - 60, x, kGround - 72, const Color(0xFF4A3326));
  }

  // ---------------- Dorf ----------------

  void _house(Canvas c, double x, double v, double v2) {
    const walls = [Color(0xFF8A5A6A), Color(0xFF6E4A7A), Color(0xFF9A6A5A)];
    final w = 70 + v * 40, h = 55 + v2 * 35;
    final top = kGround - h;
    drawRect(c, x, top, w, h, walls[(v2 * 3).floor() % 3]);
    drawTri(c, x - 8, top, x + w + 8, top, x + w / 2, top - 30 - v * 12, const Color(0xFF3A2244));
    drawRect(c, x + w / 2 - 7, kGround - 22, 14, 22, Palette.ink);
    final lit = Palette.sun.withAlpha(0xCC);
    drawRect(c, x + 10, top + 12, 12, 12, lit);
    drawRect(c, x + w - 22, top + 12, 12, 12, v > 0.5 ? lit : const Color(0xFF3A2A4A));
    if (v2 > 0.5) drawRect(c, x + w * 0.7, top - 26, 8, 16, const Color(0xFF4A2A3A));
  }

  void _lamp(Canvas c, double x) {
    drawRect(c, x - 2, kGround - 60, 4, 60, Palette.ink);
    drawCircle(c, x, kGround - 62, 14, Palette.sun.withAlpha(0x40));
    drawCircle(c, x, kGround - 62, 5, Palette.sun);
  }

  // ---------------- Wald ----------------

  void _pine(Canvas c, double x, double h, Color col) {
    drawRect(c, x - 4, kGround - 18, 8, 18, const Color(0xFF3A2A2A));
    final light = Color.lerp(col, Colors.white, 0.08)!;
    for (var k = 0; k < 3; k++) {
      final bottom = kGround - 12 - k * h * 0.27;
      final w = h * (0.42 - k * 0.1);
      drawTri(c, x - w, bottom, x + w, bottom, x, bottom - h * 0.45, k.isEven ? col : light);
    }
  }

  void _leafTree(Canvas c, double x, double v) {
    final h = 90 + v * 70;
    drawRect(c, x - 5, kGround - h * 0.5, 10, h * 0.5, const Color(0xFF4A3232));
    drawCircle(c, x, kGround - h * 0.65, h * 0.28, const Color(0xFF235A40));
    drawCircle(c, x - h * 0.18, kGround - h * 0.55, h * 0.2, const Color(0xFF2A6A48));
    drawCircle(c, x + h * 0.18, kGround - h * 0.58, h * 0.21, const Color(0xFF1E4E38));
  }

  void _bush(Canvas c, double x, double v, Color col) {
    final r = 12 + v * 8;
    drawCircle(c, x, kGround - r * 0.6, r, col);
    drawCircle(c, x + r * 0.9, kGround - r * 0.5, r * 0.8, Color.lerp(col, Colors.black, 0.15)!);
  }

  // ---------------- Gebirge & Gipfel ----------------

  void _boulder(Canvas c, double x, double v, Color col, double snow) {
    final r = 14 + v * 18;
    drawOval(c, x, kGround - r * 0.55, r, r * 0.7, col);
    drawOval(c, x - r * 0.25, kGround - r * 0.8, r * 0.45, r * 0.3, Color.lerp(col, Colors.white, 0.15 + snow * 0.6)!);
  }

  void _spire(Canvas c, double x, double v) {
    final h = 60 + v * 70;
    drawTri(c, x - 22, kGround, x + 22, kGround, x + 4, kGround - h, const Color(0xFF4A4A66));
    drawTri(c, x - 4, kGround - h * 0.7, x + 10, kGround - h * 0.7, x + 4, kGround - h, const Color(0xFFD8DCF0));
  }

  void _snowMound(Canvas c, double x, double v) {
    final w = 30 + v * 40;
    drawOval(c, x, kGround - 4, w, 10 + v * 8, const Color(0xFFD8E2F8));
    drawOval(c, x - w * 0.3, kGround - 8 - v * 6, w * 0.35, 5, Colors.white);
  }

  /// Gipfelkreuz in der Mitte der Boss-Arena.
  void _summitCross(Canvas c, double x) {
    if (x < game.camX - 100 || x > game.camX + game.viewW + 100) return;
    drawRect(c, x - 4, kGround - 110, 8, 110, const Color(0xFF4A3232));
    drawRect(c, x - 26, kGround - 90, 52, 7, const Color(0xFF4A3232));
    for (var k = 0; k < 5; k++) {
      final fx = x + 10 + k * 18.0;
      c.drawLine(Offset(fx - 18, kGround - 100 + k * 6.0), Offset(fx, kGround - 94 + k * 6.0), _line);
      drawTri(c, fx - 12, kGround - 97 + k * 6.0, fx - 4, kGround - 95 + k * 6.0, fx - 8, kGround - 85 + k * 6.0,
          [Palette.coral, Palette.sun, Palette.mint, Palette.cyan, Palette.purple][k]);
    }
    drawCircle(c, x, kGround - 112, 3 + sin(game.clock * 2).abs(), Palette.sun);
  }
}
