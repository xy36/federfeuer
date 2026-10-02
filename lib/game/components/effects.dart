import 'dart:math';

import 'package:flame/components.dart';
import 'package:flutter/material.dart';

import '../config.dart';
import '../federfeuer_game.dart';
import '../perf.dart';
import 'draw.dart';
import 'light.dart';
import 'transient.dart';

class _Spark {
  _Spark(this.x, this.y, this.vx, this.vy, this.life, this.r) : maxLife = life;
  double x, y, vx, vy, life;
  final double maxLife, r;
}

/// Partikelexplosion – eine Komponente pro Burst statt pro Partikel.
class Burst extends Component with Transient {
  Burst(Vector2 at, this.color, int n, double speed, Random rng) : super(priority: 20) {
    for (var i = 0; i < n; i++) {
      final a = rng.nextDouble() * pi * 2, v = (0.3 + rng.nextDouble() * 0.7) * speed;
      _sparks.add(_Spark(at.x, at.y, cos(a) * v, sin(a) * v, 0.3 + rng.nextDouble() * 0.3, 2 + rng.nextDouble() * 2));
    }
  }

  final Color color;
  final _sparks = <_Spark>[];

  @override
  void update(double dt) {
    if (dt == 0) return;
    var alive = false;
    for (final s in _sparks) {
      if (s.life <= 0) continue;
      s.x += s.vx * dt;
      s.y += s.vy * dt;
      s.vy += 200 * dt;
      s.life -= dt;
      if (s.life > 0) alive = true;
    }
    if (!alive) removeFromParent();
  }

  @override
  void render(Canvas c) {
    if (perfSkip.contains(RenderPart.effects)) return;
    // Leuchtende Funken, additiv in einem Aufruf
    final transforms = <RSTransform>[], colors = <Color>[];
    for (final s in _sparks) {
      if (s.life <= 0) continue;
      final k = clampD(s.life / 0.6, 0, 1);
      transforms.add(Glow.at(s.x, s.y, s.r * 4));
      colors.add(color.withAlpha((255 * k).round()));
    }
    Glow.drawMany(c, transforms, colors);
  }
}

class Ring extends PositionComponent with Transient {
  Ring(Vector2 pos, this.radius, {this.color = const Color(0xFFFF9F1C)}) : super(position: pos, priority: 19);
  final double radius;
  final Color color;
  double life = 0.25;
  final _paint = Paint()
    ..style = PaintingStyle.stroke
    ..blendMode = BlendMode.plus;

  @override
  void update(double dt) {
    if (dt == 0) return;
    life -= dt;
    if (life <= 0) removeFromParent();
  }

  @override
  void render(Canvas c) {
    if (perfSkip.contains(RenderPart.effects)) return;
    final k = clampD(life / 0.25, 0, 1), rr = radius * (1 - k * 0.6);
    // Breiter, schwacher Strich als Schein, schmaler heller Strich als Kern
    _paint
      ..strokeWidth = 12
      ..color = color.withValues(alpha: 0.3 * k);
    c.drawCircle(Offset.zero, rr, _paint);
    _paint
      ..strokeWidth = 3
      ..color = Color.lerp(color, const Color(0xFFFFFFFF), 0.45)!.withValues(alpha: k);
    c.drawCircle(Offset.zero, rr, _paint);
  }
}

/// Aufsteigende Schadens- und Heilzahlen.
class FloatText extends PositionComponent with HasGameReference<FederfeuerGame>, Transient {
  FloatText(Vector2 pos, this.text, this.color, this.fontSize) : super(position: pos, priority: 21);
  final String text;
  final Color color;
  final double fontSize;
  double life = 0.8;

  // Zähler für die Obergrenze gleichzeitiger Zahlen: erhöht beim Anlegen (FederfeuerGame.floatText)
  @override
  void onRemove() {
    game.floatTextCount--;
    super.onRemove();
  }

  @override
  void update(double dt) {
    if (dt == 0) return;
    position.y -= 40 * dt;
    life -= dt;
    if (life <= 0) removeFromParent();
  }

  @override
  void render(Canvas c) {
    if (perfSkip.contains(RenderPart.effects)) return;
    if (life < 0.2) {
      c.save();
      c.scale(life / 0.2);
      OutlineText.draw(c, text, Offset.zero, size: fontSize, color: color, display: false, glow: false);
      c.restore();
    } else {
      OutlineText.draw(c, text, Offset.zero, size: fontSize, color: color, display: false, glow: false);
    }
  }
}
