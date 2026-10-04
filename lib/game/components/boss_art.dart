import 'dart:math';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import 'light.dart';
import 'rot_art.dart';

/// Zustand eines Bosses für die Zeichnung.
class BossLook {
  const BossLook({
    required this.t,
    required this.pulse,
    this.warn = 0,
    this.hit = false,
    this.phase = 1,
    this.hp = 1,
    this.state = 0,
  });
  final double t, pulse, warn, hp;
  final bool hit;
  final int phase, state;
}

/// Ausführlich gezeichnete Bosse im Fäulnis-Stil: Geierkönig und die drei Torwächter.
/// Lokale Koordinaten, Blick nach +x, Körpermitte im Ursprung.
class BossArt {
  BossArt._();

  static const _magenta = Color(0xFFFF5AE0), _violet = Color(0xFFB44CFF), _ember = Color(0xFFFF8A3D);

  static final _line = Paint()
    ..style = PaintingStyle.stroke
    ..strokeCap = StrokeCap.round
    ..strokeJoin = StrokeJoin.round;
  static final _add = Paint()
    ..style = PaintingStyle.stroke
    ..strokeCap = StrokeCap.round
    ..strokeJoin = StrokeJoin.round
    ..blendMode = BlendMode.plus;

  static Color _k(BossLook l, Color c) => l.hit ? Color.lerp(c, Colors.white, 0.8)! : c;
  static Paint _fill(Color c) => Paint()..color = c;

  /// Dunkle Feder (Schuppe) mit violettem Saum, für Gefiederreihen.
  static void _scale(Canvas c, Offset at, double w, double h, double rot, Color body, double rim) {
    c.save();
    c.translate(at.dx, at.dy);
    c.rotate(rot);
    final p = Path()
      ..moveTo(-w / 2, 0)
      ..quadraticBezierTo(-w * 0.45, h * 0.9, 0, h)
      ..quadraticBezierTo(w * 0.45, h * 0.9, w / 2, 0)
      ..close();
    c.drawPath(p, _fill(body));
    if (rim > 0) {
      _add
        ..strokeWidth = 0.9
        ..color = _violet.withValues(alpha: rim);
      c.drawPath(
          Path()
            ..moveTo(-w * 0.45, h * 0.55)
            ..quadraticBezierTo(0, h * 1.05, w * 0.45, h * 0.55),
          _add);
    }
    c.restore();
  }

  /// Herabtropfende Fäulnis an einer Unterkante (Tropfen wachsen, reißen ab, fallen).
  static void _drips(Canvas c, List<double> xs, double y, double t, {Color color = _violet, double len = 14}) {
    for (var i = 0; i < xs.length; i++) {
      final ph = (t * 0.5 + i * 0.37) % 1;
      final grow = min(1.0, ph * 2);
      final x = xs[i];
      final p = Path()
        ..moveTo(x - 2, y)
        ..quadraticBezierTo(x, y + len * 0.6 * grow, x + 2, y)
        ..close();
      c.drawPath(p, _fill(const Color(0xFF1A0C26)));
      if (ph > 0.5) {
        final fy = y + len * 0.6 + (ph - 0.5) * 2 * 40;
        c.drawCircle(Offset(x, fy), 1.6, _fill(color.withValues(alpha: (1 - ph) * 1.4)));
      }
    }
  }

  // ============================================================== Geierkönig

  static void vultureKing(Canvas c, BossLook l) {
    final t = l.t, fl = sin(t * 6), pulse = l.pulse;
    final rage = l.phase - 1; // 0, 1, 2
    final veinCol = Color.lerp(_magenta, Colors.white, 0.15 * rage)!;

    // Schwanzfedern: lang, zerfetzt, gefächert
    for (var i = 0; i < 6; i++) {
      final a = pi - 0.35 + i * 0.14 + sin(t * 2 + i) * 0.03;
      final len = 46.0 + (i.isEven ? 8 : 0);
      final base = const Offset(-40, 6);
      final tip = base + Offset(cos(a) * len, sin(a) * len);
      final n = Offset(-sin(a), cos(a)) * 4.5;
      final p = Path()
        ..moveTo(base.dx + n.dx, base.dy + n.dy)
        ..lineTo(tip.dx + n.dx * 0.6, tip.dy + n.dy * 0.6)
        ..lineTo(tip.dx - n.dx * 0.2 + cos(a) * 4, tip.dy - n.dy * 0.2 + sin(a) * 4) // Fetzen
        ..lineTo(tip.dx - n.dx * 0.8, tip.dy - n.dy * 0.8)
        ..lineTo(base.dx - n.dx, base.dy - n.dy)
        ..close();
      c.drawPath(p, _fill(_k(l, i.isEven ? const Color(0xFF140A1E) : const Color(0xFF1C0E28))));
      _add
        ..strokeWidth = 0.8
        ..color = _violet.withValues(alpha: 0.35);
      c.drawLine(base, tip, _add);
    }

    _vultureWing(c, l, const Offset(-8, -18), fl, far: true);

    // Krallen unter dem Körper
    for (final (i, x) in [(0, -10.0), (1, 12.0)]) {
      final sway = sin(t * 3 + i) * 2;
      _line
        ..strokeWidth = 5
        ..color = _k(l, const Color(0xFF2A1A20));
      c.drawLine(Offset(x, 26), Offset(x + sway, 40), _line);
      for (var k = -1; k <= 1; k++) {
        final p = Path()
          ..moveTo(x + sway, 40)
          ..quadraticBezierTo(x + sway + k * 6, 44, x + sway + k * 8 + 2, 50);
        _line
          ..strokeWidth = 2.6
          ..color = _k(l, const Color(0xFF3A2A30));
        c.drawPath(p, _line);
        c.drawCircle(Offset(x + sway + k * 8 + 2, 50), 1.4, _fill(_k(l, const Color(0xFFE8D8C8))));
      }
    }

    // Körper: dunkle Grundform, darüber Federreihen von hinten nach vorn
    final body = Rect.fromCenter(center: const Offset(-2, 2), width: 100, height: 70);
    c.drawOval(body, l.hit ? _fill(_k(l, RotArt.ink)) : RotArt.cachedFill('vk_body', 62, center: const Offset(14, -10)));
    c.save();
    c.clipPath(Path()..addOval(body));
    for (var row = 0; row < 4; row++) {
      final y = -22.0 + row * 13;
      for (var i = 0; i < 9; i++) {
        final x = -46.0 + i * 11 + (row.isOdd ? 5.5 : 0);
        _scale(c, Offset(x, y), 13, 12, 0, _k(l, row.isEven ? const Color(0xFF160C22) : const Color(0xFF1E1030)),
            l.hit ? 0 : 0.35 + 0.2 * (row / 4));
      }
    }
    // Schattierung unten
    c.drawRect(
        body,
        Paint()
          ..shader = ui.Gradient.linear(Offset(0, body.top), Offset(0, body.bottom),
              [Colors.transparent, const Color(0x99050208)], const [0.45, 1]));
    c.restore();
    // Adern: Netz, das mit der Phase heller wird
    RotArt.veins(
        c,
        Path()
          ..moveTo(-42, 6)
          ..lineTo(-26, -4)
          ..lineTo(-14, 8)
          ..lineTo(2, -2)
          ..lineTo(16, 10)
          ..lineTo(30, 2)
          ..moveTo(-14, 8)
          ..lineTo(-10, 24)
          ..moveTo(2, -2)
          ..lineTo(6, -18)
          ..moveTo(16, 10)
          ..lineTo(20, 26),
        min(1.0, pulse + 0.3 * rage),
        color: veinCol,
        width: 1.0 + 0.35 * rage);
    RotArt.rim(c, Path()..addOval(body), Rect.fromLTRB(body.left, body.top - 2, body.right, body.top + 22), alpha: 0.55);

    // Halskrause aus spitzen Federn
    for (var i = 0; i < 11; i++) {
      final a = -pi * 0.95 + i * 0.17;
      final base = const Offset(28, -14) + Offset(cos(a) * 12, sin(a) * 12);
      final tip = base + Offset(cos(a) * 14, sin(a) * 14 + 2);
      final n = Offset(-sin(a), cos(a)) * 3.2;
      c.drawPath(
          Path()
            ..moveTo(base.dx + n.dx, base.dy + n.dy)
            ..lineTo(tip.dx, tip.dy)
            ..lineTo(base.dx - n.dx, base.dy - n.dy)
            ..close(),
          _fill(_k(l, i.isEven ? const Color(0xFF1A0E26) : const Color(0xFF241434))));
    }

    // Kahler Hals und Kopf mit faltiger, kränklich glühender Haut
    final neck = Path()
      ..moveTo(26, -18)
      ..cubicTo(34, -24, 36, -32, 40, -36)
      ..lineTo(48, -32)
      ..cubicTo(44, -26, 40, -18, 34, -10)
      ..close();
    c.drawPath(neck, _fill(_k(l, const Color(0xFF3A2236))));
    final head = Rect.fromCenter(center: const Offset(46, -38), width: 24, height: 18);
    c.drawOval(head, _fill(_k(l, const Color(0xFF4A2A44))));
    _line
      ..strokeWidth = 0.8
      ..color = const Color(0xFF2A1428);
    for (var i = 0; i < 4; i++) {
      c.drawArc(Rect.fromCenter(center: Offset(38 + i * 3.0, -26 + i * 2.0), width: 10, height: 6), 0.2, pi - 0.4, false, _line);
    }
    // Hakenschnabel
    final beak = Path()
      ..moveTo(54, -43)
      ..cubicTo(64, -44, 72, -40, 72, -32)
      ..quadraticBezierTo(70, -30, 67, -33)
      ..quadraticBezierTo(62, -36, 54, -34)
      ..close();
    c.drawPath(beak, _fill(_k(l, const Color(0xFF2A1A2A))));
    _add
      ..strokeWidth = 1
      ..color = _magenta.withValues(alpha: 0.4);
    c.drawPath(
        Path()
          ..moveTo(55, -42.5)
          ..cubicTo(64, -43.5, 71, -39.5, 71.5, -33),
        _add);
    c.drawCircle(const Offset(57, -39), 1.1, _fill(const Color(0xFF0B0612)));
    // Auge: glühender Schlitz mit Brauenwulst
    final eyeOpen = 1.0 + 0.3 * rage;
    final eye = Path()
      ..moveTo(42, -40)
      ..quadraticBezierTo(47, -44 * eyeOpen.clamp(1, 1.04), 52, -41)
      ..quadraticBezierTo(47, -37.5, 42, -40)
      ..close();
    c.drawPath(eye, _fill(Color.lerp(_magenta, Colors.white, 0.4 + 0.2 * rage)!));
    c.drawPath(
        Path()
          ..moveTo(40, -44)
          ..lineTo(54, -46)
          ..lineTo(53, -43)
          ..lineTo(41, -42)
          ..close(),
        _fill(_k(l, const Color(0xFF241434))));

    // Krone aus Lichtsplittern; schwebt leicht, in Phase 3 lodernd
    final hover = sin(t * 2) * 1.5;
    for (var i = 0; i < 5; i++) {
      final cx = 38.0 + i * 5, hgt = [10.0, 16, 22, 16, 10][i] * (1 + 0.15 * rage);
      final base = -50.0 + hover;
      final p = Path()
        ..moveTo(cx - 3, base)
        ..lineTo(cx, base - hgt)
        ..lineTo(cx + 3, base)
        ..close();
      c.drawPath(
          p,
          Paint()
            ..shader = ui.Gradient.linear(Offset(cx, base), Offset(cx, base - hgt),
                [_magenta, Color.lerp(_magenta, Colors.white, 0.7)!]));
      if (rage == 2) Glow.draw(c, cx, base - hgt, 8 + 4 * sin(t * 14 + i), _magenta.withValues(alpha: 0.6));
    }
    _line
      ..strokeWidth = 2
      ..color = const Color(0xFF5A2A60);
    c.drawLine(Offset(36, -50 + hover), Offset(62, -50 + hover), _line);

    _vultureWing(c, l, const Offset(-2, -10), fl, far: false);
    _drips(c, [-30, -8, 14, 30], 34, t, color: veinCol);
  }

  /// Riesenflügel aus drei Lagen: Deckfedern, Armschwingen, zerfetzte Handschwingen.
  static void _vultureWing(Canvas c, BossLook l, Offset at, double fl, {required bool far}) {
    c.save();
    c.translate(at.dx, at.dy);
    c.rotate(-0.15 + (1 - fl) * 0.55 + (far ? 0.25 : 0));
    final dim = far ? 0.6 : 1.0;
    // Handschwingen (lange Fingerfedern, zerfetzt)
    for (var i = 0; i < 7; i++) {
      final a = pi + 0.25 - i * 0.11;
      final len = 70.0 + (i == 2 || i == 5 ? -14 : 0) + (i.isOdd ? 6 : 0);
      final base = Offset(-24 + i * 2.0, -6 + i * 1.5);
      final tip = base + Offset(cos(a) * len, sin(a) * len);
      final n = Offset(-sin(a), cos(a)) * 4;
      final p = Path()
        ..moveTo(base.dx + n.dx, base.dy + n.dy)
        ..lineTo(tip.dx + n.dx * 0.5, tip.dy + n.dy * 0.5)
        ..lineTo(tip.dx + cos(a) * 3, tip.dy + sin(a) * 3)
        ..lineTo(tip.dx - n.dx * 0.5, tip.dy - n.dy * 0.5)
        ..lineTo(base.dx - n.dx, base.dy - n.dy)
        ..close();
      c.drawPath(p, _fill(_k(l, Color.lerp(const Color(0xFF0E0616), const Color(0xFF1C0E28), i / 6)!.withValues(alpha: dim))));
      if (!far) {
        _add
          ..strokeWidth = 0.8
          ..color = _violet.withValues(alpha: 0.4);
        c.drawLine(base, tip, _add);
      }
    }
    // Armschwingen
    for (var i = 0; i < 6; i++) {
      _scale(c, Offset(-10 - i * 7.0, 2 + i * 1.2), 9, 20, 0.4, _k(l, const Color(0xFF180C24).withValues(alpha: dim)), far ? 0 : 0.3);
    }
    // Deckfedern
    for (var row = 0; row < 2; row++) {
      for (var i = 0; i < 5; i++) {
        _scale(c, Offset(-4 - i * 8.0 - row * 4, -8 + row * 6.0), 10, 9, 0.3,
            _k(l, const Color(0xFF221432).withValues(alpha: dim)), far ? 0 : 0.4);
      }
    }
    // Vorderkante
    if (!far) {
      _add
        ..strokeWidth = 1.4
        ..color = _violet.withValues(alpha: 0.55);
      c.drawPath(
          Path()
            ..moveTo(6, -6)
            ..quadraticBezierTo(-30, -16, -66, -24),
          _add);
    }
    c.restore();
  }

  // ============================================================== Strohkönig

  static void strawKing(Canvas c, BossLook l, double r) {
    final t = l.t, warn = l.warn;
    final face = Color.lerp(_ember, Colors.white, 0.25 + 0.45 * warn)!;

    // Pfahl und Querbalken aus morschem Holz mit Maserung
    void plank(Rect rc) {
      c.drawRect(rc, _fill(_k(l, const Color(0xFF241810))));
      _line
        ..strokeWidth = 0.7
        ..color = const Color(0xFF3A2A1A);
      for (var i = 1; i < 3; i++) {
        final y = rc.top + rc.height * i / 3;
        c.drawLine(Offset(rc.left + 1, y), Offset(rc.right - 1, y + (rc.width > rc.height ? 0 : 0.5)), _line);
      }
    }

    plank(Rect.fromLTWH(-4, -8, 8, r + 10));
    plank(Rect.fromLTWH(-r * 1.25, -16, r * 2.5, 7));

    // Zerfetzter Umhang mit Flicken und Nähten
    final cape = Path()
      ..moveTo(-r * 0.8, -14)
      ..quadraticBezierTo(-r * 0.62, 8, -r * 0.6, 26)
      ..lineTo(-r * 0.46, 18)
      ..lineTo(-r * 0.38, 32)
      ..lineTo(-r * 0.22, 20)
      ..lineTo(-r * 0.08, 36)
      ..lineTo(r * 0.06, 22)
      ..lineTo(r * 0.2, 31)
      ..lineTo(r * 0.34, 19)
      ..lineTo(r * 0.48, 28)
      ..lineTo(r * 0.6, 17)
      ..quadraticBezierTo(r * 0.64, 2, r * 0.8, -14)
      ..close();
    final sway = sin(t * 1.5) * 0.04;
    c.save();
    c.translate(0, -14);
    c.rotate(sway);
    c.translate(0, 14);
    c.drawPath(cape, l.hit ? _fill(_k(l, RotArt.ink)) : RotArt.cachedFill('straw_cape', 46, center: const Offset(0, -6)));
    // Flicken
    c.drawRect(Rect.fromCenter(center: Offset(-r * 0.3, 4), width: 10, height: 9), _fill(_k(l, const Color(0xFF2A1A30))));
    _line
      ..strokeWidth = 0.9
      ..color = const Color(0xFF6A5222);
    for (var i = 0; i < 4; i++) {
      final x = -r * 0.3 - 5 + i * 3.3;
      c.drawLine(Offset(x, 0), Offset(x, 2), _line);
    }
    // Glühende Risse im Stoff
    RotArt.veins(
        c,
        Path()
          ..moveTo(r * 0.15, -6)
          ..lineTo(r * 0.25, 4)
          ..lineTo(r * 0.18, 13)
          ..moveTo(r * 0.25, 4)
          ..lineTo(r * 0.4, 8),
        l.pulse,
        color: _ember);
    c.restore();

    // Stroh hängt unten aus dem Umhang
    _line
      ..strokeWidth = 1.2
      ..color = _k(l, const Color(0xFF8A6A2A));
    for (var i = 0; i < 9; i++) {
      final x = -r * 0.5 + i * r * 0.12;
      c.drawLine(Offset(x, 22), Offset(x + sin(t * 2 + i) * 2, 30 + (i.isEven ? 4 : 0)), _line);
    }
    // Stroh quillt aus Ärmeln und Kragen
    final strawCol = _k(l, const Color(0xFF8A6A2A));
    _line
      ..strokeWidth = 1.4
      ..color = strawCol;
    for (final side in [-1.0, 1.0]) {
      for (var i = 0; i < 5; i++) {
        final x = side * r * 1.25;
        final a = (side > 0 ? 0.0 : pi) + (i - 2) * 0.35 + sin(t * 3 + i) * 0.08;
        c.drawLine(Offset(x, -12), Offset(x + cos(a) * 9, -12 + sin(a) * 9 + 4), _line);
      }
    }
    for (var i = 0; i < 7; i++) {
      final x = -10.0 + i * 3.3;
      c.drawLine(Offset(x, -18), Offset(x + (i - 3) * 1.2, -24 - (i.isEven ? 2 : 0)), _line);
    }

    // Kürbiskopf mit Rippen, Stiel und flackerndem Gesicht
    final head = Rect.fromCenter(center: const Offset(0, -34), width: 42, height: 32);
    c.drawOval(head, _fill(_k(l, const Color(0xFF3A2410))));
    _line
      ..strokeWidth = 1.2
      ..color = _k(l, const Color(0xFF241608));
    for (final dx in [-12.0, -5.0, 5.0, 12.0]) {
      c.drawArc(Rect.fromCenter(center: Offset(dx * 0.4, -34), width: (21 - dx.abs()) * 2, height: 32), -pi / 2, pi, false, _line);
    }
    RotArt.rim(c, Path()..addOval(head), Rect.fromLTRB(head.left, head.top - 2, head.right, head.top + 10), alpha: 0.5);
    // Gesicht leuchtet von innen, flackert
    final flick = 0.85 + 0.15 * sin(t * 17) * sin(t * 7);
    Glow.draw(c, 0, -32, 30, face.withValues(alpha: 0.35 * flick));
    final faceCol = face.withValues(alpha: flick);
    // Augen: schräge Dreiecke
    c.drawPath(
        Path()
          ..moveTo(-15, -40)
          ..lineTo(-4, -37)
          ..lineTo(-9, -31)
          ..close(),
        _fill(faceCol));
    c.drawPath(
        Path()
          ..moveTo(15, -40)
          ..lineTo(4, -37)
          ..lineTo(9, -31)
          ..close(),
        _fill(faceCol));
    // Gezacktes Grinsen
    final mouth = Path()..moveTo(-14, -26);
    for (var i = 0; i <= 8; i++) {
      mouth.lineTo(-14 + i * 3.5, -26 + (i.isOdd ? 3.5 : 0) + sin(i * 0.4) * 1);
    }
    mouth
      ..lineTo(14, -22)
      ..quadraticBezierTo(0, -16, -14, -22)
      ..close();
    c.drawPath(mouth, _fill(faceCol));
    // Stiel und Strohkrone
    c.drawRect(const Rect.fromLTWH(-2, -54, 4, 6), _fill(_k(l, const Color(0xFF2A3A1A))));
    for (var i = 0; i < 7; i++) {
      final sx = -18.0 + i * 6;
      final h = 14.0 + (i == 3 ? 8 : (i.isEven ? 4 : 0));
      c.drawPath(
          Path()
            ..moveTo(sx - 2.5, -48)
            ..lineTo(sx + sin(t * 2 + i) * 1.2, -48 - h)
            ..lineTo(sx + 2.5, -48)
            ..close(),
          _fill(_k(l, i.isEven ? const Color(0xFFB08A3A) : const Color(0xFF8A6A2A))));
    }

    // Zwei Fäulniskrähen hocken auf den Armen
    for (final side in [-1.0, 1.0]) {
      c.save();
      c.translate(side * r * 0.95, -20);
      c.scale(0.5 * side, 0.5);
      RotArt.crow(c, t + side, sin(t * 3 + side) * 0.3, l.pulse, hit: l.hit);
      c.restore();
    }
    // Glutfunken steigen aus dem Kopf
    for (var i = 0; i < 4; i++) {
      final ph = (t * 0.6 + i / 4) % 1;
      Glow.draw(c, -6 + i * 4 + sin(t + i) * 3, -52 - ph * 26, 3, _ember.withValues(alpha: 0.8 * (1 - ph)));
    }
  }

  // ============================================================== Glocke

  static void bell(Canvas c, BossLook l, double r) {
    final t = l.t, warn = l.warn;
    final sw = sin(t * 3) * (0.12 + 0.12 * warn);
    c.save();
    c.rotate(sw);
    // Joch aus Holz mit Eisenbändern
    c.drawRect(Rect.fromCenter(center: Offset(0, -r - 4), width: r * 1.1, height: 8), _fill(_k(l, const Color(0xFF241810))));
    for (final x in [-r * 0.4, r * 0.4]) {
      c.drawRect(Rect.fromCenter(center: Offset(x, -r - 4), width: 3, height: 9), _fill(_k(l, const Color(0xFF3A3A44))));
    }
    // Glockenkörper mit Profil (Schulter, Flanke, Schlagring)
    final bellPath = Path()
      ..moveTo(-r * 0.32, -r)
      ..quadraticBezierTo(-r * 0.62, -r * 0.95, -r * 0.66, -r * 0.4)
      ..quadraticBezierTo(-r * 0.7, r * 0.3, -r * 1.05, r * 0.72)
      ..lineTo(r * 1.05, r * 0.72)
      ..quadraticBezierTo(r * 0.7, r * 0.3, r * 0.66, -r * 0.4)
      ..quadraticBezierTo(r * 0.62, -r * 0.95, r * 0.32, -r)
      ..close();
    c.drawPath(
        bellPath,
        l.hit
            ? _fill(_k(l, RotArt.ink))
            : (Paint()
              ..shader = ui.Gradient.linear(Offset(-r, 0), Offset(r, 0),
                  [const Color(0xFF0E0A12), const Color(0xFF2A2230), const Color(0xFF16101C), const Color(0xFF0A060E)],
                  const [0, 0.35, 0.65, 1])));
    // Zierbänder mit glühender Inschrift
    for (final (y, w) in [(-r * 0.62, r * 1.3), (r * 0.45, r * 1.9)]) {
      c.drawRect(Rect.fromCenter(center: Offset(0, y), width: w, height: 4), _fill(_k(l, const Color(0xFF2A2430))));
      for (var i = 0; i < 9; i++) {
        final x = -w / 2 + 4 + i * (w - 8) / 8;
        final on = (sin(t * 2 + i * 0.9) + 1) / 2;
        c.drawRect(Rect.fromCenter(center: Offset(x, y), width: 2, height: 2.4),
            _fill(Color.lerp(const Color(0xFF6A4A20), const Color(0xFFFFC94A), on * (0.5 + 0.5 * warn))!));
      }
    }
    // Schlagring
    c.drawRect(Rect.fromLTRB(-r * 1.08, r * 0.66, r * 1.08, r * 0.78), _fill(_k(l, const Color(0xFF3A3040))));
    // Risse mit Glut; im Warnzustand gleißend
    RotArt.veins(
        c,
        Path()
          ..moveTo(-r * 0.25, -r * 0.85)
          ..lineTo(-r * 0.12, -r * 0.4)
          ..lineTo(-r * 0.35, -r * 0.05)
          ..lineTo(-r * 0.22, r * 0.35)
          ..moveTo(-r * 0.12, -r * 0.4)
          ..lineTo(r * 0.1, -r * 0.2)
          ..moveTo(r * 0.3, -r * 0.7)
          ..lineTo(r * 0.42, -r * 0.1)
          ..lineTo(r * 0.3, r * 0.3),
        min(1.0, l.pulse * 0.4 + warn),
        color: const Color(0xFFFFC94A),
        width: 0.9 + 1.4 * warn);
    // Fäulnis-Ranken wachsen über die Glocke
    _line
      ..strokeWidth = 2
      ..color = _k(l, const Color(0xFF1A2A14));
    final vine = Path()
      ..moveTo(-r * 0.6, -r * 0.5)
      ..cubicTo(-r * 0.2, -r * 0.3, -r * 0.6, 0, -r * 0.3, r * 0.3)
      ..cubicTo(-r * 0.1, r * 0.5, -r * 0.5, r * 0.6, -r * 0.7, r * 0.7);
    c.drawPath(vine, _line);
    for (var i = 0; i < 4; i++) {
      final m = vine.computeMetrics().first.getTangentForOffset(vine.computeMetrics().first.length * (0.2 + i * 0.2))!;
      c.drawOval(Rect.fromCenter(center: m.position + const Offset(3, 0), width: 5, height: 3), _fill(_k(l, const Color(0xFF2A3A20))));
    }
    RotArt.rim(c, bellPath, Rect.fromLTRB(-r * 1.1, -r - 2, r * 1.1, -r * 0.3), alpha: 0.5);
    // Rostige Kette nach oben
    for (var i = 0; i < 4; i++) {
      c.drawOval(Rect.fromCenter(center: Offset(0, -r - 12 - i * 7.0), width: i.isEven ? 6 : 3, height: 8),
          (Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 2
            ..color = _k(l, const Color(0xFF4A3A3A))));
    }
    c.restore();

    // In der Glockenöffnung: ein glühendes Auge statt Klöppel, schwingt nach
    final clap = sin(t * 3 + 1) * r * 0.25;
    final eye = Offset(clap, r * 0.62);
    Glow.draw(c, eye.dx, eye.dy, 14 + 10 * warn, const Color(0xFFFFC94A).withValues(alpha: 0.5 + 0.4 * warn));
    c.drawCircle(eye, 6, _fill(const Color(0xFF1A1016)));
    c.drawOval(Rect.fromCenter(center: eye, width: 9, height: 3.2 + 2 * warn), _fill(const Color(0xFFFFE6A0)));
    c.drawOval(Rect.fromCenter(center: eye, width: 2, height: 3.2 + 2 * warn), _fill(const Color(0xFF1A1016)));
  }

  // ============================================================== Spinnenmutter

  static void spiderMother(Canvas c, BossLook l, double r) {
    final t = l.t, pulse = l.pulse;
    // Acht gegliederte Beine (Oberschenkel, Knie, Unterschenkel, Klaue), je Seite vier
    for (var side = 0; side < 2; side++) {
      for (var i = 0; i < 4; i++) {
        final s = side == 0 ? -1.0 : 1.0;
        final phase = t * 5 + i * 1.3 + side * pi;
        final hip = Offset(s * 8, -10.0 + i * 6);
        final knee = hip + Offset(s * (18 + i * 2), -16 + i * 4 + sin(phase) * 3);
        final foot = knee + Offset(s * (12 - i * 1.5), 22 + i * 3 + cos(phase) * 3);
        final col = _k(l, side == 0 ? const Color(0xFF120818) : const Color(0xFF1E1030));
        _line
          ..strokeWidth = 4
          ..color = col;
        c.drawLine(hip, knee, _line);
        _line.strokeWidth = 2.8;
        c.drawLine(knee, foot, _line);
        c.drawCircle(knee, 2.6, _fill(col));
        // Haare und glühende Gelenkspitze
        _line
          ..strokeWidth = 0.7
          ..color = const Color(0xFF3A2440);
        for (var k = 1; k < 3; k++) {
          final p = Offset.lerp(knee, foot, k / 3)!;
          c.drawLine(p, p + Offset(s * 2.5, -2), _line);
        }
        if (side == 1) Glow.draw(c, knee.dx, knee.dy, 4, _violet.withValues(alpha: 0.5));
        c.drawPath(
            Path()
              ..moveTo(foot.dx - 1.5, foot.dy)
              ..lineTo(foot.dx + s * 3, foot.dy + 4)
              ..lineTo(foot.dx + 1.5, foot.dy)
              ..close(),
            _fill(_k(l, const Color(0xFF3A2A3A))));
      }
    }

    // Hinterleib: groß, mit Musterung und pulsierendem Eiersack
    final abd = Rect.fromCenter(center: const Offset(-10, 12), width: r * 1.6, height: r * 1.5);
    c.drawOval(abd, l.hit ? _fill(_k(l, RotArt.ink)) : RotArt.cachedFill('spider_abd', r, center: const Offset(-4, 4)));
    c.save();
    c.clipPath(Path()..addOval(abd));
    // Sanduhr-Zeichnung und Streifen
    final hour = Path()
      ..moveTo(-17, 0)
      ..lineTo(-5, 0)
      ..lineTo(-11, 9)
      ..lineTo(-5, 18)
      ..lineTo(-17, 18)
      ..lineTo(-11, 9)
      ..close();
    c.drawPath(hour, _fill(const Color(0xFFFF3B6A).withValues(alpha: 0.55 + 0.35 * pulse)));
    _line
      ..strokeWidth = 1.2
      ..color = const Color(0xFF2A1438);
    for (var i = 0; i < 4; i++) {
      c.drawArc(Rect.fromCenter(center: Offset(-10, 12), width: r * 1.6 - i * 10, height: r * 1.5 - i * 10), pi * 0.6, pi * 0.8, false, _line);
    }
    c.restore();
    RotArt.rim(c, Path()..addOval(abd), Rect.fromLTRB(abd.left, abd.top - 2, abd.right, abd.top + 12), alpha: 0.5);
    // Eiersack hinten, mit durchscheinenden Eiern
    final sac = Offset(-r * 0.85, 22);
    c.drawOval(Rect.fromCenter(center: sac, width: 22, height: 18), _fill(const Color(0xCC2A3A2A)));
    for (var i = 0; i < 5; i++) {
      final e = sac + Offset(-6 + (i % 3) * 6.0, -3 + (i ~/ 3) * 6.0);
      c.drawCircle(e, 2.6, _fill(const Color(0xFF9CFF5A).withValues(alpha: 0.35 + 0.35 * sin(t * 3 + i).abs())));
    }
    // Spinnwarzen mit Faden
    _line
      ..strokeWidth = 0.8
      ..color = const Color(0x88E6E6F2);
    c.drawLine(Offset(abd.left + 4, abd.center.dy + 6), Offset(abd.left - 10, abd.center.dy + 18), _line);

    // Kopfbruststück mit vielen Augen und Kieferklauen
    final ceph = Rect.fromCenter(center: const Offset(16, -6), width: r * 0.9, height: r * 0.75);
    c.drawOval(ceph, _fill(_k(l, const Color(0xFF1A0E26))));
    RotArt.rim(c, Path()..addOval(ceph), Rect.fromLTRB(ceph.left, ceph.top - 2, ceph.right, ceph.top + 8), alpha: 0.5);
    for (final (dx, dy, rr) in [(-6.0, -6.0, 2.6), (2.0, -8.0, 3.2), (10.0, -6.0, 2.6), (-2.0, -2.0, 1.8), (6.0, -2.5, 1.8), (13.0, -1.5, 1.5), (-9.0, -1.0, 1.5), (4.0, 1.5, 1.3)]) {
      final at = ceph.center + Offset(dx, dy);
      Glow.draw(c, at.dx, at.dy, rr * 3, const Color(0xFFFF4D6D).withValues(alpha: 0.4));
      c.drawCircle(at, rr, _fill(const Color(0xFFFF7A90)));
      c.drawCircle(at + Offset(-rr * 0.3, -rr * 0.3), rr * 0.3, _fill(Colors.white.withValues(alpha: 0.8)));
    }
    // Kieferklauen, die sich öffnen
    final open = 0.2 + 0.25 * sin(t * 4).abs() + 0.4 * l.warn;
    for (final s in [-1.0, 1.0]) {
      c.save();
      c.translate(ceph.right - 4, ceph.center.dy + 6 + s * 3);
      c.rotate(s * open);
      c.drawPath(
          Path()
            ..moveTo(0, -2)
            ..quadraticBezierTo(8, -1, 10, 6 * s)
            ..lineTo(6, 2 * s)
            ..lineTo(0, 2)
            ..close(),
          _fill(_k(l, const Color(0xFF2A1A30))));
      c.drawCircle(Offset(10, 6 * s), 1, _fill(const Color(0xFF9CFF5A)));
      c.restore();
    }
    // Gifttropfen von den Klauen
    final ph = (t * 0.7) % 1;
    c.drawCircle(Offset(ceph.right + 6, ceph.center.dy + 12 + ph * 24), 1.6, _fill(const Color(0xFF9CFF5A).withValues(alpha: 1 - ph)));
  }
}
