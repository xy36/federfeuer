import 'dart:math';

import 'package:flame/components.dart';
import 'package:flutter/material.dart';

import '../config.dart';
import 'draw.dart';
import 'light.dart';
import 'transient.dart';

/// Ziel am rechten Weltende: eine Lichtsäule, in der Lichtkugeln aufsteigen.
class Goal extends PositionComponent with Transient {
  Goal(double x, {bool Function()? locked})
      : _locked = locked,
        super(position: Vector2(x, 0), priority: -30);

  /// Versperrt (Torwächter lebt): Licht gedämpft, violette Gitterstäbe.
  final bool Function()? _locked;
  double _t = 0;
  final _beam = Paint()
    ..blendMode = BlendMode.plus
    ..shader = const LinearGradient(
      colors: [Color(0x00FFE6A0), Color(0xFFFFE6A0), Color(0x00FFE6A0)],
    ).createShader(const Rect.fromLTWH(-34, 0, 68, 1));
  final _core = Paint()
    ..blendMode = BlendMode.plus
    ..shader = const LinearGradient(
      begin: Alignment.bottomCenter,
      end: Alignment.topCenter,
      colors: [Color(0xFFFFFFFF), Color(0x00FFFFFF)],
    ).createShader(const Rect.fromLTWH(0, kCeil - 40, 1, kGround - kCeil + 40));

  @override
  void update(double dt) => _t += dt;

  @override
  void render(Canvas c) {
    final pulse = 0.5 + 0.5 * sin(_t * 2.4);
    // Breiter weicher Strahl und heller Kern
    _beam.color = Color.fromRGBO(0, 0, 0, 0.16 + 0.08 * pulse);
    c.drawRect(const Rect.fromLTRB(-34, kCeil - 40, 34, kGround), _beam);
    _core.color = Color.fromRGBO(0, 0, 0, 0.4 + 0.15 * pulse);
    c.drawRect(const Rect.fromLTRB(-2, kCeil - 40, 2, kGround), _core);

    // Aufsteigende Lichtkugeln
    for (var i = 0; i < 9; i++) {
      final k = ((_t * 0.35 + i / 9) % 1);
      final y = kGround - k * (kGround - kCeil);
      final x = sin(_t * 1.3 + i * 2.1) * 18;
      Glow.draw(c, x, y, 10 + 6 * sin(i + _t), Color.fromRGBO(255, 236, 170, 0.8 * (1 - k)));
    }

    // Lichtquelle am Boden
    Glow.draw(c, 0, kGround - 4, 80 + 20 * pulse, const Color(0x8CFFD98A));
    drawOval(c, 0, kGround - 2, 26, 5, const Color(0xFFFFF4D6));
    final locked = _locked?.call() ?? false;
    if (locked) {
      for (var i = -2; i <= 2; i++) {
        drawRect(c, i * 14.0 - 1.5, kCeil, 3, kGround - kCeil, Color.fromRGBO(180, 76, 255, 0.55 + 0.2 * pulse));
      }
      Glow.draw(c, 0, (kGround + kCeil) / 2, 90, Color.fromRGBO(180, 76, 255, 0.25 + 0.1 * pulse));
    }
    OutlineText.draw(c, locked ? 'VERSPERRT' : 'ZIEL', const Offset(0, kGround - 34),
        size: 15, color: locked ? const Color(0xFFE6B8FF) : const Color(0xFFFFF1C2));
  }
}
