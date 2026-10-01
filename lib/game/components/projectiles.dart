import 'package:flame/components.dart';
import 'package:flutter/material.dart';

import '../config.dart';
import '../federfeuer_game.dart';
import '../perf.dart';
import 'draw.dart';
import 'light.dart';
import 'enemy.dart';
import 'transient.dart';

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
  })  : _trail = Paint()
          ..color = color.withAlpha(150)
          ..strokeWidth = radius * 1.4
          ..strokeCap = StrokeCap.round
          ..blendMode = BlendMode.plus,
        super(position: position, priority: 6);

  final Vector2 vel;
  final double dmg, explosion, radius;
  final bool crit;
  final Color color;
  final Paint _trail;
  final Set<Enemy> _hit = {};
  int pierce;
  double life;
  bool _done = false;

  @override
  void update(double dt) {
    if (!game.playing || _done) return;
    position.addScaled(vel, dt);
    position.x += game.weather.windX * dt;
    life -= dt;
    if (y > kGround + 8 || y < 0 || x < 0 || x > game.worldW) life = 0;

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
          game.hurtEnemy(e, dmg, crit, vel.x / vel.length * 5);
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
    game.explode(position, explosion, dmg, crit);
    removeFromParent();
  }

  @override
  void render(Canvas c) {
    if (perfSkip.contains(RenderPart.projectiles)) return;
    final col = crit ? Palette.sun : color;
    c.drawLine(Offset.zero, Offset(-vel.x * 0.03, -vel.y * 0.03), _trail);
    Glow.draw(c, 0, 0, radius * (crit ? 5 : 3.6), col.withAlpha(200));
    drawCircle(c, 0, 0, radius * 0.65, Colors.white);
  }
}

class EnemyBullet extends PositionComponent with HasGameReference<FederfeuerGame>, Transient {
  EnemyBullet(Vector2 position, this.vel, this.radius, this.dmg, this.color)
      : super(position: position, priority: 12);

  final Vector2 vel;
  final double radius, dmg;
  final Color color;
  double life = 5;

  @override
  void update(double dt) {
    if (!game.playing) return;
    position.addScaled(vel, dt);
    position.x += game.weather.windX * dt;
    life -= dt;
    final p = game.player;
    if (position.distanceTo(p.position) < radius + p.r - 2) {
      game.hurtPlayer(dmg);
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
