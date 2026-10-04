part of 'enemy.dart';

/// Spawner (Krähennest, Wespennest, Sporenpilz, Käferkönigin, Fäulnisriss) und ihre Kinder.
/// Kinder ([Enemy.child]) lassen kein Material fallen; jeder Spawner hat eine Obergrenze.
extension _Spawners on Enemy {
  /// Lebende Kinder dieses Spawners.
  int get _children => game.enemies.where((e) => !e.dead && identical(e.spawnedBy, this)).length;

  /// Kind mit kurzer Warnung erscheinen lassen.
  void _spawnChild(EnemyType t, Vector2 at, [double warnTime = 0.5]) =>
      game.world.add(SpawnMarker(t, at, warnTime, child: true, spawnedBy: this));

  void _spawnerAi(double dt, Vector2 p, double dx, double dy, double d) {
    switch (type) {
      case EnemyType.crowNest:
        stateT -= dt;
        warn = stateT < 0.6 ? 1 - stateT / 0.6 : 0;
        if (stateT <= 0) {
          stateT = 4;
          if (_children < 3) _spawnChild(EnemyType.crow, position + Vector2(0, -r - 16));
        }
      case EnemyType.waspNest:
        // Schwärmt nur bei Treffern aus (siehe [Enemy.onHit]); pendelt leicht am Faden
        stateT = max(0.0, stateT - dt);
        warn = max(0.0, warn - dt * 3);
      case EnemyType.wasp:
        final wob = sin(t * 11) * spd * 0.7;
        vel.x += (dx / d * spd - dy / d * wob - vel.x) * 5 * dt;
        vel.y += (dy / d * spd + dx / d * wob - vel.y) * 5 * dt;
      case EnemyType.sporeShroom:
        stateT -= dt;
        warn = stateT < 0.7 ? 1 - stateT / 0.7 : 0;
        if (stateT <= 0) {
          stateT = 5;
          if (_children < 9) {
            for (var k = -1; k <= 1; k++) {
              _spawnChild(EnemyType.spore, position + Vector2(k * 22.0, -r - 18 - k.abs() * 6), 0.4);
            }
          }
        }
      case EnemyType.spore:
        vel.x += (dx / d * spd - vel.x) * 1.5 * dt;
        vel.y += (dy / d * spd + sin(t * 3) * 20 - vel.y) * 1.5 * dt;
      case EnemyType.beetleQueen:
        vel.y += 900 * dt;
        vel.x += (dx.sign * spd - vel.x) * 2 * dt;
        stateT -= dt;
        warn = stateT < 0.5 ? 1 - stateT / 0.5 : 0;
        if (stateT <= 0) {
          stateT = 4;
          if (_children < 6) {
            // Ei hinter sich ablegen
            final at = Vector2(clampD(x - dx.sign * (r + 12), 20, game.worldW - 20), kGround - enemyDefs[EnemyType.beetleEgg]!.radius);
            game.queueSpawn(EnemyType.beetleEgg, at, child: true, spawnedBy: this);
          }
        }
      case EnemyType.beetleEgg:
        // Schlüpft nach 2,5 s als Lawinenkäfer (gehört weiter zur Königin)
        if (state == 0) {
          state = 1;
          stateT = 2.5;
        }
        stateT -= dt;
        warn = stateT < 1 ? 1 - stateT : 0;
        if (stateT <= 0) {
          dead = true;
          removeFromParent();
          game.burst(position, const Color(0xFFBFE3FF), 8, 120);
          game.queueSpawn(EnemyType.avalanche, position.clone()..y = kGround - enemyDefs[EnemyType.avalanche]!.radius,
              child: true, spawnedBy: spawnedBy);
        }
      case EnemyType.rift:
        // Bleibt 12 s offen, alle 3 s ein Gegner aus dem Pool der Welle
        if (state == 0) {
          state = 1;
          stateT = 12;
          shootT = 1;
        }
        stateT -= dt;
        shootT -= dt;
        warn = shootT < 0.5 ? 1 - shootT / 0.5 : 0;
        if (shootT <= 0) {
          shootT = 3;
          final pool = spawnPool(game.run!.wave).where((e) {
            final def = enemyDefs[e.$1]!;
            return !def.spawner && !def.stationary;
          }).toList();
          final pick = pool[game.rng.nextInt(pool.length)].$1;
          final def = enemyDefs[pick]!;
          final at = def.flying ? position + Vector2(game.rnd(-40, 40), game.rnd(-30, 30)) : Vector2(x + game.rnd(-40, 40), kGround - def.radius);
          _spawnChild(pick, at, 0.4);
        }
        if (stateT <= 0) {
          // Schließt sich von selbst, ohne Material
          dead = true;
          removeFromParent();
          game.burst(position, const Color(0xFFFF5AE0), 14, 160);
        }
      default:
    }
  }

  /// Wespennest: jeder Treffer (höchstens alle 0,3 s) lässt eine Wespe ausschwärmen, höchstens sechs.
  void _spawnerOnHit() {
    if (type != EnemyType.waspNest || stateT > 0 || _children >= 6) return;
    stateT = 0.3;
    warn = 1;
    _spawnChild(EnemyType.wasp, position + Vector2(game.rnd(-14, 14), r + 6), 0.25);
  }

  // ---------------- Darstellung ----------------

  void _spawnerRender(Canvas c, Color Function(Color) k, double pulse) {
    switch (type) {
      case EnemyType.crowNest:
        EnemyArt.crowNest(c, EnemyLook(t: t, pulse: pulse, warn: warn, hit: flash > 0, state: state, aim: aim), r);
      case EnemyType.waspNest:
        EnemyArt.waspNest(c, EnemyLook(t: t, pulse: pulse, warn: warn, hit: flash > 0, state: state, aim: aim), r);
      case EnemyType.wasp:
        EnemyArt.wasp(c, EnemyLook(t: t, pulse: pulse, warn: warn, hit: flash > 0, state: state, aim: aim), r);
      case EnemyType.sporeShroom:
        EnemyArt.sporeShroom(c, EnemyLook(t: t, pulse: pulse, warn: warn, hit: flash > 0, state: state, aim: aim), r);
      case EnemyType.spore:
        EnemyArt.spore(c, EnemyLook(t: t, pulse: pulse, warn: warn, hit: flash > 0, state: state, aim: aim), r);
      case EnemyType.beetleQueen:
        EnemyArt.beetleQueen(c, EnemyLook(t: t, pulse: pulse, warn: warn, hit: flash > 0, state: state, aim: aim), r);
      case EnemyType.beetleEgg:
        final wob = sin(t * (6 + 20 * warn)) * 0.15 * (0.3 + warn);
        c.save();
        c.rotate(wob);
        drawOval(c, 0, 0, r * 0.8, r, k(const Color(0xFF4A5A70)));
        drawOval(c, -2, -3, r * 0.3, r * 0.4, const Color(0xFFBFE3FF).withAlpha((80 + 120 * warn).round()));
        c.restore();
      case EnemyType.rift:
        // Wie die Spawn-Warnung, nur größer und dauerhaft offen
        final open = 0.8 + 0.2 * sin(t * 4) + 0.3 * warn;
        c.drawOval(Rect.fromCenter(center: Offset.zero, width: r * 1.1 * open, height: r * 2.2 * open), fillOf(const Color(0xFF0A0412)));
        c.drawOval(
            Rect.fromCenter(center: Offset.zero, width: r * 1.1 * open, height: r * 2.2 * open),
            Paint()
              ..style = PaintingStyle.stroke
              ..strokeWidth = 3
              ..color = Color.fromRGBO(255, 110, 160, 0.7 + 0.3 * pulse));
      default:
    }
  }

  /// Fäden der hängenden Spawner.
  void _spawnerRenderUnflipped(Canvas c) {
    if (type == EnemyType.waspNest) {
      c.drawLine(Offset(0, kCeil - y), Offset(0, -r), Paint()
        ..color = const Color(0x88A08060)
        ..strokeWidth = 2);
    }
  }

  void _spawnerGlows(void Function(double, double, double, Color) f, GlowBatch front, double pulse) {
    switch (type) {
      case EnemyType.crowNest:
        f(0, -4, r * 1.4, Enemy._eye.withAlpha((40 + 40 * pulse).round()));
      case EnemyType.waspNest:
        f(0, r * 0.55, 18, const Color(0xFFFFC94A).withAlpha((60 + 60 * pulse).round()));
      case EnemyType.wasp:
        f(0, 0, 14, const Color(0xFFFFC94A).withAlpha(90));
      case EnemyType.sporeShroom:
        f(0, -10, r * 1.6, const Color(0xFF9CFF5A).withAlpha((50 + 60 * max(pulse, warn)).round()));
      case EnemyType.spore:
        f(0, 0, 16, const Color(0xFF9CFF5A).withAlpha(110));
      case EnemyType.beetleQueen:
        f(-r * 0.55, 0, r * 1.2, const Color(0xFFBFE3FF).withAlpha((40 + 50 * pulse).round()));
      case EnemyType.beetleEgg:
        f(0, 0, 18 + 14 * warn, Color.fromRGBO(190, 227, 255, 0.3 + 0.5 * warn));
      case EnemyType.rift:
        front.add(x, y, r * (2.6 + warn), Color.fromRGBO(255, 77, 140, 0.4 + 0.3 * pulse));
        front.add(x, y, r * 1.4, const Color(0x99B44CFF));
      default:
    }
    if (warn > 0 && type != EnemyType.rift) front.add(x, y, r * (1.6 + warn), Color.fromRGBO(255, 240, 220, 0.2 + 0.4 * warn));
  }
}
