import 'dart:math';

import 'package:flame/components.dart';
import 'package:flutter/material.dart';

import '../config.dart';
import '../federfeuer_game.dart';
import '../run_state.dart';
import 'draw.dart';
import 'enemy.dart';
import 'projectiles.dart';

/// Eine Waffe, die im Kreis um den Spieler schwebt und automatisch zielt.
class WeaponMount extends PositionComponent with HasGameReference<FederfeuerGame> {
  WeaponMount(this.weapon, this.index) : super(priority: 11);

  final OwnedWeapon weapon;
  final int index;
  double cd = 0.3, ang = 0, kick = 0;

  @override
  void update(double dt) {
    final run = game.run;
    if (run == null || !game.playing) return;

    final n = run.weapons.length;
    final p = game.player.position;
    final a = (n == 1 ? 0.0 : -pi / 2) + index / n * pi * 2;
    position.setValues(p.x + cos(a) * 30, p.y + sin(a) * 24);
    cd -= dt;
    kick = max(0.0, kick - dt * 8);

    final s = run.weaponStats(weapon.id, weapon.tier);
    Enemy? best;
    var bestD = s.range * s.range;
    for (final e in game.enemies) {
      if (e.dead) continue;
      final d2 = e.position.distanceToSquared(position);
      if (d2 < bestD) {
        bestD = d2;
        best = e;
      }
    }

    if (best != null) {
      final target = atan2(best.y - y, best.x - x);
      _turnTo(target, dt * 18);
      if (cd <= 0) _fire(s, target, run);
    } else {
      _turnTo(game.player.face > 0 ? 0.0 : pi, dt * 4);
    }
  }

  void _turnTo(double target, double k) {
    var da = target - ang;
    da = atan2(sin(da), cos(da));
    ang += da * min(1.0, k);
  }

  void _fire(WeaponStats s, double aim, RunState run) {
    final d = weapon.def;
    final rng = game.rng;
    for (var k = 0; k < d.count; k++) {
      final a = aim +
          (d.count > 1 ? (k / (d.count - 1) - 0.5) * d.spread : (rng.nextDouble() - 0.5) * d.spread);
      final crit = rng.nextDouble() * 100 < run.stat(Stat.crit);
      game.world.add(Bullet(
        position: Vector2(x + cos(aim) * d.length, y + sin(aim) * d.length),
        vel: Vector2(cos(a), sin(a))..scale(d.speed),
        dmg: s.dmg * (crit ? 2 : 1),
        crit: crit,
        pierce: d.pierce,
        life: s.range / d.speed * 1.1,
        explosion: d.explosion,
        radius: d.radius,
        color: d.color,
      ));
    }
    cd = s.cooldown;
    kick = 1;
  }

  @override
  void render(Canvas c) {
    final d = weapon.def;
    c.save();
    c.rotate(ang);
    if (cos(ang) < 0) c.scale(1, -1);
    c.translate(-kick * 4, 0);
    final th = weapon.id == 'rocket' ? 8.0 : 6.0;
    drawRect(c, -5, -th / 2 - 1.5, d.length + 3, th + 3, Palette.ink);
    drawRect(c, -3, 1, 5, 8, Palette.ink);
    drawRect(c, -3.5, -th / 2, d.length, th, tiers[weapon.tier].color);
    if (weapon.id == 'rocket') drawRect(c, d.length - 4, -th / 2, 4, th, const Color(0xFFFF9F1C));
    c.restore();
  }
}
