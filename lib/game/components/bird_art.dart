import 'dart:math';

import 'package:flutter/material.dart';

import '../config.dart';
import 'draw.dart';
import 'light.dart';

/// Haltung eines Vogels in einem Frame.
class BirdPose {
  const BirdPose({
    this.flap = 0,
    this.upright = false,
    this.blink = 0,
    this.look = Offset.zero,
    this.walk,
    this.holding = false,
    this.sway = 0,
  });

  /// Flügelschlag −1 (oben) … 1 (unten).
  final double flap;

  /// Aufrechter Körper (Pinguin).
  final bool upright;

  /// Lidschluss 0 (offen) … 1 (zu).
  final double blink;

  /// Blickrichtung der Pupillen (−1 … 1 je Achse).
  final Offset look;

  /// Laufphase am Boden (null = in der Luft, Beine eingezogen).
  final double? walk;

  /// Hält eine Waffe in den Krallen (Beine leicht nach unten gestreckt).
  final bool holding;

  /// Schwanzschwung beim Lenken (−1 … 1).
  final double sway;
}

/// Detaillierte, prozedural gezeichnete Geistvögel. Lokale Koordinaten: Blick nach +x,
/// Körpermitte im Ursprung, Radius etwa 16.
class BirdArt {
  BirdArt._();


  static final _wing = Paint()..blendMode = BlendMode.plus;
  static final _line = Paint()
    ..style = PaintingStyle.stroke
    ..strokeCap = StrokeCap.round
    ..strokeJoin = StrokeJoin.round;
  static final _rim = Paint()
    ..style = PaintingStyle.stroke
    ..strokeWidth = 1.4
    ..blendMode = BlendMode.plus;

  /// Körperverlauf in den Farben des Vogels.
  static Paint bodyPaint(CharacterDef ch) => Paint()
    ..shader = RadialGradient(
      center: const Alignment(0.3, -0.4),
      colors: [
        Color.lerp(ch.body, Colors.white, 0.7)!,
        Color.lerp(ch.body, ch.belly, 0.25)!,
        ch.body,
        Color.lerp(ch.body, Colors.black, 0.45)!,
      ],
      stops: const [0, 0.3, 0.72, 1],
    ).createShader(Rect.fromCircle(center: Offset.zero, radius: 18));

  /// Lage des Kopfes je Vogelart (Mittelpunkt, Radius).
  static (Offset, double) _headOf(CharacterDef ch, bool upright) => switch (ch.look) {
        BirdLook.penguin when upright => (const Offset(2, -15), 9),
        BirdLook.penguin => (const Offset(11, -5), 9),
        BirdLook.owl => (const Offset(7, -8), 11),
        BirdLook.hummingbird => (const Offset(10, -5), 7.5),
        BirdLook.raven => (const Offset(10, -7), 9),
        BirdLook.hen => (const Offset(9, -9), 8.5),
        _ => (const Offset(9, -6), 8.5),
      };

  static void draw(Canvas c, CharacterDef ch, Paint body, BirdPose pose) {
    if (ch.look == BirdLook.ostrich) {
      _ostrich(c, ch, body, pose);
      return;
    }
    final g = ch.glow;
    final dark = Color.lerp(ch.body, Colors.black, 0.55)!;
    final up = pose.upright;
    final (head, hr) = _headOf(ch, up);

    _legs(c, ch, pose);
    // Hinterer Flügel, gedämpft
    _wingShape(c, ch, Offset(up ? -2 : -1, up ? -4 : -5), pose.flap * (up ? 0.4 : 1), far: true);
    _tail(c, ch, pose.sway, up);

    // Körper und Kopf als eine Silhouette
    final bodyRect = up
        ? Rect.fromCenter(center: const Offset(0, 2), width: 26, height: 34)
        : Rect.fromCenter(center: const Offset(-2, 2), width: 32, height: 25);
    c.drawOval(bodyRect, body);
    c.drawCircle(head, hr, body);
    // Lichtkante oben
    _rim.color = g.withValues(alpha: 0.55);
    c.drawArc(bodyRect.deflate(0.5), pi * 1.05, pi * 0.8, false, _rim);
    c.drawArc(Rect.fromCircle(center: head, radius: hr - 0.5), pi * 1.1, pi * 0.9, false, _rim);

    // Bauch mit angedeuteten Federschuppen
    final belly = up
        ? Rect.fromCenter(center: const Offset(4, 5), width: 15, height: 26)
        : Rect.fromCenter(center: const Offset(3, 6), width: 20, height: 13);
    c.drawOval(belly, fillOf(ch.belly.withValues(alpha: 0.9)));
    _line
      ..strokeWidth = 0.7
      ..color = Color.lerp(ch.belly, ch.body, 0.45)!.withValues(alpha: 0.6);
    for (var i = 0; i < 3; i++) {
      for (var j = 0; j < 2; j++) {
        final cx = belly.left + belly.width * (0.3 + j * 0.35) + (i.isOdd ? 2 : 0);
        final cy = belly.top + belly.height * (0.3 + i * 0.22);
        c.drawArc(Rect.fromCircle(center: Offset(cx, cy), radius: 2.2), 0.2, pi - 0.4, false, _line);
      }
    }

    _markings(c, ch, head, hr, up);
    _beak(c, ch, head, hr);
    _eyes(c, ch, head, hr, pose, dark);
    _crest(c, ch, head, hr);

    // Vorderer Flügel leuchtet beim Flügelschlag auf
    _wingShape(c, ch, Offset(up ? -1 : -3, up ? 0 : 1), pose.flap * (up ? 0.3 : 0.85), far: false);
  }

  // ---------------- Flügel ----------------

  /// Flügel aus Deckfedern und fünf Schwungfedern, die sich beim Schlag auffächern.
  static void _wingShape(Canvas c, CharacterDef ch, Offset at, double flap, {required bool far}) {
    final g = ch.glow;
    final len = switch (ch.look) {
      BirdLook.penguin => 9.0,
      BirdLook.swallow => 20.0,
      BirdLook.hummingbird => 14.0,
      BirdLook.raven || BirdLook.owl => 18.0,
      BirdLook.hen => 12.0,
      _ => 16.0,
    };
    final spread = 0.13 + 0.09 * (1 + flap);
    c.save();
    c.translate(at.dx, at.dy);
    c.rotate((far ? -0.55 : 0.3) - flap * (far ? 1.0 : 0.8));
    // Schwungfedern
    for (var i = 4; i >= 0; i--) {
      final a = pi + (i - 2) * spread;
      final l = len * (0.75 + i * 0.07);
      _wing.color = Color.lerp(g, Colors.white, far ? 0 : 0.2 + 0.05 * i)!
          .withValues(alpha: far ? 0.45 : 0.6 + 0.25 * flap.abs());
      final tip = Offset(cos(a) * l, sin(a) * l);
      final nrm = Offset(-sin(a), cos(a)) * 2.4;
      final p = Path()
        ..moveTo(-2, 0)
        ..quadraticBezierTo((tip.dx) * 0.5 + nrm.dx, tip.dy * 0.5 + nrm.dy, tip.dx, tip.dy)
        ..quadraticBezierTo(tip.dx * 0.5 - nrm.dx, tip.dy * 0.5 - nrm.dy, -2, 0);
      c.drawPath(p, _wing);
    }
    // Deckfedern
    final cov = Color.lerp(ch.body, g, far ? 0.15 : 0.35)!;
    c.drawOval(Rect.fromCenter(center: Offset(-len * 0.3, 0), width: len * 0.8, height: 8),
        fillOf(far ? Color.lerp(cov, Colors.black, 0.3)! : cov));
    if (!far) {
      _line
        ..strokeWidth = 0.6
        ..color = Color.lerp(cov, Colors.white, 0.35)!;
      for (var i = 0; i < 3; i++) {
        c.drawArc(Rect.fromCircle(center: Offset(-len * 0.12 - i * 3.2, 1.5), radius: 2.4), 0.3, pi - 0.6, false, _line);
      }
    }
    c.restore();
  }

  // ---------------- Schwanz ----------------

  static void _tail(Canvas c, CharacterDef ch, double sway, bool up) {
    final g = ch.glow;
    final col = Color.lerp(ch.body, g, 0.3)!, tip = Color.lerp(col, g, 0.5)!;
    final base = up ? const Offset(-8, 14) : const Offset(-15, 1);
    final dir = up ? 2.4 : pi - 0.05 + sway * 0.25;
    void feather(double a, double l, double w, Color color) {
      final t = base + Offset(cos(a) * l, sin(a) * l);
      final n = Offset(-sin(a), cos(a)) * w;
      final p = Path()
        ..moveTo(base.dx, base.dy)
        ..quadraticBezierTo(base.dx + cos(a) * l * 0.5 + n.dx, base.dy + sin(a) * l * 0.5 + n.dy, t.dx, t.dy)
        ..quadraticBezierTo(base.dx + cos(a) * l * 0.5 - n.dx, base.dy + sin(a) * l * 0.5 - n.dy, base.dx, base.dy);
      c.drawPath(p, fillOf(color));
    }

    switch (ch.look) {
      case BirdLook.swallow: // tiefe Gabel mit langen Außenfedern
        feather(dir - 0.38, 22, 2.2, col);
        feather(dir + 0.38, 22, 2.2, col);
        feather(dir, 10, 3, tip);
      case BirdLook.magpie: // sehr langer, gestufter Schwanz
        feather(dir - 0.08, 28, 3.4, col);
        feather(dir + 0.08, 25, 3, tip);
      case BirdLook.hen: // aufgestellte Sichelfedern
        for (var i = 0; i < 4; i++) {
          feather(dir + 0.9 + i * 0.22, 14 + i * 2.0, 3.2, i.isEven ? col : tip);
        }
      case BirdLook.penguin:
        feather(dir, 7, 3, col);
      case BirdLook.owl:
        for (var i = -2; i <= 2; i++) {
          feather(dir + i * 0.16, 11, 3, i.isEven ? col : tip);
        }
      case BirdLook.hummingbird:
        for (var i = -1; i <= 1; i++) {
          feather(dir + i * 0.25, 10, 2.2, i == 0 ? tip : col);
        }
      default:
        for (var i = -2; i <= 2; i++) {
          feather(dir + i * 0.13, 14 - i.abs() * 1.5, 2.8, i.isEven ? col : tip);
        }
    }
    Glow.draw(c, base.dx - 10, base.dy, 14, g.withValues(alpha: 0.4));
  }

  // ---------------- Kopf ----------------

  static void _beak(Canvas c, CharacterDef ch, Offset head, double hr) {
    const orange = Color(0xFFFF8A3D), darkBeak = Color(0xFF2A2236);
    final base = head + Offset(hr * 0.75, hr * 0.15);
    void beak(double len, double h, Color col, {double droop = 0}) {
      final upper = Path()
        ..moveTo(base.dx - 1, base.dy - h)
        ..quadraticBezierTo(base.dx + len * 0.6, base.dy - h * 0.8, base.dx + len, base.dy + droop)
        ..lineTo(base.dx - 1, base.dy + 0.4)
        ..close();
      final lower = Path()
        ..moveTo(base.dx - 1, base.dy + 0.4)
        ..lineTo(base.dx + len * 0.85, base.dy + droop + 0.6)
        ..quadraticBezierTo(base.dx + len * 0.4, base.dy + h * 0.9, base.dx - 1, base.dy + h)
        ..close();
      c.drawPath(lower, fillOf(Color.lerp(col, Colors.black, 0.25)!));
      c.drawPath(upper, fillOf(col));
      drawCircle(c, base.dx + len * 0.25, base.dy - h * 0.45, 0.6, Colors.white.withAlpha(160));
    }

    switch (ch.look) {
      case BirdLook.hummingbird:
        beak(19, 1.2, darkBeak);
      case BirdLook.woodpecker:
        beak(14, 2.6, const Color(0xFF6A5A4A));
      case BirdLook.raven:
        beak(13, 3.4, const Color(0xFF1A1426), droop: 1.5);
      case BirdLook.owl:
        beak(5, 2.6, const Color(0xFF6A4A2A), droop: 2.5);
      case BirdLook.penguin:
        beak(10, 2.2, orange);
      case BirdLook.swallow || BirdLook.magpie:
        beak(7, 2, darkBeak);
      case BirdLook.robin:
        beak(7, 2, const Color(0xFF4A3424));
      case BirdLook.hen:
        beak(7, 2.6, const Color(0xFFFFB347), droop: 1);
      default:
        beak(10, 3.2, orange);
    }
  }

  static void _eyes(Canvas c, CharacterDef ch, Offset head, double hr, BirdPose pose, Color dark) {
    final look = Offset(pose.look.dx.clamp(-1.0, 1.0), pose.look.dy.clamp(-1.0, 1.0));
    void eye(Offset at, double r, {Color iris = const Color(0xFF1B1030), Color sclera = Colors.white, bool glow = false}) {
      if (glow) Glow.draw(c, at.dx, at.dy, r * 4, iris.withAlpha(150));
      drawCircle(c, at.dx, at.dy, r + 0.8, dark);
      drawCircle(c, at.dx, at.dy, r, sclera);
      final p = at + look * (r * 0.35);
      drawCircle(c, p.dx, p.dy, r * 0.62, iris);
      drawCircle(c, p.dx - r * 0.25, p.dy - r * 0.3, r * 0.22, Colors.white);
      // Lid schließt sich von oben
      if (pose.blink > 0) {
        c.save();
        c.clipRect(Rect.fromLTRB(at.dx - r - 1, at.dy - r - 1, at.dx + r + 1, at.dy - r - 1 + (2 * r + 2) * pose.blink));
        drawCircle(c, at.dx, at.dy, r + 0.9, ch.body);
        c.restore();
      }
    }

    final e = head + Offset(hr * 0.25, -hr * 0.2);
    switch (ch.look) {
      case BirdLook.sparrow:
        // Fliegerbrille: Lederband, leuchtendes Glas mit Messingrand
        drawRect(c, head.dx - hr - 6, e.dy - 2.4, hr * 2 + 4, 4.8, const Color(0xFF3A2440));
        Glow.draw(c, e.dx, e.dy, 12, const Color(0x999BF6FF));
        drawCircle(c, e.dx, e.dy, 4.6, const Color(0xFFC9A04A));
        eye(e, 3.6, sclera: const Color(0xFFBFF8FF));
      case BirdLook.owl:
        // Große Gesichtsscheibe mit zwei leuchtenden Augen
        for (final dx in [-4.2, 4.2]) {
          final at = head + Offset(dx + 1, -1);
          drawCircle(c, at.dx, at.dy, 5.4, Color.lerp(ch.belly, Colors.white, 0.3)!);
          eye(at, 3.8, iris: const Color(0xFFFFB347), sclera: const Color(0xFF2A1A10), glow: true);
        }
      case BirdLook.raven:
        eye(e, 2.6, iris: const Color(0xFFE6B8FF), sclera: const Color(0xFF3A2A50), glow: true);
      case BirdLook.penguin:
        // Weißer Fleck ums Auge
        drawOval(c, e.dx - 1, e.dy + 0.5, 4.5, 3.5, Colors.white);
        eye(e, 2.4);
      case BirdLook.hummingbird:
        eye(e, 2.4);
      default:
        eye(e, 2.8);
    }
  }

  /// Gefiederzeichnung je Art (Kehle, Brust, Wangen, Schulterflecken).
  static void _markings(Canvas c, CharacterDef ch, Offset head, double hr, bool up) {
    switch (ch.look) {
      case BirdLook.robin: // leuchtend orangerote Brust
        c.drawOval(Rect.fromCenter(center: head + const Offset(2, 9), width: 16, height: 13), fillOf(const Color(0xFFFF6A3D)));
        Glow.draw(c, head.dx + 2, head.dy + 9, 16, const Color(0x66FF6A3D));
      case BirdLook.swallow: // rostrote Kehle, dunkler Rücken
        c.drawOval(Rect.fromCenter(center: head + Offset(hr * 0.5, hr * 0.55), width: 8, height: 6), fillOf(const Color(0xFFB0402A)));
      case BirdLook.hummingbird: // schillernde Kehle
        final shimmer = Color.lerp(const Color(0xFFFF5AD2), const Color(0xFF8CFFC8), 0.5 + 0.5 * sin(head.dx))!;
        c.drawOval(Rect.fromCenter(center: head + Offset(hr * 0.4, hr * 0.6), width: 8, height: 6), fillOf(shimmer));
        Glow.draw(c, head.dx + hr * 0.4, head.dy + hr * 0.6, 10, shimmer.withAlpha(120));
      case BirdLook.raven: // struppige Kehlfedern
        for (var i = 0; i < 4; i++) {
          final x = head.dx + 2 + i * 2.2, y = head.dy + hr * 0.7;
          drawTri(c, x - 1.6, y, x + 1.6, y, x, y + 4 + (i.isEven ? 1 : 0), const Color(0xFF1A1426));
        }
      case BirdLook.penguin: // schwarzer Kopf, weiße Brust bis zur Kehle
        c.drawCircle(head, hr, fillOf(const Color(0xFF1A2236)));
        if (up) c.drawOval(Rect.fromCenter(center: head + const Offset(3, 7), width: 9, height: 7), fillOf(const Color(0xFFF4FAFF)));
      case BirdLook.woodpecker: // weißer Wangenstreif, schwarzer Bartstreif
        drawRect(c, head.dx - hr, head.dy + 1.5, hr * 1.7, 2.6, const Color(0xFFF2EEE6));
        drawRect(c, head.dx - hr + 2, head.dy + 4.5, hr * 1.4, 1.6, const Color(0xFF1A1A1A));
      case BirdLook.magpie: // weißer Schulterfleck mit blauem Schimmer
        c.drawOval(Rect.fromCenter(center: const Offset(-7, 0), width: 11, height: 8), fillOf(const Color(0xFFF6F6F6)));
        Glow.draw(c, -10, -2, 12, const Color(0x669FD4FF));
      case BirdLook.hen: // Kehllappen
        c.drawOval(Rect.fromCenter(center: head + Offset(hr * 0.75, hr * 0.85), width: 4.5, height: 7), fillOf(const Color(0xFFFF3B3B)));
      default:
    }
  }

  /// Hauben, Federohren, Kamm.
  static void _crest(Canvas c, CharacterDef ch, Offset head, double hr) {
    switch (ch.look) {
      case BirdLook.woodpecker:
        final p = Path()
          ..moveTo(head.dx - hr * 0.9, head.dy - hr * 0.3)
          ..quadraticBezierTo(head.dx - hr * 0.6, head.dy - hr * 1.6, head.dx + hr * 0.4, head.dy - hr * 0.9)
          ..close();
        c.drawPath(p, fillOf(const Color(0xFFFF3B3B)));
        Glow.draw(c, head.dx - hr * 0.3, head.dy - hr, 14, const Color(0x88FF3B3B));
      case BirdLook.owl:
        for (final dx in [-6.0, 5.0]) {
          drawTri(c, head.dx + dx - 2.5, head.dy - hr * 0.7, head.dx + dx + 2.5, head.dy - hr * 0.7, head.dx + dx * 1.3,
              head.dy - hr * 1.6, Color.lerp(ch.body, Colors.black, 0.4)!);
        }
      case BirdLook.hen:
        for (var i = 0; i < 3; i++) {
          drawCircle(c, head.dx - 3 + i * 3.6, head.dy - hr * 0.9 - (i == 1 ? 1.5 : 0), 2.8, const Color(0xFFFF3B3B));
        }
      case BirdLook.raven:
        drawTri(c, head.dx - hr * 0.6, head.dy - hr * 0.6, head.dx - hr * 1.3, head.dy - hr * 1.1, head.dx - hr * 0.2,
            head.dy - hr * 0.9, const Color(0xFF2A2140));
      default:
    }
  }

  // ---------------- Beine ----------------

  static void _legs(Canvas c, CharacterDef ch, BirdPose pose) {
    final col = switch (ch.look) {
      BirdLook.penguin || BirdLook.hen => const Color(0xFFFF9F43),
      BirdLook.owl => const Color(0xFFE8D8C0),
      _ => const Color(0xFFE08A3A),
    };
    _line
      ..strokeWidth = 1.8
      ..color = col;
    final hipY = pose.upright ? 16.0 : 10.0;
    final walk = pose.walk;
    for (final (i, hx) in [(0, -2.0), (1, 3.0)]) {
      final Offset foot;
      if (walk != null) {
        final ph = walk + i * pi;
        foot = Offset(hx + sin(ph) * 4, hipY + 7 - max(0.0, cos(ph)) * 2.5);
      } else if (pose.holding) {
        foot = Offset(hx + 1.5, hipY + 6);
      } else {
        foot = Offset(hx - 3, hipY + 3); // eingezogen
      }
      c.drawLine(Offset(hx, hipY), foot, _line);
      if (walk != null) {
        c.drawLine(foot, foot + const Offset(3.5, 0), _line);
        c.drawLine(foot, foot + const Offset(-2, 0.5), _line);
      }
    }
  }

  // ---------------- Strauß ----------------

  /// Strauß: langer Hals, kleiner Kopf mit Wimpern, fluffiger dunkler Körper mit weißen
  /// Flügelfedern, lange rosa Beine mit nach hinten gerichtetem Knie (immer sichtbar).
  static void _ostrich(Canvas c, CharacterDef ch, Paint body, BirdPose pose) {
    const skin = Color(0xFFE8A8B8), skinDark = Color(0xFFC07888);
    final g = ch.glow;
    final walk = pose.walk;

    // Beine: Oberschenkel, Knie hinten, Unterschenkel, zwei Zehen
    _line.strokeCap = StrokeCap.round;
    for (final (i, hx) in [(0, -3.0), (1, 2.0)]) {
      final ph = (walk ?? 0) + i * pi;
      final swing = walk != null ? sin(ph) * 7 : (pose.holding ? 2.0 : -2.0 + i * 3);
      final lift = walk != null ? max(0.0, cos(ph)) * 4 : 0.0;
      final hip = Offset(hx, 2);
      final knee = Offset(hx - 3 + swing * 0.3, 8 - lift * 0.5);
      final foot = Offset(hx + swing, 15 - lift);
      _line
        ..strokeWidth = 3
        ..color = i == 0 ? skinDark : skin;
      c.drawLine(hip, knee, _line);
      _line.strokeWidth = 2.2;
      c.drawLine(knee, foot, _line);
      c.drawLine(foot, foot + const Offset(4, 0.5), _line);
      c.drawLine(foot, foot + const Offset(1.5, 1.5), _line);
    }

    // Hinterer Flügel (weiße Federn)
    final lift = pose.flap * 0.25;
    void plumes(Offset at, double rot, double alpha) {
      c.save();
      c.translate(at.dx, at.dy);
      c.rotate(rot);
      for (var i = 0; i < 4; i++) {
        c.drawOval(Rect.fromCenter(center: Offset(-4.0 - i * 3, i * 1.2), width: 9, height: 5.5),
            fillOf(Color.lerp(ch.belly, Colors.white, 0.3)!.withValues(alpha: alpha)));
      }
      c.restore();
    }

    plumes(const Offset(-6, -9), -0.4 - lift, 0.6);
    // Schwanzbüschel
    for (var i = 0; i < 3; i++) {
      c.drawOval(Rect.fromCenter(center: Offset(-18 - i * 1.5, -9 + i * 3.0 + pose.sway * 2), width: 8, height: 5),
          fillOf(Colors.white.withValues(alpha: 0.9)));
    }

    // Körper mit fluffigem Saum
    final bodyRect = Rect.fromCenter(center: const Offset(-3, -4), width: 30, height: 20);
    c.drawOval(bodyRect, body);
    for (var i = 0; i < 7; i++) {
      final x = bodyRect.left + 4 + i * 3.6;
      drawCircle(c, x, bodyRect.bottom - 2 + (i.isEven ? 0.8 : 0), 2.4, Color.lerp(ch.body, Colors.black, 0.25)!);
    }
    _rim.color = g.withValues(alpha: 0.5);
    c.drawArc(bodyRect.deflate(0.5), pi * 1.05, pi * 0.8, false, _rim);

    // Hals mit leichter S-Kurve, wippt beim Laufen
    final bob = walk != null ? sin(walk * 2) * 1.2 : 0.0;
    final head = Offset(14, -26 + bob);
    final neck = Path()
      ..moveTo(7, -9)
      ..cubicTo(13, -12, 9, -20, head.dx - 1, head.dy + 3);
    _line
      ..strokeWidth = 4.2
      ..color = skin;
    c.drawPath(neck, _line);
    _line
      ..strokeWidth = 1.4
      ..color = Colors.white.withValues(alpha: 0.35);
    c.drawPath(neck, _line);

    // Vorderer Flügel
    plumes(const Offset(-2, -6), 0.15 - lift * 0.6, 0.95);

    // Kopf: flacher breiter Schnabel, großes Auge mit Wimpern
    c.drawCircle(head, 5, fillOf(skin));
    final beak = Path()
      ..moveTo(head.dx + 3, head.dy - 1)
      ..quadraticBezierTo(head.dx + 10, head.dy - 0.5, head.dx + 10, head.dy + 1.2)
      ..quadraticBezierTo(head.dx + 6, head.dy + 2.6, head.dx + 3, head.dy + 2)
      ..close();
    c.drawPath(beak, fillOf(const Color(0xFFE8C090)));
    final eye = head + const Offset(1.5, -1);
    drawCircle(c, eye.dx, eye.dy, 2.9, Colors.white);
    final look = Offset(pose.look.dx.clamp(-1.0, 1.0), pose.look.dy.clamp(-1.0, 1.0));
    final pp = eye + look * 0.9;
    drawCircle(c, pp.dx, pp.dy, 1.8, const Color(0xFF1B1030));
    drawCircle(c, pp.dx - 0.6, pp.dy - 0.7, 0.6, Colors.white);
    if (pose.blink > 0) {
      c.save();
      c.clipRect(Rect.fromLTRB(eye.dx - 3.5, eye.dy - 3.5, eye.dx + 3.5, eye.dy - 3.5 + 7 * pose.blink));
      drawCircle(c, eye.dx, eye.dy, 3.2, skin);
      c.restore();
    }
    // Wimpern
    _line
      ..strokeWidth = 0.8
      ..color = const Color(0xFF1B1030);
    for (var i = 0; i < 3; i++) {
      final a = -pi / 2 - 0.5 + i * 0.5;
      c.drawLine(eye + Offset(cos(a) * 2.9, sin(a) * 2.9), eye + Offset(cos(a) * 4.6, sin(a) * 4.6), _line);
    }
    // Ein paar Federn auf dem Kopf
    for (var i = 0; i < 3; i++) {
      drawCircle(c, head.dx - 2 + i * 1.6, head.dy - 4.6, 1.3, Color.lerp(skin, Colors.white, 0.4)!);
    }
  }
}
