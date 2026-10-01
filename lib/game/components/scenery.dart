import 'dart:math';

import 'package:flame/components.dart';
import 'package:flutter/material.dart';

import '../config.dart';
import '../federfeuer_game.dart';
import '../perf.dart';
import 'draw.dart';
import 'light.dart';
import 'tris.dart';

/// Pseudozufall pro Index – gleiche Welt sieht bei jedem Besuch gleich aus.
double hash01(int i, int salt) {
  var x = (i * 374761393 + salt * 668265263) & 0x7fffffff;
  x = ((x ^ (x >> 13)) * 1274126177) & 0x7fffffff;
  return (x % 10007) / 10007;
}

/// Konvexes Polygon zu einer Silhouette hinzufügen.
void addPoly(TriBatch p, List<Offset> pts) => p.addPoly(pts);

/// Parallax-Ebenen von hinten nach vorn: Faktor, Grundlinie, Höhe, zwei Frequenzen.
const _layerParams = [
  (0.12, 300.0, 95.0, 0.0035, 0.009),
  (0.26, 345.0, 75.0, 0.006, 0.017),
  (0.45, 390.0, 55.0, 0.009, 0.02),
  (0.68, 432.0, 38.0, 0.013, 0.026),
];

/// Himmel, Lichtquelle mit Strahlen, Sterne/Polarlicht und vier Silhouetten-Ebenen mit Dunst.
class Backdrop extends Component with HasGameReference<FederfeuerGame> {
  Backdrop() : super(priority: -100);

  final _sky = Paint();
  final _fill = Paint();
  final _rim = Paint()..blendMode = BlendMode.plus;
  final _fog = Paint();
  final _aurora = Paint()..blendMode = BlendMode.plus;
  final _star = Paint();
  final _tris = TriBatch();
  String _skyKey = '';

  FederfeuerGame get g => game;

  @override
  void render(Canvas c) {
    if (perfSkip.contains(RenderPart.backdrop)) return;
    final b = g.biomeDef;
    final top = -g.offY - 30, h = g.viewH + 60, left = g.camX - 40, w = g.viewW + 80;
    final key = '${g.biome}|$top|$h';
    if (key != _skyKey) {
      _skyKey = key;
      _sky.shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: b.sky,
        stops: const [0, 0.45, 0.78, 1],
      ).createShader(Rect.fromLTWH(0, top, 1, h));
    }
    c.drawRect(Rect.fromLTWH(left, top, w, h), _sky);

    if (b.stars) _stars(c, top, h);
    if (b.aurora) _drawAurora(c, b, top);

    final lx = g.camX + g.viewW * b.lightX - g.camX * 0.03, ly = b.lightY;
    _drawLight(c, b, lx, ly);

    for (var i = 0; i < 4; i++) {
      final (f, base, amp, f1, f2) = _layerParams[i];
      // Jede Ebene endet knapp unter dem tiefsten Punkt der nächsten Ebene bzw. am Boden –
      // spart die mehrfache Überzeichnung der unteren Bildhälfte.
      final double bottom;
      if (i < 3) {
        final (_, nBase, nAmp, _, _) = _layerParams[i + 1];
        bottom = nBase + b.layerDrop + nAmp * b.layerAmp * 0.45 + 12;
      } else {
        bottom = kGround + 12;
      }
      _layer(c, b, i, f, base + b.layerDrop, amp * b.layerAmp, f1, f2, bottom);
      if (i < 3) _fogBand(c, b, base + b.layerDrop, amp * b.layerAmp, bottom, i);
      // Strahlen fallen durch den Mittelgrund; nur die vorderste Ebene liegt davor.
      if (i == 2 && b.shafts) _shafts(c, b, lx, ly);
    }
  }

  // ---------------- Himmel ----------------

  void _stars(Canvas c, double top, double h) {
    final span = g.viewW + 40;
    for (var i = 0; i < 90; i++) {
      final sx = (hash01(i, 1) * span * 3 - g.camX * 0.02) % span;
      final sy = top + hash01(i, 2) * h * 0.6;
      final tw = 0.5 + 0.5 * sin(g.clock * (0.8 + hash01(i, 3) * 2) + i);
      final r = 0.6 + hash01(i, 4) * 1.3;
      _star.color = Color.fromRGBO(235, 242, 255, 0.85 * tw);
      c.drawCircle(Offset(g.camX - 20 + sx, sy), r, _star);
      if (r > 1.6) Glow.draw(c, g.camX - 20 + sx, sy, r * 6, Color.fromRGBO(200, 220, 255, 0.35 * tw));
    }
  }

  void _drawAurora(Canvas c, BiomeDef b, double top) {
    const colors = [Color(0xFF6CFFB0), Color(0xFF62E6FF), Color(0xFFB48CFF)];
    for (var r = 0; r < 3; r++) {
      final baseY = top + 110 + r * 34;
      final path = Path();
      final pts = <Offset>[];
      for (double sx = -40; sx <= g.viewW + 40; sx += 16) {
        final wx = sx + g.camX * 0.05;
        final y = baseY + sin(wx * 0.004 + g.clock * 0.25 + r * 1.7) * 28 + sin(wx * 0.011 - g.clock * 0.4 + r) * 10;
        pts.add(Offset(g.camX + sx, y));
      }
      path.moveTo(pts.first.dx, pts.first.dy);
      for (final p in pts) {
        path.lineTo(p.dx, p.dy);
      }
      for (final p in pts.reversed) {
        path.lineTo(p.dx, p.dy - 110);
      }
      path.close();
      final col = colors[r];
      _aurora.shader = LinearGradient(
        begin: Alignment.bottomCenter,
        end: Alignment.topCenter,
        colors: [col.withAlpha(0), col.withAlpha(150), col.withAlpha(40), col.withAlpha(0)],
        stops: const [0, 0.12, 0.55, 1],
      ).createShader(Rect.fromLTWH(0, baseY - 150, 1, 190));
      c.drawPath(path, _aurora);
    }
  }

  void _drawLight(Canvas c, BiomeDef b, double x, double y) {
    final s = b.lightSize;
    Glow.draw(c, x, y, s * 9, b.light.withAlpha(70));
    Glow.draw(c, x, y, s * 4, b.light.withAlpha(110));
    if (b.moon) {
      drawCircle(c, x, y, s * 0.55, Color.lerp(b.light, Colors.white, 0.5)!);
      drawCircle(c, x - s * 0.14, y - s * 0.1, s * 0.13, b.light.withAlpha(90));
      drawCircle(c, x + s * 0.18, y + s * 0.12, s * 0.09, b.light.withAlpha(90));
    } else {
      Glow.draw(c, x, y, s * 1.6, Colors.white.withAlpha(200));
      drawCircle(c, x, y, s * 0.5, Color.lerp(b.light, Colors.white, 0.6)!);
    }
  }

  /// Lichtstrahlen, die von der Lichtquelle schräg nach unten fächern und leicht schwanken.
  void _shafts(Canvas c, BiomeDef b, double lx, double ly) {
    // Jeder Strahl lebt für sich: wandert langsam, atmet, verschwindet zeitweise ganz.
    const count = 8;
    final t = g.clock;
    final tr = <RSTransform>[], cols = <Color>[];
    for (var i = 0; i < count; i++) {
      final h1 = hash01(i, 21), h2 = hash01(i, 22), h3 = hash01(i, 23);
      final base = -0.62 + i * (1.24 / (count - 1)) + (h1 - 0.5) * 0.08;
      final a = base + sin(t * (0.05 + h2 * 0.05) + i * 1.7) * 0.06 + sin(t * 0.13 + i * 2.9) * 0.015;
      final len = (560 + h3 * 300) * (0.92 + 0.08 * sin(t * 0.21 + i));
      // Langsames Auf- und Abblenden (Zyklus ~20–40 s) mal schnelleres Atmen
      final cycle = 0.5 + 0.5 * sin(t * (0.16 + h1 * 0.12) + i * 4.1);
      final fade = cycle * cycle * (3 - 2 * cycle); // weich (smoothstep)
      final breathe = 0.75 + 0.25 * sin(t * (0.6 + h2 * 0.5) + i * 2.3);
      final alpha = (0.2 + 0.8 * fade) * breathe * (0.6 + 0.4 * h3) * b.shaftStrength;
      tr.add(Rays.at(lx, ly, a, len));
      cols.add(b.light.withAlpha((230 * alpha).round().clamp(0, 255)));
    }
    Rays.drawMany(c, tr, cols);
  }


  // ---------------- Ebenen ----------------

  double _terrain(BiomeDef b, double wx, double base, double amp, double f1, double f2) {
    final double k;
    if (b.style == LayerStyle.peaks) {
      k = (_tri(wx * f1 / pi) * 0.65 + _tri(wx * f2 / pi + 2.3) * 0.35) * 1.6;
    } else {
      k = sin(wx * f1) * 0.6 + sin(wx * f2 + 2.3) * 0.4 + 0.6;
    }
    return base - k * amp;
  }

  /// Dreieckswelle: 0 bei ganzen Zahlen, 1 dazwischen.
  static double _tri(double t) => 1 - (2 * (t - t.floorToDouble()) - 1).abs();

  void _layer(Canvas c, BiomeDef b, int i, double f, double base, double amp, double f1, double f2, double bottom) {
    final shift = g.camX * f; // Weltposition der Ebene am linken Bildrand
    final path = _tris..clear();
    path.addTerrain([
      for (double sx = -40; sx <= g.viewW + 48; sx += 8) Offset(g.camX + sx, _terrain(b, sx + shift, base, amp, f1, f2)),
    ], bottom);

    _props(path, b, i, shift, base, amp, f1, f2);

    // Lichtkante auf den vorderen Ebenen: Silhouette zur Lichtquelle versetzt,
    // die eigentliche Silhouette deckt sie bis auf die Außenkante wieder zu.
    if (i >= 2) {
      final dir = b.lightX >= 0.5 ? 1.0 : -1.0;
      _rim.color = b.rim.withAlpha(i == 3 ? 95 : 55);
      c.save();
      c.translate(dir * 1.5, -1.5);
      path.draw(c, _rim);
      c.restore();
    }

    final col = b.layers[i];
    _fill.color = col;
    path.draw(c, _fill);

    if (b.snow && i < (b.aurora ? 4 : 2)) _snow(c, b, col, shift, base, amp, f1, f2);

    // Warme Fenster in den Ruinen
    if (b.style == LayerStyle.ruins && i >= 1) _ruinLights(c, b, i, shift, base, amp, f1, f2);
  }

  /// Schnee folgt den Graten und wird zu den Gipfeln hin dicker (Bäume bleiben frei).
  void _snow(Canvas c, BiomeDef b, Color col, double shift, double base, double amp, double f1, double f2) {
    final line = base - amp * 0.85;
    final top = <Offset>[], under = <Offset>[];
    for (double sx = -40; sx <= g.viewW + 48; sx += 8) {
      final wx = sx + shift;
      final y = _terrain(b, wx, base, amp, f1, f2);
      final depth = y < line ? (line - y) * 0.5 + 3 + sin(wx * 0.21) * 2.5 : 0.0;
      top.add(Offset(g.camX + sx, y));
      under.add(Offset(g.camX + sx, y + depth));
    }
    final snow = _tris..clear();
    snow.addStrip(top, under);
    _fill.color = Color.lerp(col, Colors.white, 0.75)!;
    snow.draw(c, _fill);
  }

  /// Dunstband über dem Fuß einer Ebene – trennt die Tiefen voneinander.
  void _fogBand(Canvas c, BiomeDef b, double base, double amp, double bottom, int i) {
    final top = base - amp * 0.7;
    _fog.shader = LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: [b.fog.withAlpha(0), b.fog.withAlpha(i == 0 ? 120 : 80), b.fog.withAlpha(i == 0 ? 150 : 90)],
      stops: const [0, 0.6, 1],
    ).createShader(Rect.fromLTRB(0, top, 1, base + 70));
    c.drawRect(Rect.fromLTRB(g.camX - 40, top, g.camX + g.viewW + 60, min(bottom, base + 70)), _fog);
  }

  /// Silhouetten-Objekte einer Ebene (Bäume, Ruinen), gleiche Farbe wie die Ebene.
  void _props(TriBatch path, BiomeDef b, int i, double shift, double base, double amp, double f1, double f2) {
    final scale = const [0.45, 0.6, 0.8, 1.0][i];
    final spacing = switch (b.style) {
      LayerStyle.forest => const [22.0, 34.0, 60.0, 150.0][i],
      LayerStyle.hills => const [110.0, 150.0, 210.0, 300.0][i],
      LayerStyle.ruins => const [70.0, 95.0, 130.0, 190.0][i],
      LayerStyle.peaks => const [0.0, 0.0, 120.0, 90.0][i],
    };
    if (spacing == 0) return;
    final x0 = shift - 120, x1 = shift + g.viewW + 120;
    for (var k = (x0 / spacing).floor(); k * spacing < x1; k++) {
      final wx = k * spacing + hash01(k, 31 + i) * spacing * 0.6;
      final r = hash01(k, 41 + i), v = hash01(k, 51 + i);
      final sx = g.camX + (wx - shift);
      final y = _terrain(b, wx, base, amp, f1, f2) + 6;
      switch (b.style) {
        case LayerStyle.forest:
          if (i == 3) {
            if (r < 0.7) _giantTrunk(path, sx, y, v);
          } else if (r < 0.55) {
            _pine(path, sx, y, (70 + v * 90) * scale * 1.6);
          } else {
            _roundTree(path, sx, y, (60 + v * 60) * scale * 1.5);
          }
        case LayerStyle.hills:
          if (r < 0.4) _roundTree(path, sx, y, (50 + v * 50) * scale * 1.3);
          if (r > 0.9 && i == 1) _windmill(path, sx, y, 70 * scale * 1.6);
        case LayerStyle.ruins:
          if (r < 0.45) {
            _ruinHouse(path, sx, y, scale, v);
          } else if (r < 0.62) {
            _tower(path, sx, y, scale, v);
          } else if (r < 0.8) {
            _roundTree(path, sx, y, (40 + v * 40) * scale * 1.3);
          }
        case LayerStyle.peaks:
          if (r < 0.5) _pine(path, sx, y, (30 + v * 40) * scale * 1.4);
      }
    }
  }

  void _pine(TriBatch p, double x, double y, double h) {
    p.addRect(Rect.fromLTWH(x - h * 0.03, y - h * 0.25, h * 0.06, h * 0.25));
    for (var k = 0; k < 3; k++) {
      final by = y - h * 0.15 - k * h * 0.25, w = h * (0.28 - k * 0.07);
      addPoly(p, [Offset(x - w, by), Offset(x + w, by), Offset(x, by - h * 0.42)]);
    }
  }

  void _roundTree(TriBatch p, double x, double y, double h) {
    p.addRect(Rect.fromLTWH(x - h * 0.04, y - h * 0.55, h * 0.08, h * 0.55));
    p.addOval(Rect.fromCircle(center: Offset(x, y - h * 0.72), radius: h * 0.3));
    p.addOval(Rect.fromCircle(center: Offset(x - h * 0.22, y - h * 0.6), radius: h * 0.22));
    p.addOval(Rect.fromCircle(center: Offset(x + h * 0.24, y - h * 0.62), radius: h * 0.24));
  }

  /// Riesige Stämme ganz vorn im Wald, die oben aus dem Bild ragen.
  void _giantTrunk(TriBatch p, double x, double y, double v) {
    final w = 26 + v * 26;
    final top = -g.offY - 40;
    addPoly(p, [
      Offset(x - w * 1.8, y),
      Offset(x - w * 0.55, y - 40),
      Offset(x - w * 0.45, top),
      Offset(x + w * 0.45, top),
      Offset(x + w * 0.6, y - 50),
      Offset(x + w * 1.6, y),
    ]);
    // Ast
    if (v > 0.4) {
      final by = y - 180 - v * 80;
      addPoly(p, [Offset(x, by), Offset(x + 70 + v * 40, by - 50), Offset(x + 76 + v * 40, by - 42), Offset(x, by + 14)]);
    }
  }

  void _windmill(TriBatch p, double x, double y, double h) {
    addPoly(p, [Offset(x - h * 0.16, y), Offset(x + h * 0.16, y), Offset(x + h * 0.08, y - h), Offset(x - h * 0.08, y - h)]);
    final hub = Offset(x, y - h);
    final a = g.clock * 0.4;
    for (var k = 0; k < 4; k++) {
      final ang = a + k * pi / 2;
      final d = Offset(cos(ang), sin(ang)), n = Offset(-d.dy, d.dx);
      addPoly(p, [
        hub + n * 2,
        hub + d * h * 0.7 + n * 2,
        hub + d * h * 0.7 + n * 9,
        hub + d * h * 0.2 + n * 9,
      ]);
    }
  }

  void _ruinHouse(TriBatch p, double x, double y, double s, double v) {
    final w = (60 + v * 40) * s * 1.4, h = (50 + v * 40) * s * 1.4;
    p.addRect(Rect.fromLTWH(x, y - h, w, h));
    // Dach, bei manchen eingestürzt
    if (v > 0.35) {
      addPoly(p, [Offset(x - 6 * s, y - h), Offset(x + w + 6 * s, y - h), Offset(x + w * 0.5, y - h - w * 0.45)]);
    } else {
      addPoly(p, [Offset(x - 4 * s, y - h), Offset(x + w * 0.45, y - h), Offset(x + w * 0.2, y - h - w * 0.3)]);
    }
    if (v > 0.6) p.addRect(Rect.fromLTWH(x + w * 0.7, y - h - w * 0.5, 8 * s, w * 0.3));
  }

  void _tower(TriBatch p, double x, double y, double s, double v) {
    final w = (26 + v * 12) * s * 1.4, h = (110 + v * 70) * s * 1.4;
    p.addRect(Rect.fromLTWH(x, y - h, w, h));
    addPoly(p, [Offset(x - 5 * s, y - h), Offset(x + w + 5 * s, y - h), Offset(x + w / 2, y - h - w * 1.2)]);
  }

  void _ruinLights(Canvas c, BiomeDef b, int i, double shift, double base, double amp, double f1, double f2) {
    const spacing = [0.0, 95.0, 130.0, 190.0];
    final s = const [0.45, 0.6, 0.8, 1.0][i];
    final x0 = shift - 120, x1 = shift + g.viewW + 120;
    for (var k = (x0 / spacing[i]).floor(); k * spacing[i] < x1; k++) {
      final r = hash01(k, 41 + i), v = hash01(k, 51 + i);
      if (r >= 0.62 || hash01(k, 61 + i) > 0.55) continue;
      final wx = k * spacing[i] + hash01(k, 31 + i) * spacing[i] * 0.6;
      final sx = g.camX + (wx - shift);
      final y = _terrain(b, wx, base, amp, f1, f2) + 6;
      final double lx, ly;
      if (r < 0.45) {
        final w = (60 + v * 40) * s * 1.4, h = (50 + v * 40) * s * 1.4;
        lx = sx + w * 0.3;
        ly = y - h * 0.55;
      } else {
        final w = (26 + v * 12) * s * 1.4, h = (110 + v * 70) * s * 1.4;
        lx = sx + w / 2;
        ly = y - h * 0.75;
      }
      final flicker = 0.8 + 0.2 * sin(g.clock * 6 + k * 3.1);
      drawRect(c, lx - 3 * s, ly - 4 * s, 6 * s, 8 * s, b.glow.withAlpha((200 * flicker).round()));
      Glow.draw(c, lx, ly, 34 * s, b.glow.withAlpha((110 * flicker).round()));
    }
  }
}

/// Dunkler Boden mit leuchtender Kante, Gras-Silhouetten, Leuchtpflanzen,
/// Fluss (Wald) und leuchtenden Weltgrenzen.
class Ground extends Component with HasGameReference<FederfeuerGame> {
  Ground() : super(priority: -50);

  final _fill = Paint();
  final _rim = Paint()
    ..style = PaintingStyle.stroke
    ..strokeWidth = 2
    ..blendMode = BlendMode.plus;
  final _rimGlow = Paint()..blendMode = BlendMode.plus;
  final _line = Paint()
    ..strokeCap = StrokeCap.round
    ..blendMode = BlendMode.plus;
  final _beam = Paint()..blendMode = BlendMode.plus;
  final _tris = TriBatch();

  FederfeuerGame get g => game;

  /// Leicht unebene Oberkante (nur optisch; die Spielfläche endet bei kGround).
  static double surface(double x) => kGround + 3 + sin(x * 0.045) * 2 + sin(x * 0.013 + 1) * 2.5;

  @override
  void render(Canvas c) {
    if (perfSkip.contains(RenderPart.ground)) return;
    final b = g.biomeDef;
    final x0 = g.camX - 60, x1 = g.camX + g.viewW + 60;
    final bottom = g.viewH - g.offY + 40;

    final edge = Path()..moveTo(x0, surface(x0));
    for (var x = x0; x <= x1; x += 6) {
      edge.lineTo(x, surface(x));
    }
    final body = _tris..clear();
    body.addTerrain([for (var x = x0; x <= x1 + 6; x += 6) Offset(x, surface(x))], kGround + 12);

    // Gras bzw. Schneewehen als Silhouette auf der Kante
    final tufts = body;
    for (var i = (x0 / 7).floor(); i * 7 < x1; i++) {
      final x = i * 7.0 + hash01(i, 5) * 4;
      final y = surface(x);
      if (b.snow) {
        if (i % 9 == 0) tufts.addOval(Rect.fromCenter(center: Offset(x, y), width: 40 + hash01(i, 6) * 40, height: 10 + hash01(i, 7) * 8));
      } else {
        final hgt = 5 + hash01(i, 6) * 12;
        final lean = (hash01(i, 7) - 0.5) * 6;
        addPoly(tufts, [Offset(x - 2, y + 2), Offset(x + 2, y + 2), Offset(x + lean, y - hgt)]);
      }
    }
    // Einfarbige Silhouette (drawVertices), darunter der Verlauf ins Dunkle als Rechteck
    final top = Color.lerp(b.ground, b.layers[3], 0.35)!;
    _fill
      ..shader = null
      ..color = top;
    body.draw(c, _fill);
    _fill.shader = LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: [top, b.ground],
    ).createShader(Rect.fromLTRB(0, kGround + 8, 1, kGround + 60));
    c.drawRect(Rect.fromLTRB(x0, kGround + 8, x1, bottom), _fill);
    _fill.shader = null;

    // Leuchtende Kante
    // Weiches Leuchtband über der Kante (Verlauf statt Weichzeichner)
    _rimGlow.shader = LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: [b.rim.withAlpha(0), b.rim.withAlpha(40), b.rim.withAlpha(0)],
      stops: const [0, 0.7, 1],
    ).createShader(const Rect.fromLTRB(0, kGround - 16, 1, kGround + 10));
    c.drawRect(Rect.fromLTRB(x0, kGround - 16, x1, kGround + 10), _rimGlow);
    _rim.color = b.rim.withAlpha(150);
    c.drawPath(edge, _rim);

    _flora(c, b, x0, x1);
    if (b.river) _river(c, b, x0, x1);
    _bounds(c, b);
  }

  /// Leuchtpflanzen: Pilze im Wald, Blüten auf den Feldern, Glut im Dorf, Kristalle im Gebirge.
  void _flora(Canvas c, BiomeDef b, double x0, double x1) {
    for (var i = (x0 / 55).floor(); i * 55 < x1; i++) {
      if (hash01(i, 71) > 0.42) continue;
      final x = i * 55.0 + hash01(i, 72) * 40;
      final y = surface(x);
      final v = hash01(i, 73);
      final pulse = 0.75 + 0.25 * sin(g.clock * (1.5 + v) + i);
      final glow = b.glow.withAlpha((170 * pulse).round());
      switch (g.biome) {
        case Biome.forest:
          // Pilz mit leuchtendem Hut
          final h = 8 + v * 10;
          drawRect(c, x - 1.5, y - h, 3, h, b.ground);
          c.drawArc(Rect.fromCenter(center: Offset(x, y - h), width: 12 + v * 8, height: 10 + v * 6), pi, pi, true,
              fillOf(Color.lerp(b.glow, Colors.white, 0.3)!.withAlpha((230 * pulse).round())));
          Glow.draw(c, x, y - h, 26 + v * 16, glow);
        case Biome.fields:
          final h = 10 + v * 14;
          drawRect(c, x - 1, y - h, 2, h, b.ground);
          drawCircle(c, x, y - h, 2.4, Colors.white.withAlpha((220 * pulse).round()));
          Glow.draw(c, x, y - h, 16 + v * 10, glow);
        case Biome.village:
          Glow.draw(c, x, y - 2, 14 + v * 10, b.glow.withAlpha((120 * pulse).round()));
          drawCircle(c, x, y - 2, 1.8, Colors.white.withAlpha((200 * pulse).round()));
        case Biome.mountains:
        case Biome.summit:
          final h = 6 + v * 8;
          drawTri(c, x - 3, y, x + 3, y, x + 0.5, y - h, Color.lerp(b.glow, Colors.white, 0.4)!.withAlpha((220 * pulse).round()));
          Glow.draw(c, x, y - h * 0.5, 18 + v * 10, b.glow.withAlpha((110 * pulse).round()));
      }
    }
  }

  /// Leuchtender Fluss unter der Grasnarbe; Glitzern treibt nach rechts.
  void _river(Canvas c, BiomeDef b, double x0, double x1) {
    const top = kGround + 30, h = 30.0;
    c.drawRect(
      Rect.fromLTRB(x0, top, x1, top + h),
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [b.rim.withAlpha(110), const Color(0xFF0B3550), const Color(0xFF051A2A)],
          stops: const [0, 0.35, 1],
        ).createShader(const Rect.fromLTWH(0, top, 1, h)),
    );
    final drift = g.clock * 26;
    for (var i = ((x0 - drift) / 41).floor(); i * 41 + drift < x1; i++) {
      final x = i * 41 + drift + hash01(i, 8) * 20;
      final y = top + 6 + hash01(i, 9) * (h - 10);
      _line
        ..strokeWidth = 1.6
        ..color = b.rim.withAlpha((60 + 90 * hash01(i, 10)).round());
      c.drawLine(Offset(x, y), Offset(x + 8 + hash01(i, 11) * 14, y), _line);
    }
  }

  /// Außerhalb der Welt abdunkeln, an den Rändern leuchtende Lichtvorhänge.
  void _bounds(Canvas c, BiomeDef b) {
    const dim = Color(0xA6050310);
    drawRect(c, -800, -800, 800, 2000, dim);
    drawRect(c, g.worldW, -800, 800, 2000, dim);
    for (final wx in [0.0, g.worldW]) {
      if (wx < g.camX - 80 || wx > g.camX + g.viewW + 80) continue;
      _beam.shader = LinearGradient(
        colors: [b.rim.withAlpha(0), b.rim.withAlpha(90), b.rim.withAlpha(0)],
      ).createShader(Rect.fromLTWH(wx - 30, 0, 60, 1));
      c.drawRect(Rect.fromLTRB(wx - 30, kCeil - 20, wx + 30, kGround + 10), _beam);
      _line
        ..strokeWidth = 2
        ..color = b.rim.withAlpha(180);
      c.drawLine(Offset(wx, kCeil - 20), Offset(wx, kGround + 4), _line);
    }
  }
}
