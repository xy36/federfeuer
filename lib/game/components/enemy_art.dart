import 'dart:math';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../config.dart';
import 'boss_art.dart';
import 'light.dart';
import 'rot_art.dart';

/// Zustand eines Gegners für die Zeichnung.
class EnemyLook {
  const EnemyLook({required this.t, required this.pulse, this.warn = 0, this.hit = false, this.state = 0, this.aim = 0});
  final double t, pulse, warn, aim;
  final bool hit;
  final int state;
}

/// Ausgearbeitete Formen der Gegner im Fäulnis-Stil (außer Krähe, Bossen und den reinen
/// Lichterscheinungen Irrlicht, Riss und Ei). Lokale Koordinaten, Blick nach +x.
/// Augenpositionen passen zu den Leuchtpunkten in `collectGlows`.
class EnemyArt {
  EnemyArt._();

  static const _ember = Color(0xFFFF8A3D), _toxic = Color(0xFF9CFF5A), _eye = Color(0xFFFF4D6D);
  static const _frost = Color(0xFFBFE3FF), _gold = Color(0xFFFFC94A);

  static final _line = Paint()
    ..style = PaintingStyle.stroke
    ..strokeCap = StrokeCap.round
    ..strokeJoin = StrokeJoin.round;

  static Color _k(EnemyLook l, Color c) => l.hit ? Color.lerp(c, Colors.white, 0.8)! : c;
  static Paint _p(Color c) => Paint()..color = c;
  static Paint _body(EnemyLook l, String key, double r, {Offset center = Offset.zero, Color core = const Color(0xFF2A1440)}) =>
      l.hit ? _p(_k(l, RotArt.ink)) : RotArt.cachedFill(key, r, center: center, core: core);

  static void _slit(Canvas c, Offset at, double r, Color col) {
    final p = Path()
      ..moveTo(at.dx - r * 1.2, at.dy + r * 0.2)
      ..quadraticBezierTo(at.dx, at.dy - r * 0.9, at.dx + r * 1.1, at.dy - r * 0.3)
      ..quadraticBezierTo(at.dx, at.dy + r * 0.5, at.dx - r * 1.2, at.dy + r * 0.2)
      ..close();
    c.drawPath(p, _p(Color.lerp(col, Colors.white, 0.35)!));
  }

  static void _leg(Canvas c, EnemyLook l, List<Offset> pts, double w, {Color col = const Color(0xFF1C0E28)}) {
    _line
      ..strokeWidth = w
      ..color = _k(l, col);
    for (var i = 0; i < pts.length - 1; i++) {
      c.drawLine(pts[i], pts[i + 1], _line);
    }
    for (final p in pts.skip(1).take(pts.length - 2)) {
      c.drawCircle(p, w * 0.6, _p(_k(l, col)));
    }
  }

  // ---------------- Glutkäfer ----------------

  /// Gewölbter Panzer aus zwei Flügeldecken mit Glutnaht, Halsschild, Fühler, sechs Beine.
  static void beetle(Canvas c, EnemyLook l, double r) {
    final t = l.t;
    // Beine: drei Paare, gegenläufig
    for (var i = 0; i < 3; i++) {
      final x = -8.0 + i * 8;
      for (final s in [0, 1]) {
        final ph = t * 14 + i * 2.1 + s * pi;
        final knee = Offset(x - 3 + sin(ph) * 2, 9);
        final foot = Offset(x + sin(ph) * 4 - 2, 15 - max(0.0, cos(ph)) * 2);
        _leg(c, l, [Offset(x, 5), knee, foot], 1.8, col: s == 0 ? const Color(0xFF120818) : const Color(0xFF1E1030));
      }
    }
    // Panzer
    final shell = Path()
      ..moveTo(-16, 6)
      ..cubicTo(-17, -8, -6, -13, 4, -11)
      ..cubicTo(10, -10, 13, -4, 12, 6)
      ..close();
    c.drawPath(shell, _body(l, 'beetle', 18, center: const Offset(-2, -6)));
    // Flügeldeckennaht mit Glut
    RotArt.veins(
        c,
        Path()
          ..moveTo(-15, 2)
          ..quadraticBezierTo(-4, -4, 8, -9),
        l.pulse,
        color: _ember);
    // Glühende Risse
    RotArt.veins(
        c,
        Path()
          ..moveTo(-10, 4)
          ..lineTo(-7, -2)
          ..lineTo(-3, 1)
          ..moveTo(2, -2)
          ..lineTo(5, 3),
        l.pulse * 0.7,
        color: _ember,
        width: 0.9);
    RotArt.rim(c, shell, const Rect.fromLTRB(-18, -14, 14, -4));
    // Halsschild und Kopf mit Fühlern
    c.drawPath(
        Path()
          ..moveTo(10, -6)
          ..quadraticBezierTo(17, -7, 18, 1)
          ..quadraticBezierTo(15, 5, 10, 5)
          ..close(),
        _p(_k(l, const Color(0xFF1C0E28))));
    _line
      ..strokeWidth = 1
      ..color = _k(l, const Color(0xFF2A1A36));
    final wave = sin(t * 6) * 1.5;
    c.drawPath(
        Path()
          ..moveTo(17, -3)
          ..quadraticBezierTo(22, -9 + wave, 26, -7 + wave),
        _line);
    c.drawPath(
        Path()
          ..moveTo(18, -1)
          ..quadraticBezierTo(24, -4 - wave, 27, -2 - wave),
        _line);
    _slit(c, const Offset(17, -1.5), 2, _ember);
  }

  // ---------------- Spucker ----------------

  /// Schwebender Schleimbeutel mit durchscheinendem Giftsack, Tentakeln und Spuckmaul.
  static void spitter(Canvas c, EnemyLook l, double r) {
    final t = l.t, wb = sin(t * 5);
    // Tentakel
    for (var i = 0; i < 4; i++) {
      final x = -9.0 + i * 6;
      final p = Path()..moveTo(x, 8);
      for (var k = 1; k <= 5; k++) {
        p.lineTo(x + sin(t * 6 + i + k * 0.8) * 2.5, 8 + k * 3.0);
      }
      _line
        ..strokeWidth = 2.6 - i * 0.2
        ..color = _k(l, const Color(0xFF180C24));
      c.drawPath(p, _line);
    }
    // Körper, pulsiert
    final body = Rect.fromCenter(center: Offset.zero, width: 30 + wb * 2, height: 25 - wb * 2);
    c.drawOval(body, _body(l, 'spitter', 17, center: const Offset(-3, 2), core: const Color(0xFF1E2A14)));
    // Giftsack (durchscheinend, Blasen steigen)
    final sac = Rect.fromCenter(center: const Offset(-3, 3), width: 14 + wb, height: 11 + wb);
    c.drawOval(
        sac,
        Paint()
          ..shader = ui.Gradient.radial(sac.center, 7,
              [_toxic.withValues(alpha: 0.75 + 0.2 * l.pulse), const Color(0xFF3A6A1A).withValues(alpha: 0.4)]));
    for (var i = 0; i < 3; i++) {
      final ph = (t * 0.8 + i / 3) % 1;
      c.drawCircle(Offset(-5 + i * 2.5, 7 - ph * 8), 0.9, _p(Colors.white.withValues(alpha: 0.7 * (1 - ph))));
    }
    RotArt.rim(c, Path()..addOval(body), Rect.fromLTRB(body.left, body.top - 2, body.right, body.top + 7));
    // Warzen
    for (final (x, y) in [(-10.0, -6.0), (2.0, -9.0), (9.0, -4.0)]) {
      c.drawCircle(Offset(x, y), 1.6, _p(_k(l, const Color(0xFF24183A))));
    }
    // Spuckmaul mit Gifttropfen
    c.drawOval(Rect.fromCenter(center: const Offset(11, 3), width: 6, height: 4.5 + 2 * l.warn), _p(const Color(0xFF05020A)));
    final ph = (t * 1.2) % 1;
    c.drawCircle(Offset(12, 6 + ph * 6), 1.2, _p(_toxic.withValues(alpha: 1 - ph)));
    _slit(c, const Offset(4, -5), 2.6, _toxic);
  }

  // ---------------- Brocken ----------------

  /// Kantiger Felsklotz aus Bruchflächen mit Glutadern, Moos und Kiefer.
  static void rock(Canvas c, EnemyLook l, double r) {
    const pts = [
      Offset(1, -0.2), Offset(0.7, -0.75), Offset(0.15, -1), Offset(-0.5, -0.85), Offset(-0.95, -0.35),
      Offset(-0.9, 0.4), Offset(-0.45, 0.9), Offset(0.3, 0.95), Offset(0.85, 0.55),
    ];
    final path = Path()..moveTo(pts[0].dx * r, pts[0].dy * r);
    for (final p in pts.skip(1)) {
      path.lineTo(p.dx * r, p.dy * r);
    }
    path.close();
    c.drawPath(path, _body(l, 'rock', r * 1.2, center: Offset(r * 0.2, -r * 0.3), core: const Color(0xFF2A1A1A)));
    // Bruchflächen: hellere und dunklere Facetten
    c.save();
    c.clipPath(path);
    c.drawPath(
        Path()
          ..moveTo(0, -r)
          ..lineTo(r * 0.7, -r * 0.75)
          ..lineTo(r * 0.25, -r * 0.15)
          ..lineTo(-r * 0.2, -r * 0.4)
          ..close(),
        _p(_k(l, const Color(0xFF221828))));
    c.drawPath(
        Path()
          ..moveTo(-r * 0.9, r * 0.4)
          ..lineTo(-r * 0.2, r * 0.2)
          ..lineTo(r * 0.3, r * 0.95)
          ..lineTo(-r * 0.45, r * 0.95)
          ..close(),
        _p(_k(l, const Color(0xFF07040A))));
    c.restore();
    RotArt.veins(
        c,
        Path()
          ..moveTo(-r * 0.75, r * 0.15)
          ..lineTo(-r * 0.3, -r * 0.05)
          ..lineTo(-r * 0.05, r * 0.35)
          ..lineTo(r * 0.3, r * 0.1)
          ..lineTo(r * 0.6, r * 0.3)
          ..moveTo(-r * 0.3, -r * 0.05)
          ..lineTo(-r * 0.15, -r * 0.6),
        l.pulse,
        color: _ember,
        width: 1.4);
    RotArt.rim(c, path, Rect.fromLTRB(-r, -r - 2, r, -r * 0.35));
    // Fäulnismoos oben
    for (var i = 0; i < 5; i++) {
      c.drawCircle(Offset(-r * 0.4 + i * r * 0.2, -r * 0.88 + (i.isOdd ? 1.5 : 0)), 2.2, _p(_k(l, const Color(0xFF2A1A36))));
    }
    // Kiefer mit Zähnen unter den Augen
    c.drawPath(
        Path()
          ..moveTo(4, 2)
          ..lineTo(20, 0)
          ..lineTo(18, 6)
          ..lineTo(5, 7)
          ..close(),
        _p(const Color(0xFF05020A)));
    for (var i = 0; i < 4; i++) {
      final x = 7.0 + i * 3.4;
      c.drawPath(
          Path()
            ..moveTo(x, 1.6)
            ..lineTo(x + 1.4, 4)
            ..lineTo(x + 2.8, 1.4)
            ..close(),
          _p(_k(l, const Color(0xFFD8C8B8))));
    }
    _slit(c, const Offset(7, -6), 3, _ember);
    _slit(c, const Offset(15, -6), 2.6, _ember);
  }

  // ---------------- Pusteling ----------------

  /// Aufgeblähte Pollenkugel mit Stacheln, Adern und giftigem Kern.
  static void puffball(Canvas c, EnemyLook l, double r) {
    final t = l.t, swell = 1 + 0.06 * sin(t * 3) + 0.15 * l.warn;
    for (var i = 0; i < 14; i++) {
      final a = i / 14 * pi * 2 + t * 0.3;
      final len = r * (1.25 + (i.isEven ? 0.25 : 0)) * swell;
      final base = r * 0.85 * swell;
      final n = Offset(-sin(a), cos(a)) * 2;
      c.drawPath(
          Path()
            ..moveTo(cos(a) * base + n.dx, sin(a) * base + n.dy)
            ..lineTo(cos(a) * len, sin(a) * len)
            ..lineTo(cos(a) * base - n.dx, sin(a) * base - n.dy)
            ..close(),
          _p(_k(l, const Color(0xFF1C0E28))));
      c.drawCircle(Offset(cos(a) * len, sin(a) * len), 1, _p(_toxic.withValues(alpha: 0.6)));
    }
    final ball = Rect.fromCircle(center: Offset.zero, radius: r * swell);
    c.drawOval(ball, _body(l, 'puff', r, center: const Offset(-3, 3), core: const Color(0xFF1E3A14)));
    RotArt.veins(
        c,
        Path()
          ..moveTo(-r * 0.7, 0)
          ..quadraticBezierTo(-r * 0.2, -r * 0.4, r * 0.3, -r * 0.6)
          ..moveTo(-r * 0.2, r * 0.6)
          ..quadraticBezierTo(r * 0.1, r * 0.1, r * 0.6, r * 0.2),
        l.pulse,
        color: _toxic,
        width: 0.9);
    RotArt.rim(c, Path()..addOval(ball), Rect.fromLTRB(ball.left, ball.top - 2, ball.right, ball.top + r * 0.6));
    _slit(c, const Offset(4, -3), 2.2, _toxic);
  }

  // ---------------- Vogelscheuche ----------------

  /// Kleine, morsche Vogelscheuche: Pfahl, zerlumpter Mantel, Sackkopf mit Naht und Hut.
  static void scarecrow(Canvas c, EnemyLook l, double r) {
    final t = l.t, sway = sin(t * 1.4) * 0.05;
    c.drawRect(Rect.fromLTWH(-2, -4, 4, r + 6), _p(_k(l, const Color(0xFF241810))));
    c.save();
    c.rotate(sway);
    c.drawRect(Rect.fromLTWH(-r, -7, r * 2, 3.5), _p(_k(l, const Color(0xFF241810))));
    // Mantel mit Fransen
    final coat = Path()
      ..moveTo(-r * 0.75, -6)
      ..lineTo(-r * 0.6, 10)
      ..lineTo(-r * 0.4, 6)
      ..lineTo(-r * 0.25, 12)
      ..lineTo(0, 7)
      ..lineTo(r * 0.25, 12)
      ..lineTo(r * 0.45, 6)
      ..lineTo(r * 0.6, 10)
      ..lineTo(r * 0.75, -6)
      ..close();
    c.drawPath(coat, _body(l, 'scare_coat', r, center: const Offset(0, -2)));
    RotArt.veins(
        c,
        Path()
          ..moveTo(-2, -4)
          ..lineTo(1, 2)
          ..lineTo(-1, 7),
        l.pulse * 0.6,
        color: _ember,
        width: 0.8);
    // Stroh an den Armen
    _line
      ..strokeWidth = 1.1
      ..color = _k(l, const Color(0xFF8A6A2A));
    for (final s in [-1.0, 1.0]) {
      for (var i = 0; i < 3; i++) {
        final x = s * r, a = (s > 0 ? 0 : pi) + (i - 1) * 0.45;
        c.drawLine(Offset(x, -5), Offset(x + cos(a) * 6, -5 + sin(a) * 6 + 2), _line);
      }
    }
    // Sackkopf mit Naht
    c.drawOval(Rect.fromCenter(center: const Offset(0, -14), width: 16, height: 15), _p(_k(l, const Color(0xFF3A2A1A))));
    _line
      ..strokeWidth = 0.8
      ..color = const Color(0xFF1A1008);
    for (var i = 0; i < 4; i++) {
      c.drawLine(Offset(-5 + i * 3.3, -9), Offset(-4.4 + i * 3.3, -7.5), _line);
    }
    c.drawLine(const Offset(-6, -8.5), const Offset(6, -8.5), _line);
    // Hut mit Krempe
    c.drawPath(
        Path()
          ..moveTo(-8, -20)
          ..lineTo(-2, -32)
          ..lineTo(5, -30)
          ..lineTo(8, -20)
          ..close(),
        _p(_k(l, RotArt.ink)));
    c.drawOval(Rect.fromCenter(center: const Offset(0, -20), width: 28, height: 4), _p(_k(l, const Color(0xFF140A1E))));
    RotArt.rim(c, Path()..addOval(Rect.fromCenter(center: const Offset(0, -20), width: 28, height: 4)),
        const Rect.fromLTRB(-15, -23, 15, -20));
    c.restore();
    _slit(c, const Offset(-3, -14), 2, _ember);
    _slit(c, const Offset(3, -14), 2, _ember);
  }

  // ---------------- Fledermaus ----------------

  /// Fledermaus mit Hautflügeln über Fingerknochen, großen Ohren und Fangzähnen.
  static void bat(Canvas c, EnemyLook l, double r) {
    final fl = sin(l.t * 22);
    for (final s in [-1.0, 1.0]) {
      final tip = Offset(s * 20, -8 - fl * 9);
      final mid = Offset(s * 13, -2 - fl * 5);
      final membrane = Path()
        ..moveTo(s * 3, -2)
        ..lineTo(tip.dx, tip.dy)
        ..quadraticBezierTo(s * 17, 1 - fl * 3, mid.dx + s * 2, 4 - fl * 2)
        ..quadraticBezierTo(s * 10, 2, s * 7, 6)
        ..quadraticBezierTo(s * 5, 3, s * 3, 4)
        ..close();
      c.drawPath(membrane, _p(_k(l, s < 0 ? const Color(0xFF120818) : const Color(0xFF1C0E28))));
      _line
        ..strokeWidth = 0.9
        ..color = const Color(0xFFB44CFF).withValues(alpha: 0.45);
      c.drawLine(Offset(s * 3, -2), tip, _line);
      c.drawLine(Offset(s * 6, -1), Offset(mid.dx + s * 2, 4 - fl * 2), _line);
    }
    c.drawOval(Rect.fromCenter(center: Offset.zero, width: 13, height: 12), _body(l, 'bat', 8));
    // Ohren
    for (final s in [-1.0, 1.0]) {
      c.drawPath(
          Path()
            ..moveTo(s * 2, -4)
            ..lineTo(s * 4.5, -12)
            ..lineTo(s * 6, -3)
            ..close(),
          _p(_k(l, const Color(0xFF1C0E28))));
    }
    // Fangzähne
    for (final s in [-1.0, 1.0]) {
      c.drawPath(
          Path()
            ..moveTo(s * 1.5, 2.5)
            ..lineTo(s * 2, 5)
            ..lineTo(s * 2.6, 2.5)
            ..close(),
          _p(_k(l, const Color(0xFFE8D8C8))));
    }
    _slit(c, const Offset(-2.5, -1), 1.6, _eye);
    _slit(c, const Offset(2.5, -1), 1.6, _eye);
  }

  // ---------------- Wetterhahn ----------------

  /// Rostiger Wetterhahn auf Stange mit Windrose; der Hahn dreht sich mit [EnemyLook.aim].
  static void weathercock(Canvas c, EnemyLook l, double r) {
    // Stange und Windrose
    c.drawRect(Rect.fromLTWH(-1.5, 0, 3, r + 4), _p(_k(l, const Color(0xFF2A2430))));
    _line
      ..strokeWidth = 1.2
      ..color = _k(l, const Color(0xFF3A3040));
    c.drawLine(Offset(-9, r * 0.5), Offset(9, r * 0.5), _line);
    for (final (s, ch) in [(-1.0, 'W'), (1.0, 'O')]) {
      c.drawCircle(Offset(s * 9, r * 0.5), 1.4, _p(_k(l, const Color(0xFF6A5A4A))));
      ch.length;
    }
    c.save();
    final sc = cos(l.aim);
    c.scale(sc.abs() < 0.25 ? 0.25 * sc.sign : sc, 1);
    // Hahn als flache Blechsilhouette mit Rostflecken
    final cock = Path()
      ..moveTo(-10, -2)
      ..cubicTo(-12, -14, -20, -22, -16, -24) // Schwanzbogen
      ..cubicTo(-10, -20, -6, -12, -2, -8)
      ..cubicTo(2, -10, 4, -14, 7, -18) // Hals
      ..lineTo(12, -18)
      ..lineTo(16, -15) // Schnabel
      ..lineTo(11, -13)
      ..cubicTo(10, -8, 8, -2, 4, 0)
      ..close();
    c.drawPath(cock, _body(l, 'cock', 16, center: const Offset(0, -12), core: const Color(0xFF2A2020)));
    for (final (x, y) in [(-8.0, -8.0), (2.0, -6.0), (-13.0, -18.0)]) {
      c.drawCircle(Offset(x, y), 1.6, _p(_k(l, const Color(0xFF5A2A1A))));
    }
    // Kamm
    for (var i = 0; i < 3; i++) {
      c.drawCircle(Offset(8.0 + i * 2.2, -19.5 - (i == 1 ? 1 : 0)), 1.6, _p(_k(l, const Color(0xFF8A2A2A))));
    }
    RotArt.rim(c, cock, const Rect.fromLTRB(-22, -26, 18, -12), color: _gold, alpha: 0.5);
    _slit(c, const Offset(10, -15.5), 1.4, _gold);
    c.restore();
  }

  // ---------------- Spinne ----------------

  /// Spinne mit gegliederten Beinen, gemustertem Hinterleib, vier Augen und Kieferklauen.
  static void spider(Canvas c, EnemyLook l, double r) {
    final t = l.t;
    for (var side = 0; side < 2; side++) {
      for (var i = 0; i < 4; i++) {
        final s = side == 0 ? -1.0 : 1.0;
        final ph = t * 6 + i + side * pi;
        final hip = Offset(s * 4, -6.0 + i * 4);
        final knee = hip + Offset(s * 9, -7 + i * 2 + sin(ph) * 1.5);
        final foot = knee + Offset(s * 6, 9 + i * 1.5);
        _leg(c, l, [hip, knee, foot], 1.6, col: side == 0 ? const Color(0xFF120818) : const Color(0xFF1E1030));
      }
    }
    final abd = Rect.fromCenter(center: const Offset(0, 4), width: 22, height: 24);
    c.drawOval(abd, _body(l, 'spider', 13, center: const Offset(0, 0)));
    c.save();
    c.clipPath(Path()..addOval(abd));
    for (var i = 0; i < 3; i++) {
      c.drawOval(Rect.fromCenter(center: Offset(0, -2.0 + i * 6), width: 9 - i * 2.0, height: 3), _p(_eye.withValues(alpha: 0.35 + 0.2 * l.pulse)));
    }
    c.restore();
    RotArt.rim(c, Path()..addOval(abd), Rect.fromLTRB(abd.left, abd.top - 2, abd.right, abd.top + 6));
    c.drawOval(Rect.fromCenter(center: const Offset(0, -9), width: 14, height: 11), _p(_k(l, const Color(0xFF1C0E28))));
    for (final (ex, ey) in [(-3.0, -10.0), (3.0, -10.0), (-1.5, -7.5), (1.5, -7.5)]) {
      c.drawCircle(Offset(ex, ey), 1.3, _p(const Color(0xFFFF7A90)));
    }
    for (final s in [-1.0, 1.0]) {
      c.drawPath(
          Path()
            ..moveTo(s * 2, -4)
            ..quadraticBezierTo(s * 3.5, -1, s * 1.5, 1)
            ..lineTo(s * 1, -3)
            ..close(),
          _p(_k(l, const Color(0xFF2A1A30))));
    }
  }

  // ---------------- Felsadler ----------------

  /// Fäulnis-Adler: kantiger Raubvogel mit zerfetzten Fingerfedern, Hakenschnabel, Fängen.
  static void eagle(Canvas c, EnemyLook l, double r) {
    final t = l.t;
    final diving = l.state == 2;
    final fl = diving ? -0.2 : sin(t * 8);
    if (!diving) RotArt.rotWing(c, const Offset(-4, -6), fl, 34, _k(l, const Color(0xFF120818)), far: true);
    // Körper
    final body = Path()
      ..moveTo(20, -8)
      ..cubicTo(16, -14, 4, -12, -4, -8)
      ..lineTo(-22, -6)
      ..lineTo(-30, -9)
      ..lineTo(-26, -3)
      ..lineTo(-32, 1)
      ..lineTo(-24, 2)
      ..lineTo(-28, 6)
      ..lineTo(-18, 4)
      ..cubicTo(-8, 10, 8, 10, 14, 2)
      ..close();
    c.drawPath(body, _body(l, 'eagle', 24, center: const Offset(6, -4)));
    RotArt.rim(c, body, const Rect.fromLTRB(-34, -16, 22, -5));
    RotArt.veins(
        c,
        Path()
          ..moveTo(-16, 0)
          ..lineTo(-6, -4)
          ..lineTo(2, 0)
          ..lineTo(8, -3),
        l.pulse * 0.7,
        width: 1);
    // Kopf, Schnabel, Braue
    c.drawOval(Rect.fromCenter(center: const Offset(15, -7), width: 14, height: 11), _p(_k(l, const Color(0xFF1C0E28))));
    c.drawPath(
        Path()
          ..moveTo(20, -10)
          ..cubicTo(26, -10, 30, -7, 29, -3)
          ..quadraticBezierTo(27, -2, 25, -4)
          ..lineTo(20, -5)
          ..close(),
        _p(_k(l, const Color(0xFF3A2A20))));
    c.drawPath(
        Path()
          ..moveTo(11, -11)
          ..lineTo(21, -12)
          ..lineTo(20, -9.5)
          ..lineTo(12, -9)
          ..close(),
        _p(_k(l, const Color(0xFF241434))));
    // Fänge, im Sturzflug ausgestreckt
    final reach = diving ? 8.0 : 2.0;
    for (final x in [-2.0, 6.0]) {
      _leg(c, l, [Offset(x, 6), Offset(x + 2, 10 + reach)], 2, col: const Color(0xFF2A1A20));
      for (var k = -1; k <= 1; k++) {
        _line
          ..strokeWidth = 1.2
          ..color = _k(l, const Color(0xFFD8C8B8));
        c.drawLine(Offset(x + 2, 10 + reach), Offset(x + 2 + k * 2.5, 13 + reach), _line);
      }
    }
    if (!diving) RotArt.rotWing(c, const Offset(-2, -4), fl, 32, _k(l, const Color(0xFF1C0E28)), far: false);
    _slit(c, const Offset(17, -8), 2.2, l.state == 1 ? Colors.white : _eye);
  }

  // ---------------- Lawinenkäfer (laufend) ----------------

  /// Gepanzerter Käfer mit Frost-Rillen im Panzer; eingerollt zeichnet ihn die Weltlogik.
  static void avalancheWalk(Canvas c, EnemyLook l, double r) {
    final t = l.t;
    for (var i = 0; i < 3; i++) {
      final x = -10.0 + i * 10;
      final ph = t * 12 + i * 2;
      _leg(c, l, [Offset(x, 6), Offset(x - 3 + sin(ph) * 2, 11), Offset(x + sin(ph) * 4, r)], 2.2);
    }
    final shell = Rect.fromCircle(center: const Offset(0, 6), radius: r);
    c.drawArc(shell, pi, pi, true, _body(l, 'avalanche', r, center: const Offset(-2, -4), core: const Color(0xFF1A2440)));
    _line
      ..strokeWidth = 1.2
      ..color = _frost.withValues(alpha: 0.45 + 0.3 * l.pulse);
    for (var i = 0; i < 3; i++) {
      c.drawArc(Rect.fromCircle(center: const Offset(0, 6), radius: r * (0.35 + i * 0.22)), pi + 0.25, pi - 0.5, false, _line);
    }
    // Frostzacken oben
    for (var i = 0; i < 4; i++) {
      final a = pi + 0.5 + i * 0.6;
      final p = Offset(cos(a) * r, 6 + sin(a) * r);
      c.drawPath(
          Path()
            ..moveTo(p.dx - 2, p.dy + 1)
            ..lineTo(p.dx + cos(a) * 4, p.dy + sin(a) * 4)
            ..lineTo(p.dx + 2, p.dy + 1)
            ..close(),
          _p(_k(l, const Color(0xFF8AA8C8))));
    }
    c.drawCircle(Offset(r - 1, 2), 5, _p(_k(l, const Color(0xFF1C0E28))));
    _slit(c, Offset(r + 1, 1), 1.8, _frost);
  }

  // ---------------- Spawner ----------------

  /// Krähennest auf einem Pfahl aus verflochtenen Zweigen mit glühenden Augen darin.
  static void crowNest(Canvas c, EnemyLook l, double r) {
    final shake = l.warn > 0 ? sin(l.t * 40) * 2 * l.warn : 0.0;
    c.drawRect(Rect.fromLTWH(-2.5, 0, 5, r + 4), _p(_k(l, const Color(0xFF241810))));
    c.save();
    c.translate(shake, 0);
    final bowl = Rect.fromCenter(center: const Offset(0, -2), width: r * 2.3, height: r * 1.5);
    c.drawArc(bowl, 0, pi, true, _p(_k(l, const Color(0xFF1A1008))));
    _line.strokeWidth = 1.4;
    for (var i = 0; i < 9; i++) {
      final a = i / 9 * pi;
      _line.color = _k(l, i.isEven ? const Color(0xFF3A2A1A) : const Color(0xFF2A1C10));
      c.drawLine(Offset(cos(a) * r * 1.15, -2 + sin(a) * 4), Offset(-cos(a) * r * 0.8 + sin(i * 1.7) * 3, 1 + sin(a) * 9), _line);
    }
    // Herausstehende Zweige
    for (final (x, a) in [(-r * 1.1, -2.6), (r * 1.1, -0.5), (-r * 0.6, -2.0)]) {
      c.drawLine(Offset(x, -2), Offset(x + cos(a) * 7, -2 + sin(a) * 7), _line);
    }
    // Augen im Dunkel des Nests
    c.drawOval(Rect.fromCenter(center: const Offset(0, -3), width: r * 1.6, height: 6), _p(const Color(0xFF05020A)));
    _slit(c, const Offset(-6, -4), 1.8, _eye);
    _slit(c, const Offset(5, -4.5), 1.8, _eye);
    c.restore();
  }

  /// Wespennest aus Papierschichten mit Flugloch, aus dem es glüht.
  static void waspNest(Canvas c, EnemyLook l, double r) {
    final shake = l.warn > 0 ? sin(l.t * 40) * 2 * l.warn : 0.0;
    c.save();
    c.translate(shake, 0);
    final nest = Rect.fromCenter(center: Offset.zero, width: r * 1.7, height: r * 2.2);
    c.drawOval(nest, _body(l, 'wasp_nest', r * 1.1, center: const Offset(-3, -4), core: const Color(0xFF3A2A1A)));
    c.save();
    c.clipPath(Path()..addOval(nest));
    for (var i = -3; i <= 3; i++) {
      _line
        ..strokeWidth = 1.6
        ..color = _k(l, i.isEven ? const Color(0xFF2A1E12) : const Color(0xFF4A3A22));
      c.drawArc(Rect.fromCenter(center: Offset(0, i * 5.0 - 18), width: r * 2, height: 24), 0.2, pi - 0.4, false, _line);
    }
    c.restore();
    RotArt.rim(c, Path()..addOval(nest), Rect.fromLTRB(nest.left, nest.top - 2, nest.right, nest.top + 10), color: _gold, alpha: 0.4);
    c.drawOval(Rect.fromCenter(center: Offset(0, r * 0.6), width: 8, height: 6), _p(const Color(0xFF05020A)));
    c.drawCircle(Offset(0, r * 0.6), 2, _p(_gold.withValues(alpha: 0.5 + 0.4 * l.pulse)));
    c.restore();
  }

  /// Fäulniswespe: gestreifter Hinterleib mit Stachel, Glasflügel.
  static void wasp(Canvas c, EnemyLook l, double r) {
    final fl = sin(l.t * 30);
    c.drawOval(Rect.fromCenter(center: Offset(-2, -5 - fl * 2), width: 10, height: 5), _p(const Color(0x88DFF8FF)));
    c.drawOval(Rect.fromCenter(center: const Offset(-4, 1), width: 10, height: 7), _p(_k(l, const Color(0xFF241A0C))));
    for (var i = 0; i < 2; i++) {
      c.drawRect(Rect.fromLTWH(-7.0 + i * 3.5, -2, 1.6, 6), _p(_k(l, _gold)));
    }
    c.drawPath(
        Path()
          ..moveTo(-9, 0)
          ..lineTo(-12, 2)
          ..lineTo(-9, 2.5)
          ..close(),
        _p(_k(l, const Color(0xFFE8D8C8))));
    c.drawCircle(const Offset(3, -1), 3, _p(_k(l, const Color(0xFF1C140A))));
    _slit(c, const Offset(4.5, -1.5), 1.2, _eye);
  }

  /// Sporenpilz: Hut mit Lamellen und Leuchtpunkten, knorriger Stiel mit Wurzeln.
  static void sporeShroom(Canvas c, EnemyLook l, double r) {
    final grow = 1 + 0.08 * l.warn;
    // Wurzeln
    _line
      ..strokeWidth = 2
      ..color = _k(l, const Color(0xFF1A1020));
    for (final s in [-1.0, 1.0]) {
      c.drawPath(
          Path()
            ..moveTo(s * 4, r)
            ..quadraticBezierTo(s * 9, r - 2, s * 12, r + 2),
          _line);
    }
    // Stiel
    c.drawPath(
        Path()
          ..moveTo(-6, -2)
          ..quadraticBezierTo(-8, r * 0.5, -5, r)
          ..lineTo(5, r)
          ..quadraticBezierTo(7, r * 0.5, 6, -2)
          ..close(),
        _p(_k(l, const Color(0xFF241A30))));
    c.save();
    c.scale(grow, grow);
    // Hut
    final cap = Path()
      ..moveTo(-r * 1.2, -2)
      ..cubicTo(-r * 1.1, -r * 1.1, r * 1.1, -r * 1.1, r * 1.2, -2)
      ..quadraticBezierTo(0, 2, -r * 1.2, -2)
      ..close();
    c.drawPath(cap, _body(l, 'shroom', r * 1.2, center: Offset(0, -r * 0.6), core: const Color(0xFF1E3A14)));
    // Lamellen
    _line
      ..strokeWidth = 0.8
      ..color = const Color(0xFF3A5A2A).withValues(alpha: 0.7);
    for (var i = -4; i <= 4; i++) {
      c.drawLine(Offset(i * r * 0.22, -1), Offset(i * r * 0.18, 1.5), _line);
    }
    for (final (x, y, s) in [(-10.0, -12.0, 2.6), (3.0, -16.0, 3.0), (12.0, -8.0, 2.2), (-2.0, -7.0, 1.8), (-15.0, -5.0, 1.6)]) {
      c.drawCircle(Offset(x, y), s, _p(_toxic.withValues(alpha: 0.55 + 0.4 * max(l.pulse, l.warn))));
    }
    RotArt.rim(c, cap, Rect.fromLTRB(-r * 1.3, -r * 1.2, r * 1.3, -r * 0.4), color: _toxic, alpha: 0.35);
    c.restore();
  }

  /// Spore: kleiner Keim mit Härchen und leuchtendem Kern.
  static void spore(Canvas c, EnemyLook l, double r) {
    _line
      ..strokeWidth = 0.7
      ..color = _k(l, const Color(0xFF2A3A20));
    for (var i = 0; i < 8; i++) {
      final a = i / 8 * pi * 2 + l.t;
      c.drawLine(Offset(cos(a) * r * 0.6, sin(a) * r * 0.6), Offset(cos(a) * r * 1.1, sin(a) * r * 1.1), _line);
    }
    c.drawCircle(Offset.zero, r * 0.7, _p(_k(l, const Color(0xFF1A1424))));
    c.drawCircle(const Offset(-0.5, -0.5), r * 0.38, _p(_toxic.withValues(alpha: 0.6 + 0.3 * l.pulse)));
  }

  /// Käferkönigin: massiger Panzer mit Frostkrone, schwerer Eiersack hinten.
  static void beetleQueen(Canvas c, EnemyLook l, double r) {
    final t = l.t;
    for (var i = 0; i < 3; i++) {
      final x = -12.0 + i * 12;
      final ph = t * 8 + i * 2;
      _leg(c, l, [Offset(x, 8), Offset(x - 4 + sin(ph) * 2, 14), Offset(x + sin(ph) * 3, r)], 3);
    }
    // Eiersack
    final sac = Rect.fromCenter(center: Offset(-r * 0.75, 6), width: r * 1.1, height: r * 0.9);
    c.drawOval(sac, _p(_k(l, const Color(0xFF1A2236))));
    for (var i = 0; i < 4; i++) {
      c.drawCircle(sac.center + Offset(-5 + (i % 2) * 8.0, -3 + (i ~/ 2) * 6.0), 3,
          _p(_frost.withValues(alpha: 0.3 + 0.35 * sin(t * 2 + i).abs() + 0.3 * l.warn)));
    }
    final shell = Rect.fromCircle(center: const Offset(0, 8), radius: r);
    c.drawArc(shell, pi, pi, true, _body(l, 'queen', r, center: const Offset(-2, -6), core: const Color(0xFF1A2440)));
    _line
      ..strokeWidth = 1.4
      ..color = _frost.withValues(alpha: 0.4 + 0.3 * l.pulse);
    c.drawLine(Offset(0, 8 - r), const Offset(0, 8), _line);
    for (var i = 0; i < 2; i++) {
      c.drawArc(Rect.fromCircle(center: const Offset(0, 8), radius: r * (0.45 + i * 0.3)), pi + 0.3, pi - 0.6, false, _line);
    }
    RotArt.rim(c, Path()..addArc(shell, pi, pi), Rect.fromLTRB(-r, 8 - r - 2, r, 8 - r * 0.4), color: _frost, alpha: 0.4);
    // Kopf mit Frostkrone
    c.drawCircle(Offset(r - 2, 2), 7, _p(_k(l, const Color(0xFF1C0E28))));
    for (var i = 0; i < 3; i++) {
      final cx = r * 0.35 + i * 6;
      c.drawPath(
          Path()
            ..moveTo(cx - 3, -r * 0.55)
            ..lineTo(cx, -r * 0.55 - 9 - (i == 1 ? 4 : 0))
            ..lineTo(cx + 3, -r * 0.55)
            ..close(),
          _p(_frost));
    }
    _slit(c, Offset(r + 1, 0), 2.2, _frost);
  }

  /// Gegner nach Typ zeichnen (für Vorschauen in Kompendium und Info-Panels).
  static void drawType(Canvas c, EnemyType type, EnemyLook l, double r) {
    final b = BossLook(t: l.t, pulse: l.pulse);
    switch (type) {
      case EnemyType.crow:
        RotArt.crow(c, l.t, 0.2, l.pulse);
        _slit(c, const Offset(6, -5), 2.6, _eye);
      case EnemyType.beetle:
        beetle(c, l, r);
      case EnemyType.spitter:
        spitter(c, l, r);
      case EnemyType.rock:
        rock(c, l, r);
      case EnemyType.puffball:
        puffball(c, l, r);
      case EnemyType.scarecrow:
        scarecrow(c, l, r);
      case EnemyType.bat:
        bat(c, l, r);
      case EnemyType.weathercock:
        weathercock(c, l, r);
      case EnemyType.spider:
        spider(c, l, r);
      case EnemyType.wisp:
        Glow.draw(c, 0, 0, r * 3, const Color(0x88BFF0FF));
        c.drawCircle(Offset.zero, r * 0.55, _p(const Color(0xFFDFF8FF)));
      case EnemyType.eagle:
        eagle(c, l, r);
      case EnemyType.avalanche:
        avalancheWalk(c, l, r);
      case EnemyType.crowNest:
        crowNest(c, l, r);
      case EnemyType.waspNest:
        waspNest(c, l, r);
      case EnemyType.wasp:
        wasp(c, l, r);
      case EnemyType.sporeShroom:
        sporeShroom(c, l, r);
      case EnemyType.spore:
        spore(c, l, r);
      case EnemyType.beetleQueen:
        beetleQueen(c, l, r);
      case EnemyType.beetleEgg:
        c.drawOval(Rect.fromCenter(center: Offset.zero, width: r * 1.6, height: r * 2), _p(const Color(0xFF4A5A70)));
        Glow.draw(c, 0, 0, r * 2, const Color(0x66BFE3FF));
      case EnemyType.rift:
        Glow.draw(c, 0, 0, r * 2.6, const Color(0x88FF4D8C));
        c.drawOval(Rect.fromCenter(center: Offset.zero, width: r * 1.1, height: r * 2.2), _p(const Color(0xFF0A0412)));
      case EnemyType.strawKing:
        BossArt.strawKing(c, b, r);
      case EnemyType.bell:
        BossArt.bell(c, b, r);
      case EnemyType.spiderMother:
        BossArt.spiderMother(c, b, r);
      case EnemyType.boss:
        BossArt.vultureKing(c, b);
    }
  }
}
