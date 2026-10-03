import 'dart:math';

import 'package:flutter/material.dart';

import 'draw.dart';
import 'light.dart';

/// Eigene Modelle für alle 18 Waffen, prozedural gezeichnet.
///
/// Koordinaten: Griff im Ursprung, die Waffe zeigt nach +x (Zielrichtung), Länge etwa 24.
/// [kick] 0–1 = Rückstoß/Schussmoment, [t] = Zeit für Animationen (Drehen, Flackern),
/// [tier] = Stufenfarbe (Rand, Glanz, Edelstein am Griff).
class WeaponArt {
  WeaponArt._();

  static final _stroke = Paint()
    ..style = PaintingStyle.stroke
    ..strokeCap = StrokeCap.round
    ..strokeJoin = StrokeJoin.round;
  static final _glowStroke = Paint()
    ..style = PaintingStyle.stroke
    ..strokeCap = StrokeCap.round
    ..blendMode = BlendMode.plus;

  /// Spitze, aus der geschossen wird (für Mündungslicht), je Waffe.
  static double muzzle(String id) => switch (id) {
        'pistol' => 24,
        'rail' => 26,
        'disco' => 0,
        'rocket' => 20,
        'shotgun' => 22,
        'popcorn' => 6,
        'smg' => 16,
        'feather' => 0,
        'dandelion' => 22,
        'vine' => 24,
        'crowcall' => 22,
        'lantern' => 14,
        'water' => 24,
        'bubbles' => 22,
        'raincloud' => 14,
        'pebble' => 18,
        'gnome' => 22,
        'bowling' => 18,
        _ => 20,
      };

  /// Waffen, die beim Zielen nicht mitdrehen (rundum, über dem Vogel, an Henkel/Stiel hängend).
  static bool upright(String id) => const {'disco', 'popcorn', 'lantern', 'raincloud', 'feather'}.contains(id);

  static void draw(Canvas c, String id, {required double kick, required double t, required Color tier}) {
    // Stufen-Schein hinter der Waffe, wächst mit der Stufe über den Grundton
    Glow.draw(c, 10, 0, 26, tier.withAlpha(70));
    final recoil = -kick * 4;
    c.save();
    c.translate(recoil, 0);
    switch (id) {
      case 'pistol':
        _quill(c, kick, t);
      case 'rail':
        _sunLens(c, kick, t);
      case 'disco':
        _disco(c, t);
      case 'rocket':
        _emberCannon(c, kick, t);
      case 'shotgun':
        _sparkFan(c, kick, t);
      case 'popcorn':
        _popcorn(c, kick, t);
      case 'smg':
        _pinwheel(c, kick, t);
      case 'feather':
        _handFan(c, t);
      case 'dandelion':
        _dandelion(c, kick, t);
      case 'vine':
        _vine(c, kick, t);
      case 'crowcall':
        _crowHorn(c, kick, t);
      case 'lantern':
        _lantern(c, kick, t);
      case 'water':
        _waterGun(c, kick, t);
      case 'bubbles':
        _bubbleWand(c, kick, t);
      case 'raincloud':
        _cloudStaff(c, kick, t);
      case 'pebble':
        _slingshot(c, kick, t);
      case 'gnome':
        _gnomeCannon(c, kick, t);
      case 'bowling':
        _bowlingRamp(c, kick, t);
      default:
        drawRect(c, 0, -2, 20, 4, Colors.white);
    }
    // Edelstein in Stufenfarbe am Griff
    drawCircle(c, 0, 0, 2.6, tier);
    drawCircle(c, -0.6, -0.6, 1, Colors.white.withAlpha(200));
    c.restore();
    // Mündungslicht beim Schuss
    final m = muzzle(id);
    if (kick > 0 && m > 0) Glow.draw(c, m + recoil, 0, 8 + 16 * kick, Color.lerp(tier, Colors.white, 0.6)!.withAlpha((230 * kick).round()));
  }

  // ---------------- Licht ----------------

  /// Lichtfeder: Federkiel mit goldener Fahne und leuchtender Spitze.
  static void _quill(Canvas c, double kick, double t) {
    final vane = Path()
      ..moveTo(2, 0)
      ..quadraticBezierTo(10, -7, 22, -1.5)
      ..lineTo(24, 0)
      ..quadraticBezierTo(12, 5, 2, 0)
      ..close();
    c.drawPath(vane, fillOf(const Color(0xFFFFE6A0)));
    // Federäste
    _stroke
      ..strokeWidth = 0.8
      ..color = const Color(0xFFC9A04A);
    for (var i = 0; i < 6; i++) {
      final x = 5.0 + i * 3;
      c.drawLine(Offset(x, 0), Offset(x + 2.5, -3.2 + i * 0.25), _stroke);
    }
    _stroke
      ..strokeWidth = 1.4
      ..color = const Color(0xFFFFFFFF);
    c.drawLine(const Offset(-2, 0), const Offset(24, 0), _stroke);
    Glow.draw(c, 24, 0, 8 + 3 * sin(t * 6), const Color(0xCCFFF3B0));
  }

  /// Sonnenstrahl: goldenes Rohr mit Ringen und großer Linse vorn.
  static void _sunLens(Canvas c, double kick, double t) {
    drawRect(c, -2, -3, 22, 6, const Color(0xFF8A6A2A));
    drawRect(c, -2, -3, 22, 2, const Color(0xFFC9A04A));
    for (final x in [4.0, 10.0, 16.0]) {
      drawRect(c, x, -3.6, 1.6, 7.2, const Color(0xFFFFD27A));
    }
    drawOval(c, 23, 0, 3, 6, const Color(0xFFFFF0B8));
    drawOval(c, 23.6, -1.5, 1, 2.2, Colors.white);
    Glow.draw(c, 24, 0, 12 + 4 * sin(t * 3), const Color(0x99FFE6A0));
  }

  /// Diskokugel an kurzem Stiel, Facetten drehen sich.
  static void _disco(Canvas c, double t) {
    drawRect(c, -1, 0, 2, 10, const Color(0xFF6A6080));
    drawCircle(c, 0, -2, 8, const Color(0xFF8A84A8));
    for (var row = -2; row <= 2; row++) {
      final ry = row * 3.0 - 2;
      final half = sqrt(max(0.0, 64 - pow(row * 3.0, 2)));
      for (var k = 0; k < 4; k++) {
        final x = -half + ((k / 4 + t * 0.4) % 1) * half * 2;
        final bright = (k + row).isEven;
        drawRect(c, x - 1.2, ry - 1.2, 2.4, 2.4, bright ? const Color(0xFFFFFFFF) : const Color(0xFFFF9FE6));
      }
    }
    Glow.draw(c, 0, -2, 16, const Color(0x88F2D6FF));
  }

  // ---------------- Glut ----------------

  /// Glutkern: kurze, dicke Kohlenkanone mit glühendem Inneren.
  static void _emberCannon(Canvas c, double kick, double t) {
    final body = Path()
      ..moveTo(-2, -4)
      ..lineTo(16, -6)
      ..lineTo(20, -6)
      ..lineTo(20, 6)
      ..lineTo(16, 6)
      ..lineTo(-2, 4)
      ..close();
    c.drawPath(body, fillOf(const Color(0xFF2A1A16)));
    // Glutrisse
    _glowStroke
      ..strokeWidth = 1.4
      ..color = Color.fromRGBO(255, 138, 61, 0.7 + 0.3 * sin(t * 7));
    c.drawLine(const Offset(3, -3), const Offset(9, 1), _glowStroke);
    c.drawLine(const Offset(9, 1), const Offset(14, -3), _glowStroke);
    drawOval(c, 20, 0, 2.5, 5, Color.lerp(const Color(0xFFFF8A3D), Colors.white, 0.3 * kick)!);
    Glow.draw(c, 20, 0, 12 + 8 * kick, const Color(0xAAFF8A3D));
  }

  /// Funkenfächer: fünf Speichen mit glühenden Spitzen.
  static void _sparkFan(Canvas c, double kick, double t) {
    final spread = 0.55 + 0.15 * kick;
    for (var i = -2; i <= 2; i++) {
      final a = i / 2 * spread;
      final tip = Offset(cos(a) * 20, sin(a) * 20);
      _stroke
        ..strokeWidth = 1.8
        ..color = const Color(0xFF5A3A2A);
      c.drawLine(Offset.zero, tip, _stroke);
      drawCircle(c, tip.dx, tip.dy, 2.2, const Color(0xFFFFB37A));
      Glow.draw(c, tip.dx, tip.dy, 7 + 2 * sin(t * 9 + i), const Color(0xAAFFB37A));
    }
    drawCircle(c, 0, 0, 3.5, const Color(0xFF3A2A20));
  }

  /// Popcornmaschine: kleiner rot-weiß gestreifter Wagen mit Kurbel und Popcornkrone.
  static void _popcorn(Canvas c, double kick, double t) {
    drawRect(c, -7, -6, 14, 12, const Color(0xFFE8E0D0));
    for (var i = 0; i < 3; i++) {
      drawRect(c, -7 + i * 5.0, -6, 2.4, 12, const Color(0xFFD03A3A));
    }
    drawRect(c, -8, -8, 16, 2.5, const Color(0xFF8A2A2A));
    // Popcorn quillt oben heraus, hüpft beim Schuss
    for (final (x, y) in [(-4.0, -10.0), (0.0, -11.5), (4.0, -10.0), (-1.5, -13.0), (2.5, -13.5)]) {
      drawCircle(c, x, y - kick * 3, 2.2, const Color(0xFFFFF4C2));
    }
    // Kurbel dreht sich
    final a = t * 4 + kick * 3;
    _stroke
      ..strokeWidth = 1.4
      ..color = const Color(0xFF5A5A6A);
    c.drawLine(const Offset(7, 0), Offset(7 + cos(a) * 4, sin(a) * 4), _stroke);
    drawCircle(c, 7 + cos(a) * 4, sin(a) * 4, 1.4, const Color(0xFFFFC94A));
  }

  // ---------------- Wind ----------------

  /// Böenschwarm: Windrad, dreht sich schneller beim Schießen.
  static void _pinwheel(Canvas c, double kick, double t) {
    _stroke
      ..strokeWidth = 1.6
      ..color = const Color(0xFF8AA8A0);
    c.drawLine(const Offset(-2, 0), const Offset(12, 0), _stroke);
    c.save();
    c.translate(13, 0);
    c.rotate(t * (6 + 20 * kick));
    for (var i = 0; i < 4; i++) {
      c.save();
      c.rotate(i * pi / 2);
      drawTri(c, 0, 0, 7, -2, 6, 3, i.isEven ? const Color(0xFFD9FFF2) : const Color(0xFF7FE8C8));
      c.restore();
    }
    drawCircle(c, 0, 0, 1.6, Colors.white);
    c.restore();
  }

  /// Federwirbel: Handfächer aus Federn.
  static void _handFan(Canvas c, double t) {
    drawRect(c, -1, 0, 2, 7, const Color(0xFF6A8A80));
    final sway = sin(t * 2) * 0.1;
    for (var i = -3; i <= 3; i++) {
      final a = -pi / 2 + i * 0.28 + sway;
      final tip = Offset(cos(a) * 14, sin(a) * 14);
      final p = Path()
        ..moveTo(0, 0)
        ..quadraticBezierTo(tip.dx + cos(a + pi / 2) * 3, tip.dy + sin(a + pi / 2) * 3, tip.dx, tip.dy)
        ..quadraticBezierTo(tip.dx + cos(a - pi / 2) * 3, tip.dy + sin(a - pi / 2) * 3, 0, 0);
      c.drawPath(p, fillOf(i.isEven ? const Color(0xFFCFFFF0) : const Color(0xFF9FE8D0)));
    }
  }

  /// Pusteblume: Stiel mit Samenkugel, Schirmchen fliegen beim Schuss weg.
  static void _dandelion(Canvas c, double kick, double t) {
    final stem = Path()
      ..moveTo(0, 0)
      ..quadraticBezierTo(9, -4, 18, 0);
    _stroke
      ..strokeWidth = 1.6
      ..color = const Color(0xFF6A9A50);
    c.drawPath(stem, _stroke);
    _stroke
      ..strokeWidth = 0.7
      ..color = const Color(0xDDFFFFFF);
    for (var i = 0; i < 12; i++) {
      final a = i / 12 * pi * 2 + t * 0.2;
      final len = 5.0 + (i.isEven ? 1 : 0) - kick * 2;
      c.drawLine(const Offset(18, 0), Offset(18 + cos(a) * len, sin(a) * len), _stroke);
      drawCircle(c, 18 + cos(a) * len, sin(a) * len, 0.9, Colors.white);
    }
    Glow.draw(c, 18, 0, 10, const Color(0x66FFFFF2));
  }

  // ---------------- Böse ----------------

  /// Dornenranke: eingerollte, dornige Peitsche, schnalzt beim Hieb nach vorn.
  static void _vine(Canvas c, double kick, double t) {
    final reach = 12 + 12 * kick;
    final p = Path()..moveTo(0, 0);
    for (var i = 1; i <= 8; i++) {
      final f = i / 8;
      p.lineTo(f * reach + 4, sin(f * pi * 2 + t * 3) * 4 * (1 - kick) - f * 2);
    }
    _stroke
      ..strokeWidth = 2.2
      ..color = const Color(0xFF3A5A2A);
    c.drawPath(p, _stroke);
    for (var i = 1; i <= 6; i++) {
      final f = i / 7;
      final x = f * reach + 4, y = sin(f * pi * 2 + t * 3) * 4 * (1 - kick) - f * 2;
      drawTri(c, x - 1, y, x + 1, y, x, y - 3.5, const Color(0xFFD08CFF));
    }
    drawCircle(c, reach + 4, -2, 2.2, const Color(0xFFB44CFF));
  }

  /// Krähenruf: gebogenes Horn aus Knochen mit violettem Leuchten.
  static void _crowHorn(Canvas c, double kick, double t) {
    final p = Path()
      ..moveTo(0, -1.5)
      ..quadraticBezierTo(10, -8, 20, -5)
      ..lineTo(22, 4)
      ..quadraticBezierTo(10, 3, 0, 1.5)
      ..close();
    c.drawPath(p, fillOf(const Color(0xFFD8CCB8)));
    for (final x in [6.0, 11.0, 16.0]) {
      drawRect(c, x, -6 + x * 0.15, 1.4, 7, const Color(0xFF8A7A6A));
    }
    drawOval(c, 21, -0.5, 2, 4.6, const Color(0xFF1A0E26));
    Glow.draw(c, 22, 0, 10 + 8 * kick, Color.fromRGBO(192, 123, 255, 0.5 + 0.3 * sin(t * 4)));
  }

  /// Paktlaterne: Laterne mit magentafarbener Flamme am Henkel.
  static void _lantern(Canvas c, double kick, double t) {
    _stroke
      ..strokeWidth = 1.4
      ..color = const Color(0xFF4A3A5A);
    c.drawArc(Rect.fromCenter(center: const Offset(0, -10), width: 8, height: 8), pi, pi, false, _stroke);
    drawRect(c, -5, -10, 10, 2, const Color(0xFF4A3A5A));
    drawRect(c, -4.5, -8, 9, 12, const Color(0x55FF6AD5));
    drawRect(c, -5, 4, 10, 2, const Color(0xFF4A3A5A));
    for (final x in [-4.5, 3.5]) {
      drawRect(c, x, -8, 1, 12, const Color(0xFF4A3A5A));
    }
    final fl = 1 + 0.15 * sin(t * 13) + 0.4 * kick;
    drawTri(c, -2 * fl, 2, 2 * fl, 2, 0, -5 * fl, const Color(0xFFFF6AD5));
    drawTri(c, -1, 2, 1, 2, 0, -2.5 * fl, Colors.white);
    Glow.draw(c, 0, -2, 16 + 10 * kick, const Color(0xAAFF6AD5));
  }

  // ---------------- Wasser ----------------

  /// Wasserpistole: bunte Spritzpistole mit Tank.
  static void _waterGun(Canvas c, double kick, double t) {
    drawRect(c, -1, -1, 4, 9, const Color(0xFF2A7AD0));
    final body = RRect.fromRectAndRadius(const Rect.fromLTWH(-2, -6, 20, 7), const Radius.circular(3));
    c.drawRRect(body, fillOf(const Color(0xFF3D9BFF)));
    drawRect(c, 18, -4.5, 6, 3, const Color(0xFF2A7AD0));
    drawOval(c, 6, -9, 5, 3.5, const Color(0xFFFF9F43));
    drawOval(c, 5, -10, 2, 1.2, const Color(0xCCFFFFFF));
    // Wassertropfen an der Mündung
    drawCircle(c, 25 + kick * 4, -3, 1.6 + kick, const Color(0xFFA8E6FF));
  }

  /// Seifenblasen: Pustering mit schillerndem Film.
  static void _bubbleWand(Canvas c, double kick, double t) {
    _stroke
      ..strokeWidth = 1.6
      ..color = const Color(0xFFE88AD0);
    c.drawLine(Offset.zero, const Offset(14, 0), _stroke);
    c.drawCircle(const Offset(18, 0), 4.5, _stroke);
    final film = Paint()
      ..shader = SweepGradient(
        colors: const [Color(0x6680D8FF), Color(0x66FF9FE6), Color(0x66FFF4A0), Color(0x6680D8FF)],
        transform: GradientRotation(t * 2),
      ).createShader(Rect.fromCircle(center: const Offset(18, 0), radius: 4.5));
    c.drawCircle(const Offset(18, 0), 4, film);
    // Blase löst sich beim Schuss
    if (kick > 0) {
      _stroke
        ..strokeWidth = 0.8
        ..color = Colors.white.withAlpha((200 * kick).round());
      c.drawCircle(Offset(22 + (1 - kick) * 6, -2), 3 + (1 - kick) * 2, _stroke);
    }
  }

  /// Regenwolke: kleine Wolke auf einem Stab, es tröpfelt.
  static void _cloudStaff(Canvas c, double kick, double t) {
    drawRect(c, -1, -2, 2, 12, const Color(0xFF5A6A8A));
    for (final (x, y, rr) in [(-5.0, -8.0, 5.0), (1.0, -10.0, 6.0), (6.0, -8.0, 4.5)]) {
      drawCircle(c, x, y, rr, const Color(0xFF9AAAD0));
    }
    drawRect(c, -9, -8, 19, 4, const Color(0xFF9AAAD0));
    for (var i = 0; i < 3; i++) {
      final y = -3.0 + ((t * 2 + i * 0.33) % 1) * 9;
      drawRect(c, -4.0 + i * 4, y, 1, 2.5, const Color(0xFFA8E6FF));
    }
    Glow.draw(c, 1, -9, 14, const Color(0x669FD4FF));
  }

  // ---------------- Stein ----------------

  /// Kieselschleuder: Holz-Y mit Gummiband, das sich beim Schuss spannt.
  static void _slingshot(Canvas c, double kick, double t) {
    _stroke
      ..strokeWidth = 3
      ..color = const Color(0xFF8A5A2A);
    c.drawLine(Offset.zero, const Offset(9, 0), _stroke);
    c.drawLine(const Offset(9, 0), const Offset(16, -6), _stroke);
    c.drawLine(const Offset(9, 0), const Offset(16, 6), _stroke);
    final pull = 6 - kick * 6;
    _stroke
      ..strokeWidth = 1
      ..color = const Color(0xFFB04A3A);
    c.drawLine(const Offset(16, -6), Offset(16 - pull, 0), _stroke);
    c.drawLine(const Offset(16, 6), Offset(16 - pull, 0), _stroke);
    if (kick < 0.5) drawCircle(c, 16 - pull, 0, 2.6, const Color(0xFFB8AFA0));
  }

  /// Gartenzwergwerfer: Mörser, aus dem eine rote Zipfelmütze schaut.
  static void _gnomeCannon(Canvas c, double kick, double t) {
    final body = Path()
      ..moveTo(-2, -4)
      ..lineTo(18, -6)
      ..lineTo(18, 6)
      ..lineTo(-2, 4)
      ..close();
    c.drawPath(body, fillOf(const Color(0xFF5A6A5A)));
    drawRect(c, 4, -5, 2, 10, const Color(0xFF7A8A7A));
    drawOval(c, 19, 0, 2.5, 6, const Color(0xFF2A302A));
    // Zipfelmütze guckt raus, fliegt beim Schuss mit
    final out = 4 + kick * 6;
    drawTri(c, 16 + out, -3.5, 16 + out, 3.5, 24 + out, 0, const Color(0xFFE63946));
    drawCircle(c, 15 + out, 0, 2.5, const Color(0xFFFFD2B0));
  }

  /// Bowlingkugel: Kugel in einer gebogenen Rinne, rollt beim Schuss nach vorn.
  static void _bowlingRamp(Canvas c, double kick, double t) {
    _stroke
      ..strokeWidth = 2.4
      ..color = const Color(0xFF6A5A8A);
    final ramp = Path()
      ..moveTo(-2, -4)
      ..quadraticBezierTo(6, 8, 20, 4);
    c.drawPath(ramp, _stroke);
    final x = 8 + kick * 10;
    drawCircle(c, x, -1, 6, const Color(0xFF2A2440));
    drawCircle(c, x + 1.5, -3.5, 1, const Color(0xFF8F86B8));
    drawCircle(c, x + 3.5, -2, 1, const Color(0xFF8F86B8));
    drawCircle(c, x + 1.5, -0.5, 1, const Color(0xFF8F86B8));
    drawCircle(c, x - 2.5, -3.5, 1.6, const Color(0x55FFFFFF));
  }

  /// Krallen, die die Hauptwaffe am Griff halten (über die Waffe gezeichnet).
  static void claws(Canvas c, Color color) {
    _stroke
      ..strokeWidth = 1.8
      ..color = color;
    for (final dx in [-2.5, 0.0, 2.5]) {
      final p = Path()
        ..moveTo(dx, -4)
        ..quadraticBezierTo(dx + 2.5, -1, dx + 0.5, 3);
      c.drawPath(p, _stroke);
    }
  }
}
