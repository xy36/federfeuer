import 'dart:math';

import 'package:flame/components.dart';
import 'package:flutter/material.dart';

import '../config.dart';
import '../federfeuer_game.dart';
import '../perf.dart';
import '../run_state.dart';
import 'draw.dart';
import 'enemy.dart';
import 'glyph_art.dart';
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
      game.hurtEnemy(t, stats.dmg, false, vel.x.sign * stats.knock, fx: stats, classes: stats.classes);
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
        game.hurtEnemy(e, stats.dmg, false, 0, fx: stats, classes: stats.classes);
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
        game.dropMaterial(position, 5, spread: 18);
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

/// Wirbelsturm: Tornado zieht zur nächsten Gegnergruppe, saugt Gegner (außer Boss und
/// stationären) und Material ein und trifft alle 0,4 s alles darin (Wind-Treffer).
/// Gewittersturm: zusätzlich alle 0,3 s ein Blitz in einen Gegner in der Nähe.
class Tornado extends PositionComponent with HasGameReference<FederfeuerGame>, Transient {
  Tornado(Vector2 pos, this.dmg, this.life, {this.lightning = false}) : super(position: pos, priority: 18);
  final double dmg;
  final bool lightning;
  double life, _tick = 0, _bolt = 0, _t = 0;
  static const radius = 70.0;

  @override
  void update(double dt) {
    if (!game.playing) return;
    life -= dt;
    _t += dt;
    if (life <= 0) {
      removeFromParent();
      return;
    }
    // Zur nächsten Gegnergruppe treiben
    Enemy? near;
    var best = double.infinity;
    for (final e in game.enemies) {
      if (e.dead) continue;
      final d = (e.x - x).abs();
      if (d < best) {
        best = d;
        near = e;
      }
    }
    if (near != null) position.x += clampD(near.x - x, -1, 1) * 120 * dt;
    position.x = clampD(x, 30, game.worldW - 30);
    // Einsaugen
    for (final e in game.enemies) {
      if (e.dead || e.boss || e.stationary) continue;
      final d = position - e.position, len = d.length;
      if (len < radius * 2.4 && len > 8) e.position.addScaled(d / len, 260 * dt);
    }
    for (final dr in game.world.children.whereType<Drop>()) {
      if (dr.position.distanceTo(position) < radius * 2.4) dr.pull();
    }
    _tick -= dt;
    if (_tick <= 0) {
      _tick = 0.4;
      for (final e in [...game.enemies]) {
        if (!e.dead && e.position.distanceTo(position) < radius + e.r) {
          game.hurtEnemy(e, dmg, false, 0, classes: const [WeaponClass.wind]);
        }
      }
    }
    if (lightning) {
      _bolt -= dt;
      if (_bolt <= 0) {
        _bolt = 0.3;
        game.lightningAround(position, 220, 1, dmg * 1.8);
      }
    }
  }

  @override
  void render(Canvas c) {
    if (perfSkip.contains(RenderPart.effects)) return;
    final a = clampD(life / 0.5, 0, 1) * clampD(_t / 0.3, 0, 1);
    final col = lightning ? const Color(0xFFBFD8FF) : const Color(0xFFBFF8E6);
    // Trichter: übereinanderliegende, wirbelnde Ringe, unten schmal, oben breit
    for (var k = 0; k < 7; k++) {
      final y = 40 - k * 18.0, w = 16 + k * 9.0, sway = sin(_t * 5 + k * 0.7) * 8;
      Glow.draw(c, sway, y, w * 1.3, col.withValues(alpha: 0.18 * a));
      c.drawOval(
          Rect.fromCenter(center: Offset(sway, y), width: w * 2, height: 10),
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 2
            ..blendMode = BlendMode.plus
            ..color = col.withValues(alpha: 0.6 * a));
    }
  }
}

/// Platzregen: dichter Regen über dem ganzen Bild für kurze Zeit (nur Darstellung).
class Downpour extends Component with HasGameReference<FederfeuerGame>, Transient {
  Downpour(this.left, this.width, this.life) : _max = life, super(priority: 49);
  final double left, width, _max;
  double life;
  static final _paint = Paint()
    ..strokeWidth = 2
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
    final a = clampD(life / _max, 0, 1);
    _paint.color = Color.fromRGBO(140, 210, 255, 0.55 * a);
    final fall = (_max - life) * 900;
    for (var i = 0; i < 90; i++) {
      final x = left + (i * 37.0) % width, y = kCeil + ((i * 53.0 + fall) % (kGround - kCeil));
      c.drawLine(Offset(x, y), Offset(x - 4, y + 16), _paint);
    }
  }
}

/// Zielkreis einer angekündigten Kraft: pulsiert am Ziel (Glutbombe, Wirbelsturm) bzw. um den
/// Vogel (Felsbeben) und zieht sich bis zum Auslösen zusammen.
class ActionTelegraph extends Component with HasGameReference<FederfeuerGame> {
  ActionTelegraph() : super(priority: 19);
  static final _ring = Paint()
    ..style = PaintingStyle.stroke
    ..blendMode = BlendMode.plus;

  @override
  void render(Canvas c) {
    final id = game.announcing;
    if (id == null || perfSkip.contains(RenderPart.effects)) return;
    final Vector2 at;
    final double radius;
    switch (id) {
      case ActionId.fireBomb || ActionId.hellmaw || ActionId.whirlwind || ActionId.thunderstorm:
        final t = game.announceAt;
        if (t == null) return;
        at = t;
        radius = id == ActionId.whirlwind || id == ActionId.thunderstorm ? 70 : kFireBombRadius;
      case ActionId.quake:
        at = Vector2(game.player.x, kGround);
        radius = kQuakeRadius;
      default:
        return;
    }
    final k = clampD(game.announceT / game.announceTotal, 0, 1); // 1 → 0 bis zum Auslösen
    final col = GlyphArt.colorOf(ActionGlyph(id));
    final pulse = 0.5 + 0.5 * sin(game.clock * 18);
    final rr = radius * (0.6 + 0.4 * k);
    Glow.draw(c, at.x, at.y, rr * 1.2, col.withValues(alpha: 0.12 + 0.1 * pulse));
    _ring
      ..strokeWidth = 8
      ..color = col.withValues(alpha: 0.25 + 0.15 * pulse);
    c.drawCircle(Offset(at.x, at.y), rr, _ring);
    _ring
      ..strokeWidth = 2.5
      ..color = Color.lerp(col, Colors.white, 0.4)!.withValues(alpha: 0.7 + 0.3 * pulse);
    c.drawCircle(Offset(at.x, at.y), rr, _ring);
  }
}
