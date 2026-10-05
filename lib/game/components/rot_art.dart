import 'dart:math';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

/// Gegner im Stil „Fäulnis“ – das Gegenstück zu den Lichtvögeln: fast schwarze Silhouetten
/// mit violettem Schimmer im Inneren, glühenden Rissen, zerfransten Rändern und
/// abreißenden Rauchfahnen. Formen und Verläufe werden je Gegnertyp einmal gebaut und
/// wiederverwendet, weil bis zu 110 Gegner gleichzeitig gezeichnet werden.
class RotArt {
  RotArt._();

  static const ink = Color(0xFF0B0612), inkLight = Color(0xFF241433), vein = Color(0xFFE04AFF);

  /// Füllung mit violettem Kern (lokale Koordinaten, Radius [r]).
  static Paint fill(double r, {Offset center = Offset.zero, Color core = const Color(0xFF2A1440)}) => Paint()
    ..shader = ui.Gradient.radial(center, r, [core, const Color(0xFF140A1E), ink], const [0, 0.4, 1]);

  static final _fills = <String, Paint>{};
  static Paint cachedFill(String key, double r, {Offset center = Offset.zero, Color core = const Color(0xFF2A1440)}) =>
      _fills.putIfAbsent(key, () => fill(r, center: center, core: core));

  static final _veinPaint = Paint()
    ..style = PaintingStyle.stroke
    ..strokeCap = StrokeCap.round
    ..strokeJoin = StrokeJoin.round
    ..blendMode = BlendMode.plus;
  static final _rimPaint = Paint()
    ..style = PaintingStyle.stroke
    ..strokeJoin = StrokeJoin.round
    ..blendMode = BlendMode.plus;

  /// Glühende Adern (pulsierend). [pulse] 0–1.
  static void veins(Canvas c, Path p, double pulse, {Color color = vein, double width = 1.2}) {
    _veinPaint
      ..strokeWidth = width * 3
      ..color = color.withValues(alpha: 0.12 + 0.12 * pulse);
    c.drawPath(p, _veinPaint);
    _veinPaint
      ..strokeWidth = width
      ..color = Color.lerp(color, Colors.white, 0.25)!.withValues(alpha: 0.55 + 0.4 * pulse);
    c.drawPath(p, _veinPaint);
  }

  /// Kränkliches Gegenlicht an der Oberkante einer Form.
  static void rim(Canvas c, Path p, Rect clip, {Color color = const Color(0xFFB44CFF), double alpha = 0.6}) {
    c.save();
    c.clipRect(clip);
    _rimPaint
      ..strokeWidth = 1
      ..color = color.withValues(alpha: alpha);
    c.drawPath(p, _rimPaint);
    c.restore();
  }

  /// Rauchfahne: weiche, dunkel-violette Schwaden, die nach hinten abreißen und verblassen.
  static void smoke(Canvas c, Offset from, double t, {int n = 4, double len = 22, double seed = 0}) {
    for (var i = 0; i < n; i++) {
      final ph = (t * 0.9 + i / n + seed) % 1;
      final p = from + Offset(-ph * len, sin(t * 3 + i + seed) * 3 - ph * 5);
      final a = (1 - ph) * min(1.0, ph * 5);
      c.drawCircle(p, 2 + ph * 3, Paint()..color = const Color(0xFF1A0C26).withValues(alpha: 0.16 * a));
    }
  }

  // ---------------- Fäulniskrähe ----------------

  static final _crowBody = Path()
    ..moveTo(13, -4) // Stirn
    ..cubicTo(11, -10, 3, -10, 0, -6)
    ..cubicTo(-5, -5, -11, -5, -15, -1) // Rücken
    ..lineTo(-21, -3) // zerfranster Schwanz
    ..lineTo(-18, 0)
    ..lineTo(-23, 2)
    ..lineTo(-17, 3)
    ..lineTo(-20, 6)
    ..lineTo(-13, 5)
    ..cubicTo(-7, 9, 4, 9, 9, 4) // Bauch
    ..cubicTo(12, 2, 14, 0, 13, -4)
    ..close();
  static final _crowBeak = Path()
    ..moveTo(12, -4)
    ..lineTo(23, -0.5)
    ..lineTo(12, 1.5)
    ..close();
  static final _crowVeins = Path()
    ..moveTo(-12, -1)
    ..lineTo(-6, -3)
    ..lineTo(-2, 0)
    ..lineTo(3, -2)
    ..moveTo(-2, 0)
    ..lineTo(0, 4);

  /// Fäulniskrähe: Körper mit zerfranstem Schwanz, breite Flügel mit zerfetzter Hinterkante,
  /// glühende Adern, Rauchschwaden. [fl] Flügelschlag −1 (oben) … 1 (unten).
  static void crow(Canvas c, double t, double fl, double pulse, {bool hit = false, bool withSmoke = true}) {
    Color k(Color col) => hit ? Color.lerp(col, Colors.white, 0.85)! : col;
    if (withSmoke) crowSmoke(c, t);
    rotWing(c, const Offset(-1, -5), fl, 21, k(const Color(0xFF120818)), far: true);
    c.drawPath(_crowBody, hit ? (Paint()..color = k(ink)) : cachedFill('crow', 18, center: const Offset(3, -2)));
    rim(c, _crowBody, const Rect.fromLTRB(-25, -12, 15, -3), alpha: 0.45);
    veins(c, _crowVeins, pulse);
    c.drawPath(_crowBeak, Paint()..color = k(const Color(0xFF221430)));
    rotWing(c, const Offset(0, -3), fl, 20, k(const Color(0xFF1C0E28)), far: false);
  }

  /// Rauchfahne der Krähe (wird bei den Gegner-Sprites live darübergezeichnet).
  static void crowSmoke(Canvas c, double t) => smoke(c, const Offset(-16, 1), t, n: 3, len: 18, seed: 0.3);

  /// Flügel: breite Form vom Schultergelenk nach hinten oben, Hinterkante mit Fetzen und Lücken.
  /// Schlägt zwischen steil oben (fl = −1) und waagerecht/leicht unten (fl = 1).
  static void rotWing(Canvas c, Offset at, double fl, double len, Color col, {required bool far}) {
    c.save();
    c.translate(at.dx, at.dy);
    c.rotate(-0.1 + (1 - fl) * 0.55 + (far ? 0.25 : 0));
    final p = Path()
      ..moveTo(3, 0)
      ..quadraticBezierTo(-len * 0.4, -len * 0.32, -len, -len * 0.18) // Vorderkante
      // zerfetzte Hinterkante: Federspitzen mit Lücken
      ..lineTo(-len * 0.86, -len * 0.04)
      ..lineTo(-len * 0.92, len * 0.06)
      ..lineTo(-len * 0.72, len * 0.04)
      ..lineTo(-len * 0.76, len * 0.16)
      ..lineTo(-len * 0.56, len * 0.1)
      ..lineTo(-len * 0.58, len * 0.2)
      ..lineTo(-len * 0.36, len * 0.12)
      ..quadraticBezierTo(-len * 0.15, len * 0.16, 3, 3)
      ..close();
    c.drawPath(p, Paint()..color = col);
    if (!far) {
      _rimPaint
        ..strokeWidth = 0.9
        ..color = const Color(0xFFB44CFF).withValues(alpha: 0.5);
      c.drawPath(
          Path()
            ..moveTo(3, 0)
            ..quadraticBezierTo(-len * 0.4, -len * 0.32, -len, -len * 0.18),
          _rimPaint);
    }
    c.restore();
  }
}
