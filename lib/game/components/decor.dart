import 'dart:math';

import 'package:flame/components.dart';
import 'package:flutter/material.dart';

import '../config.dart';
import '../federfeuer_game.dart';
import '../perf.dart';
import 'light.dart';
import 'scenery.dart';
import 'tris.dart';

/// Kulissen-Silhouetten, die hinter der Spielfläche auf dem Boden stehen.
/// Jede Silhouette bekommt eine Lichtkante auf der Seite der Lichtquelle.
/// Gezeichnet wird nur der sichtbare Ausschnitt; Art und Position hängen am Index.
class Decor extends Component with HasGameReference<FederfeuerGame> {
  Decor() : super(priority: -60);

  final _shape = Paint();
  final _tris = TriBatch();
  final _edge = Paint()..blendMode = BlendMode.plus;

  FederfeuerGame get g => game;

  @override
  void render(Canvas c) {
    if (perfSkip.contains(RenderPart.decor)) return;
    final b = g.biomeDef;
    final spacing = switch (g.biome) {
      Biome.fields => 95.0,
      Biome.village => 180.0,
      Biome.forest => 75.0,
      Biome.mountains => 120.0,
      Biome.summit => 150.0,
    };
    final path = _tris..clear();
    final lights = <(double, double, double)>[]; // x, y, Radius
    final x0 = g.camX - 260, x1 = g.camX + g.viewW + 260;
    for (var i = (x0 / spacing).floor(); i * spacing < x1; i++) {
      final x = i * spacing + hash01(i, 11) * spacing * 0.5;
      final r = hash01(i, 12), v = hash01(i, 13);
      final y = Ground.surface(x) + 2;
      switch (g.biome) {
        case Biome.fields:
          if (r < 0.5) {
            _wheat(path, x, y, v);
          } else if (r < 0.68) {
            _fence(path, x, y, v);
          } else if (r < 0.76) {
            _scarecrow(path, x, y);
          } else if (r < 0.9) {
            _tree(path, x, y, 110 + v * 60);
          }
        case Biome.village:
          if (r < 0.55) {
            _ruin(path, x, y, v, hash01(i, 14), lights);
          } else if (r < 0.8) {
            _lantern(path, x, y, lights);
          } else if (r < 0.95) {
            _fence(path, x, y, v);
          }
        case Biome.forest:
          if (r < 0.35) {
            _fern(path, x, y, 26 + v * 26);
          } else if (r < 0.55) {
            _trunk(path, x, y, v);
          } else if (r < 0.85) {
            _bigMushroom(path, x, y, v, lights);
          }
        case Biome.mountains:
          if (r < 0.4) {
            _boulder(path, x, y, v);
          } else if (r < 0.75) {
            _pine(path, x, y, 70 + v * 60);
          }
        case Biome.summit:
          if (r < 0.45) _boulder(path, x, y, v);
      }
    }
    if (g.biome == Biome.summit) _summitCross(path, g.worldW / 2, Ground.surface(g.worldW / 2) + 2, lights);

    // Lichtkante: Silhouette zur Lichtquelle hin versetzt in Kantenfarbe, darüber die Silhouette.
    final dir = b.lightX >= 0.5 ? 1.0 : -1.0;
    _edge.color = b.rim.withAlpha(120);
    c.save();
    c.translate(dir * 1.8, -1.6);
    path.draw(c, _edge);
    c.restore();
    _shape.color = Color.lerp(b.layers[3], b.ground, 0.55)!;
    path.draw(c, _shape);

    for (final (x, y, r) in lights) {
      final flicker = 0.85 + 0.15 * sin(g.clock * 7 + x);
      Glow.draw(c, x, y, r, b.glow.withAlpha((170 * flicker).round()));
      c.drawCircle(Offset(x, y), r * 0.09, Paint()..color = Colors.white.withAlpha((230 * flicker).round()));
    }
  }

  // ---------------- Felder ----------------

  void _wheat(TriBatch p, double x, double y, double v) {
    final w = 36 + v * 44;
    for (double sx = 0; sx < w; sx += 4.5) {
      final h = 20 + hash01(sx.round(), x.round()) * 14;
      final lean = sin(g.clock * 1.4 + (x + sx) * 0.05) * 2.5;
      addPoly(p, [Offset(x + sx - 0.8, y), Offset(x + sx + 0.8, y), Offset(x + sx + lean + 0.6, y - h), Offset(x + sx + lean - 0.6, y - h)]);
      p.addOval(Rect.fromCenter(center: Offset(x + sx + lean, y - h - 3), width: 3.6, height: 8));
    }
  }

  void _fence(TriBatch p, double x, double y, double v) {
    final n = 3 + (v * 3).floor();
    for (var k = 0; k < n; k++) {
      p.addRect(Rect.fromLTWH(x + k * 18, y - 28 + (k.isOdd ? 3 : 0), 4, 28));
    }
    p.addRect(Rect.fromLTWH(x - 3, y - 22, n * 18.0, 3));
    p.addRect(Rect.fromLTWH(x - 3, y - 12, n * 18.0, 3));
  }

  void _scarecrow(TriBatch p, double x, double y) {
    p.addRect(Rect.fromLTWH(x - 2, y - 62, 4, 62));
    p.addRect(Rect.fromLTWH(x - 20, y - 48, 40, 4));
    addPoly(p, [Offset(x - 11, y - 50), Offset(x + 11, y - 50), Offset(x + 14, y - 24), Offset(x - 14, y - 24)]);
    p.addOval(Rect.fromCircle(center: Offset(x, y - 60), radius: 7));
    addPoly(p, [Offset(x - 13, y - 63), Offset(x + 13, y - 63), Offset(x + 2, y - 78)]);
  }

  void _tree(TriBatch p, double x, double y, double h) {
    addPoly(p, [Offset(x - 9, y), Offset(x + 9, y), Offset(x + 4, y - h * 0.6), Offset(x - 4, y - h * 0.6)]);
    for (final (dx, dy, r) in [(0.0, 0.8, 0.28), (-0.24, 0.66, 0.22), (0.26, 0.68, 0.23), (0.05, 0.58, 0.2)]) {
      p.addOval(Rect.fromCircle(center: Offset(x + dx * h, y - dy * h), radius: r * h));
    }
  }

  // ---------------- Dorf ----------------

  void _ruin(TriBatch p, double x, double y, double v, double v2, List<(double, double, double)> lights) {
    final w = 80 + v * 50, h = 60 + v2 * 45;
    final top = y - h;
    // Mauer mit ausgebrochener Ecke
    addPoly(p, [
      Offset(x, y),
      Offset(x, top),
      Offset(x + w * 0.55, top),
      Offset(x + w * 0.7, top + h * 0.25),
      Offset(x + w, top + h * 0.3),
      Offset(x + w, y),
    ]);
    if (v2 > 0.4) addPoly(p, [Offset(x - 8, top), Offset(x + w * 0.58, top), Offset(x + w * 0.2, top - 34 - v * 10)]);
    // Fensterbogen, manchmal erleuchtet
    final wx = x + w * 0.28, wy = top + h * 0.35;
    if (v > 0.35) lights.add((wx, wy, 38));
  }

  void _lantern(TriBatch p, double x, double y, List<(double, double, double)> lights) {
    p.addRect(Rect.fromLTWH(x - 2, y - 70, 4, 70));
    p.addRect(Rect.fromLTWH(x - 2, y - 70, 18, 3));
    p.addRect(Rect.fromLTWH(x + 12, y - 67, 2, 8));
    lights.add((x + 13, y - 55, 46));
  }

  // ---------------- Wald ----------------

  void _fern(TriBatch p, double x, double y, double s) {
    for (var k = -3; k <= 3; k++) {
      final a = -pi / 2 + k * 0.32 + sin(g.clock * 1.2 + x * 0.02 + k) * 0.04;
      final tip = Offset(x + cos(a) * s * 1.6, y + sin(a) * s * (1.2 - k.abs() * 0.12));
      final mid = Offset(x + cos(a) * s * 0.8 + k * 2, y + sin(a) * s * 0.9);
      final n = Offset(-sin(a), cos(a)) * (s * 0.12);
      addPoly(p, [Offset(x, y), mid + n, tip, mid - n]);
    }
  }

  void _trunk(TriBatch p, double x, double y, double v) {
    final w = 14 + v * 14;
    final top = -g.offY - 40;
    addPoly(p, [
      Offset(x - w * 1.6, y),
      Offset(x - w * 0.5, y - 26),
      Offset(x - w * 0.42, top),
      Offset(x + w * 0.42, top),
      Offset(x + w * 0.55, y - 30),
      Offset(x + w * 1.4, y),
    ]);
  }

  void _bigMushroom(TriBatch p, double x, double y, double v, List<(double, double, double)> lights) {
    final h = 14 + v * 18, cw = 36 + v * 26;
    addPoly(p, [Offset(x - 7, y), Offset(x + 7, y), Offset(x + 5, y - h), Offset(x - 5, y - h)]);
    p.addArc(Rect.fromCenter(center: Offset(x, y - h + 2), width: cw, height: cw * 0.75), pi, pi);
    p.addOval(Rect.fromCenter(center: Offset(x, y - h + 2), width: cw, height: 7));
    // Leuchtpunkte auf dem Hut
    lights.add((x - cw * 0.18, y - h - cw * 0.12, 16 + v * 8));
    lights.add((x + cw * 0.14, y - h - cw * 0.2, 13 + v * 6));
  }

  // ---------------- Gebirge & Gipfel ----------------

  void _boulder(TriBatch p, double x, double y, double v) {
    final r = 16 + v * 20;
    p.addOval(Rect.fromCenter(center: Offset(x, y - r * 0.45), width: r * 2.2, height: r * 1.3));
    p.addOval(Rect.fromCenter(center: Offset(x + r * 0.8, y - r * 0.25), width: r * 1.2, height: r * 0.8));
  }

  void _pine(TriBatch p, double x, double y, double h) {
    p.addRect(Rect.fromLTWH(x - 3, y - h * 0.2, 6, h * 0.2));
    for (var k = 0; k < 3; k++) {
      final by = y - h * 0.12 - k * h * 0.25, w = h * (0.3 - k * 0.07);
      addPoly(p, [Offset(x - w, by), Offset(x + w, by), Offset(x, by - h * 0.42)]);
    }
  }

  /// Gipfelkreuz in der Mitte der Boss-Arena, Gebetsfahnen glimmen.
  void _summitCross(TriBatch p, double x, double y, List<(double, double, double)> lights) {
    p.addRect(Rect.fromLTWH(x - 4, y - 120, 8, 120));
    p.addRect(Rect.fromLTWH(x - 28, y - 98, 56, 7));
    for (var k = 0; k < 5; k++) {
      final fx = x + 16 + k * 18.0, fy = y - 104 + k * 6.0 + sin(g.clock * 3 + k) * 2;
      addPoly(p, [Offset(fx - 6, fy), Offset(fx + 6, fy), Offset(fx, fy + 11)]);
      if (k.isEven) lights.add((fx, fy + 4, 16));
    }
    lights.add((x, y - 124, 40));
  }
}
