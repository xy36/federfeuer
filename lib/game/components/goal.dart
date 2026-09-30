import 'dart:math';

import 'package:flame/components.dart';
import 'package:flutter/material.dart';

import '../config.dart';
import 'draw.dart';
import 'transient.dart';

/// Ziel am rechten Weltende: leuchtendes Tor mit Zielflagge.
class Goal extends PositionComponent with Transient {
  Goal(double x) : super(position: Vector2(x, 0), priority: -30);

  double _t = 0;
  final _glow = Paint()
    ..shader = LinearGradient(
      colors: [Palette.sun.withAlpha(0), Palette.sun, Palette.sun.withAlpha(0)],
    ).createShader(const Rect.fromLTWH(-40, 0, 80, 1));

  @override
  void update(double dt) => _t += dt;

  @override
  void render(Canvas c) {
    // Leuchtender Streifen über die ganze Flughöhe; die Paint-Deckkraft pulsiert.
    _glow.color = Color.fromRGBO(0, 0, 0, 0.25 + 0.2 * sin(_t * 3));
    c.drawRect(const Rect.fromLTWH(-40, kCeil, 80, kGround - kCeil), _glow);

    // Mast
    drawRect(c, -4, kCeil + 30, 8, kGround - kCeil - 30, Palette.ink);
    drawCircle(c, 0, kCeil + 28, 7, Palette.sun);

    // Karierte Flagge, weht leicht
    const cols = 6, rows = 4, cell = 12.0;
    for (var i = 0; i < cols; i++) {
      final wave = sin(_t * 5 - i * 0.7) * 3;
      for (var j = 0; j < rows; j++) {
        final col = (i + j).isEven ? Colors.white : Palette.ink;
        drawRect(c, 4 + i * cell, kCeil + 34 + j * cell + wave, cell, cell, col);
      }
    }
    OutlineText.draw(c, 'ZIEL', const Offset(0, kGround - 20), size: 16, color: Palette.sun);
  }
}
