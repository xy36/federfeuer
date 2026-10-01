import 'dart:math';

import 'package:flame/components.dart';
import 'package:flutter/material.dart';

import '../config.dart';
import '../federfeuer_game.dart';
import '../perf.dart';
import 'light.dart';
import 'scenery.dart';
import 'tris.dart';

/// Dunkle, unscharfe Silhouetten ganz vorn. Sie ziehen schneller vorbei als die
/// Spielfläche (Parallax > 1) und geben dem Bild Tiefe. Bleiben überwiegend
/// unterhalb der Bodenlinie, damit sie Gegner am Boden kaum verdecken.
class Foreground extends Component with HasGameReference<FederfeuerGame> {
  Foreground() : super(priority: 30);

  static const _parallax = 1.35;
  // Kein Weichzeichner: über die ganze Bildbreite ist er auf großen Bildschirmen zu teuer.
  final _paint = Paint();
  final _tris = TriBatch();
  final _rim = Paint()..blendMode = BlendMode.plus;

  FederfeuerGame get g => game;

  @override
  void render(Canvas c) {
    if (perfSkip.contains(RenderPart.foreground)) return;
    final b = g.biomeDef;
    final shift = g.camX * _parallax;
    final bottom = g.viewH - g.offY + 40;
    final path = _tris..clear();
    const spacing = 70.0;
    final x0 = shift - 200, x1 = shift + g.viewW + 200;
    for (var i = (x0 / spacing).floor(); i * spacing < x1; i++) {
      final wx = i * spacing + hash01(i, 91) * spacing;
      final x = g.camX + (wx - shift);
      final r = hash01(i, 92), v = hash01(i, 93);
      // Grundhügel unter der Bodenlinie
      path.addOval(Rect.fromCenter(center: Offset(x, bottom - 6), width: 150 + v * 120, height: (bottom - kGround) * 1.1 + v * 30));
      if (r > 0.72) {
        final h = 40 + v * 50;
        switch (g.biome) {
          case Biome.forest:
            _leaves(path, x, bottom - 10, h + 30, i);
          case Biome.fields:
          case Biome.village:
            _grass(path, x, bottom - 6, h, i);
          case Biome.mountains:
          case Biome.summit:
            path.addOval(Rect.fromCenter(center: Offset(x, bottom - h * 0.6), width: h * 1.6, height: h * 1.4));
        }
      }
    }
    // Hängende Ranken oben im Wald
    if (g.biome == Biome.forest) {
      final top = -g.offY - 10;
      for (var i = (x0 / 160).floor(); i * 160 < x1; i++) {
        if (hash01(i, 94) > 0.45) continue;
        final x = g.camX + (i * 160 + hash01(i, 95) * 120 - shift);
        final len = 40 + hash01(i, 96) * 70;
        final sway = sin(g.clock * 0.8 + i) * 4;
        addPoly(path, [Offset(x - 5, top), Offset(x + 5, top), Offset(x + sway + 1.5, top + len), Offset(x + sway - 1.5, top + len)]);
        path.addOval(Rect.fromCenter(center: Offset(x + sway, top + len), width: 14, height: 20));
      }
    }

    _rim.color = b.rim.withAlpha(45);
    c.save();
    c.translate(0, -2);
    path.draw(c, _rim);
    c.restore();
    _paint.color = Color.lerp(b.ground, Colors.black, 0.4)!;
    path.draw(c, _paint);
  }

  void _grass(TriBatch p, double x, double y, double h, int seed) {
    for (var k = 0; k < 9; k++) {
      final bx = x + (k - 4) * 6.0;
      final hh = h * (0.5 + hash01(seed * 13 + k, 97) * 0.6);
      final lean = (hash01(seed * 13 + k, 98) - 0.5) * 22 + sin(g.clock * 1.1 + bx * 0.03) * 3;
      addPoly(p, [Offset(bx - 3, y), Offset(bx + 3, y), Offset(bx + lean, y - hh)]);
    }
  }

  void _leaves(TriBatch p, double x, double y, double h, int seed) {
    for (var k = -2; k <= 2; k++) {
      final a = -pi / 2 + k * 0.42 + sin(g.clock * 0.9 + seed + k) * 0.04;
      final tip = Offset(x + cos(a) * h, y + sin(a) * h);
      final mid = Offset(x + cos(a) * h * 0.5, y + sin(a) * h * 0.5);
      final n = Offset(-sin(a), cos(a)) * (h * 0.16);
      addPoly(p, [Offset(x, y), mid + n, tip, mid - n]);
    }
  }
}

class _Mote {
  double x = 0, y = 0, vx = 0, vy = 0, size = 0, phase = 0;
}

/// Schwebende Lichtpartikel und Vignette im Bildschirmraum.
class Atmosphere extends Component with HasGameReference<FederfeuerGame> {
  Atmosphere({super.priority = 45});

  final _rng = Random(7);
  final _motes = <_Mote>[];
  double _lastCamX = 0;
  Biome? _biome;
  final _vignette = Paint();
  Size _vignetteSize = Size.zero;

  FederfeuerGame get g => game;

  void _reset(BiomeDef b) {
    _motes.clear();
    final s = g.size;
    for (var i = 0; i < b.motes; i++) {
      _motes.add(_Mote()
        ..x = _rng.nextDouble() * s.x
        ..y = _rng.nextDouble() * s.y
        ..vx = (_rng.nextDouble() - 0.5) * 14
        ..vy = -6 - _rng.nextDouble() * 16
        ..size = 1.5 + _rng.nextDouble() * 3.5
        ..phase = _rng.nextDouble() * 10);
    }
  }

  @override
  void update(double dt) {
    final b = g.biomeDef;
    if (_biome != g.biome || _motes.length != b.motes) {
      _biome = g.biome;
      _reset(b);
    }
    final s = g.size;
    // Kamerabewegung verschiebt die Partikel leicht (liegen zwischen Kamera und Szene)
    final dcam = (g.camX - _lastCamX) * g.zoom * 0.5;
    _lastCamX = g.camX;
    if (dcam.abs() > s.x) return;
    for (final m in _motes) {
      m.phase += dt;
      m.x += (m.vx + sin(m.phase * 0.7) * 8) * dt - dcam;
      m.y += m.vy * dt;
      if (m.y < -10) m.y = s.y + 10;
      if (m.x < -10) m.x += s.x + 20;
      if (m.x > s.x + 10) m.x -= s.x + 20;
    }
  }

  @override
  void render(Canvas c) {
    if (perfSkip.contains(RenderPart.atmosphere)) return;
    final b = g.biomeDef;
    final s = g.size;
    final transforms = <RSTransform>[], colors = <Color>[];
    for (final m in _motes) {
      final tw = 0.45 + 0.55 * (0.5 + 0.5 * sin(m.phase * 2.2));
      transforms.add(Glow.at(m.x, m.y, m.size * 3.2 * g.zoom.clamp(0.8, 1.6)));
      colors.add(b.glow.withAlpha((200 * tw).round()));
    }
    Glow.drawMany(c, transforms, colors);

    // Vignette
    final size = Size(s.x, s.y);
    if (size != _vignetteSize) {
      _vignetteSize = size;
      _vignette.shader = RadialGradient(
        radius: 0.85,
        colors: const [Color(0x00000000), Color(0x00000000), Color(0x8C02030C)],
        stops: const [0, 0.55, 1],
      ).createShader(Rect.fromCenter(center: Offset(s.x / 2, s.y / 2), width: s.x * 1.2, height: s.y * 1.6));
    }
    c.drawRect(Rect.fromLTWH(0, 0, s.x, s.y), _vignette);
  }
}
