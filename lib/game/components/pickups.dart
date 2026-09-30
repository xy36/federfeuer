import 'dart:math';

import 'package:flame/components.dart';
import 'package:flutter/material.dart';

import '../config.dart';
import '../federfeuer_game.dart';
import 'draw.dart';
import 'transient.dart';

/// Material (Geld + XP) oder Herz (Heilung).
class Drop extends PositionComponent with HasGameReference<FederfeuerGame>, Transient {
  Drop(Vector2 pos, {required this.material, required Random rng})
      : vel = Vector2((rng.nextDouble() - 0.5) * 80, material ? -20 - rng.nextDouble() * 60 : -60),
        super(position: pos, priority: 1);

  final bool material;
  final Vector2 vel;
  bool taken = false, _pulled = false;

  @override
  void update(double dt) {
    if (!game.playing || taken) return;
    final p = game.player.position;
    final dx = p.x - x, dy = p.y - y;
    final dist = max(0.001, sqrt(dx * dx + dy * dy));
    final pickRange = 70 + game.run!.stat(Stat.pickup);

    if (dist < pickRange || _pulled) {
      _pulled = true;
      position.x += dx / dist * 520 * dt;
      position.y += dy / dist * 520 * dt;
    } else {
      vel.y = min(vel.y + 300 * dt, 70.0 * game.weather.dropFallFactor);
      vel.x *= pow(0.1, dt);
      position.x += vel.x * dt;
      position.y = min(kGround - 5, y + vel.y * dt);
    }
    if (dist < game.player.r + 8) {
      taken = true;
      if (material) {
        game.gain(1);
      } else {
        game.heal(3);
      }
      removeFromParent();
    }
  }

  @override
  void render(Canvas c) {
    if (material) {
      c.save();
      c.rotate(pi / 4);
      drawRect(c, -4, -4, 8, 8, Palette.mint);
      c.restore();
    } else {
      drawCircle(c, -3, -2, 4, Palette.coral);
      drawCircle(c, 3, -2, 4, Palette.coral);
      drawTri(c, -7, 0, 7, 0, 0, 8, Palette.coral);
    }
  }
}

/// Rotes X, das kurz vor dem Erscheinen eines Gegners warnt.
class SpawnMarker extends PositionComponent with HasGameReference<FederfeuerGame>, Transient {
  SpawnMarker(this.type, Vector2 pos, this.t) : super(position: pos, priority: 2);

  final EnemyType type;
  double t;
  final _paint = Paint()
    ..style = PaintingStyle.stroke
    ..strokeWidth = 3;

  @override
  void update(double dt) {
    if (!game.playing) return;
    t -= dt;
    if (t <= 0) {
      game.addEnemy(type, position.clone());
      removeFromParent();
    }
  }

  @override
  void render(Canvas c) {
    final a = 0.5 + 0.5 * sin(t * 20);
    _paint.color = Color.fromRGBO(255, 77, 109, a);
    final s = type == EnemyType.boss ? 30.0 : 10.0;
    c.drawLine(Offset(-s, -s), Offset(s, s), _paint);
    c.drawLine(Offset(s, -s), Offset(-s, s), _paint);
  }
}
