import 'dart:math';
import 'dart:ui' as ui;

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
import 'boss_art.dart';
import 'enemy_art.dart';
import 'rot_art.dart';
import 'transient.dart';

part 'enemy_boss.dart';
part 'enemy_gate.dart';
part 'enemy_spawner.dart';
part 'enemy_sprites.dart';
part 'enemy_world.dart';

class Enemy extends PositionComponent with HasGameReference<FederfeuerGame>, Transient {
  Enemy(this.type, Vector2 pos, int wave, DifficultyDef diff, Random rng,
      {this.elite, this.mini = false, this.child = false, this.spawnedBy})
      : super(position: pos, priority: 5) {
    final d = enemyDefs[type]!;
    // Wellenskalierung gilt laut GDD nicht für den Endboss.
    final boss = kFinalBosses.contains(type);
    sizeK = elite != null ? kEliteScale : (mini ? kSplitScale : 1);
    r = d.radius * sizeK;
    // Schwierigkeitsstufe wirkt auch auf den Boss.
    final hpMul = elite != null ? kEliteHp : (mini ? kSplitHp : 1);
    // Weniger, aber zähere Gegner (nicht Boss, Torwächter und Spawner-Kinder)
    final regular = !boss && !child && !_gatekeeperType(type);
    toughness = regular ? enemyToughness(wave) : 1;
    materialFactor = regular ? enemyMaterialFactor(wave) : 1;
    final growth = _gatekeeperType(type) ? kGateHpGrowth : 0.38;
    maxHp = (boss ? d.hp : d.hp * (1 + (wave - 1) * growth)) * diff.hp * hpMul * toughness;
    hp = maxHp;
    dmg = ((boss ? d.dmg : d.dmg * (1 + (wave - 1) * 0.15)) * diff.dmg * (regular ? enemyDmgBonus(wave) : 1))
        .roundToDouble();
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

  /// HP- und Material-Faktor (siehe [enemyToughness]); 1 für Boss, Torwächter, Kinder.
  late final double toughness;

  /// Material-Faktor (siehe [enemyMaterialFactor]); 1 für Boss, Torwächter, Kinder.
  late final double materialFactor;
  static bool _gatekeeperType(EnemyType t) => kGatekeepers.contains(t);
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

  /// Nässe (Wasser-Treffer), eingefroren (Reaktion Frost), Sperre bis zur nächsten Reaktion.
  double wetT = 0, frozenT = 0, reactCd = 0;

  /// Items: verwirrt (greift andere Gegner an), in ein Huhn verwandelt (harmlos, verwundbar).
  double confusedT = 0, chickenT = 0, _confuseHitT = 0;

  /// Kann von Wirrkraut und Hühnerzauber getroffen werden (nicht Boss, Torwächter, stationär).
  bool get chaosable => !boss && !stationary;
  double burnDps = 0, stickDps = 0, slowAmt = 0;
  double _dotAcc = 0;

  /// Boss oder Torwächter: immun gegen Einfangen und Rückstoß, Betäubung wirkt nur kurz.
  bool get boss => finalBoss || gatekeeper;
  bool get gatekeeper => kGatekeepers.contains(type);
  bool get finalBoss => kFinalBosses.contains(type);

  /// Dornenwurm unter der Erde: Treffer prallen ab, kein Berührungsschaden.
  bool get burrowed => type == EnemyType.thornWorm && (state == 0 || state == 1);

  /// Phase des Endbosses (1–3, wechselt bei 66 % und 33 % HP).
  int bossPhase = 1;

  /// Radius des Glockenschlags.
  static const double bellRadius = 230;

  /// Zeiten der neuen Torwächter: Stampf-Warnung, Verblassen, Wurm (Warnung, oben, Abtauchen).
  static const double golemStompWarn = 0.9, lanternFade = 0.6, wormWarn = 0.8, wormUp = 2.6, wormSink = 0.6;
  bool get disabled => stunT > 0 || trapT > 0 || frozenT > 0 || confusedT > 0 || chickenT > 0;
  bool get wet => wetT > 0;
  bool get frozen => frozenT > 0;
  bool get burning => burnT > 0;
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
    if (s.trap > 0) trapFor(s.trap);
    if (s.curse > 0) curseT = max(curseT, s.curse);
  }

  /// Einfangen; Boss und stationäre Gegner werden stattdessen verlangsamt.
  void trapFor(double time) {
    if (boss || stationary) {
      slow(0.5, time);
    } else {
      trapT = max(trapT, time);
      vel.setZero();
    }
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
    wetT = max(0.0, wetT - dt);
    frozenT = max(0.0, frozenT - dt);
    reactCd = max(0.0, reactCd - dt);
    confusedT = max(0.0, confusedT - dt);
    chickenT = max(0.0, chickenT - dt);
    _confuseHitT = max(0.0, _confuseHitT - dt);
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

  /// Verwirrt: jagt den nächsten anderen Gegner und rammt ihn (Wirrkraut).
  void _confusedAi(double dt) {
    Enemy? near;
    var best = double.infinity;
    for (final o in game.enemies) {
      if (o.dead || identical(o, this)) continue;
      final d2 = o.position.distanceToSquared(position);
      if (d2 < best) {
        best = d2;
        near = o;
      }
    }
    if (near == null) {
      vel.scale(pow(0.1, dt).toDouble());
      return;
    }
    final dv = near.position - position, d = max(1.0, dv.length);
    vel.x += (dv.x / d * spd * 1.2 - vel.x) * 3 * dt;
    if (fly) vel.y += (dv.y / d * spd * 1.2 - vel.y) * 3 * dt;
    if (_confuseHitT <= 0 && d < r + near.r) {
      _confuseHitT = 0.5;
      game.hurtEnemy(near, max(1.0, dmg) * kConfuseHitMul, false, dv.x.sign * 20);
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
    // Verlangsamung wirkt auf Bewegung und Angriffe
    final realDt = dt;
    dt *= slowT > 0 ? 1 - slowAmt : 1;
    // Eingefroren: auch die Animation steht still
    if (frozenT <= 0) t += dt;
    final p = game.player.position;
    final dx = p.x - x, dy = p.y - y;
    final d = max(1.0, sqrt(dx * dx + dy * dy));

    if (trapT > 0) {
      // In der Blase: treibt hilflos nach oben
      vel.x *= pow(0.05, realDt).toDouble();
      vel.y = -55;
    } else if (frozenT > 0) {
      // Eingefroren: steht starr
      vel.setZero();
    } else if (chickenT > 0) {
      // Huhn: hüpft ziellos herum und sinkt zu Boden
      vel.x += (sin(t * 2.3) * 45 - vel.x) * 3 * dt;
      vel.y += 700 * dt;
    } else if (confusedT > 0) {
      _confusedAi(dt);
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
            EnemyType.avalanche ||
            EnemyType.wirrling:
        _worldAi(dt, p, dx, dy, d);
        if (dead) return;
      case EnemyType.strawKing ||
            EnemyType.bell ||
            EnemyType.spiderMother ||
            EnemyType.moorGolem ||
            EnemyType.lanternMan ||
            EnemyType.thornWorm:
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
      case EnemyType.ashPhoenix:
        _phoenixAi(dt, p, dx, dy);
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
    if (!disabled && dmg > 0 && type != EnemyType.wisp && !burrowed && position.distanceTo(p) < r + game.player.r - 3) {
      game.hurtPlayer(dmg, source: this);
    }
  }

  // ---------------- Darstellung: dunkle Fäulnis-Kreaturen ----------------

  static const _body = RotArt.ink;
  static const _aura = Color(0xFFB44CFF), _eye = Color(0xFFFF4D6D), _ember = Color(0xFFFF8A3D);
  static const _toxic = Color(0xFF9CFF5A), _crown = Color(0xFFFF5AE0);

  static final _eliteRing = Paint()..style = PaintingStyle.stroke;
  static final _rotRim = Paint()
    ..style = PaintingStyle.stroke
    ..strokeCap = StrokeCap.round
    ..blendMode = BlendMode.plus;
  static final _bubble = Paint()
    ..style = PaintingStyle.stroke
    ..strokeWidth = 2;
  static final _crack = Paint()
    ..style = PaintingStyle.stroke
    ..strokeWidth = 1.6
    ..strokeCap = StrokeCap.round
    ..blendMode = BlendMode.plus;

  /// Blickrichtung: 1 = nach rechts (zum Spieler), −1 = nach links.
  double get face => (game.player.x - x) >= 0 ? 1.0 : -1.0;

  /// Vorgerenderter Körper (siehe [EnemyBodyPass]); null = live zeichnen.
  /// Der eingerollte Lawinenkäfer dreht sich frei und bleibt live.
  EnemySpriteDef? get spriteDef => chickenT > 0 || (type == EnemyType.avalanche && (state == 1 || state == 2))
      ? null
      : enemySpriteDefs[type];

  /// Zelle im Atlas: Variante, Pulsstufe, Phase der Hauptbewegung.
  int spriteCell(EnemySpriteDef def) {
    final variant = def.variantOf?.call(this) ?? 0;
    final pulse = 0.5 + 0.5 * sin(t * 3);
    final level = min(def.pulseLevels - 1, (pulse * def.pulseLevels).floor());
    final frame = def.omega > 0 ? ((t * def.omega / (2 * pi)) % 1 * def.frames).floor() % def.frames : 0;
    return (variant * def.pulseLevels + level) * def.frames + frame;
  }

  /// Wackeln der Nester vor dem Ausschwärmen (lokale Einheiten, in Blickrichtung).
  double get spriteShake =>
      (type == EnemyType.crowNest || type == EnemyType.waspNest) && warn > 0 ? sin(t * 40) * 2 * warn : 0;

  @override
  void render(Canvas c) {
    if (perfSkip.contains(RenderPart.enemyBodies)) return;
    final sprited = spriteDef != null;
    if (!sprited) drawShadow(c, y, r);
    final face = this.face;
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
    // Huhn (Hühnerzauber) statt des eigentlichen Körpers; vorgerenderter Körper: nur, was live bleibt.
    if (chickenT > 0) {
      _chicken(c, hit);
    } else if (sprited) {
      _spriteExtras(c);
    } else {
    switch (type) {
      case EnemyType.puffball ||
            EnemyType.scarecrow ||
            EnemyType.bat ||
            EnemyType.weathercock ||
            EnemyType.spider ||
            EnemyType.wisp ||
            EnemyType.eagle ||
            EnemyType.avalanche ||
            EnemyType.wirrling:
        _worldRender(c, k, pulse);
      case EnemyType.strawKing ||
            EnemyType.bell ||
            EnemyType.spiderMother ||
            EnemyType.moorGolem ||
            EnemyType.lanternMan ||
            EnemyType.thornWorm:
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
        EnemyArt.beetle(c, EnemyLook(t: t, pulse: pulse, warn: warn, hit: flash > 0, state: state, aim: aim), r);
      case EnemyType.spitter:
        EnemyArt.spitter(c, EnemyLook(t: t, pulse: pulse, warn: warn, hit: flash > 0, state: state, aim: aim), r);
      case EnemyType.rock:
        EnemyArt.rock(c, EnemyLook(t: t, pulse: pulse, warn: warn, hit: flash > 0, state: state, aim: aim), r);
      case EnemyType.boss:
        BossArt.vultureKing(c, _bossLook(hit, pulse));
      case EnemyType.ashPhoenix:
        BossArt.ashPhoenix(c, _bossLook(hit, pulse), r);
    }
    }
    c.restore();

    // Fäulnis-Stil: kränklich violette Gegenlichtkante oben
    if (!boss && type != EnemyType.wisp && type != EnemyType.rift && type != EnemyType.beetleEgg && type != EnemyType.crow) {
      _rotRim
        ..strokeWidth = boss ? 2 : 1.1
        ..color = Color.fromRGBO(180, 76, 255, hit ? 0 : 0.45);
      c.drawArc(Rect.fromCircle(center: Offset.zero, radius: r * 0.95), pi * 1.15, pi * 0.7, false, _rotRim);
    }

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
    _statusOverlays(c);
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

  static final _drop = Paint()..color = const Color(0xFF8FD0FF);
  static final _ice = Paint()..color = const Color(0x5590D8FF);
  static final _iceEdge = Paint()
    ..style = PaintingStyle.stroke
    ..strokeWidth = 1.4
    ..strokeJoin = StrokeJoin.round
    ..color = const Color(0xCCE8F8FF);
  static final _rune = Paint()
    ..style = PaintingStyle.stroke
    ..strokeWidth = 1.5
    ..strokeCap = StrokeCap.round
    ..color = const Color(0xFFD08CFF);

  /// Sichtbare Zustände über dem Körper: Tropfen (nass), Eishülle (eingefroren),
  /// kreisende Runen (verflucht). Brand-Flammen kommen als Leuchten, siehe [collectGlows].
  void _statusOverlays(Canvas c) {
    if (wetT > 0) {
      for (var i = 0; i < 3; i++) {
        final ph = (game.clock * 1.4 + i / 3) % 1;
        final dx = (i - 1) * r * 0.55, dy = r * 0.2 + ph * r * 1.1;
        _drop.color = Color.fromRGBO(143, 208, 255, 1 - ph);
        c.drawPath(
            Path()
              ..moveTo(dx, dy - 3.2)
              ..quadraticBezierTo(dx + 2.2, dy, dx, dy + 1.8)
              ..quadraticBezierTo(dx - 2.2, dy, dx, dy - 3.2),
            _drop);
      }
    }
    if (frozenT > 0) {
      // Eiskristall-Hülle: unregelmäßiges Vieleck mit hellen Kanten und Zacken
      final ice = Path();
      for (var i = 0; i < 7; i++) {
        final a = i / 7 * pi * 2 + 0.3;
        final rr = r * (1.12 + (i.isEven ? 0.12 : -0.02));
        i == 0 ? ice.moveTo(cos(a) * rr, sin(a) * rr) : ice.lineTo(cos(a) * rr, sin(a) * rr);
      }
      ice.close();
      c.drawPath(ice, _ice);
      c.drawPath(ice, _iceEdge);
      c.drawLine(Offset(-r * 0.5, -r * 0.6), Offset(-r * 0.15, -r * 0.2), _iceEdge);
      c.drawLine(Offset(r * 0.3, -r * 0.7), Offset(r * 0.55, -r * 0.35), _iceEdge);
    }
    if (confusedT > 0) {
      // Verwirrt: zwei kreisende Wirbel über dem Kopf
      for (var i = 0; i < 2; i++) {
        final a = game.clock * 7 + i * pi;
        c.drawCircle(Offset(cos(a) * r * 0.6, -r - 9 + sin(a) * 2.5), 2.4, _rune);
      }
    }
    if (curseT > 0) {
      // Drei Runen kreisen über dem Kopf
      for (var i = 0; i < 3; i++) {
        final a = game.clock * 2.2 + i * pi * 2 / 3;
        final rx = cos(a) * r * 0.75, ry = -r - 12 + sin(a) * 3;
        c.drawPath(
            Path()
              ..moveTo(rx - 2.5, ry + 3)
              ..lineTo(rx, ry - 3.5)
              ..lineTo(rx + 2.5, ry + 3)
              ..moveTo(rx - 1.5, ry + 0.5)
              ..lineTo(rx + 1.5, ry + 0.5),
            _rune);
      }
    }
  }

  static final _chickenBody = Paint()..color = const Color(0xFFF4F0E8);

  /// Harmloses Huhn (Hühnerzauber): weißer Körper, roter Kamm, gelber Schnabel, Beinchen.
  void _chicken(Canvas c, bool hit) {
    _chickenBody.color = hit ? Colors.white : const Color(0xFFF4F0E8);
    final hop = (sin(t * 9).abs()) * 3;
    c.save();
    c.translate(0, -hop);
    drawRect(c, -4, 6, 1.6, 6, const Color(0xFFE8A030));
    drawRect(c, 2, 6, 1.6, 6, const Color(0xFFE8A030));
    c.drawOval(const Rect.fromLTRB(-11, -6, 9, 9), _chickenBody);
    c.drawCircle(const Offset(8, -8), 5.5, _chickenBody);
    drawCircle(c, 7, -15, 2.4, const Color(0xFFE8303A));
    drawCircle(c, 10, -14, 2, const Color(0xFFE8303A));
    drawTri(c, 13, -9, 17, -7.5, 13, -6, const Color(0xFFF0B030));
    drawCircle(c, 9.5, -9, 1.1, const Color(0xFF1A1020));
    drawTri(c, -11, -2, -16, -7, -12, 2, const Color(0xFFE8E0D0));
    c.restore();
  }

  /// Teile vorgerenderter Gegner, die live gezeichnet werden (gespiegelter Raum).
  void _spriteExtras(Canvas c) {
    switch (type) {
      case EnemyType.crow:
        RotArt.crowSmoke(c, t);
      case EnemyType.weathercock:
        // Zeigerpfeil in Schussrichtung
        final ax = cos(aim) * 22, ay = sin(aim) * 22 - 6;
        drawTri(c, ax, ay, ax - cos(aim + 0.5) * 7, ay - sin(aim + 0.5) * 7, ax - cos(aim - 0.5) * 7,
            ay - sin(aim - 0.5) * 7, const Color(0xFFFFC94A).withAlpha((150 + 100 * warn).round()));
      default:
    }
  }

  BossLook _bossLook(bool hit, double pulse) =>
      BossLook(t: t, pulse: pulse, warn: warn, hit: hit, phase: bossPhase, hp: hp / maxHp, state: state);

  /// Glühendes Schlitzauge (Fäulnis-Stil).
  static void _slitEye(Canvas c, double x, double y, double r, Color col) {
    final p = Path()
      ..moveTo(x - r * 1.2, y + r * 0.2)
      ..quadraticBezierTo(x, y - r * 0.9, x + r * 1.1, y - r * 0.3)
      ..quadraticBezierTo(x, y + r * 0.5, x - r * 1.2, y + r * 0.2)
      ..close();
    c.drawPath(p, fillOf(Color.lerp(col, Colors.white, 0.35)!));
  }



  /// Leuchtpunkte dieses Gegners in Weltkoordinaten: [back] hinter dem Körper (Aura),
  /// [front] davor (Augen, Risse, Giftsack, Krone, HP-Glut).
  void collectGlows(GlowBatch back, GlowBatch front) {
    if (dead) return;
    final face = (game.player.x - x) >= 0 ? 1.0 : -1.0;
    final pulse = 0.5 + 0.5 * sin(t * 3);
    void f(double lx, double ly, double rad, Color col) => front.add(x + face * lx, y + ly, rad, col);
    void eye(double lx, double ly, double rad, Color col) => f(lx, ly, rad * 3, col.withAlpha(200));

    // Statuseffekte
    if (burnT > 0) {
      // Flammen: Glutkern plus aufsteigende, kleiner werdende Flammenzungen
      front.add(x, y + r * 0.2, r * 1.3, Color.fromRGBO(255, 110, 30, 0.35 + 0.15 * sin(game.clock * 18)));
      for (var i = 0; i < 4; i++) {
        final ph = (game.clock * 1.8 + i / 4 + t * 0.37) % 1;
        final sx = sin(game.clock * 5 + i * 2.1) * r * 0.45;
        front.add(x + sx, y + r * 0.5 - ph * r * 2.1, r * 0.55 * (1 - ph) + 4,
            Color.fromRGBO(255, (210 - 130 * ph).round(), 40, 0.9 * (1 - ph)));
      }
    }
    if (stickT > 0) front.add(x, y, r * 1.3, const Color(0x66FFFFE0));
    if (slowT > 0) front.add(x, y, r * 1.5, const Color(0x5578C8FF));
    if (wetT > 0) front.add(x, y, r * 1.3, const Color(0x3A6EBEFF));
    if (frozenT > 0) front.add(x, y, r * 1.7, const Color(0x73BEEBFF));
    if (curseT > 0) front.add(x, y - r - 12, 12, const Color(0x99B44CFF));

    // Violette Aura, damit die dunklen Körper vor dunklem Hintergrund lesbar bleiben
    final el = elite;
    if (el != null) {
      // Elite: goldener Schein plus Farbe des Modifikators
      back.add(x, y, r * 2.6, Color.fromRGBO(255, 201, 74, 0.35 + 0.15 * pulse));
      back.add(x, y, r * 1.8, el.color.withAlpha(90));
      front.add(x, y - r - 18, 16, el.color.withAlpha(150));
    } else {
      back.add(x, y, r * (finalBoss ? 3.0 : 1.9),
          _aura.withAlpha((finalBoss ? 90 + 40 * pulse : 70).round()));
    }
    if (healGlow > 0) front.add(x, y, r * 1.8, Color.fromRGBO(140, 245, 176, healGlow));
    // Fäulnis-Stil: violetter Schimmer im Inneren des dunklen Körpers
    if (type != EnemyType.wisp && type != EnemyType.rift) front.add(x, y, r * 0.75, Color.fromRGBO(150, 60, 220, 0.16 + 0.08 * pulse));
    if (el == EliteMod.healer) back.add(x, y, 140, Color.fromRGBO(140, 245, 176, 0.08 + 0.05 * pulse));
    if (confusedT > 0) front.add(x, y - r - 9, 16, const Color(0x99C77DFF));
    if (chickenT > 0) return;
    switch (type) {
      case EnemyType.puffball ||
            EnemyType.scarecrow ||
            EnemyType.bat ||
            EnemyType.weathercock ||
            EnemyType.spider ||
            EnemyType.wisp ||
            EnemyType.eagle ||
            EnemyType.avalanche ||
            EnemyType.wirrling:
        _worldGlows(f, eye, front, pulse);
      case EnemyType.strawKing ||
            EnemyType.bell ||
            EnemyType.spiderMother ||
            EnemyType.moorGolem ||
            EnemyType.lanternMan ||
            EnemyType.thornWorm:
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
        f(48, -64, 26, _crown.withAlpha((80 + 60 * pulse).round()));
        f(47, -40, 9, _crown.withAlpha(220));
        if (warn > 0) front.add(x, y, r * (1.5 + warn), Color.fromRGBO(255, 230, 250, 0.2 + 0.5 * warn));
      case EnemyType.ashPhoenix:
        _phoenixGlows(f, front, pulse);
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
