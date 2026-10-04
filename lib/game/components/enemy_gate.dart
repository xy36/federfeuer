part of 'enemy.dart';

/// Torwächter am Ende von Felder, Dorf und Wald: versperren das Ziel, bis sie besiegt sind.
/// Wie bei den Welt-Gegnern kündigt [Enemy.warn] Angriffe an.
extension _Gatekeepers on Enemy {
  void _gateAi(double dt, Vector2 p, double dx, double dy, double d) {
    switch (type) {
      case EnemyType.strawKing:
        _strawKingAi(dt, p, dx, dy);
      case EnemyType.bell:
        _bellAi(dt, p, dx, dy, d);
      case EnemyType.spiderMother:
        _spiderMotherAi(dt, p, dx, dy, d);
      default:
    }
  }

  /// Bleibt in der Nähe seines Platzes vor dem Ziel.
  double _leash(double dx) => (home.x + dx.clamp(-220, 220) - x).clamp(-spd, spd);

  void _strawKingAi(double dt, Vector2 p, double dx, double dy) {
    vel.x += (_leash(dx) - vel.x) * 2 * dt;
    vel.y += 900 * dt;
    // Strohfächer: drei brennende Bündel mit unterschiedlicher Flugzeit
    shootT -= dt;
    warn = shootT < 0.6 ? 1 - shootT / 0.6 : 0;
    if (shootT <= 0) {
      shootT = 2.6;
      const g = 520.0;
      for (final flight in [0.8, 1.05, 1.3]) {
        final tx = dx + (flight - 1.05) * 260;
        final v = Vector2(tx / flight, (dy - 0.5 * g * flight * flight) / flight);
        game.world.add(EnemyBullet(position + Vector2(0, -r), v, 8, dmg, const Color(0xFFFF8A3D), gravity: g));
      }
    }
    // Ruft Krähen
    summonT -= dt;
    if (summonT <= 0) {
      summonT = 8;
      for (var k = 0; k < 2; k++) {
        game.world.add(SpawnMarker(EnemyType.crow, Vector2(x + game.rnd(-120, 120), kCeil + 80 + game.rnd(0, 80)), 0.8));
      }
    }
  }

  void _bellAi(double dt, Vector2 p, double dx, double dy, double d) {
    vel.x += (_leash(dx) - vel.x) * 1.5 * dt;
    vel.y += ((190 + sin(t * 1.4) * 30) - y - vel.y) * 2 * dt;
    // Kugelring, jedes Mal leicht gedreht
    shootT -= dt;
    if (shootT <= 0) {
      shootT = 2.2;
      aim += 0.3;
      for (var k = 0; k < 10; k++) {
        final a = aim + k / 10 * pi * 2;
        game.world.add(EnemyBullet(position.clone(), Vector2(cos(a), sin(a)) * 170, 6, dmg - 1, const Color(0xFFFFC94A)));
      }
    }
    // Glockenschlag: Warnkreis, dann Schaden im ganzen Kreis
    stateT -= dt;
    if (state == 0 && stateT <= 0) {
      state = 1;
      stateT = 1.0;
    }
    if (state == 1) {
      warn = 1 - stateT / 1.0;
      if (stateT <= 0) {
        state = 0;
        stateT = 6;
        warn = 0;
        game.world.add(Ring(position.clone(), Enemy.bellRadius, color: const Color(0xFFFFC94A)));
        game.shake = max(game.shake, 9);
        if (d < Enemy.bellRadius) game.hurtPlayer(dmg * 1.5, source: this);
      }
    }
  }

  void _spiderMotherAi(double dt, Vector2 p, double dx, double dy, double d) {
    vel.x += (_leash(dx) * 1.4 - vel.x) * 2 * dt;
    stateT -= dt;
    switch (state) {
      case 0: // Hängt oben, schießt Netzfächer, ruft Spinnen
        vel.y += ((kCeil + r + 30) - y - vel.y) * 3 * dt;
        warn = 0;
        shootT -= dt;
        if (shootT <= 0) {
          shootT = 2.6;
          final base = atan2(dy, dx);
          for (var k = -1; k <= 1; k++) {
            final a = base + k * 0.28;
            game.world.add(EnemyBullet(position.clone(), Vector2(cos(a), sin(a)) * 210, 8, dmg * 0.5,
                const Color(0xFFE6E6F2), web: true));
          }
        }
        summonT -= dt;
        if (summonT <= 0) {
          summonT = 7;
          for (final side in [-1.0, 1.0]) {
            game.world.add(SpawnMarker(EnemyType.spider, Vector2(x + side * 140, kCeil + 30), 0.8));
          }
        }
        if (stateT <= 0) {
          state = 1;
          stateT = 0.8;
        }
      case 1: // Warnung vor dem Fall
        vel.x *= pow(0.05, dt).toDouble();
        vel.y = 0;
        warn = 1 - stateT / 0.8;
        if (stateT <= 0) {
          state = 2;
          stateT = 1.2;
        }
      case 2: // Lässt sich fallen
        warn = 0;
        vel.y = 520;
        if (y >= kGround - r - 2 || stateT <= 0) {
          state = 3;
          stateT = 1.0;
          game.shake = max(game.shake, 6);
        }
      default: // Klettert zurück
        vel.y = -260;
        if (y <= kCeil + r + 30 || stateT <= 0) {
          state = 0;
          stateT = 9;
        }
    }
  }

  // ---------------- Darstellung ----------------

  void _gateRender(Canvas c, Color Function(Color) k, double pulse) {
    final look = _bossLook(flash > 0, pulse);
    switch (type) {
      case EnemyType.strawKing:
        BossArt.strawKing(c, look, r);
      case EnemyType.bell:
        BossArt.bell(c, look, r);
      case EnemyType.spiderMother:
        BossArt.spiderMother(c, look, r);
      default:
    }
  }

  void _gateRenderUnflipped(Canvas c) {
    // Faden bzw. Kette nach oben
    if (type == EnemyType.spiderMother || type == EnemyType.bell) {
      c.drawLine(Offset(0, kCeil - y), Offset(0, -r), Paint()
        ..color = type == EnemyType.bell ? const Color(0xAA4A3A5A) : const Color(0x88E6E6F2)
        ..strokeWidth = type == EnemyType.bell ? 3 : 1.5);
    }
    // Warnkreis des Glockenschlags
    if (type == EnemyType.bell && state == 1) {
      c.drawCircle(Offset.zero, Enemy.bellRadius, Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2 + 3 * warn
        ..color = Color.fromRGBO(255, 201, 74, 0.3 + 0.6 * warn));
      c.drawCircle(Offset.zero, Enemy.bellRadius, fillOf(Color.fromRGBO(255, 201, 74, 0.06 + 0.1 * warn)));
    }
  }

  void _gateGlows(void Function(double, double, double, Color) f, GlowBatch front, double pulse) {
    switch (type) {
      case EnemyType.strawKing:
        f(0, -32, 30, Enemy._ember.withAlpha((60 + 50 * max(pulse, warn)).round()));
      case EnemyType.bell:
        f(0, 0, r * 1.6, const Color(0xFFFFC94A).withAlpha((40 + 60 * max(pulse * 0.5, warn)).round()));
      case EnemyType.spiderMother:
        f(16, -12, 18, Enemy._eye.withAlpha((70 + 50 * pulse).round()));
      default:
    }
    if (warn > 0) front.add(x, y, r * (1.6 + warn), Color.fromRGBO(255, 240, 220, 0.2 + 0.4 * warn));
  }
}
