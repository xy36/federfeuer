import 'dart:math';

import 'package:flame/components.dart';
import 'package:flutter/material.dart';

import '../config.dart';
import '../federfeuer_game.dart';
import 'draw.dart';

class Player extends PositionComponent with HasGameReference<FederfeuerGame> {
  Player() : super(priority: 10);

  final vel = Vector2.zero();
  final double r = 16;
  double face = 1, iframe = 0, anim = 0;
  bool grounded = false;

  static final _stroke = Paint()
    ..style = PaintingStyle.stroke
    ..strokeWidth = 2
    ..color = Palette.ink;

  void reset(Vector2 p) {
    position.setFrom(p);
    vel.setZero();
    iframe = 1;
    face = 1;
  }

  @override
  void update(double dt) {
    final run = game.run;
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
  }

  @override
  void render(Canvas c) {
    if (game.run == null) return;
    drawShadow(c, position.y, r);
    if (iframe > 0 && (iframe * 20).floor().isOdd) return;

    c.save();
    c.scale(face, 1);
    c.rotate(clampD(vel.y / 1000, -0.35, 0.35));
    final fl = sin(anim) * 0.9;
    drawOval(c, -3, -4, 13, 6, const Color(0xFFD69A00), -0.6 + fl);
    drawTri(c, -13, -3, -25, -10, -23, 5, const Color(0xFFFF9F1C));
    drawCircle(c, 0, 0, 16, Palette.sun);
    drawOval(c, 4, 6, 9, 7, const Color(0xFFFFF0B3));
    drawTri(c, 13, -3, 25, 1, 13, 5, const Color(0xFFFF7A3D));
    drawRect(c, -15, -9, 27, 5, Palette.ink);
    drawCircle(c, 7, -6, 5.5, Palette.cyan);
    c.drawCircle(const Offset(7, -6), 5.5, _stroke);
    drawCircle(c, 8.5, -6, 2, Palette.ink);
    drawOval(c, -4, 3, 12, 6, const Color(0xFFFFBF1F), 0.35 - fl * 0.8);
    c.restore();
  }
}
