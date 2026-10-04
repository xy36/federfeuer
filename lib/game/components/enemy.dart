import 'dart:math';

import 'package:flame/components.dart';
import 'package:flutter/material.dart';

import '../config.dart';
import '../federfeuer_game.dart';
import '../perf.dart';
import '../run_state.dart';
import 'draw.dart';
import 'effects.dart';
import 'light.dart';
import 'pickups.dart';
import 'projectiles.dart';
import 'rot_art.dart';
import 'transient.dart';

part 'enemy_boss.dart';
part 'enemy_gate.dart';
part 'enemy_spawner.dart';
part 'enemy_world.dart';

class Enemy extends PositionComponent with HasGameReference<FederfeuerGame>, Transient {
  Enemy(this.type, Vector2 pos, int wave, DifficultyDef diff, Random rng,
      {this.elite, this.mini = false, this.child = false, this.spawnedBy})
      : super(position: pos, priority: 5) {
    final d = enemyDefs[type]!;
    // Wellenskalierung gilt laut GDD nicht für den Boss.
    final boss = type == EnemyType.boss;
    sizeK = elite != null ? kEliteScale : (mini ? kSplitScale : 1);
    r = d.radius * sizeK;
    // Schwierigkeitsstufe wirkt auch auf den Boss.
    final hpMul = elite != null ? kEliteHp : (mini ? kSplitHp : 1);
    maxHp = (boss ? d.hp : d.hp * (1 + (wave - 1) * 0.38)) * diff.hp * hpMul;
    hp = maxHp;
    dmg = ((boss ? d.dmg : d.dmg * (1 + (wave - 1) * 0.15)) * diff.dmg).roundToDouble();
    spd = (boss ? d.speed : d.speed * (1 + wave * 0.02)) * (elite == EliteMod.swift ? 1.25 : 1);
    fly = d.flying;
    t = rng.nextDouble() * 10;
    shootT = 0.5 + rng.nextDouble() * 1.5;
    home = pos.clone();
    stateT = 1.5 + rng.nextDouble() * 1.5;
    aim = rng.nextDouble() * pi * 2;
  }

  final EnemyType type;

  /// Elite-Modifikator (null = normaler Gegner); [mini] = Kopie eines teilenden Elitegegners.
  final EliteMod? elite;
  final bool mini;

  /// Von einem Spawner erzeugt: lässt kein Material fallen; [spawnedBy] ist der Spawner.
  final bool child;
  final Enemy? spawnedBy;

  /// Treffer durch den Spieler (Wespennest schwärmt aus).
  void onHit() => _spawnerOnHit();
  late final double r, maxHp, dmg, spd, sizeK;
  double _healT = 0;
  late final bool fly;
  late double hp;
  double t = 0, shootT = 0, jumpT = 1, summonT = 5, flash = 0;
  bool dead = false;
  final vel = Vector2.zero();

  /// Zustandsmaschine der Welt-Gegner (Sturzflug, Einrollen, Springen …), Richtung, Ziel.
  int state = 0, hops = 0;
  double stateT = 0, aim = 0;

  /// Angriffs-Ankündigung 0–1 (Aufleuchten vor Schuss, Sturz oder Explosion).
  double warn = 0;
  final target = Vector2.zero();

  /// Startpunkt; stationäre Gegner bleiben hier.
  late final Vector2 home;
  bool get stationary => enemyDefs[type]!.stationary;

  /// Heiler-Elite: heilt Gegner im Umkreis 140 um 4 % ihrer Max-HP pro Sekunde.
  void _healNearby(double dt) {
    _healT -= dt;
    if (_healT > 0) return;
    _healT = 0.5;
    for (final o in game.enemies) {
      if (o.dead || identical(o, this) || o.hp >= o.maxHp) continue;
      if (o.position.distanceTo(position) < 140) {
        o.hp = min(o.maxHp, o.hp + o.maxHp * 0.02);
        o.healGlow = 0.4;
      }
    }
  }

  /// Kurzes grünes Aufleuchten nach einer Heilung.
  double healGlow = 0;

  /// Lässt sich nicht verschieben (Boss, stationäre Gegner).
  bool get immovable => boss || stationary;

  // ---------------- Statuseffekte ----------------

  /// Restdauer (s) von Brand, Kleben, Verlangsamung, Betäubung, Einfangen, Fluch und Furcht.
  double burnT = 0, stickT = 0, slowT = 0, stunT = 0, trapT = 0, curseT = 0, fearT = 0;
  double burnDps = 0, stickDps = 0, slowAmt = 0;
  double _dotAcc = 0;

  /// Boss oder Torwächter: immun gegen Einfangen und Rückstoß, Betäubung wirkt nur kurz.
  bool get boss => type == EnemyType.boss || gatekeeper;
  bool get gatekeeper => type == EnemyType.strawKing || type == EnemyType.bell || type == EnemyType.spiderMother;

  /// Phase des Geierkönigs (1–3, wechselt bei 66 % und 33 % HP).
  int bossPhase = 1;

  /// Radius des Glockenschlags.
  static const double bellRadius = 230;
  bool get disabled => stunT > 0 || trapT > 0;
  bool get cursed => curseT > 0;

  /// Treffereffekte einer Waffe anwenden. Der Boss lässt sich nicht einfangen und nur kurz betäuben.
  void applyEffects(WeaponStats s) {
    if (s.burnTime > 0) {
      burnT = max(burnT, s.burnTime);
      burnDps = max(burnDps, s.burnDps);
    }
    if (s.stickTime > 0) {
      stickT = max(stickT, s.stickTime);
      stickDps = max(stickDps, s.stickDps);
    }
    if (s.slow > 0) slow(s.slow, s.slowTime);
    if (s.stun > 0) stun(s.stun);
    if (s.trap > 0) {
      if (boss || stationary) {
        slow(0.5, s.trap);
      } else {
        trapT = max(trapT, s.trap);
        vel.setZero();
      }
    }
    if (s.curse > 0) curseT = max(curseT, s.curse);
  }

  void slow(double amount, double time) {
    slowAmt = max(slowT > 0 ? slowAmt : 0, amount);
    slowT = max(slowT, time);
  }

  void stun(double time) => stunT = max(stunT, boss ? time * 0.3 : time);

  void ignite(double time, double dps) {
    burnT = max(burnT, time);
    burnDps = max(burnDps, dps);
  }

  void _tickStatus(double dt) {
    burnT = max(0.0, burnT - dt);
    stickT = max(0.0, stickT - dt);
    slowT = max(0.0, slowT - dt);
    stunT = max(0.0, stunT - dt);
    trapT = max(0.0, trapT - dt);
    curseT = max(0.0, curseT - dt);
    fearT = max(0.0, fearT - dt);
    // Schaden über Zeit in Schritten von 0,5 s
    final dps = (burnT > 0 ? burnDps : 0) + (stickT > 0 ? stickDps : 0);
    if (dps <= 0) {
      _dotAcc = 0;
      return;
    }
    _dotAcc += dt;
    if (_dotAcc >= 0.5) {
      _dotAcc -= 0.5;
      game.hurtEnemy(this, dps * 0.5, false, 0, dot: true);
    }
  }

  /// Wie stark der Wind diesen Gegner verschiebt.
  double get windFactor => enemyDefs[type]!.wind;

  @override
  void update(double dt) {
    if (dead || !game.playing) return;
    _tickStatus(dt);
    if (dead) return;
    if (elite == EliteMod.swift) dt *= 1.35;
    if (elite == EliteMod.healer) _healNearby(dt);
    flash -= dt;
    healGlow = max(0.0, healGlow - dt);
    // Verlangsamung und Zeitlupe (Taschenuhr) wirken auf Bewegung und Angriffe
    final realDt = dt;
    dt *= (slowT > 0 ? 1 - slowAmt : 1) * (game.timeSlowT > 0 ? 0.3 : 1);
    t += dt;
    final p = game.player.position;
    final dx = p.x - x, dy = p.y - y;
    final d = max(1.0, sqrt(dx * dx + dy * dy));

    if (trapT > 0) {
      // In der Blase: treibt hilflos nach oben
      vel.x *= pow(0.05, realDt).toDouble();
      vel.y = -55;
    } else if (stunT > 0) {
      vel.scale(pow(0.02, realDt).toDouble());
    } else if (fearT > 0) {
      // Flieht vom Spieler weg
      vel.x += (-dx / d * spd * 1.3 - vel.x) * 4 * dt;
      if (fly) vel.y += (-dy / d * spd - vel.y) * 4 * dt;
    } else {
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
      case EnemyType.puffball ||
            EnemyType.scarecrow ||
            EnemyType.bat ||
            EnemyType.weathercock ||
            EnemyType.spider ||
            EnemyType.wisp ||
            EnemyType.eagle ||
            EnemyType.avalanche:
        _worldAi(dt, p, dx, dy, d);
        if (dead) return;
      case EnemyType.strawKing || EnemyType.bell || EnemyType.spiderMother:
        _gateAi(dt, p, dx, dy, d);
      case EnemyType.crowNest ||
            EnemyType.waspNest ||
            EnemyType.wasp ||
            EnemyType.sporeShroom ||
            EnemyType.spore ||
            EnemyType.beetleQueen ||
            EnemyType.beetleEgg ||
            EnemyType.rift:
        _spawnerAi(dt, p, dx, dy, d);
        if (dead) return;
      case EnemyType.boss:
        _bossAi(dt, p, dx, dy);
    }

    }

    position.x = clampD(x + (vel.x + game.weather.windX * windFactor) * dt, r, game.worldW - r);
    position.y += vel.y * dt;
    // Stationäre Gegner lassen sich nicht verschieben
    if (stationary) {
      position.setFrom(home);
      vel.setZero();
    }
    if (y > kGround - r) {
      position.y = kGround - r;
      vel.y = min(0.0, vel.y);
    }
    if (y < kCeil + r) {
      position.y = kCeil + r;
      vel.y = max(0.0, vel.y);
    }
    // Berührungsschaden (das Irrlicht schadet nur durch seine Explosion)
    if (!disabled && dmg > 0 && type != EnemyType.wisp && position.distanceTo(p) < r + game.player.r - 3) {
      game.hurtPlayer(dmg, source: this);
    }
  }

  // ---------------- Darstellung: dunkle Fäulnis-Kreaturen ----------------

  static const _body = Color(0xFF120A1E), _body2 = Color(0xFF221433);
  static const _aura = Color(0xFFB44CFF), _eye = Color(0xFFFF4D6D), _ember = Color(0xFFFF8A3D);
  static const _toxic = Color(0xFF9CFF5A), _crown = Color(0xFFFF5AE0);

  static final _eliteRing = Paint()..style = PaintingStyle.stroke;
  static final _bubble = Paint()
    ..style = PaintingStyle.stroke
    ..strokeWidth = 2;
  static final _leg = Paint()
    ..strokeWidth = 2.2
    ..strokeCap = StrokeCap.round;
  static final _crack = Paint()
    ..style = PaintingStyle.stroke
    ..strokeWidth = 1.6
    ..strokeCap = StrokeCap.round
    ..blendMode = BlendMode.plus;

  @override
  void render(Canvas c) {
    if (perfSkip.contains(RenderPart.enemyBodies)) return;
    drawShadow(c, y, r);
    final face = (game.player.x - x) >= 0 ? 1.0 : -1.0;
    final hit = flash > 0;
    // Treffer: Körper blitzt hell auf
    Color k(Color col) => hit ? Color.lerp(col, Colors.white, 0.85)! : col;
    final pulse = 0.5 + 0.5 * sin(t * 3);

    // Leuchten (Aura, Augen, Risse) zeichnet der EnemyGlowPass gesammelt, siehe [collectGlows].

    _worldRenderUnflipped(c);
    _gateRenderUnflipped(c);
    _spawnerRenderUnflipped(c);
    c.save();
    c.scale(face * sizeK, sizeK);
    switch (type) {
      case EnemyType.puffball ||
            EnemyType.scarecrow ||
            EnemyType.bat ||
            EnemyType.weathercock ||
            EnemyType.spider ||
            EnemyType.wisp ||
            EnemyType.eagle ||
            EnemyType.avalanche:
        _worldRender(c, k, pulse);
      case EnemyType.strawKing || EnemyType.bell || EnemyType.spiderMother:
        _gateRender(c, k, pulse);
      case EnemyType.crowNest ||
            EnemyType.waspNest ||
            EnemyType.wasp ||
            EnemyType.sporeShroom ||
            EnemyType.spore ||
            EnemyType.beetleQueen ||
            EnemyType.beetleEgg ||
            EnemyType.rift:
        _spawnerRender(c, k, pulse);
      case EnemyType.crow:
        // Fäulnis-Stil (Test an der Krähe)
        RotArt.crow(c, t, sin(t * 16), pulse, hit: hit);
        _slitEye(c, 6, -5, 2.6, _eye);
      case EnemyType.beetle:
        for (var i = -1; i <= 1; i++) {
          final lg = sin(t * 14 + i) * 3;
          _leg.color = k(_body2);
          c.drawLine(Offset(i * 7.0, 4), Offset(i * 7 + lg, 15), _leg);
        }
        c.drawArc(Rect.fromCircle(center: const Offset(0, 4), radius: 16), pi, pi, true, fillOf(k(_body)));
        // Glühende Risse im Panzer
        _crack.color = _ember.withAlpha((150 + 90 * pulse).round());
        c.drawPath(
            Path()
              ..moveTo(-12, 1)
              ..lineTo(-6, -6)
              ..lineTo(-1, -2)
              ..lineTo(5, -9)
              ..moveTo(-1, -2)
              ..lineTo(3, 2),
            _crack);
        drawCircle(c, 15, 0, 6, k(_body2));
        _glowEye(c, 17, -1.5, 2, _ember);
      case EnemyType.spitter:
        final wb = sin(t * 5) * 1.5;
        drawOval(c, 0, 0, 15 + wb, 13 - wb, k(_body));
        for (var i = -1; i <= 1; i++) {
          drawTri(c, i * 8 - 3.0, 10, i * 8 + 3.0, 10, i * 8.0, 19 + sin(t * 6 + i) * 3, k(_body2));
        }
        // Pulsierender Giftsack
        drawOval(c, -3, 3, 6, 5, _toxic.withAlpha((170 + 60 * pulse).round()));
        drawOval(c, 7, 3, 4.5, 3.5, k(const Color(0xFF05020A)));
        _glowEye(c, 4, -5, 2.6, _toxic);
      case EnemyType.rock:
        final path = Path();
        for (var i = 0; i < 8; i++) {
          final a = i / 8 * pi * 2, rr = r * (i.isOdd ? 0.86 : 1);
          if (i == 0) {
            path.moveTo(rr, 0);
          } else {
            path.lineTo(cos(a) * rr, sin(a) * rr);
          }
        }
        path.close();
        c.drawPath(path, fillOf(k(_body)));
        // Glutadern
        _crack.color = _ember.withAlpha((140 + 100 * pulse).round());
        c.drawPath(
            Path()
              ..moveTo(-r * 0.7, r * 0.2)
              ..lineTo(-r * 0.25, -r * 0.1)
              ..lineTo(0, r * 0.35)
              ..lineTo(r * 0.3, r * 0.1)
              ..moveTo(-r * 0.25, -r * 0.1)
              ..lineTo(-r * 0.1, -r * 0.55),
            _crack);
        drawRect(c, 3, -12, 16, 3, k(_body2));
        _glowEye(c, 7, -6, 3.2, _ember);
        _glowEye(c, 15, -6, 2.8, _ember);
      case EnemyType.boss:
        final fl = sin(t * 6);
        drawTri(c, -10, -10, -74, -44 - fl * 25, 10, -6, k(_body2));
        drawTri(c, -30, -16, -80, -18 - fl * 20, -12, -6, k(_body2));
        drawOval(c, 0, 0, 52, 38, k(_body));
        drawTri(c, -6, 0, -68, 28 + fl * 18, 14, 4, k(_body2));
        drawOval(c, 30, -18, 16, 13, k(const Color(0xFF2E1B3C)));
        drawTri(c, 40, -16, 64, -6, 40, -4, k(const Color(0xFF3A2440)));
        // Krone aus Lichtsplittern
        for (var i = 0; i < 3; i++) {
          final cx = 13.0 + i * 10, hgt = i == 1 ? 18.0 : 14.0;
          drawTri(c, cx - 4, -32, cx, -32 - hgt, cx + 4, -32, _crown.withAlpha(230));
        }
        _glowEye(c, 34, -20, 4, _crown);
    }
    c.restore();

    // Elite: goldener, pulsierender Ring um den Körper
    if (elite != null) {
      _eliteRing
        ..strokeWidth = 2
        ..color = Color.fromRGBO(255, 201, 74, 0.55 + 0.35 * pulse);
      c.drawCircle(Offset.zero, r + 4, _eliteRing);
    }

    if (trapT > 0) {
      // Schillernde Blase
      _bubble.color = Color.fromRGBO(220, 245, 255, 0.55 + 0.2 * sin(t * 6));
      c.drawCircle(Offset.zero, r + 7, _bubble);
      drawCircle(c, -r * 0.4, -r * 0.5, 3, const Color(0xB3FFFFFF));
    }
    if (stunT > 0) {
      for (var i = 0; i < 3; i++) {
        final a = game.clock * 6 + i * 2.09;
        drawCircle(c, cos(a) * r * 0.8, -r - 8 + sin(a) * 3, 2.6, const Color(0xFFFFF2A8));
      }
    }

    final el = elite;
    if (el != null) {
      // Zeichen des Modifikators über dem Kopf, darunter eine schmale HP-Leiste
      drawEliteMark(c, el, Offset(0, -r - 19), 11, el.color);
      drawRect(c, -r, -r - 9, r * 2, 3, const Color(0xCC120A1E));
      drawRect(c, -r, -r - 9, r * 2 * clampD(hp / maxHp, 0, 1), 3, el.color);
    }
    if (type == EnemyType.rock && hp < maxHp && el == null) {
      drawRect(c, -20, -r - 10, 40, 4, const Color(0xCC120A1E));
      drawRect(c, -20, -r - 10, 40 * clampD(hp / maxHp, 0, 1), 4, _ember);
    }
  }

  /// Glühendes Schlitzauge (Fäulnis-Stil).
  static void _slitEye(Canvas c, double x, double y, double r, Color col) {
    final p = Path()
      ..moveTo(x - r * 1.2, y + r * 0.2)
      ..quadraticBezierTo(x, y - r * 0.9, x + r * 1.1, y - r * 0.3)
      ..quadraticBezierTo(x, y + r * 0.5, x - r * 1.2, y + r * 0.2)
      ..close();
    c.drawPath(p, fillOf(Color.lerp(col, Colors.white, 0.35)!));
  }

  static void _glowEye(Canvas c, double x, double y, double r, Color col) {
    drawCircle(c, x, y, r, Color.lerp(col, Colors.white, 0.45)!);
  }

  /// Leuchtpunkte dieses Gegners in Weltkoordinaten: [back] hinter dem Körper (Aura),
  /// [front] davor (Augen, Risse, Giftsack, Krone, HP-Glut).
  void collectGlows(GlowBatch back, GlowBatch front) {
    if (dead) return;
    final face = (game.player.x - x) >= 0 ? 1.0 : -1.0;
    final pulse = 0.5 + 0.5 * sin(t * 3);
    void f(double lx, double ly, double rad, Color col) => front.add(x + face * lx, y + ly, rad, col);
    void eye(double lx, double ly, double rad, Color col) => f(lx, ly, rad * 6, col.withAlpha(170));

    // Statuseffekte
    if (burnT > 0) front.add(x, y + r * 0.2, r * 1.7, Color.fromRGBO(255, 130, 40, 0.45 + 0.2 * sin(t * 18)));
    if (stickT > 0) front.add(x, y, r * 1.3, const Color(0x66FFFFE0));
    if (slowT > 0) front.add(x, y, r * 1.5, const Color(0x5578C8FF));
    if (curseT > 0) front.add(x, y - r - 10, 14, const Color(0xCCB44CFF));

    // Violette Aura, damit die dunklen Körper vor dunklem Hintergrund lesbar bleiben
    final el = elite;
    if (el != null) {
      // Elite: goldener Schein plus Farbe des Modifikators
      back.add(x, y, r * 2.6, Color.fromRGBO(255, 201, 74, 0.35 + 0.15 * pulse));
      back.add(x, y, r * 1.8, el.color.withAlpha(90));
      front.add(x, y - r - 18, 16, el.color.withAlpha(150));
    } else {
      back.add(x, y, r * (type == EnemyType.boss ? 3.0 : 1.9),
          _aura.withAlpha((type == EnemyType.boss ? 90 + 40 * pulse : 70).round()));
    }
    if (healGlow > 0) front.add(x, y, r * 1.8, Color.fromRGBO(140, 245, 176, healGlow));
    if (el == EliteMod.healer) back.add(x, y, 140, Color.fromRGBO(140, 245, 176, 0.08 + 0.05 * pulse));
    switch (type) {
      case EnemyType.puffball ||
            EnemyType.scarecrow ||
            EnemyType.bat ||
            EnemyType.weathercock ||
            EnemyType.spider ||
            EnemyType.wisp ||
            EnemyType.eagle ||
            EnemyType.avalanche:
        _worldGlows(f, eye, front, pulse);
      case EnemyType.strawKing || EnemyType.bell || EnemyType.spiderMother:
        _gateGlows(f, front, pulse);
      case EnemyType.crowNest ||
            EnemyType.waspNest ||
            EnemyType.wasp ||
            EnemyType.sporeShroom ||
            EnemyType.spore ||
            EnemyType.beetleQueen ||
            EnemyType.beetleEgg ||
            EnemyType.rift:
        _spawnerGlows(f, front, pulse);
      case EnemyType.crow:
        // Schlitzauge: kleines, scharfes Glühen statt großem Lichthof
        f(6, -5, 7, _eye.withAlpha(200));
      case EnemyType.beetle:
        f(-2, -3, 16, _ember.withAlpha((60 + 50 * pulse).round()));
        eye(17, -1.5, 2, _ember);
      case EnemyType.spitter:
        f(-3, 3, 22, _toxic.withAlpha((90 + 80 * pulse).round()));
        eye(4, -5, 2.6, _toxic);
      case EnemyType.rock:
        f(-r * 0.1, r * 0.1, r * 1.1, _ember.withAlpha((50 + 50 * pulse).round()));
        eye(7, -6, 3.2, _ember);
        eye(15, -6, 2.8, _ember);
        if (hp < maxHp) front.add(x - 20 + 40 * clampD(hp / maxHp, 0, 1), y - r - 8, 10, _ember.withAlpha(120));
      case EnemyType.boss:
        for (var i = 0; i < 3; i++) {
          final hgt = i == 1 ? 18.0 : 14.0;
          f(13.0 + i * 10, -32 - hgt * 0.6, 16, _crown.withAlpha((90 + 60 * pulse).round()));
        }
        eye(34, -20, 4, _crown);
        if (warn > 0) front.add(x, y, r * (1.5 + warn), Color.fromRGBO(255, 230, 250, 0.2 + 0.5 * warn));
    }
  }
}

/// Zeichnet das Leuchten aller Gegner in einem Aufruf: [front] = false hinter den
/// Körpern (Aura), true davor (Augen, Risse …).
class EnemyGlowPass extends Component with HasGameReference<FederfeuerGame> {
  EnemyGlowPass({required this.front}) : super(priority: front ? 6 : 4);
  final bool front;
  final _back = GlowBatch(), _front = GlowBatch();

  @override
  void render(Canvas c) {
    if (perfSkip.contains(RenderPart.enemyGlow)) return;
    for (final e in game.enemies) {
      e.collectGlows(_back, _front);
    }
    // Jeder Durchgang zeichnet nur seine Hälfte und verwirft die andere.
    if (front) {
      _front.flush(c);
      _back.clear();
    } else {
      _back.flush(c);
      _front.clear();
    }
  }
}
