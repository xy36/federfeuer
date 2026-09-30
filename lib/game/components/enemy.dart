import 'dart:math';

import 'package:flame/components.dart';
import 'package:flutter/material.dart';

import '../config.dart';
import '../federfeuer_game.dart';
import 'draw.dart';
import 'pickups.dart';
import 'projectiles.dart';
import 'transient.dart';

class Enemy extends PositionComponent with HasGameReference<FederfeuerGame>, Transient {
  Enemy(this.type, Vector2 pos, int wave, Random rng) : super(position: pos, priority: 5) {
    final d = enemyDefs[type]!;
    // Wellenskalierung gilt laut GDD nicht für den Boss.
    final boss = type == EnemyType.boss;
    r = d.radius;
    maxHp = boss ? d.hp : d.hp * (1 + (wave - 1) * 0.38);
    hp = maxHp;
    dmg = boss ? d.dmg : (d.dmg * (1 + (wave - 1) * 0.15)).roundToDouble();
    spd = boss ? d.speed : d.speed * (1 + wave * 0.02);
    fly = d.flying;
    t = rng.nextDouble() * 10;
    shootT = 0.5 + rng.nextDouble() * 1.5;
  }

  final EnemyType type;
  late final double r, maxHp, dmg, spd;
  late final bool fly;
  late double hp;
  double t = 0, shootT = 0, jumpT = 1, summonT = 5, flash = 0;
  bool dead = false;
  final vel = Vector2.zero();

  /// Wie stark der Wind diesen Gegner verschiebt.
  double get windFactor => switch (type) {
        EnemyType.crow => WeatherConfig.windFactorLight,
        EnemyType.spitter => WeatherConfig.windFactorMedium,
        EnemyType.beetle => WeatherConfig.windFactorGround,
        EnemyType.rock => WeatherConfig.windFactorHeavy,
        EnemyType.boss => WeatherConfig.windFactorBoss,
      };

  static final _legPaint = Paint()
    ..color = const Color(0xFF1D3A26)
    ..strokeWidth = 2;

  @override
  void update(double dt) {
    if (dead || !game.playing) return;
    t += dt;
    flash -= dt;
    final p = game.player.position;
    final dx = p.x - x, dy = p.y - y;
    final d = max(1.0, sqrt(dx * dx + dy * dy));

    switch (type) {
      case EnemyType.crow:
        {
          final ty = dy + sin(t * 3) * 30;
          vel.x += (dx / d * spd - vel.x) * 2.5 * dt;
          vel.y += (ty / d * spd - vel.y) * 2.5 * dt;
        }
      case EnemyType.rock:
        {
          vel.x += (dx / d * spd - vel.x) * 1.2 * dt;
          vel.y += (dy / d * spd - vel.y) * 1.2 * dt;
        }
      case EnemyType.beetle:
        {
          vel.y += 900 * dt;
          vel.x += (dx.sign * spd - vel.x) * 4 * dt;
          if (y >= kGround - r - 1) {
            jumpT -= dt;
            if (jumpT <= 0 && dx.abs() < 220 && p.y < y - 60) {
              vel.y = -game.rnd(380, 520);
              jumpT = game.rnd(1.5, 2.5);
            }
          }
        }
      case EnemyType.spitter:
        {
          final want = d > 300 ? 1 : (d < 200 ? -1 : 0);
          vel.x += (dx / d * spd * want - vel.x) * 2 * dt;
          vel.y += (dy / d * spd * want + sin(t * 2) * 40 - vel.y) * 2 * dt;
          shootT -= dt;
          if (shootT <= 0 && d < 520) {
            shootT = 2.4 * game.rnd(0.8, 1.2);
            game.world.add(EnemyBullet(position.clone(), Vector2(dx / d * 240, dy / d * 240), 6, dmg,
                const Color(0xFFB8F35A)));
          }
        }
      case EnemyType.boss:
        {
          vel.x += (dx.sign * spd * (dx.abs() > 120 ? 1 : 0) - vel.x) * dt;
          vel.y += ((170 + sin(t * 0.8) * 90) - y - vel.y) * 1.5 * dt;
          shootT -= dt;
          if (shootT <= 0) {
            shootT = 1.5;
            final base = atan2(dy, dx);
            for (var k = 0; k < 7; k++) {
              final a = base + (k / 6 - 0.5);
              game.world.add(EnemyBullet(
                  position.clone(), Vector2(cos(a), sin(a))..scale(220), 7, dmg - 2, Palette.coral));
            }
          }
          summonT -= dt;
          if (summonT <= 0) {
            summonT = 6;
            for (var k = 0; k < 3; k++) {
              game.world.add(SpawnMarker(
                EnemyType.crow,
                Vector2(clampD(x + game.rnd(-90, 90), 40, game.worldW - 40),
                    clampD(y + game.rnd(-40, 60), kCeil + 40, kGround - 60)),
                0.6,
              ));
            }
          }
        }
    }

    position.x = clampD(x + (vel.x + game.weather.windX * windFactor) * dt, r, game.worldW - r);
    position.y += vel.y * dt;
    if (y > kGround - r) {
      position.y = kGround - r;
      vel.y = min(0.0, vel.y);
    }
    if (y < kCeil + r) {
      position.y = kCeil + r;
      vel.y = max(0.0, vel.y);
    }
    if (position.distanceTo(p) < r + game.player.r - 3) game.hurtPlayer(dmg);
  }

  @override
  void render(Canvas c) {
    drawShadow(c, y, r);
    final face = (game.player.x - x) >= 0 ? 1.0 : -1.0;
    final f = flash > 0;
    Color k(Color col) => f ? Colors.white : col;

    c.save();
    c.scale(face, 1);
    switch (type) {
      case EnemyType.crow:
        {
          final fl = sin(t * 16);
          drawTri(c, -4, -2, -18, -14 - fl * 8, 6, -4, k(const Color(0xFF3A2C52)));
          drawOval(c, 0, 0, 14, 11, k(const Color(0xFF3A2C52)));
          drawTri(c, -2, 0, -16, 8 + fl * 6, 6, 2, k(const Color(0xFF4D3C6B)));
          drawTri(c, 11, -3, 22, 1, 11, 4, Palette.sun);
          drawCircle(c, 6, -4, 2.5, const Color(0xFFFF4D6D));
        }
      case EnemyType.beetle:
        {
          for (var i = -1; i <= 1; i++) {
            final lg = sin(t * 14 + i) * 3;
            c.drawLine(Offset(i * 7.0, 4), Offset(i * 7 + lg, 15), _legPaint);
          }
          c.drawArc(Rect.fromCircle(center: const Offset(0, 4), radius: 16), pi, pi, true,
              fillOf(k(const Color(0xFF46B36A))));
          drawCircle(c, -6, -3, 3, k(const Color(0xFF2F7D49)));
          drawCircle(c, 5, -6, 2.5, k(const Color(0xFF2F7D49)));
          drawCircle(c, 15, 0, 6, k(const Color(0xFF1D3A26)));
          drawCircle(c, 17, -2, 2, Colors.white);
        }
      case EnemyType.spitter:
        {
          final wb = sin(t * 5) * 1.5;
          drawOval(c, 0, 0, 15 + wb, 13 - wb, k(const Color(0xFF9B5DE5)));
          for (var i = -1; i <= 1; i++) {
            drawTri(c, i * 8 - 3.0, 10, i * 8 + 3.0, 10, i * 8.0, 18 + sin(t * 6 + i) * 3,
                k(const Color(0xFF7A3FC4)));
          }
          drawOval(c, 7, 3, 5, 4, Palette.ink);
          drawCircle(c, 3, -5, 4, Colors.white);
          drawCircle(c, 4, -5, 2, Palette.ink);
        }
      case EnemyType.rock:
        {
          final path = Path();
          for (var i = 0; i < 8; i++) {
            final a = i / 8 * pi * 2, rr = r * (i.isOdd ? 0.88 : 1);
            if (i == 0) {
              path.moveTo(rr, 0);
            } else {
              path.lineTo(cos(a) * rr, sin(a) * rr);
            }
          }
          path.close();
          c.drawPath(path, fillOf(k(const Color(0xFF7D7A8C))));
          drawCircle(c, -8, 8, 6, k(const Color(0xFF615E70)));
          drawCircle(c, 6, -5, 4, Palette.sun);
          drawCircle(c, 15, -5, 3.5, Palette.sun);
          drawRect(c, 3, -12, 16, 3, Palette.ink);
        }
      case EnemyType.boss:
        {
          final fl = sin(t * 6);
          drawTri(c, -10, -10, -70, -40 - fl * 25, 10, -6, k(const Color(0xFF3A1F4F)));
          drawOval(c, 0, 0, 52, 38, k(const Color(0xFF3A1F4F)));
          drawTri(c, -6, 0, -64, 26 + fl * 18, 14, 4, k(const Color(0xFF5A2F75)));
          drawOval(c, 30, -18, 16, 14, const Color(0xFFE8C7A0));
          drawTri(c, 40, -16, 64, -6, 40, -4, Palette.sun);
          drawTri(c, 8, -32, 12, -46, 18, -32, Palette.sun);
          drawTri(c, 18, -32, 22, -50, 28, -32, Palette.sun);
          drawTri(c, 28, -32, 32, -46, 38, -32, Palette.sun);
          drawCircle(c, 34, -20, 4, const Color(0xFFFF4D6D));
        }
    }
    c.restore();

    if (type == EnemyType.rock && hp < maxHp) {
      drawRect(c, -20, -r - 10, 40, 5, Palette.ink);
      drawRect(c, -20, -r - 10, 40 * clampD(hp / maxHp, 0, 1), 5, Palette.coral);
    }
  }
}
