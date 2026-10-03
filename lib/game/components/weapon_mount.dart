import 'dart:math';

import 'package:flame/components.dart';
import 'package:flutter/material.dart';

import '../config.dart';
import '../federfeuer_game.dart';
import '../run_state.dart';
import 'draw.dart';
import 'light.dart';
import 'enemy.dart';
import 'projectiles.dart';
import 'weapon_art.dart';
import 'weapon_fx.dart';

/// Eine Waffe des Spielers: die erste hält der Vogel in den Krallen, die übrigen schweben
/// im Kreis um ihn. Alle zielen automatisch.
class WeaponMount extends PositionComponent with HasGameReference<FederfeuerGame> {
  WeaponMount(this.weapon, this.index) : super(priority: 11);

  final OwnedWeapon weapon;
  final int index;
  double cd = 0.3, ang = 0, kick = 0;

  /// Die erste Waffe hält der Vogel in den Krallen.
  bool get held => index == 0;

  /// Federwirbel: Winkel der kreisenden Klingen, letzte Treffer je Gegner.
  double _orbit = 0;
  final _orbitHits = <Enemy, double>{};

  /// Diskokugel: dreht sich weiter, egal wo Gegner sind.
  double _disco = 0;
  final _minions = <Minion>[];

  @override
  void update(double dt) {
    final run = game.run;
    if (run == null || !game.playing) return;

    final n = run.weapons.length;
    final pl = game.player, p = pl.position;
    if (held) {
      // In den Krallen: unter dem Bauch, folgt der Blickrichtung
      final k = pl.character.scale;
      position.setValues(p.x + pl.face * 3 * k, p.y + pl.r * 0.95);
    } else {
      final floaters = n - 1, slot = index - 1;
      final a = (floaters == 1 ? -pi / 2 : -pi / 2) + slot / max(1, floaters) * pi * 2;
      position.setValues(p.x + cos(a) * 40, p.y + sin(a) * 32);
    }
    cd -= dt;
    kick = max(0.0, kick - dt * 8);

    final d = weapon.def;
    final s = run.weaponStats(weapon.id, weapon.tier, raining: game.weather.isRaining);
    if (d.kind == WeaponKind.orbit) {
      _updateOrbit(s, dt);
      return;
    }
    _disco += dt * 2.4;
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
      if (cd <= 0) _fire(s, target, run, best);
    } else {
      _turnTo(game.player.face > 0 ? 0.0 : pi, dt * 4);
    }
  }

  void _turnTo(double target, double k) {
    var da = target - ang;
    da = atan2(sin(da), cos(da));
    ang += da * min(1.0, k);
  }

  bool _crit(RunState run) => game.rng.nextDouble() * 100 < run.stat(Stat.crit);

  void _fire(WeaponStats s, double aim, RunState run, Enemy target) {
    final d = weapon.def;
    final rng = game.rng;
    cd = s.cooldown;
    kick = 1;
    switch (d.kind) {
      case WeaponKind.whip:
        _whip(s, aim, run);
        return;
      case WeaponKind.summon:
        _minions.removeWhere((m) => m.life <= 0);
        if (_minions.length >= d.count) return;
        final m = Minion(position.clone(), s, d.speed);
        _minions.add(m);
        game.world.add(m);
        return;
      case WeaponKind.cloud:
        game.world.add(RainCloud(Vector2(target.x, max(kCeil + 30, target.y - 90)), s, d.radius, target));
        return;
      case WeaponKind.roll:
        final crit = _crit(run);
        final dir = (target.x - x).sign == 0 ? game.player.face : (target.x - x).sign;
        game.world.add(Bullet(
          position: position.clone(),
          vel: Vector2(dir * d.speed, 0),
          dmg: s.dmg * (crit ? 2 : 1),
          crit: crit,
          pierce: d.pierce,
          life: s.range / d.speed,
          explosion: 0,
          radius: d.radius,
          color: d.color,
          fx: s,
          cls: d.cls,
          look: d.id,
          gravity: 900,
          roll: true,
          knock: s.knock,
        ));
        return;
      default:
    }
    // Schüsse, Bögen und Diskokugel; Spiegelscherbe verdoppelt jedes Projektil
    final mirror = run.has(ItemEffect.mirror);
    final lob = d.kind == WeaponKind.lob;
    for (var copy = 0; copy < (mirror ? 2 : 1); copy++) {
      final off = mirror ? (copy == 0 ? -0.07 : 0.07) : 0.0;
      for (var k = 0; k < d.count; k++) {
        final double a;
        if (d.kind == WeaponKind.disco) {
          a = _disco + k / d.count * pi * 2 + off;
        } else {
          a = aim + off +
              (d.count > 1 ? (k / (d.count - 1) - 0.5) * d.spread : (rng.nextDouble() - 0.5) * d.spread);
        }
        final crit = _crit(run);
        // Bogenwurf: Ziel in Wurfweite treffen, leicht nach oben gezielt
        final dist = target.position.distanceTo(position);
        final speed = lob ? clampD(sqrt(dist * 650), 220, d.speed * 1.6) : d.speed;
        final la = lob ? atan2(sin(a) - 0.75, cos(a)) : a;
        game.world.add(Bullet(
          position: Vector2(x + cos(aim) * d.length, y + sin(aim) * d.length),
          vel: Vector2(cos(la), sin(la))..scale(speed),
          dmg: s.dmg * (crit ? 2 : 1),
          crit: crit,
          pierce: d.pierce,
          life: lob ? 3 : s.range / d.speed * 1.1,
          explosion: s.explosion,
          radius: d.radius,
          color: d.color,
          fx: s,
          cls: d.cls,
          look: d.id,
          gravity: lob ? 650 : (d.stick > 0 ? -25 : 0),
          fuse: d.fuse,
          knock: s.knock,
        ));
      }
    }
    // Paktlaterne: jeder Schuss kostet Leben (tötet nie)
    if (d.hpCost > 0 && run.hp > d.hpCost) {
      run.hp -= d.hpCost;
      game.floatText(game.player.position - Vector2(0, 26), '-${d.hpCost}', const Color(0xFFC07BFF), 12);
    }
  }

  void _whip(WeaponStats s, double aim, RunState run) {
    final d = weapon.def;
    final p = game.player.position;
    game.world.add(WhipArc(p.clone(), aim, s.range, d.spread));
    for (final e in [...game.enemies]) {
      if (e.dead) continue;
      final dv = e.position - p;
      if (dv.length > s.range + e.r) continue;
      var da = atan2(dv.y, dv.x) - aim;
      da = atan2(sin(da), cos(da));
      if (da.abs() > d.spread / 2 + 0.15) continue;
      final crit = _crit(run);
      game.hurtEnemy(e, s.dmg * (crit ? 2 : 1), crit, dv.x.sign * s.knock, fx: s, cls: d.cls);
    }
  }

  /// Position einer Federklinge (Weltkoordinaten).
  Vector2 _blade(int k, int count, double radius) {
    final a = _orbit + k / count * pi * 2;
    return game.player.position + Vector2(cos(a) * radius, sin(a) * radius * 0.8);
  }

  void _updateOrbit(WeaponStats s, double dt) {
    final d = weapon.def, run = game.run!;
    _orbit += d.speed * dt;
    _orbitHits.updateAll((_, t) => t - dt);
    _orbitHits.removeWhere((e, t) => t <= 0 || e.dead);
    for (var k = 0; k < d.count; k++) {
      final b = _blade(k, d.count, s.range);
      for (final e in [...game.enemies]) {
        if (e.dead || _orbitHits.containsKey(e)) continue;
        if (e.position.distanceTo(b) < e.r + d.radius) {
          _orbitHits[e] = s.cooldown;
          final crit = _crit(run);
          final dir = (e.x - game.player.x).sign;
          game.hurtEnemy(e, s.dmg * (crit ? 2 : 1), crit, dir * s.knock, fx: s, cls: d.cls);
        }
      }
    }
  }

  @override
  void onRemove() {
    for (final m in _minions) {
      m.removeFromParent();
    }
    super.onRemove();
  }

  @override
  void render(Canvas c) {
    final d = weapon.def;
    if (d.kind == WeaponKind.orbit && game.run != null) {
      final s = game.run!.weaponStats(weapon.id, weapon.tier);
      for (var k = 0; k < d.count; k++) {
        final b = _blade(k, d.count, s.range) - position;
        final a = _orbit + k / d.count * pi * 2 + pi / 2;
        Glow.draw(c, b.x, b.y, 26, d.color.withAlpha(150));
        c.save();
        c.translate(b.x, b.y);
        c.rotate(a);
        drawOval(c, 0, 0, d.length * 0.5, 3.2, Color.lerp(d.color, Colors.white, 0.4)!);
        drawRect(c, -d.length * 0.5, -0.5, d.length, 1, const Color(0xFF7FBFAA));
        c.restore();
      }
    }
    // Eigenes Modell je Waffe; schwebende wippen leicht, die gehaltene schwingt mit dem Flügelschlag
    final bob = held ? sin(game.player.anim) * 0.8 : sin(game.clock * 3 + index) * 1.5;
    final scale = held ? 1.0 : 1.15;
    c.save();
    c.translate(0, bob);
    c.scale(scale);
    if (WeaponArt.upright(weapon.id)) {
      // Rundum- und Henkelwaffen drehen nicht mit, nur Spiegelung nach Blickrichtung
      if (game.player.face < 0) c.scale(-1, 1);
    } else {
      c.rotate(ang);
      if (cos(ang) < 0) c.scale(1, -1);
    }
    WeaponArt.draw(c, weapon.id, kick: kick, t: game.clock + index * 0.7, tier: tiers[weapon.tier].color);
    if (held) WeaponArt.claws(c, const Color(0xFFE08A3A));
    c.restore();
  }
}
