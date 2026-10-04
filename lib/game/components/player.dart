import 'dart:math';

import 'package:flame/components.dart';
import 'package:flutter/material.dart';

import '../config.dart';
import '../federfeuer_game.dart';
import 'bird_art.dart';
import 'light.dart';

class Player extends PositionComponent with HasGameReference<FederfeuerGame> {
  Player() : super(priority: 10);

  final vel = Vector2.zero();
  double face = 1, iframe = 0, anim = 0;
  bool grounded = false;

  /// Gewählter Vogel: bestimmt Flugprofil, Trefferfläche und Aussehen.
  CharacterDef get character => _character;
  CharacterDef _character = characterDefs.first;
  set character(CharacterDef c) {
    _character = c;
    _body = BirdArt.bodyPaint(c);
  }

  double get r => character.radius;

  /// Sturzflug, Bauchrutscher, verbleibender Schub (Huhn).
  double dashT = 0, slideT = 0, stamina = 1;

  /// Im Spinnennetz: langsamer und weniger Schub.
  double webT = 0;
  bool clinging = false;

  void reset(Vector2 p) {
    position.setFrom(p);
    vel.setZero();
    iframe = 1;
    face = 1;
    dashT = slideT = webT = 0;
    stamina = 1;
    _trail.clear();
  }

  /// Sturzflug-Feder: kurzer Sprint in Flugrichtung, unverwundbar.
  void dash([double time = 0.22, double speed = 760]) {
    dashT = time;
    iframe = max(iframe, time + 0.08);
    vel.setValues(face * speed, 0);
    game.burst(position, character.glow, 10, 140);
  }

  /// Frack: Bauchrutscher am Boden.
  void slide([double time = 0.7]) {
    slideT = time;
    iframe = max(iframe, 0.25);
    vel.x = face * 640;
    vel.y = max(vel.y, 500);
  }

  @override
  void update(double dt) {
    final run = game.run;
    if (run == null && game.phase == Phase.menu) {
      _menuFlight(dt);
      return;
    }
    if (run == null || !game.playing) return;

    final c = character;
    final dir = (game.inRight ? 1 : 0) - (game.inLeft ? 1 : 0);
    webT = max(0.0, webT - dt);
    final webbed = webT > 0 ? kWebSlow : 1.0;
    var maxSpeed = kPlayerSpeed * max(0.4, 1 + run.stat(Stat.speed) / 100) * c.speedMul * webbed;
    if (grounded) maxSpeed *= c.groundMul;
    final accel = 1500 * c.accelMul;

    // Huhn: Schub nur in kurzen Hüpfern, lädt am Boden wieder auf
    var fly = game.inFly;
    if (c.stamina > 0) {
      if (fly && stamina > 0) {
        stamina -= dt / c.stamina;
      } else if (grounded) {
        stamina = min(1.0, stamina + dt * 2.2);
      }
      if (stamina <= 0) fly = false;
    }

    final w = game.weather;
    final rain = w.isRaining && !run.has(ItemEffect.raincoat);
    final thrustF = (rain ? w.thrustFactor : 1.0) * (webT > 0 ? kWebThrust : 1.0);
    final glideF = rain ? w.glideFallFactor : 1.0;
    // Windfahne: Wind schiebt nur in die eigene Flugrichtung
    final windX = run.has(ItemEffect.windVane) && w.windX.sign != face ? 0.0 : w.windX;

    if (dashT > 0 || slideT > 0) {
      dashT = max(0.0, dashT - dt);
      slideT = max(0.0, slideT - dt);
      if (slideT > 0) vel.y += 1600 * dt;
    } else {
      if (c.freeFlight) {
        // Kolibri: Stick analog – halber Ausschlag, halbes Tempo
        final h = game.inHorizontal;
        vel.x += clampD(h * maxSpeed - vel.x, -accel * dt, accel * dt);
        if (h.abs() > 0.1) face = h.sign;
      } else if (dir != 0) {
        vel.x += dir * accel * dt;
        face = dir.toDouble();
      } else {
        vel.x *= pow(0.002, dt);
      }
      vel.x = clampD(vel.x, -maxSpeed, maxSpeed);

      if (c.freeFlight) {
        // Kolibri: keine Schwerkraft, senkrecht wie waagerecht steuern, ohne Eingabe stehen bleiben
        final target = game.inVertical * kFreeFlightSpeed * (1 + run.stat(Stat.thrust) / 100) * thrustF;
        final step = kFreeFlightAccel * c.accelMul * dt;
        vel.y += clampD(target - vel.y, -step, step);
      } else {
        // Halten = Schub nach oben, Loslassen = langsames Gleiten nach unten
        final thrust = 1250.0 * c.thrustMul * (1 + run.stat(Stat.thrust) / 100) * thrustF;
        final glide = 150 * c.glideMul * glideF / (1 + max(0.0, run.stat(Stat.glide)) / 100);
        // Sinkflug (nach unten halten): schnell nach unten statt gleiten
        final dive = game.inDown && !fly;
        vel.y += ((fly ? -thrust : 0.0) + 650 + (dive ? kDiveAccel : 0)) * dt;
        vel.y = clampD(vel.y, -340, fly ? 340.0 : (dive ? kDiveSpeed : glide));
      }
    }

    position.x = clampD(position.x + (vel.x + windX) * dt, r, game.worldW - r);
    position.y += vel.y * dt;
    // Specht: klammert sich an den Weltrand, solange er dagegen drückt
    clinging = c.wallCling &&
        !fly &&
        ((position.x <= r + 1 && dir < 0) || (position.x >= game.worldW - r - 1 && dir > 0));
    if (clinging) vel.y = 0;
    if (position.y < kCeil + r) {
      position.y = kCeil + r;
      vel.y = max(0.0, vel.y);
    }
    grounded = false;
    if (position.y > kGround - r) {
      position.y = kGround - r;
      vel.y = 0;
      grounded = true;
    }
    final flapping = fly || (c.freeFlight && !grounded);
    anim += dt * (flapping ? 24 : (grounded ? 3 : 8)) * (c.look == BirdLook.hummingbird ? 2.2 : 1);
    _updateFace(dt);
    iframe = max(0.0, iframe - dt);

    _trailT -= dt;
    if (_trailT <= 0) {
      _trailT = 0.025;
      _trail.insert(0, position.clone());
      if (_trail.length > 16) _trail.removeLast();
    }
  }

  /// Blinzeln alle paar Sekunden, Blick zum nächsten Gegner.
  double _blinkT = 2, _blink = 0;
  Offset _look = Offset.zero;

  void _updateFace(double dt) {
    _blinkT -= dt;
    if (_blinkT <= 0) {
      _blinkT = 2.5 + game.rng.nextDouble() * 3;
    }
    final b = _blinkT < 0.16 ? sin(_blinkT / 0.16 * pi) : 0.0;
    _blink = b;
    Vector2? near;
    var best = 400.0 * 400;
    for (final e in game.enemies) {
      if (e.dead) continue;
      final d2 = e.position.distanceToSquared(position);
      if (d2 < best) {
        best = d2;
        near = e.position;
      }
    }
    final target = near == null ? Offset.zero : Offset((near.x - x) * face, near.y - y) / max(1.0, sqrt(best)) * 1.0;
    _look = Offset.lerp(_look, target, min(1.0, dt * 8))!;
  }

  /// Im Titelbildschirm zieht der Vogel ruhige Bögen unter dem Menü.
  void _menuFlight(double dt) {
    if (dt <= 0) return;
    final t = game.clock;
    final tx = game.camX + game.viewW * (0.5 + 0.36 * sin(t * 0.21));
    final ty = 410 + sin(t * 0.57) * 26 + sin(t * 1.3) * 8;
    vel.setValues((tx - x) / dt, (ty - y) / dt);
    if (vel.x.abs() > 5) face = vel.x.sign;
    position.setValues(tx, ty);
    anim += dt * (vel.y < 0 ? 22 : 9);
    _trailT -= dt;
    if (_trailT <= 0) {
      _trailT = 0.025;
      _trail.insert(0, position.clone());
      if (_trail.length > 16) _trail.removeLast();
    }
  }

  // ---------------- Darstellung: leuchtender Geistvogel ----------------

  /// Letzte Positionen für den Lichtschweif (Weltkoordinaten).
  final _trail = <Vector2>[];
  double _trailT = 0;

  static Paint bodyPaint(CharacterDef ch) => BirdArt.bodyPaint(ch);
  Paint _body = BirdArt.bodyPaint(characterDefs.first);
  static final _bubble = Paint()
    ..style = PaintingStyle.stroke
    ..strokeWidth = 2.5;

  @override
  void render(Canvas c) {
    if (game.run == null && game.phase != Phase.menu) return;
    final ch = character, g = ch.glow;
    final blink = iframe > 0 && dashT <= 0 && (iframe * 20).floor().isOdd;

    // Licht auf dem Boden, schwächer je höher der Vogel fliegt
    final h = clampD(1 - (kGround - y) / 420, 0.15, 1);
    Glow.draw(c, 0, kGround - y + 4, 70 * h + 20, g.withValues(alpha: 0.45 * h));

    // Lichtschweif (Glutkehlchen: Funken, Sturzflug: heller und länger)
    final boost = dashT > 0 || slideT > 0;
    for (var i = 1; i < _trail.length; i++) {
      final p = _trail[i], k = 1 - i / _trail.length;
      final col = ch.look == BirdLook.robin && i.isEven ? const Color(0xFFFF6A2A) : g;
      Glow.draw(c, p.x - x, p.y - y, (6 + 14 * k) * (boost ? 1.6 : 1), col.withValues(alpha: (boost ? 0.8 : 0.5) * k));
    }

    // Aura
    Glow.draw(c, 0, 0, 62 * ch.scale, g.withValues(alpha: blink ? 0.25 : 0.55));
    if (game.shieldT > 0) {
      final a = clampD(game.shieldT, 0, 1);
      Glow.draw(c, 0, 0, r * 3.4, Color.fromRGBO(160, 230, 255, 0.35 * a));
      _bubble.color = Color.fromRGBO(200, 245, 255, 0.85 * a);
      c.drawCircle(Offset.zero, r + 10, _bubble);
    }
    if (blink) return;

    c.save();
    c.scale(face * ch.scale, ch.scale);
    final webbed = webT > 0;
    final upright = ch.look == BirdLook.penguin && slideT <= 0;
    c.rotate(slideT > 0 ? pi / 2.4 : (upright ? 0 : clampD(vel.y / 1000, -0.35, 0.35)));
    final fl = sin(anim) * 0.9;
    drawBird(c, ch, _body, fl, upright, pose: BirdPose(
      flap: fl,
      upright: upright,
      blink: _blink,
      look: _look,
      walk: grounded && vel.x.abs() > 20 && slideT <= 0 ? x * 0.12 : null,
      holding: (game.run?.weapons.isNotEmpty ?? false) && !grounded,
      sway: clampD(vel.x * face / 300, -1, 1),
      t: game.clock,
    ));
    if (webbed) _drawWeb(c);
    c.restore();
  }

  static final _webPaint = Paint()
    ..style = PaintingStyle.stroke
    ..strokeWidth = 1
    ..color = const Color(0xCCE6E6F2);

  /// Spinnennetz über dem Vogel.
  static void _drawWeb(Canvas c) {
    for (var i = 0; i < 6; i++) {
      final a = i / 6 * pi;
      c.drawLine(Offset(cos(a) * 20, sin(a) * 20), Offset(-cos(a) * 20, -sin(a) * 20), _webPaint);
    }
    c.drawCircle(Offset.zero, 9, _webPaint);
    c.drawCircle(Offset.zero, 16, _webPaint);
  }

  /// Vogel ohne Schein und Schweif in lokalen Koordinaten (auch für die Vorschau im Menü).
  static void drawBird(Canvas c, CharacterDef ch, Paint body, double fl, bool upright, {BirdPose? pose}) =>
      BirdArt.draw(c, ch, body, pose ?? BirdPose(flap: fl, upright: upright));

}
