import 'dart:math';

import 'package:flame/components.dart';
import 'package:flutter/material.dart';

import '../config.dart';
import '../federfeuer_game.dart';
import 'draw.dart';
import 'light.dart';

class Player extends PositionComponent with HasGameReference<FederfeuerGame> {
  Player() : super(priority: 10);

  final vel = Vector2.zero();
  final double r = 16;
  double face = 1, iframe = 0, anim = 0;
  bool grounded = false;

  void reset(Vector2 p) {
    position.setFrom(p);
    vel.setZero();
    iframe = 1;
    face = 1;
    _trail.clear();
  }

  @override
  void update(double dt) {
    final run = game.run;
    if (run == null && game.phase == Phase.menu) {
      _menuFlight(dt);
      return;
    }
    if (run == null || !game.playing) return;

    final dir = (game.inRight ? 1 : 0) - (game.inLeft ? 1 : 0);
    final double maxSpeed = kPlayerSpeed * max(0.4, 1 + run.stat(Stat.speed) / 100);
    final fly = game.inFly;

    if (dir != 0) {
      vel.x += dir * 1500 * dt;
      face = dir.toDouble();
    } else {
      vel.x *= pow(0.002, dt);
    }
    vel.x = clampD(vel.x, -maxSpeed, maxSpeed);

    // Halten = Schub nach oben, Loslassen = langsames Gleiten nach unten
    // Regen: weniger Schub, schnelleres Absinken beim Gleiten
    final w = game.weather;
    vel.y += ((fly ? -1250.0 * w.thrustFactor : 0.0) + 650) * dt;
    vel.y = clampD(vel.y, -340, fly ? 340.0 : 150 * w.glideFallFactor);

    // Wind als Drift: Höchsttempo bleibt, gegen den Wind geht es langsamer voran
    position.x = clampD(position.x + (vel.x + w.windX) * dt, r, game.worldW - r);
    position.y += vel.y * dt;
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
    anim += dt * (fly ? 24 : (grounded ? 3 : 8));
    iframe = max(0.0, iframe - dt);

    _trailT -= dt;
    if (_trailT <= 0) {
      _trailT = 0.025;
      _trail.insert(0, position.clone());
      if (_trail.length > 16) _trail.removeLast();
    }
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

  static final _body = Paint()
    ..shader = const RadialGradient(
      center: Alignment(0.25, -0.3),
      colors: [Color(0xFFFFFFFF), Color(0xFFFFF3C4), Color(0xFFFFD23F), Color(0xFFFF9F1C)],
      stops: [0, 0.3, 0.72, 1],
    ).createShader(Rect.fromCircle(center: Offset.zero, radius: 16));
  static final _wing = Paint()..blendMode = BlendMode.plus;
  static final _lens = Paint()
    ..style = PaintingStyle.stroke
    ..strokeWidth = 1.5
    ..color = const Color(0xFFE6FDFF);

  @override
  void render(Canvas c) {
    if (game.run == null && game.phase != Phase.menu) return;
    final blink = iframe > 0 && (iframe * 20).floor().isOdd;

    // Licht auf dem Boden, schwächer je höher der Vogel fliegt
    final h = clampD(1 - (kGround - y) / 420, 0.15, 1);
    Glow.draw(c, 0, kGround - y + 4, 70 * h + 20, Color.fromRGBO(255, 214, 140, 0.45 * h));

    // Lichtschweif
    for (var i = 1; i < _trail.length; i++) {
      final p = _trail[i], k = 1 - i / _trail.length;
      Glow.draw(c, p.x - x, p.y - y, 6 + 14 * k, Color.fromRGBO(255, 220, 150, 0.5 * k));
    }

    // Aura
    Glow.draw(c, 0, 0, 62, Color.fromRGBO(255, 200, 110, blink ? 0.25 : 0.55));
    if (blink) return;

    c.save();
    c.scale(face, 1);
    c.rotate(clampD(vel.y / 1000, -0.35, 0.35));
    final fl = sin(anim) * 0.9;

    // Hinterer Flügel und Schwanzfedern aus Licht
    _wing.color = const Color(0x99FFC857);
    _feather(c, -3, -4, 15, 7, -0.6 + fl);
    _wing.color = const Color(0xB3FFE08A);
    drawTri(c, -13, -3, -27, -11, -25, 6, const Color(0xFFFFB347));
    Glow.draw(c, -24, -2, 16, const Color(0x80FFD27A));

    // Körper mit Lichtkern
    c.drawCircle(Offset.zero, 16, _body);
    drawOval(c, 4, 6, 8, 6, const Color(0xCCFFFFFF));
    // Schnabel
    drawTri(c, 13, -3, 24, 1, 13, 5, const Color(0xFFFF8A3D));
    // Fliegerbrille: dunkles Band, leuchtendes Glas
    drawRect(c, -15, -9, 26, 4.5, const Color(0xFF3A2440));
    Glow.draw(c, 7, -6.5, 14, const Color(0xB39BF6FF));
    drawCircle(c, 7, -6.5, 5, const Color(0xFFBFF8FF));
    c.drawCircle(const Offset(7, -6.5), 5, _lens);
    drawCircle(c, 8.5, -6.5, 1.8, const Color(0xFF1B1030));

    // Vorderer Flügel, leuchtet beim Flügelschlag auf
    _wing.color = Color.fromRGBO(255, 236, 170, 0.75 + 0.2 * fl.abs());
    _feather(c, -4, 3, 14, 7, 0.35 - fl * 0.8);
    c.restore();
  }

  /// Lichtflügel als gestreckte Tropfenform, additiv gezeichnet.
  void _feather(Canvas c, double x, double y, double rx, double ry, double rot) {
    c.save();
    c.translate(x, y);
    c.rotate(rot);
    final p = Path()
      ..moveTo(rx, 0)
      ..quadraticBezierTo(0, -ry * 1.3, -rx, 0)
      ..quadraticBezierTo(0, ry * 1.1, rx, 0)
      ..close();
    c.drawPath(p, _wing);
    c.restore();
  }
}
