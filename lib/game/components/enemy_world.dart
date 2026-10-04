part of 'enemy.dart';

/// Verhalten und Aussehen der Welt-Gegner (Felder, Dorf, Wald, Gebirge).
/// Angriffe werden angekündigt: [Enemy.warn] > 0 lässt den Gegner aufleuchten.
extension _WorldEnemies on Enemy {
  // ---------------- Verhalten ----------------

  void _worldAi(double dt, Vector2 p, double dx, double dy, double d) {
    switch (type) {
      case EnemyType.puffball:
        // Treibt langsam heran und wippt; bei Berührung platzt er
        vel.x += (dx / d * spd - vel.x) * 1.2 * dt;
        vel.y += (dy / d * spd + sin(t * 2) * 25 - vel.y) * 1.2 * dt;
        if (d < r + game.player.r) _pop();
      case EnemyType.scarecrow:
        // Wirft brennendes Stroh im Bogen auf die Stelle, an der du gerade bist
        shootT -= dt;
        warn = shootT < 0.6 && d < 560 ? 1 - shootT / 0.6 : 0;
        if (shootT <= 0) {
          shootT = 2.4 * game.rnd(0.85, 1.15);
          if (d < 560) {
            const flight = 1.1, g = 520.0;
            final v = Vector2(dx / flight, (dy - 0.5 * g * flight * flight) / flight);
            game.world.add(EnemyBullet(position + Vector2(0, -r), v, 6, dmg, const Color(0xFFFF8A3D), gravity: g));
          }
        }
      case EnemyType.bat:
        // Zickzack: Richtung Spieler plus kräftiges Pendeln quer dazu
        final wob = sin(t * 7) * spd * 0.9;
        vel.x += (dx / d * spd - dy / d * wob - vel.x) * 4 * dt;
        vel.y += (dy / d * spd + dx / d * wob - vel.y) * 4 * dt;
      case EnemyType.weathercock:
        // Dreht sich gleichmäßig und schießt in die Richtung, in die er zeigt
        aim += 0.9 * dt;
        shootT -= dt;
        warn = shootT < 0.25 ? 1 - shootT / 0.25 : 0;
        if (shootT <= 0) {
          shootT = 0.8;
          if (d < 620) {
            game.world.add(EnemyBullet(position + Vector2(cos(aim), sin(aim)) * 18, Vector2(cos(aim), sin(aim)) * 210, 5,
                dmg, const Color(0xFFFFC94A)));
          }
        }
      case EnemyType.spider:
        // Hängt am Faden: folgt dir oben entlang, seilt sich bis knapp über dich ab, schießt Netze
        vel.x += ((dx.abs() > 40 ? dx.sign : 0) * spd - vel.x) * 2 * dt;
        final targetY = clampD(p.y - 70, kCeil + r + 10, kGround - 120);
        vel.y += ((targetY - y).clamp(-90, 90) - vel.y) * 3 * dt;
        shootT -= dt;
        warn = shootT < 0.5 ? 1 - shootT / 0.5 : 0;
        if (shootT <= 0) {
          shootT = 2.8 * game.rnd(0.85, 1.15);
          if (d < 480) {
            game.world.add(
                EnemyBullet(position.clone(), Vector2(dx / d, dy / d) * 200, 8, dmg * 0.5, const Color(0xFFE6E6F2), web: true));
          }
        }
      case EnemyType.wisp:
        _wispAi(dt, p, d);
      case EnemyType.eagle:
        _eagleAi(dt, p, dx, dy);
      case EnemyType.avalanche:
        _avalancheAi(dt, dx);
      default:
    }
  }

  void _wispAi(double dt, Vector2 p, double d) {
    vel.setZero();
    stateT -= dt;
    if (state == 0) {
      // Kurz verblassen, dann woanders auftauchen
      if (stateT <= 0) {
        hops++;
        final side = game.rng.nextBool() ? 1.0 : -1.0;
        final dist = hops >= 3 ? game.rnd(50, 80) : game.rnd(120, 220);
        position.setValues(
          clampD(p.x + side * dist, 30, game.worldW - 30),
          clampD(p.y + game.rnd(-70, 70), kCeil + 40, kGround - 40),
        );
        game.burst(position, const Color(0xFFBFF0FF), 8, 120);
        stateT = 2.2;
        if (hops >= 3 || d < 100) {
          state = 1;
          stateT = 0.8;
        }
      }
      warn = 0;
    } else {
      // Scharf: pulsiert und explodiert
      warn = 1 - stateT / 0.8;
      if (stateT <= 0) _explodeSelf(75);
    }
  }

  void _eagleAi(double dt, Vector2 p, double dx, double dy) {
    stateT -= dt;
    switch (state) {
      case 0: // Kreisen oben über dem Spieler
        final tx = p.x + sin(t * 1.3) * 140, ty = kCeil + 60 + sin(t * 2.1) * 20;
        vel.x += ((tx - x).clamp(-spd, spd) - vel.x) * 2 * dt;
        vel.y += ((ty - y).clamp(-spd, spd) - vel.y) * 2 * dt;
        warn = 0;
        if (stateT <= 0) {
          state = 1;
          stateT = 0.7;
          target.setFrom(p);
        }
      case 1: // Warnung: hält inne und leuchtet
        vel.scale(pow(0.02, dt).toDouble());
        warn = 1 - stateT / 0.7;
        if (stateT <= 0) {
          state = 2;
          stateT = 1.1;
          final dir = target - position;
          vel.setFrom(dir.length < 1 ? Vector2(0, 1) : dir.normalized()..scale(560));
        }
      case 2: // Sturzflug
        warn = 0;
        if (stateT <= 0 || y >= kGround - r - 2) {
          state = 3;
          stateT = 1.2;
        }
      default: // Steigt wieder auf
        vel.x *= pow(0.3, dt).toDouble();
        vel.y += (-200 - vel.y) * 3 * dt;
        if (stateT <= 0 || y < kCeil + 80) {
          state = 0;
          stateT = game.rnd(2.5, 3.5);
        }
    }
  }

  void _avalancheAi(double dt, double dx) {
    vel.y += 900 * dt;
    stateT -= dt;
    switch (state) {
      case 0: // Läuft heran
        vel.x += (dx.sign * spd - vel.x) * 3 * dt;
        warn = 0;
        if (stateT <= 0 && dx.abs() < 380) {
          state = 1;
          stateT = 0.6;
          aim = dx.sign == 0 ? 1 : dx.sign;
        }
      case 1: // Rollt sich ein (Warnung)
        vel.x *= pow(0.01, dt).toDouble();
        warn = 1 - stateT / 0.6;
        if (stateT <= 0) {
          state = 2;
          stateT = 1.6;
        }
      default: // Rollt
        warn = 0;
        vel.x = aim * 430;
        if (x <= r + 2 || x >= game.worldW - r - 2) aim = -aim;
        if (stateT <= 0) {
          state = 0;
          stateT = 2;
        }
    }
  }

  /// Pusteling platzt: Giftwolke, kein Material.
  void _pop() {
    if (dead) return;
    dead = true;
    removeFromParent();
    game.burst(position, const Color(0xFFC6FF6A), 14, 160);
    game.world.add(PoisonCloud(position.clone(), dmg));
  }

  /// Irrlicht explodiert: Schaden im Umkreis, kein Material.
  void _explodeSelf(double radius) {
    if (dead) return;
    dead = true;
    removeFromParent();
    game.world.add(Ring(position.clone(), radius, color: const Color(0xFFBFF0FF)));
    game.burst(position, const Color(0xFFBFF0FF), 18, 220);
    if (position.distanceTo(game.player.position) < radius + game.player.r) game.hurtPlayer(dmg, source: this);
  }

  // ---------------- Darstellung ----------------

  void _worldRender(Canvas c, Color Function(Color) k, double pulse) {
    const body = Enemy._body;
    switch (type) {
      case EnemyType.puffball:
        EnemyArt.puffball(c, EnemyLook(t: t, pulse: pulse, warn: warn, hit: flash > 0, state: state, aim: aim), r);
      case EnemyType.scarecrow:
        EnemyArt.scarecrow(c, EnemyLook(t: t, pulse: pulse, warn: warn, hit: flash > 0, state: state, aim: aim), r);
      case EnemyType.bat:
        EnemyArt.bat(c, EnemyLook(t: t, pulse: pulse, warn: warn, hit: flash > 0, state: state, aim: aim), r);
      case EnemyType.weathercock:
        EnemyArt.weathercock(c, EnemyLook(t: t, pulse: pulse, warn: warn, hit: flash > 0, state: state, aim: aim), r);
        // Zeigerpfeil in Schussrichtung
        final ax = cos(aim) * 22, ay = sin(aim) * 22 - 6;
        drawTri(c, ax, ay, ax - cos(aim + 0.5) * 7, ay - sin(aim + 0.5) * 7, ax - cos(aim - 0.5) * 7,
            ay - sin(aim - 0.5) * 7, const Color(0xFFFFC94A).withAlpha((150 + 100 * warn).round()));
      case EnemyType.spider:
        EnemyArt.spider(c, EnemyLook(t: t, pulse: pulse, warn: warn, hit: flash > 0, state: state, aim: aim), r);
      case EnemyType.wisp:
        final fl = 0.85 + 0.15 * sin(t * 13);
        drawCircle(c, 0, 0, r * 0.55 * fl, Color.lerp(const Color(0xFFBFF0FF), Colors.white, 0.5 + 0.5 * warn)!);
        drawTri(c, -5, 2, 5, 2, 0, 14 + sin(t * 9) * 3, const Color(0xAABFF0FF));
      case EnemyType.eagle:
        EnemyArt.eagle(c, EnemyLook(t: t, pulse: pulse, warn: warn, hit: flash > 0, state: state, aim: aim), r);
      case EnemyType.avalanche:
        if (state == 2 || state == 1) {
          // Eingerollt: Kugel mit drehenden Streifen
          final spin = state == 2 ? t * 14 * aim : 0.0;
          drawCircle(c, 0, 0, r, k(body));
          for (var i = 0; i < 3; i++) {
            final a = spin + i * pi * 2 / 3;
            Enemy._crack.color = const Color(0xFFBFE3FF).withAlpha((90 + 80 * pulse).round());
            c.drawArc(Rect.fromCircle(center: Offset.zero, radius: r * 0.65), a, 1.4, false, Enemy._crack);
          }
        } else {
          EnemyArt.avalancheWalk(c, EnemyLook(t: t, pulse: pulse, warn: warn, hit: flash > 0, state: state, aim: aim), r);
        }
      default:
    }
  }

  /// Faden der Spinne (in Weltkoordinaten relativ zum Gegner, ohne Spiegelung).
  void _worldRenderUnflipped(Canvas c) {
    if (type == EnemyType.spider) {
      c.drawLine(Offset(0, kCeil - y), Offset(0, -r), Paint()
        ..color = const Color(0x66E6E6F2)
        ..strokeWidth = 1);
    }
  }

  void _worldGlows(void Function(double, double, double, Color) f, void Function(double, double, double, Color) eye,
      GlowBatch front, double pulse) {
    switch (type) {
      case EnemyType.puffball:
        f(-3, 3, r * 1.6, const Color(0xFFC6FF6A).withAlpha((60 + 50 * pulse).round()));
        eye(4, -3, 2.2, const Color(0xFFC6FF6A));
      case EnemyType.scarecrow:
        eye(-3, -14, 2, Enemy._ember);
        eye(3, -14, 2, Enemy._ember);
      case EnemyType.bat:
        eye(0, -1, 2, Enemy._eye);
      case EnemyType.weathercock:
        front.add(x + cos(aim) * 22, y + sin(aim) * 22 - 6, 14 + 14 * warn, Color.fromRGBO(255, 201, 74, 0.4 + 0.5 * warn));
      case EnemyType.spider:
        eye(0, -9, 2.2, Enemy._eye);
      case EnemyType.wisp:
        front.add(x, y, r * (3 + 2 * warn), Color.fromRGBO(190, 240, 255, 0.55 + 0.35 * warn));
      case EnemyType.eagle:
        eye(17, -8, 2.2, Enemy._eye);
      case EnemyType.avalanche:
        f(0, 0, r * 1.3, const Color(0xFFBFE3FF).withAlpha((40 + 40 * pulse).round()));
      default:
    }
    // Angekündigter Angriff: helles, wachsendes Leuchten
    if (warn > 0) front.add(x, y, r * (1.8 + 1.4 * warn), Color.fromRGBO(255, 240, 220, 0.25 + 0.5 * warn));
  }
}

/// Giftwolke des Pustelings: schadet, solange man drin ist.
class PoisonCloud extends PositionComponent with HasGameReference<FederfeuerGame>, Transient, CombatEffect {
  PoisonCloud(Vector2 pos, this.dmg) : super(position: pos, priority: 18);
  final double dmg;
  static const radius = 60.0, duration = 3.0;
  double life = duration;

  @override
  void update(double dt) {
    if (!game.playing) return;
    life -= dt;
    if (life <= 0) {
      removeFromParent();
      return;
    }
    if (position.distanceTo(game.player.position) < radius + game.player.r * 0.5) game.hurtPlayer(dmg);
  }

  @override
  void render(Canvas c) {
    if (perfSkip.contains(RenderPart.effects)) return;
    final a = clampD(life / 0.6, 0, 1) * clampD((duration - life) / 0.3, 0, 1);
    for (var i = 0; i < 5; i++) {
      final ang = i / 5 * pi * 2 + game.clock * 0.6;
      Glow.draw(c, cos(ang) * 24, sin(ang) * 16, radius * 0.9, Color.fromRGBO(170, 255, 90, 0.28 * a));
    }
    Glow.draw(c, 0, 0, radius * 1.3, Color.fromRGBO(140, 220, 60, 0.3 * a));
  }
}

/// Rest eines explosiven Elitegegners: pulsiert kurz und explodiert dann.
class VolatileRemnant extends PositionComponent with HasGameReference<FederfeuerGame>, Transient, CombatEffect {
  VolatileRemnant(Vector2 pos, this.dmg) : super(position: pos, priority: 18);
  final double dmg;
  static const radius = 80.0, fuse = 0.7;
  double t = fuse;

  @override
  void update(double dt) {
    if (!game.playing) return;
    t -= dt;
    if (t > 0) return;
    removeFromParent();
    game.world.add(Ring(position.clone(), radius, color: const Color(0xFFFF8A3D)));
    game.burst(position, const Color(0xFFFF8A3D), 20, 240);
    game.shake = max(game.shake, 6);
    if (position.distanceTo(game.player.position) < radius + game.player.r) game.hurtPlayer(dmg);
  }

  @override
  void render(Canvas c) {
    final k = 1 - t / fuse;
    // Warnkreis wächst bis zum Explosionsradius
    c.drawCircle(Offset.zero, radius * k, Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2
      ..color = Color.fromRGBO(255, 138, 61, 0.4 + 0.5 * k));
    Glow.draw(c, 0, 0, 20 + 30 * k, Color.fromRGBO(255, 160, 80, 0.5 + 0.4 * sin(k * 30).abs()));
  }
}
