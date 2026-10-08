part of 'enemy.dart';

/// Torwächter in Welle 4, 8 und 12 (Pool, je Run ausgelost): versperren das Ziel, bis sie besiegt sind.
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
      case EnemyType.moorGolem:
        _moorGolemAi(dt, p, dx, dy);
      case EnemyType.lanternMan:
        _lanternManAi(dt, p, dx, dy);
      case EnemyType.thornWorm:
        _thornWormAi(dt, p, dx, dy);
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

  /// Moorgolem: Felsbrocken im Bogen; Stampfen schickt Bodenwellen nach links und rechts.
  void _moorGolemAi(double dt, Vector2 p, double dx, double dy) {
    vel.x += (_leash(dx) - vel.x) * 2 * dt;
    vel.y += 900 * dt;
    shootT -= dt;
    if (state == 0 && shootT <= 0) {
      shootT = 2.8;
      const g = 600.0, flight = 1.1;
      final v = Vector2(dx / flight, (dy - 0.5 * g * flight * flight) / flight);
      game.world.add(EnemyBullet(position + Vector2(0, -r * 0.8), v, 11, dmg, const Color(0xFFB8A27A), gravity: g));
    }
    stateT -= dt;
    if (state == 0 && stateT <= 0) {
      state = 1;
      stateT = Enemy.golemStompWarn;
    }
    if (state == 1) {
      // Holt aus (leuchtet auf), dann Stampfer
      warn = 1 - stateT / Enemy.golemStompWarn;
      vel.x *= pow(0.05, dt).toDouble();
      if (stateT <= 0) {
        state = 0;
        stateT = 5.5;
        warn = 0;
        game.shake = max(game.shake, 10);
        for (final dir in [-1.0, 1.0]) {
          game.world.add(GroundWave(Vector2(x + dir * r * 0.8, kGround), dir, dmg * 1.2));
        }
        game.burst(Vector2(x, kGround - 4), const Color(0xFF8A6A4A), 18, 220);
      }
    }
  }

  /// Laternenmann: langsame Irrlicht-Kugeln, ruft Irrlichter, Lichtstrahl (erst Linie, dann
  /// brennend und langsam folgend), verschwindet und taucht an anderer Stelle wieder auf.
  void _lanternManAi(double dt, Vector2 p, double dx, double dy) {
    stateT -= dt;
    switch (state) {
      case 0:
        vel.x += (_leash(dx) * 0.8 - vel.x) * 1.5 * dt;
        vel.y += ((200 + sin(t * 1.1) * 40) - y - vel.y) * 2 * dt;
        shootT -= dt;
        if (shootT <= 0) {
          shootT = 2.4;
          final base = atan2(dy, dx);
          for (var k = -1; k <= 1; k++) {
            final a = base + k * 0.25;
            game.world.add(EnemyBullet(position.clone(), Vector2(cos(a), sin(a)) * 150, 8, dmg - 1, const Color(0xFFB8FF9A)));
          }
        }
        summonT -= dt;
        if (summonT <= 0) {
          summonT = 10;
          for (final side in [-1.0, 1.0]) {
            game.world.add(SpawnMarker(EnemyType.wisp, Vector2(x + side * 120, y + game.rnd(-40, 60)), 0.8));
          }
        }
        jumpT -= dt;
        if (jumpT <= 0) {
          jumpT = 7;
          game.world.add(LanternBeam(this, atan2(dy, dx)));
        }
        if (stateT <= 0) {
          state = 1;
          stateT = Enemy.lanternFade;
        }
      case 1: // verblasst
        vel.scale(pow(0.05, dt).toDouble());
        warn = 1 - stateT / Enemy.lanternFade;
        if (stateT <= 0) {
          final side = x < home.x ? 1.0 : -1.0;
          position.setValues(clampD(home.x + side * game.rnd(120, 220), r, game.worldW - r), game.rnd(170, 260));
          game.burst(position, const Color(0xFFFFE6A0), 16, 200);
          for (var k = 0; k < 6; k++) {
            final a = k / 6 * pi * 2 + t;
            game.world.add(EnemyBullet(position.clone(), Vector2(cos(a), sin(a)) * 140, 7, dmg - 1, const Color(0xFFB8FF9A)));
          }
          state = 2;
          stateT = Enemy.lanternFade;
          warn = 0;
        }
      default: // taucht wieder auf
        if (stateT <= 0) {
          state = 0;
          stateT = 9;
        }
    }
  }

  /// Sichtbarkeit des Laternenmanns beim Verschwinden/Auftauchen.
  double get lanternAlpha => switch (state) {
        1 => clampD(stateT / Enemy.lanternFade, 0, 1),
        2 => clampD(1 - stateT / Enemy.lanternFade, 0, 1),
        _ => 1,
      };

  /// Dornenwurm: gräbt sich unter der Erde heran (Treffer prallen ab), Risse im Boden warnen,
  /// dann bricht er hervor (Schaden nah am Boden, Dornenfächer), schießt gezielte Dornen, taucht ab.
  void _thornWormAi(double dt, Vector2 p, double dx, double dy) {
    vel.y += 900 * dt;
    stateT -= dt;
    switch (state) {
      case 0: // gräbt sich zum Spieler (innerhalb seines Reviers)
        final tx = clampD(p.x, home.x - 420, home.x + 220);
        vel.x += (((tx - x).abs() > 8 ? (tx - x).sign : 0) * spd - vel.x) * 3 * dt;
        warn = 0;
        if ((tx - x).abs() < 30 || stateT <= 0) {
          state = 1;
          stateT = Enemy.wormWarn;
        }
      case 1: // Risse im Boden
        vel.x = 0;
        warn = 1 - stateT / Enemy.wormWarn;
        if (stateT <= 0) {
          state = 2;
          stateT = Enemy.wormUp;
          warn = 0;
          game.shake = max(game.shake, 8);
          game.burst(Vector2(x, kGround - 6), const Color(0xFF8A6A4A), 24, 260);
          final pl = game.player;
          if ((pl.x - x).abs() < r + 34 && pl.y > kGround - 170) game.hurtPlayer(dmg * 1.5, source: this);
          for (var k = 0; k < 7; k++) {
            final a = -pi / 2 + (k / 6 - 0.5) * 1.8;
            game.world.add(EnemyBullet(position - Vector2(0, r * 0.6), Vector2(cos(a), sin(a)) * 260, 7, dmg - 1,
                const Color(0xFFC8D070)));
          }
          shootT = 1.0;
        }
      case 2: // oben: gezielte Dornen
        vel.x *= pow(0.05, dt).toDouble();
        shootT -= dt;
        if (shootT <= 0) {
          shootT = 0.9;
          final base = atan2(dy + r, dx);
          for (var k = -1; k <= 1; k++) {
            final a = base + k * 0.18;
            game.world.add(EnemyBullet(position - Vector2(0, r), Vector2(cos(a), sin(a)) * 240, 7, dmg - 1,
                const Color(0xFFC8D070)));
          }
        }
        if (stateT <= 0) {
          state = 3;
          stateT = Enemy.wormSink;
        }
      default: // taucht ab
        vel.x = 0;
        if (stateT <= 0) {
          state = 0;
          stateT = 3.5;
        }
    }
  }

  /// Wie weit der Dornenwurm aus dem Boden ragt (0–1).
  double get wormRise => switch (state) {
        2 => clampD((Enemy.wormUp - stateT) / 0.25, 0, 1),
        3 => clampD(stateT / Enemy.wormSink, 0, 1),
        _ => 0,
      };

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
      case EnemyType.moorGolem:
        BossArt.moorGolem(c, look, r);
      case EnemyType.lanternMan:
        final a = lanternAlpha;
        if (a < 1) c.saveLayer(null, Paint()..color = Color.fromRGBO(0, 0, 0, a));
        BossArt.lanternMan(c, look, r);
        if (a < 1) c.restore();
      case EnemyType.thornWorm:
        BossArt.thornWorm(
            c,
            BossLook(t: t, pulse: pulse, warn: warn, hit: flash > 0, state: state, rise: wormRise),
            r);
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
    // Dornenwurm: Risse im Boden über ihm, bevor er hervorbricht
    if (type == EnemyType.thornWorm && state == 1) {
      final gy = kGround - y;
      final p = Paint()
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round
        ..strokeWidth = 1.5 + 2 * warn
        ..color = Color.fromRGBO(200, 208, 112, 0.4 + 0.5 * warn);
      for (var k = 0; k < 5; k++) {
        final a = -pi + (k + 0.5) / 5 * pi;
        final len = (r + 20) * (0.4 + 0.6 * warn);
        c.drawLine(Offset(0, gy), Offset(cos(a) * len, gy + sin(a) * len * 0.25), p);
      }
      Glow.draw(c, 0, gy, r * (1 + warn), Color.fromRGBO(200, 208, 112, 0.25 + 0.4 * warn));
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
      case EnemyType.moorGolem:
        f(r * 0.3, -r * 0.5, 12, Enemy._ember.withAlpha((90 + 60 * max(pulse, warn)).round()));
        f(0, r * 0.1, r * 0.9, const Color(0xFF6A8A3A).withAlpha((30 + 40 * warn).round()));
      case EnemyType.lanternMan:
        final a = lanternAlpha;
        f(r * 0.7, r * 0.35, 46, const Color(0xFFFFE6A0).withAlpha(((70 + 50 * pulse) * a).round()));
        f(r * 0.7, r * 0.35, 14, const Color(0xFFFFF4D0).withAlpha((200 * a).round()));
      case EnemyType.thornWorm:
        if (wormRise > 0.3) f(r * 0.35, -r * 0.7 * wormRise, 14, const Color(0xFFC8D070).withAlpha((120 * wormRise).round()));
      default:
    }
    if (warn > 0) front.add(x, y, r * (1.6 + warn), Color.fromRGBO(255, 240, 220, 0.2 + 0.4 * warn));
  }
}

/// Bodenwelle des Moorgolems: läuft am Boden entlang; trifft nur, wer tief fliegt.
class GroundWave extends PositionComponent with HasGameReference<FederfeuerGame>, Transient, CombatEffect {
  GroundWave(Vector2 pos, this.dir, this.dmg) : super(position: pos, priority: 13);
  final double dir, dmg;
  static const speed = 340.0, crest = 46.0, range = 900.0;
  double travelled = 0;
  bool _hit = false;

  @override
  void update(double dt) {
    if (!game.playing || game.freezeT > 0) return;
    final s = speed * dt;
    position.x += dir * s;
    travelled += s;
    final pl = game.player;
    if (!_hit && (pl.x - x).abs() < 22 + pl.r * 0.5 && pl.y + pl.r > kGround - crest) {
      game.hurtPlayer(dmg);
      _hit = true;
    }
    if (travelled > range || x < 0 || x > game.worldW) removeFromParent();
  }

  @override
  void render(Canvas c) {
    final a = clampD(1 - travelled / range, 0, 1);
    final shape = Path()
      ..moveTo(-34, 0)
      ..quadraticBezierTo(-10, -crest * 1.1, dir * 8, -crest)
      ..quadraticBezierTo(18, -crest * 0.4, 34, 0)
      ..close();
    c.drawPath(shape, Paint()..color = Color.fromRGBO(42, 30, 22, 0.85 * a));
    c.drawPath(
        shape,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2
          ..blendMode = BlendMode.plus
          ..color = Color.fromRGBO(255, 138, 61, 0.7 * a));
    Glow.draw(c, dir * 4, -crest * 0.7, 30, Color.fromRGBO(255, 138, 61, 0.45 * a));
    for (var k = 1; k <= 3; k++) {
      c.drawCircle(Offset(-dir * (14.0 + k * 12), -6.0 - k * 3), 4.0 - k, Paint()..color = Color.fromRGBO(120, 96, 70, 0.6 * a));
    }
  }
}

/// Lichtstrahl des Laternenmanns: zuerst eine feine Warnlinie, dann brennt er und dreht
/// langsam zum Spieler; Treffer höchstens alle 0,5 s.
class LanternBeam extends Component with HasGameReference<FederfeuerGame>, Transient, CombatEffect {
  LanternBeam(this.owner, this.angle) : super(priority: 16);
  final Enemy owner;
  double angle;
  double t = 0, _tick = 0;
  static const warnTime = 1.0, burnTime = 1.6, length = 900.0, width = 18.0, turn = 0.45;

  Offset get _origin => Offset(owner.x + owner.r * 0.7 * owner.face, owner.y + owner.r * 0.35);

  @override
  void update(double dt) {
    if (!game.playing) return;
    if (owner.dead || owner.state != 0) {
      removeFromParent();
      return;
    }
    t += dt;
    if (t > warnTime) {
      final o = _origin, pl = game.player;
      final want = atan2(pl.y - o.dy, pl.x - o.dx);
      var diff = want - angle;
      while (diff > pi) {
        diff -= 2 * pi;
      }
      while (diff < -pi) {
        diff += 2 * pi;
      }
      angle += clampD(diff, -turn * dt, turn * dt);
      _tick -= dt;
      final dir = Offset(cos(angle), sin(angle));
      final rel = Offset(pl.x - o.dx, pl.y - o.dy);
      final along = clampD(rel.dx * dir.dx + rel.dy * dir.dy, 0, length);
      final dist = (rel - dir * along).distance;
      if (_tick <= 0 && dist < width / 2 + pl.r) {
        game.hurtPlayer(owner.dmg, source: owner);
        _tick = 0.5;
      }
    }
    if (t > warnTime + burnTime) removeFromParent();
  }

  @override
  void render(Canvas c) {
    final o = _origin, end = o + Offset(cos(angle), sin(angle)) * length;
    if (t < warnTime) {
      final k = t / warnTime;
      c.drawLine(
          o,
          end,
          Paint()
            ..strokeWidth = 1.2 + 2 * k
            ..blendMode = BlendMode.plus
            ..color = Color.fromRGBO(255, 230, 160, 0.25 + 0.45 * k * (0.6 + 0.4 * sin(t * 30))));
      return;
    }
    final fade = clampD((warnTime + burnTime - t) / 0.25, 0, 1);
    c.drawLine(
        o,
        end,
        Paint()
          ..strokeWidth = width * 1.9
          ..strokeCap = StrokeCap.round
          ..blendMode = BlendMode.plus
          ..color = Color.fromRGBO(255, 214, 120, 0.3 * fade));
    c.drawLine(
        o,
        end,
        Paint()
          ..strokeWidth = width * 0.55
          ..strokeCap = StrokeCap.round
          ..blendMode = BlendMode.plus
          ..color = Color.fromRGBO(255, 246, 220, 0.9 * fade));
    Glow.draw(c, o.dx, o.dy, 40, Color.fromRGBO(255, 230, 160, 0.7 * fade));
  }
}
