import 'dart:math';

import 'package:flame/components.dart';
import 'package:flutter/material.dart';

import '../config.dart';
import '../federfeuer_game.dart';
import 'draw.dart';
import 'enemy.dart';
import 'light.dart';
import 'transient.dart';

/// Material (Geld + XP), Herz (Heilung) oder Geschenk der Elster (zufälliges Item).
class Drop extends PositionComponent with HasGameReference<FederfeuerGame>, Transient {
  Drop(Vector2 pos, {required this.material, required Random rng, this.fallSpeed = 70, this.gift = false, this.value = 1})
      : vel = Vector2((rng.nextDouble() - 0.5) * 80, material ? -20 - rng.nextDouble() * 60 : -60),
        _phase = rng.nextDouble() * 6.28,
        super(position: pos, priority: 1);

  final bool material, gift;

  /// Wert eines Material-Kristalls (1, 3, 5, 10) – bestimmt Farbe und Größe.
  final int value;

  /// Höchste Sinkgeschwindigkeit (je Schwierigkeit); 0 = schwebt am Todesort.
  final double fallSpeed;
  final Vector2 vel;
  final double _phase;
  double _t = 0;
  bool taken = false, _pulled = false;

  /// Schon im Sammelradius erfasst und auf dem Weg zum Spieler.
  bool get pulled => _pulled;

  /// Wirbelsturm: fliegt sofort zum Spieler.
  void pull() => _pulled = true;

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
    } else if (fallSpeed > 0) {
      // Beschleunigung passend zur Endgeschwindigkeit, damit langsame Drops sanft absinken
      vel.y = min(vel.y + fallSpeed * 4.3 * dt, fallSpeed * game.weather.dropFallFactor);
      vel.x *= pow(0.1, dt);
      position.x += vel.x * dt;
      position.y = min(kGround - 5, y + vel.y * dt);
    } else {
      // Kurzer Sprung beim Tod, dann schwebend mit leichtem Wippen
      _t += dt;
      final damp = pow(0.02, dt).toDouble();
      vel.scale(damp);
      position.x += vel.x * dt;
      position.y = clampD(y + vel.y * dt + cos(_t * 2.2 + _phase) * 6 * dt, kCeil + 12, kGround - 5);
    }
    if (dist < game.player.r + 8) {
      taken = true;
      if (gift) {
        game.giveGift();
      } else if (material) {
        game.gain(value);
      } else {
        game.healHeart();
      }
      removeFromParent();
    }
  }

  @override
  void render(Canvas c) {
    final pulse = 0.75 + 0.25 * sin(game.clock * 5 + x * 0.1);
    if (gift) {
      // Geschenk: blaues Päckchen mit Schleife
      Glow.draw(c, 0, 0, 26, const Color(0xFF9FD4FF).withAlpha((170 * pulse).round()));
      drawRect(c, -6, -5, 12, 10, const Color(0xFF5A9BFF));
      drawRect(c, -1.5, -5, 3, 10, const Color(0xFFFFE066));
      drawRect(c, -6, -1.5, 12, 3, const Color(0xFFFFE066));
      drawCircle(c, -2.5, -7, 2.4, const Color(0xFFFFE066));
      drawCircle(c, 2.5, -7, 2.4, const Color(0xFFFFE066));
    } else if (material) {
      // Leuchtender Kristall; wertvollere sind größer und andersfarbig
      final col = materialColor(value);
      final sz = value >= 10 ? 7.0 : (value >= 5 ? 6.0 : (value >= 3 ? 5.0 : 4.0));
      Glow.draw(c, 0, 0, 14 + sz, col.withAlpha((150 * pulse).round()));
      c.save();
      c.rotate(pi / 4);
      drawRect(c, -sz, -sz, sz * 2, sz * 2, col);
      drawRect(c, -sz / 2, -sz / 2, sz, sz, Colors.white);
      c.restore();
    } else {
      Glow.draw(c, 0, 1, 24, Palette.coral.withAlpha((160 * pulse).round()));
      drawCircle(c, -3, -2, 4, const Color(0xFFFF8FA0));
      drawCircle(c, 3, -2, 4, const Color(0xFFFF8FA0));
      drawTri(c, -7, 0, 7, 0, 0, 8, const Color(0xFFFF8FA0));
      drawCircle(c, -3, -3, 1.6, Colors.white);
    }
  }
}

/// Rotes X, das kurz vor dem Erscheinen eines Gegners warnt.
class SpawnMarker extends PositionComponent with HasGameReference<FederfeuerGame>, Transient {
  SpawnMarker(this.type, Vector2 pos, this.t, {this.child = false, this.spawnedBy})
      : super(position: pos, priority: 2);

  final EnemyType type;

  /// Kind eines Spawners (kein Material, zählt zu dessen Obergrenze).
  final bool child;
  final Enemy? spawnedBy;
  double t;
  final _paint = Paint()
    ..style = PaintingStyle.stroke
    ..strokeWidth = 3;

  @override
  void update(double dt) {
    if (!game.playing) return;
    t -= dt;
    if (t <= 0) {
      if (child) {
        game.addEnemy(type, position.clone(), child: true, spawnedBy: spawnedBy);
      } else {
        game.spawnEnemy(type, position.clone());
      }
      removeFromParent();
    }
  }

  @override
  void render(Canvas c) {
    // Fäulnis-Riss: pulsierender dunkler Kern mit violett-rotem Leuchten, der sich öffnet
    final big = kFinalBosses.contains(type);
    final s = big ? 34.0 : 13.0;
    final open = 1 - clampD(t / (big ? 2 : 0.9), 0, 1);
    final a = 0.55 + 0.45 * sin(t * 18);
    Glow.draw(c, 0, 0, s * (2.4 + open), Color.fromRGBO(255, 77, 140, 0.55 * a));
    Glow.draw(c, 0, 0, s * 1.4, Color.fromRGBO(180, 76, 255, 0.6));
    c.drawOval(Rect.fromCenter(center: Offset.zero, width: s * (0.8 + open), height: s * (1.6 + open * 0.8)), fillOf(const Color(0xFF0A0412)));
    _paint
      ..color = Color.fromRGBO(255, 110, 160, a)
      ..blendMode = BlendMode.plus;
    c.drawOval(Rect.fromCenter(center: Offset.zero, width: s * (0.8 + open), height: s * (1.6 + open * 0.8)), _paint);
  }
}
