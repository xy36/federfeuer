import 'dart:math';

import 'package:flame/components.dart';
import 'package:flutter/material.dart';

import '../config.dart';
import '../federfeuer_game.dart';
import '../perf.dart';
import '../run_state.dart';
import 'draw.dart';
import 'light.dart';
import 'enemy.dart';
import 'transient.dart';

/// Eigenes Geschoss. Je nach Waffe fliegt es gerade, im Bogen ([gravity]),
/// wartet auf seinen Zünder ([fuse]) oder rollt über den Boden ([roll]).
class Bullet extends PositionComponent with HasGameReference<FederfeuerGame>, Transient {
  Bullet({
    required Vector2 position,
    required this.vel,
    required this.dmg,
    required this.crit,
    required this.pierce,
    required this.life,
    required this.explosion,
    required this.radius,
    required this.color,
    this.fx,
    this.cls,
    this.look = '',
    this.gravity = 0,
    this.fuse = 0,
    this.roll = false,
    this.knock = 5,
  })  : _trail = Paint()
          ..color = color.withAlpha(150)
          ..strokeWidth = radius * 1.4
          ..strokeCap = StrokeCap.round
          ..blendMode = BlendMode.plus,
        super(position: position, priority: 6);

  final Vector2 vel;
  final double dmg, explosion, radius, gravity, knock;
  final bool crit, roll;
  final Color color;

  /// Treffereffekte (Brand, Verlangsamen, …) und Klasse der Waffe.
  final WeaponStats? fx;
  final WeaponClass? cls;

  /// Waffen-ID für die Darstellung (Popcorn, Gartenzwerg, Bowlingkugel, …).
  final String look;
  final Paint _trail;
  final Set<Enemy> _hit = {};
  int pierce;
  double life, fuse, _spin = 0;
  bool _done = false;

  @override
  void update(double dt) {
    if (!game.playing || _done) return;
    vel.y += gravity * dt;
    position.addScaled(vel, dt);
    if (!roll) position.x += game.weather.windX * dt;
    _spin += vel.x * dt * 0.08;
    life -= dt;
    // Boden: rollen, liegen bleiben (Zünder) oder aufschlagen
    if (y > kGround - radius) {
      if (roll) {
        position.y = kGround - radius;
        vel.y = 0;
      } else if (fuse > 0) {
        position.y = kGround - radius;
        vel.setZero();
      } else if (gravity > 0 && explosion > 0) {
        _explode();
        return;
      }
    }
    if (y > kGround + 8 || y < 0 || x < 0 || x > game.worldW) life = 0;
    if (fuse > 0) {
      fuse -= dt;
      if (fuse <= 0) {
        game.floatText(position - Vector2(0, 14), 'PLOPP!', const Color(0xFFFFF4C2), 13);
        _explode();
      }
      return;
    }

    if (life > 0) {
      for (final e in game.enemies) {
        if (e.dead || _hit.contains(e)) continue;
        final rr = e.r + radius;
        if (e.position.distanceToSquared(position) < rr * rr) {
          if (explosion > 0) {
            _explode();
            return;
          }
          _hit.add(e);
          final dir = vel.x == 0 ? 0.0 : vel.x.sign;
          game.hurtEnemy(e, dmg, crit, dir * knock, fx: fx, cls: cls);
          if (--pierce < 0) {
            life = 0;
            break;
          }
        }
      }
    }
    if (life <= 0) {
      if (explosion > 0) {
        _explode();
      } else {
        _done = true;
        removeFromParent();
      }
    }
  }

  void _explode() {
    if (_done) return;
    _done = true;
    final stone = cls == WeaponClass.stone;
    game.explode(position, explosion, dmg, crit,
        fx: fx, color: stone ? const Color(0xFFFFD27A) : const Color(0xFFFF9F1C));
    removeFromParent();
  }

  @override
  void render(Canvas c) {
    if (perfSkip.contains(RenderPart.projectiles)) return;
    final col = crit ? Palette.sun : color;
    switch (look) {
      case 'popcorn':
        final pop = fuse < 0.25 ? 1.4 : 1.0;
        Glow.draw(c, 0, 0, radius * 4, const Color(0xAAFFD27A));
        drawCircle(c, -2 * pop, 0, 3.4 * pop, const Color(0xFFFFF4C2));
        drawCircle(c, 2 * pop, -1, 3 * pop, const Color(0xFFFFFFFF));
        drawCircle(c, 0, 2 * pop, 2.6 * pop, const Color(0xFFFFE066));
      case 'gnome':
        c.save();
        c.rotate(_spin);
        Glow.draw(c, 0, 0, radius * 3.5, const Color(0x88FFD27A));
        drawOval(c, 0, 3, 5, 5, const Color(0xFF5A9BFF));
        drawCircle(c, 0, -1, 3.2, const Color(0xFFFFD2B0));
        drawOval(c, 0, 2, 3.4, 2.6, const Color(0xFFFFFFFF));
        drawTri(c, -4.5, -2.5, 4.5, -2.5, 0, -13, const Color(0xFFE63946));
        c.restore();
      case 'bowling':
        Glow.draw(c, 0, 0, radius * 3, col.withAlpha(140));
        drawCircle(c, 0, 0, radius, const Color(0xFF2A2440));
        c.save();
        c.rotate(_spin);
        drawCircle(c, 3, -3, 1.6, const Color(0xFF8F86B8));
        drawCircle(c, 5.5, 0, 1.6, const Color(0xFF8F86B8));
        drawCircle(c, 2, 2, 1.6, const Color(0xFF8F86B8));
        c.restore();
      case 'bubbles':
        Glow.draw(c, 0, 0, radius * 3, const Color(0x669FE4FF));
        c.drawCircle(Offset.zero, radius, _ring..color = const Color(0xCCDFF8FF));
        drawCircle(c, -radius * 0.35, -radius * 0.35, radius * 0.25, Colors.white);
      case 'dandelion':
        Glow.draw(c, 0, 0, radius * 3.5, const Color(0x88FFFFF2));
        for (var i = 0; i < 6; i++) {
          final a = i / 6 * pi - pi;
          c.drawLine(Offset.zero, Offset(cos(a) * 6, sin(a) * 6), _ring..color = const Color(0xDDFFFFFF));
        }
        drawCircle(c, 0, 2, 1.4, const Color(0xFFB0A060));
      case 'pebble':
        c.save();
        c.rotate(_spin);
        Glow.draw(c, 0, 0, radius * 3, col.withAlpha(120));
        drawOval(c, 0, 0, radius, radius * 0.75, const Color(0xFFB8AFA0));
        drawOval(c, -1, -1, radius * 0.4, radius * 0.3, const Color(0xFFE6E0D4));
        c.restore();
      default:
        c.drawLine(Offset.zero, Offset(-vel.x * 0.03, -vel.y * 0.03), _trail);
        Glow.draw(c, 0, 0, radius * (crit ? 5 : 3.6), col.withAlpha(200));
        drawCircle(c, 0, 0, radius * 0.65, Colors.white);
    }
  }

  static final _ring = Paint()
    ..style = PaintingStyle.stroke
    ..strokeWidth = 1.4;
}

class EnemyBullet extends PositionComponent with HasGameReference<FederfeuerGame>, Transient {
  EnemyBullet(Vector2 position, this.vel, this.radius, this.dmg, this.color, {this.gravity = 0, this.web = false})
      : super(position: position, priority: 12);

  final Vector2 vel;
  final double radius, dmg;
  final Color color;

  /// Bogenwurf (brennendes Stroh der Vogelscheuche).
  final double gravity;

  /// Spinnennetz: verlangsamt den Spieler beim Treffer.
  final bool web;
  double life = 5;

  @override
  void update(double dt) {
    if (!game.playing) return;
    // Schnappschuss: Gegnerkugeln stehen still
    if (game.freezeT > 0) return;
    vel.y += gravity * dt;
    position.addScaled(vel, dt);
    position.x += game.weather.windX * dt;
    life -= dt;
    final p = game.player;
    if (position.distanceTo(p.position) < radius + p.r - 2) {
      game.hurtPlayer(dmg);
      if (web) p.webT = 2;
      life = 0;
    }
    if (gravity > 0 && y > kGround - radius) {
      game.burst(position, color, 6, 90);
      life = 0;
    }
    if (life <= 0 || y > kGround) removeFromParent();
  }

  @override
  void render(Canvas c) {
    if (perfSkip.contains(RenderPart.projectiles)) return;
    // Dunkler Kern mit rotem Leuchten – klar unterscheidbar von eigenen Kugeln
    Glow.draw(c, 0, 0, radius * 4, color.withAlpha(190));
    drawCircle(c, 0, 0, radius + 1.5, Color.lerp(color, Colors.white, 0.3)!);
    drawCircle(c, 0, 0, radius - 1, const Color(0xFF1B0A1E));
  }
}
