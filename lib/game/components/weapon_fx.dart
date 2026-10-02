import 'dart:math';

import 'package:flame/components.dart';
import 'package:flutter/material.dart';

import '../config.dart';
import '../federfeuer_game.dart';
import '../perf.dart';
import '../run_state.dart';
import 'draw.dart';
import 'enemy.dart';
import 'light.dart';
import 'pickups.dart';
import 'transient.dart';

Enemy? _nearest(FederfeuerGame game, Vector2 from, double range) {
  Enemy? best;
  var bestD = range * range;
  for (final e in game.enemies) {
    if (e.dead) continue;
    final d2 = e.position.distanceToSquared(from);
    if (d2 < bestD) {
      bestD = d2;
      best = e;
    }
  }
  return best;
}

/// Krähenruf: kleine Geisterkrähe, die selbstständig Gegner jagt.
class Minion extends PositionComponent with HasGameReference<FederfeuerGame>, Transient, CombatEffect {
  Minion(Vector2 pos, this.stats, this.speed) : super(position: pos, priority: 9);

  final WeaponStats stats;
  final double speed;
  final vel = Vector2.zero();
  double life = 8, _hitCd = 0, _flap = 0;
  Enemy? _target;

  @override
  void update(double dt) {
    if (!game.playing) return;
    life -= dt;
    _hitCd = max(0.0, _hitCd - dt);
    _flap += dt * 18;
    if (life <= 0) {
      game.burst(position, const Color(0xFFC07BFF), 6, 90);
      removeFromParent();
      return;
    }
    if (_target == null || _target!.dead) _target = _nearest(game, position, stats.range);
    final t = _target;
    // Ohne Ziel: um den Spieler kreisen
    final goal = t?.position ??
        game.player.position + Vector2(cos(game.clock * 2 + hashCode) * 50, -30 + sin(game.clock * 3) * 14);
    final d = goal - position;
    final want = d.length < 1 ? Vector2.zero() : (d.normalized()..scale(speed));
    vel.lerp(want, min(1.0, dt * 5));
    position.addScaled(vel, dt);
    if (t != null && _hitCd <= 0 && t.position.distanceTo(position) < t.r + 8) {
      game.hurtEnemy(t, stats.dmg, false, vel.x.sign * stats.knock, fx: stats, cls: WeaponClass.dark);
      _hitCd = 0.6;
      vel.scale(-0.8);
    }
  }

  @override
  void render(Canvas c) {
    if (perfSkip.contains(RenderPart.projectiles)) return;
    final a = clampD(life, 0, 1);
    Glow.draw(c, 0, 0, 26, Color.fromRGBO(192, 123, 255, 0.55 * a));
    c.save();
    if (vel.x < 0) c.scale(-1, 1);
    final f = sin(_flap) * 4;
    drawTri(c, -2, 0, -10, -6 - f, 4, -2, const Color(0xCC6A3AA0));
    drawOval(c, 0, 0, 7, 5, const Color(0xFF2A1A40));
    drawTri(c, 6, -2, 11, 0, 6, 2, const Color(0xFFE6B8FF));
    drawCircle(c, 3, -2, 1.4, const Color(0xFFE6B8FF));
    c.restore();
  }
}

/// Regenwolke: hängt über einem Gegner und regnet verlangsamenden Schaden.
class RainCloud extends PositionComponent with HasGameReference<FederfeuerGame>, Transient, CombatEffect {
  RainCloud(Vector2 pos, this.stats, this.span, this.target) : super(position: pos, priority: 18);

  final WeaponStats stats;
  final double span;
  Enemy? target;
  double life = 3, _tick = 0;

  @override
  void update(double dt) {
    if (!game.playing) return;
    life -= dt;
    if (life <= 0) {
      removeFromParent();
      return;
    }
    final t = target;
    if (t != null && !t.dead) {
      position.x += (t.x - x) * min(1.0, dt * 2.5);
      position.y += (max(kCeil + 30, t.y - 90) - y) * min(1.0, dt * 2.5);
    }
    _tick -= dt;
    if (_tick <= 0) {
      _tick = 0.5;
      for (final e in [...game.enemies]) {
        if (e.dead || (e.x - x).abs() > span + e.r || e.y < y) continue;
        game.hurtEnemy(e, stats.dmg, false, 0, fx: stats, cls: WeaponClass.water);
      }
    }
  }

  @override
  void render(Canvas c) {
    if (perfSkip.contains(RenderPart.effects)) return;
    final a = clampD(life * 2, 0, 1);
    Glow.draw(c, 0, 0, span * 2.2, Color.fromRGBO(140, 190, 255, 0.35 * a));
    drawOval(c, -span * 0.4, 2, span * 0.5, 13, Color.fromRGBO(120, 140, 190, 0.9 * a));
    drawOval(c, span * 0.35, 3, span * 0.5, 12, Color.fromRGBO(120, 140, 190, 0.9 * a));
    drawOval(c, 0, -6, span * 0.55, 16, Color.fromRGBO(150, 170, 215, 0.95 * a));
    // Regenstriche
    final ph = game.clock * 9;
    for (var i = 0; i < 9; i++) {
      final rx = -span + (i + 0.5) * span * 2 / 9;
      final ry = 14 + ((ph + i * 0.37) % 1) * 70;
      drawRect(c, rx, ry, 1.6, 8, Color.fromRGBO(170, 220, 255, 0.8 * a));
    }
  }
}

/// Dornenranke: kurz sichtbarer Peitschenbogen.
class WhipArc extends PositionComponent with Transient {
  WhipArc(Vector2 pos, this.aim, this.radius, this.sweep) : super(position: pos, priority: 12);
  final double aim, radius, sweep;
  double life = 0.18;
  final _paint = Paint()
    ..style = PaintingStyle.stroke
    ..strokeCap = StrokeCap.round
    ..blendMode = BlendMode.plus;

  @override
  void update(double dt) {
    life -= dt;
    if (life <= 0) removeFromParent();
  }

  @override
  void render(Canvas c) {
    if (perfSkip.contains(RenderPart.effects)) return;
    final k = clampD(life / 0.18, 0, 1);
    final rect = Rect.fromCircle(center: Offset.zero, radius: radius * (0.85 + 0.15 * (1 - k)));
    _paint
      ..strokeWidth = 10
      ..color = Color.fromRGBO(140, 60, 200, 0.4 * k);
    c.drawArc(rect, aim - sweep / 2, sweep, false, _paint);
    _paint
      ..strokeWidth = 3
      ..color = Color.fromRGBO(180, 255, 160, k);
    c.drawArc(rect, aim - sweep / 2, sweep, false, _paint);
  }
}

/// Henriette: Ei, das über den Boden rollt und explodiert.
class Egg extends PositionComponent with HasGameReference<FederfeuerGame>, Transient, CombatEffect {
  Egg(Vector2 pos, double dir, this.dmg, {this.storm = false, this.gold = false})
      : vel = Vector2(dir * 240, -80),
        super(position: pos, priority: 9);

  final Vector2 vel;
  final double dmg;

  /// Gewitterei: zerplatzt zusätzlich in einen Blitzregen.
  final bool storm;

  /// Goldenes Ei: lässt bei der Explosion Material regnen.
  final bool gold;
  double fuse = 1.6, _spin = 0;

  @override
  void update(double dt) {
    if (!game.playing) return;
    vel.y += 900 * dt;
    position.addScaled(vel, dt);
    _spin += vel.x * dt * 0.1;
    if (y > kGround - 7) {
      position.y = kGround - 7;
      vel.y = 0;
      vel.x *= pow(0.6, dt);
    }
    position.x = clampD(x, 8, game.worldW - 8);
    fuse -= dt;
    final hit = game.enemies.any((e) => !e.dead && e.position.distanceTo(position) < e.r + 8);
    if (fuse <= 0 || hit) {
      game.explode(position, 75, dmg, false, color: const Color(0xFFFFE08A));
      if (storm) game.lightningAround(position, 180, 6, dmg / 1.6);
      if (gold) {
        for (var i = 0; i < 5; i++) {
          game.world.add(Drop(position.clone()..x += (i - 2) * 9, material: true, rng: game.rng, fallSpeed: game.run!.difficultyDef.dropFallSpeed));
        }
      }
      removeFromParent();
    }
  }

  @override
  void render(Canvas c) {
    final blink = fuse < 0.5 && (fuse * 16).floor().isEven;
    Glow.draw(c, 0, 0, gold ? 34 : 26, blink ? const Color(0xCCFF6A3D) : (gold ? const Color(0xCCFFC94A) : const Color(0x88FFE08A)));
    c.save();
    c.rotate(_spin);
    drawOval(c, 0, 0, 6, 8, gold ? const Color(0xFFFFD45A) : const Color(0xFFFFF6E6));
    drawOval(c, -1.5, -2.5, 2, 3, const Color(0xFFFFFFFF));
    c.restore();
  }
}

/// Gewitterwolke: Blitz von oben in einen Gegner.
class Lightning extends PositionComponent with Transient, CombatEffect {
  Lightning(Vector2 target) : super(position: target, priority: 19) {
    final rng = Random();
    var px = 0.0;
    for (var yy = -(target.y - kCeil); yy < 0; yy += 26) {
      _pts.add(Offset(px, yy));
      px += (rng.nextDouble() - 0.5) * 26;
    }
    _pts.add(Offset.zero);
  }

  final _pts = <Offset>[];
  double life = 0.22;
  final _paint = Paint()
    ..style = PaintingStyle.stroke
    ..strokeJoin = StrokeJoin.round
    ..blendMode = BlendMode.plus;

  @override
  void update(double dt) {
    life -= dt;
    if (life <= 0) removeFromParent();
  }

  @override
  void render(Canvas c) {
    if (perfSkip.contains(RenderPart.effects)) return;
    final k = clampD(life / 0.22, 0, 1);
    final path = Path()..addPolygon(_pts, false);
    _paint
      ..strokeWidth = 9
      ..color = Color.fromRGBO(160, 200, 255, 0.4 * k);
    c.drawPath(path, _paint);
    _paint
      ..strokeWidth = 2.5
      ..color = Color.fromRGBO(255, 255, 255, k);
    c.drawPath(path, _paint);
    Glow.draw(c, 0, 0, 50, Color.fromRGBO(190, 220, 255, 0.7 * k));
  }
}
