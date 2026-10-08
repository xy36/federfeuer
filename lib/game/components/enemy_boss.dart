part of 'enemy.dart';

/// Endbosse in drei Phasen (Wechsel bei 66 % und 33 % HP). Der Geierkönig:
/// 1. Federfächer und Krähenruf, 2. dazu Federregen von oben, 3. dazu Sturzflüge quer durchs Bild,
/// alles schneller. Jeder Phasenwechsel wird mit Beben, Funken und Text angekündigt.
extension _Boss on Enemy {
  void _bossAi(double dt, Vector2 p, double dx, double dy) {
    _bossPhaseCheck();
    if (state == 1 || state == 2) {
      _bossDive(dt, p);
      return;
    }
    vel.x += (dx.sign * spd * (dx.abs() > 120 ? 1 : 0) - vel.x) * dt;
    vel.y += ((170 + sin(t * 0.8) * 90) - y - vel.y) * 1.5 * dt;

    // Federfächer: in Phase 3 breiter und schneller
    shootT -= dt;
    if (shootT <= 0) {
      shootT = bossPhase == 3 ? 1.1 : 1.5;
      final n = bossPhase == 3 ? 9 : 7;
      final base = atan2(dy, dx);
      for (var k = 0; k < n; k++) {
        final a = base + (k / (n - 1) - 0.5) * (bossPhase == 3 ? 1.3 : 1);
        game.world.add(EnemyBullet(position.clone(), Vector2(cos(a), sin(a))..scale(220), 7, dmg - 2, Palette.coral));
      }
    }
    // Krähenruf
    summonT -= dt;
    if (summonT <= 0) {
      summonT = bossPhase == 3 ? 4 : 6;
      for (var k = 0; k < 3; k++) {
        game.world.add(SpawnMarker(
          EnemyType.crow,
          Vector2(clampD(x + game.rnd(-90, 90), 40, game.worldW - 40), clampD(y + game.rnd(-40, 60), kCeil + 40, kGround - 60)),
          0.6,
        ));
      }
    }
    // Federregen ab Phase 2
    if (bossPhase >= 2) {
      jumpT -= dt;
      if (jumpT <= 0) {
        jumpT = bossPhase == 3 ? 4 : 5;
        game.world.add(FeatherRain(game.camX, game.viewW, dmg - 1, bossPhase == 3 ? 8 : 6));
      }
    }
    // Sturzflug ab Phase 3
    if (bossPhase == 3) {
      stateT -= dt;
      if (stateT <= 0) {
        state = 1;
        stateT = 0.9;
        target.setFrom(p);
      }
    }
  }

  /// Sturzflug: kurz innehalten und leuchten, dann quer durchs Bild auf Höhe des Spielers.
  void _bossDive(double dt, Vector2 p) {
    stateT -= dt;
    if (state == 1) {
      vel.scale(pow(0.02, dt).toDouble());
      warn = 1 - stateT / 0.9;
      if (stateT <= 0) {
        state = 2;
        stateT = 1.4;
        aim = (target.x - x).sign == 0 ? 1 : (target.x - x).sign;
        vel.setValues(aim * 680, (target.y - y) * 1.6);
      }
    } else {
      warn = 0;
      vel.y *= pow(0.2, dt).toDouble();
      if (stateT <= 0 || x <= r + 2 || x >= game.worldW - r - 2) {
        state = 0;
        stateT = 7;
      }
    }
  }

  void _bossPhaseCheck() {
    final phase = hp > maxHp * 0.66 ? 1 : (hp > maxHp * 0.33 ? 2 : 3);
    if (phase <= bossPhase) return;
    bossPhase = phase;
    final phoenix = type == EnemyType.ashPhoenix;
    final col = phoenix ? Enemy._ember : Enemy._crown;
    game.shake = max(game.shake, 16);
    game.burst(position, col, 50, 320);
    final text = phoenix
        ? (phase == 2 ? 'DER PHÖNIX LODERT!' : 'AUS DER ASCHE!')
        : (phase == 2 ? 'DER GEIERKÖNIG TOBT!' : 'LETZTE KRAFT!');
    game.floatText(position - Vector2(0, r + 30), text, col, 22);
    jumpT = 1.5;
    stateT = 2;
  }

  /// Der Aschephönix: 1. Glutbögen und Glutkäfer, 2. dazu Flammensäulen an markierten Stellen,
  /// 3. dazu Feuerwände mit nur einer Lücke; alles schneller.
  void _phoenixAi(double dt, Vector2 p, double dx, double dy) {
    _bossPhaseCheck();
    vel.x += (dx.sign * spd * (dx.abs() > 160 ? 1 : 0) - vel.x) * dt;
    vel.y += ((180 + sin(t * 0.9) * 80) - y - vel.y) * 1.5 * dt;
    // Glutbögen: mehrere brennende Kugeln im Bogen, verteilt um den Spieler
    shootT -= dt;
    warn = shootT < 0.4 ? 1 - shootT / 0.4 : 0;
    if (shootT <= 0) {
      shootT = bossPhase == 3 ? 1.4 : 1.9;
      const g = 420.0;
      final n = bossPhase == 1 ? 4 : 5;
      for (var k = 0; k < n; k++) {
        final flight = 0.9 + k * 0.18;
        final tx = dx + (k - (n - 1) / 2) * 90;
        final v = Vector2(tx / flight, (dy - 0.5 * g * flight * flight) / flight);
        game.world.add(EnemyBullet(position.clone(), v, 8, dmg - 2, Enemy._ember, gravity: g));
      }
    }
    // Glutkäfer
    summonT -= dt;
    if (summonT <= 0) {
      summonT = bossPhase == 3 ? 5 : 7;
      for (var k = 0; k < 2; k++) {
        final bx = clampD(x + game.rnd(-220, 220), 40, game.worldW - 40);
        game.world.add(SpawnMarker(EnemyType.beetle, Vector2(bx, kGround - enemyDefs[EnemyType.beetle]!.radius), 0.7));
      }
    }
    // Flammensäulen ab Phase 2
    if (bossPhase >= 2) {
      jumpT -= dt;
      if (jumpT <= 0) {
        jumpT = bossPhase == 3 ? 5.5 : 6.5;
        game.world.add(FlamePillars(game.camX, game.viewW, game.player.x, dmg, bossPhase == 3 ? 4 : 3));
      }
    }
    // Feuerwand ab Phase 3
    if (bossPhase == 3) {
      stateT -= dt;
      if (stateT <= 0) {
        stateT = 7;
        game.world.add(FireWall(game.camX, game.viewW, dmg - 1, fromLeft: game.player.x > x));
      }
    }
  }

  void _phoenixGlows(void Function(double, double, double, Color) f, GlowBatch front, double pulse) {
    f(0, 0, r * 1.6, Enemy._ember.withAlpha((70 + 50 * pulse).round()));
    f(r * 0.55, -r * 0.55, 10, const Color(0xFFFFE6A0).withAlpha(230));
    f(-r * 0.9, -r * 0.2, r * 0.8, const Color(0xFFFF5A2A).withAlpha((40 + 40 * pulse).round()));
    if (warn > 0) front.add(x, y, r * (1.4 + warn), Color.fromRGBO(255, 200, 120, 0.2 + 0.4 * warn));
  }
}

/// Federregen: Warnlinien an mehreren Stellen im Bild, dann fallen dort Federn von oben.
class FeatherRain extends Component with HasGameReference<FederfeuerGame>, Transient, CombatEffect {
  FeatherRain(double camX, double viewW, this.dmg, int count) : super(priority: 17) {
    final rng = Random();
    for (var i = 0; i < count; i++) {
      xs.add(camX + (i + 0.2 + rng.nextDouble() * 0.6) * viewW / count);
    }
  }

  final double dmg;
  final xs = <double>[];
  static const warnTime = 0.8;
  double t = warnTime;

  @override
  void update(double dt) {
    if (!game.playing) return;
    t -= dt;
    if (t > 0) return;
    for (final x in xs) {
      game.world.add(EnemyBullet(Vector2(x, kCeil + 4), Vector2(0, 330), 7, dmg, const Color(0xFFFF5AE0)));
    }
    removeFromParent();
  }

  @override
  void render(Canvas c) {
    final k = 1 - t / warnTime;
    final p = Paint()
      ..strokeWidth = 2 + 4 * k
      ..color = Color.fromRGBO(255, 90, 224, 0.15 + 0.35 * k);
    for (final x in xs) {
      c.drawLine(Offset(x, kCeil), Offset(x, kGround), p);
      Glow.draw(c, x, kCeil + 10, 16 + 10 * k, Color.fromRGBO(255, 90, 224, 0.4 + 0.4 * k));
    }
  }
}

/// Flammensäulen des Aschephönix: Glutflecken am Boden warnen, dann lodern dort Säulen
/// über die ganze Höhe (eine immer beim Spieler).
class FlamePillars extends Component with HasGameReference<FederfeuerGame>, Transient, CombatEffect {
  FlamePillars(double camX, double viewW, double playerX, this.dmg, int count) : super(priority: 17) {
    final rng = Random();
    xs.add(playerX);
    for (var i = 1; i < count; i++) {
      xs.add(camX + 60 + rng.nextDouble() * (viewW - 120));
    }
  }

  final double dmg;
  final xs = <double>[];
  static const warnTime = 1.0, burnTime = 0.9, halfWidth = 34.0;
  double t = 0;
  bool _hit = false;

  @override
  void update(double dt) {
    if (!game.playing) return;
    t += dt;
    if (t > warnTime && !_hit) {
      final pl = game.player;
      if (xs.any((x) => (pl.x - x).abs() < halfWidth + pl.r * 0.5)) {
        game.hurtPlayer(dmg);
        _hit = true;
      }
    }
    if (t > warnTime + burnTime) removeFromParent();
  }

  @override
  void render(Canvas c) {
    if (t < warnTime) {
      final k = t / warnTime;
      for (final x in xs) {
        Glow.draw(c, x, kGround - 6, halfWidth * (1 + k), Color.fromRGBO(255, 120, 50, 0.3 + 0.5 * k));
        c.drawLine(
            Offset(x, kCeil),
            Offset(x, kGround),
            Paint()
              ..strokeWidth = 1 + 2 * k
              ..blendMode = BlendMode.plus
              ..color = Color.fromRGBO(255, 138, 61, 0.15 + 0.3 * k));
      }
      return;
    }
    final k = clampD((warnTime + burnTime - t) / 0.3, 0, 1);
    for (final x in xs) {
      final rect = Rect.fromLTRB(x - halfWidth, kCeil, x + halfWidth, kGround);
      c.drawRect(
          rect,
          Paint()
            ..blendMode = BlendMode.plus
            ..shader = LinearGradient(
              colors: [
                Color.fromRGBO(255, 90, 30, 0),
                Color.fromRGBO(255, 138, 61, 0.55 * k),
                Color.fromRGBO(255, 230, 160, 0.8 * k),
                Color.fromRGBO(255, 138, 61, 0.55 * k),
                Color.fromRGBO(255, 90, 30, 0),
              ],
              stops: const [0, 0.25, 0.5, 0.75, 1],
            ).createShader(rect));
      Glow.draw(c, x, kGround - 20, halfWidth * 2.2, Color.fromRGBO(255, 160, 80, 0.6 * k));
    }
  }
}

/// Feuerwand des Aschephönix: am Bildrand zeigt eine Linie mit hell markierter Lücke an,
/// dann rast eine Wand aus Glutkugeln quer durchs Bild – nur durch die Lücke kommt man durch.
class FireWall extends Component with HasGameReference<FederfeuerGame>, Transient, CombatEffect {
  FireWall(double camX, double viewW, this.dmg, {required this.fromLeft}) : super(priority: 17) {
    x = fromLeft ? camX + 14 : camX + viewW - 14;
    gapY = kCeil + 90 + Random().nextDouble() * (kGround - kCeil - 180);
  }

  final double dmg;
  final bool fromLeft;
  late final double x, gapY;
  static const warnTime = 1.1, gap = 150.0, speed = 280.0, step = 34.0;
  double t = warnTime;

  @override
  void update(double dt) {
    if (!game.playing) return;
    t -= dt;
    if (t > 0) return;
    for (var y = kCeil + 12; y < kGround - 8; y += step) {
      if ((y - gapY).abs() < gap / 2) continue;
      game.world.add(EnemyBullet(Vector2(x, y), Vector2(fromLeft ? speed : -speed, 0), 9, dmg, const Color(0xFFFF8A3D)));
    }
    removeFromParent();
  }

  @override
  void render(Canvas c) {
    final k = 1 - t / warnTime;
    final p = Paint()
      ..strokeWidth = 3 + 4 * k
      ..strokeCap = StrokeCap.round
      ..blendMode = BlendMode.plus
      ..color = Color.fromRGBO(255, 110, 50, 0.25 + 0.5 * k);
    c.drawLine(Offset(x, kCeil), Offset(x, gapY - gap / 2), p);
    c.drawLine(Offset(x, gapY + gap / 2), Offset(x, kGround), p);
    // Lücke hell markiert
    Glow.draw(c, x, gapY, gap * 0.6, Color.fromRGBO(140, 245, 176, 0.25 + 0.35 * k));
  }
}
