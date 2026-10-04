import 'dart:math';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../config.dart';
import 'bird_art.dart';
import 'light.dart';

enum _Tail { flow, fork, long, fan, sickle, stub, plume, wedge }

/// Maße und Merkmale eines Vogels im Stil „leuchtender Geist“.
class _Spec {
  const _Spec({
    this.body = const Rect.fromLTWH(-18, -11, 32, 24),
    this.head = const Offset(9, -7),
    this.headR = 8.5,
    this.beakLen = 8,
    this.beakH = 3,
    this.beakDroop = 0,
    this.beakColor = const Color(0xFFFFB45A),
    this.eye = 2.6,
    this.wing = 22,
    this.tail = _Tail.flow,
    this.upright = false,
  });
  final Rect body;
  final Offset head;
  final double headR, beakLen, beakH, beakDroop, eye, wing;
  final Color beakColor;
  final _Tail tail;
  final bool upright;
}

/// Stil „leuchtender Geist“: Vögel aus Licht statt Comic-Vögel.
/// Innen heller Kern, nach außen durchscheinend, leuchtende Kante oben, weiche
/// Schattierung unten, Lichtflügel, die zu den Spitzen ausblenden, fließende
/// Schwanzformen, Leuchtakzente je Art und aufsteigende Funken.
/// Lokale Koordinaten wie [BirdArt]: Blick nach +x, Körpermitte im Ursprung.
class SpiritBirdArt {
  SpiritBirdArt._();

  static final _stroke = Paint()
    ..style = PaintingStyle.stroke
    ..strokeCap = StrokeCap.round
    ..strokeJoin = StrokeJoin.round
    ..blendMode = BlendMode.plus;

  static _Spec _spec(BirdLook look) => switch (look) {
        BirdLook.sparrow => const _Spec(),
        BirdLook.robin => const _Spec(beakColor: Color(0xFFD08A5A), beakLen: 7),
        BirdLook.swallow => const _Spec(
            body: Rect.fromLTWH(-19, -9, 34, 19), head: Offset(10, -5), headR: 7.5, beakLen: 6, beakH: 2.4,
            beakColor: Color(0xFF8A8AA8), wing: 28, tail: _Tail.fork),
        BirdLook.hummingbird => const _Spec(
            body: Rect.fromLTWH(-13, -8, 24, 17), head: Offset(8, -5), headR: 7, beakLen: 18, beakH: 1.3,
            beakColor: Color(0xFFB8B8D8), eye: 2.2, wing: 17, tail: _Tail.stub),
        BirdLook.raven => const _Spec(
            body: Rect.fromLTWH(-19, -11, 34, 25), head: Offset(11, -7), headR: 9, beakLen: 13, beakH: 3.6, beakDroop: 1.8,
            beakColor: Color(0xFF7A6A9A), wing: 26, tail: _Tail.wedge),
        BirdLook.penguin => const _Spec(
            body: Rect.fromLTWH(-12, -14, 24, 34), head: Offset(2, -16), headR: 9, beakLen: 10, beakH: 2.4,
            wing: 11, tail: _Tail.stub, upright: true),
        BirdLook.woodpecker => const _Spec(
            beakLen: 15, beakH: 2.6, beakColor: Color(0xFFC8B8A0), tail: _Tail.wedge),
        BirdLook.owl => const _Spec(
            body: Rect.fromLTWH(-17, -10, 30, 26), head: Offset(6, -9), headR: 11.5, beakLen: 4.5, beakH: 2.8,
            beakDroop: 2.5, beakColor: Color(0xFFC8A070), eye: 3.6, wing: 24, tail: _Tail.fan),
        BirdLook.magpie => const _Spec(
            body: Rect.fromLTWH(-17, -10, 30, 22), head: Offset(10, -6), headR: 8, beakLen: 7, beakH: 2.4,
            beakColor: Color(0xFF8A8AA8), tail: _Tail.long),
        BirdLook.hen => const _Spec(
            body: Rect.fromLTWH(-17, -10, 30, 26), head: Offset(9, -10), headR: 8, beakLen: 7, beakH: 2.8,
            beakDroop: 1, beakColor: Color(0xFFFFC870), wing: 16, tail: _Tail.sickle),
        BirdLook.eagle => const _Spec(
            body: Rect.fromLTWH(-19, -11, 34, 26), head: Offset(11, -7), headR: 9, beakLen: 11, beakH: 4, beakDroop: 4,
            beakColor: Color(0xFFFFC94A), wing: 30, tail: _Tail.fan),
        BirdLook.ostrich => const _Spec(
            body: Rect.fromLTWH(-18, -14, 30, 20), head: Offset(14, -26), headR: 5, beakLen: 7, beakH: 2,
            beakColor: Color(0xFFE8C090), eye: 2.2, wing: 14, tail: _Tail.plume),
      };

  /// Silhouetten werden einmal je Art gebaut (Körper ∪ Kopf ∪ ggf. Hals).
  static final _shapes = <BirdLook, Path>{};

  static Path _silhouette(BirdLook look, _Spec s) => _shapes.putIfAbsent(look, () {
        var p = Path()..addOval(s.body);
        p = Path.combine(PathOperation.union, p, Path()..addOval(Rect.fromCircle(center: s.head, radius: s.headR)));
        if (look == BirdLook.ostrich) {
          final neck = Path()
            ..moveTo(4, -12)
            ..cubicTo(12, -14, 8, -21, s.head.dx - 2.5, s.head.dy + 2)
            ..lineTo(s.head.dx + 1.5, s.head.dy + 3)
            ..cubicTo(13, -20, 16, -12, 9, -8)
            ..close();
          p = Path.combine(PathOperation.union, p, neck);
        } else {
          // Weicher Übergang Kopf–Körper (Nacken und Kehle)
          final bridge = Path()
            ..moveTo(s.head.dx - s.headR * 0.9, s.head.dy + s.headR * 0.2)
            ..quadraticBezierTo(s.head.dx - s.headR * 0.4, s.head.dy + s.headR * 1.3, s.body.center.dx, s.body.top + 2)
            ..lineTo(s.body.center.dx + 6, s.body.center.dy)
            ..lineTo(s.head.dx + s.headR * 0.6, s.head.dy + s.headR * 0.7)
            ..close();
          p = Path.combine(PathOperation.union, p, bridge);
        }
        return p;
      });

  static void draw(Canvas c, CharacterDef ch, BirdPose pose) {
    final s = _spec(ch.look);
    final g = ch.glow, t = pose.t;
    final core = Color.lerp(ch.body, Colors.white, 0.72)!;
    final shape = _silhouette(ch.look, s);
    final bounds = shape.getBounds();

    _legs(c, ch, s, pose, g);
    _tail(c, s, g, core, t, pose.sway);
    _wing(c, ch, s, g, core, pose.flap, t, far: true);

    // Körper: heller Kern → Körperfarbe → durchscheinende Leuchtkante
    c.drawPath(
      shape,
      Paint()
        ..shader = ui.Gradient.radial(
          s.head + Offset(-s.headR * 0.2, s.headR * 0.9),
          max(bounds.width, bounds.height) * 0.75,
          [Color.lerp(core, Colors.white, 0.5)!, core, ch.body, Color.lerp(ch.body, g, 0.4)!.withValues(alpha: 0.7)],
          const [0, 0.18, 0.62, 1],
        ),
    );
    c.save();
    c.clipPath(shape);
    // Schattierung unten
    c.drawRect(
      bounds,
      Paint()
        ..shader = ui.Gradient.linear(Offset(0, bounds.top), Offset(0, bounds.bottom),
            [Colors.transparent, Colors.transparent, const Color(0x80301A40)], const [0, 0.45, 1]),
    );
    // Feine Federzüge im hinteren Körper, schräg nach hinten auslaufend
    _stroke
      ..strokeWidth = 0.8
      ..color = Colors.white.withValues(alpha: 0.07);
    for (var i = 0; i < 3; i++) {
      final y = s.body.top + s.body.height * (0.3 + i * 0.18);
      final x0 = s.body.center.dx + 2;
      c.drawPath(
          Path()
            ..moveTo(x0, y)
            ..quadraticBezierTo(x0 - s.body.width * 0.25, y + 3, s.body.left + 3, y + 1 + i),
          _stroke);
    }
    _accentsInside(c, ch, s, t);
    c.restore();

    // Leuchtende Kante oben (Gegenlicht): Rand nur in der oberen Hälfte
    c.save();
    c.clipRect(Rect.fromLTRB(bounds.left - 4, bounds.top - 4, bounds.right + 4, bounds.center.dy + (s.upright ? 2 : -1)));
    _stroke
      ..strokeWidth = 4
      ..color = g.withValues(alpha: 0.14);
    c.drawPath(shape, _stroke);
    _stroke
      ..strokeWidth = 0.9
      ..color = Color.lerp(g, Colors.white, 0.5)!.withValues(alpha: 0.55);
    c.drawPath(shape, _stroke);
    c.restore();
    Glow.draw(c, s.head.dx - s.headR * 0.2, s.head.dy + s.headR * 1.1, 14, Colors.white.withValues(alpha: 0.28));

    _accentsOutside(c, ch, s, t);
    _beak(c, s);
    _eyes(c, ch, s, pose);
    _wing(c, ch, s, g, core, pose.flap, t, far: false);
    _motes(c, ch, s, t);
  }

  // ---------------- Flügel ----------------

  static void _wing(Canvas c, CharacterDef ch, _Spec s, Color g, Color core, double flap, double t, {required bool far}) {
    final look = ch.look;
    if (look == BirdLook.ostrich) {
      _plumes(c, ch, flap, far: far);
      return;
    }
    // Kolibri: schwirrende Flügel als Unschärfe aus drei Phasen
    final ghosts = look == BirdLook.hummingbird ? 3 : 1;
    for (var k = 0; k < ghosts; k++) {
      final f = ghosts == 1 ? flap : sin(t * 50 + k * 2.1);
      final alphaMul = ghosts == 1 ? 1.0 : 0.45;
      c.save();
      final at = s.upright ? Offset(far ? 1 : -2, far ? -4 : 0) : Offset(s.body.center.dx + 1, s.body.top + (far ? 4 : 8));
      c.translate(at.dx, at.dy);
      // Vorne beim Abwärtsschlag weniger weit drehen, damit der Flügel sichtbar bleibt
      c.rotate(s.upright ? (far ? -0.3 : 0.5) - f * 0.3 : (far ? -0.6 : 0.25) - f * (far ? 1.0 : 0.6));
      final len = s.wing, spread = 1 + 0.25 * f;
      final lead = Path()
        ..moveTo(4, 0)
        ..cubicTo(-2, -5, -len * 0.55, -len * 0.32 * spread, -len, -len * 0.16 * spread);
      final wing = Path.from(lead)
        ..cubicTo(-len * 0.85, -1, -len * 0.92, len * 0.08, -len * 0.77, len * 0.12)
        ..cubicTo(-len * 0.6, len * 0.2, -len * 0.3, len * 0.24, 4, 3)
        ..close();
      final front = !far;
      c.drawPath(
        wing,
        Paint()
          ..blendMode = front ? BlendMode.srcOver : BlendMode.plus
          ..shader = ui.Gradient.linear(
            const Offset(4, 0),
            Offset(-len, -len * 0.12),
            front
                ? [
                    core.withValues(alpha: 0.9 * alphaMul),
                    Color.lerp(core, g, 0.6)!.withValues(alpha: 0.6 * alphaMul),
                    g.withValues(alpha: 0),
                  ]
                : [g.withValues(alpha: 0.3 * alphaMul), g.withValues(alpha: 0.12 * alphaMul), g.withValues(alpha: 0)],
            const [0, 0.6, 1],
          ),
      );
      _stroke
        ..strokeWidth = front ? 1.3 : 0.8
        ..color = Colors.white.withValues(alpha: (front ? 0.7 : 0.25) * alphaMul);
      final m = lead.computeMetrics().first;
      c.drawPath(m.extractPath(0, m.length * 0.85), _stroke);
      // Schwungfedern; beim Adler als gespreizte Fingerfedern
      final fingers = look == BirdLook.eagle;
      _stroke
        ..strokeWidth = fingers ? 1.2 : 0.8
        ..color = Colors.white.withValues(alpha: (front ? 0.3 : 0.1) * alphaMul);
      for (var i = 0; i < (fingers ? 5 : 4); i++) {
        final ty = -len * 0.25 * spread + i * len * (fingers ? 0.09 : 0.1);
        c.drawPath(
            Path()
              ..moveTo(-len * 0.18, 1.5)
              ..quadraticBezierTo(-len * 0.55, ty * 0.6, -len * (0.95 + (fingers ? 0.12 : 0.05) * i / 4), ty),
            _stroke);
      }
      c.restore();
    }
  }

  /// Strauß: weiße Federbüschel statt Flugflügel.
  static void _plumes(Canvas c, CharacterDef ch, double flap, {required bool far}) {
    c.save();
    c.translate(far ? -6 : -2, far ? -11 : -7);
    c.rotate((far ? -0.4 : 0.15) - flap * 0.25);
    for (var i = 0; i < 4; i++) {
      c.drawOval(Rect.fromCenter(center: Offset(-4.0 - i * 3, i * 1.2), width: 9, height: 5.5),
          Paint()..color = Colors.white.withValues(alpha: far ? 0.35 : 0.8));
    }
    Glow.draw(c, -8, 1, 12, Colors.white.withValues(alpha: far ? 0.15 : 0.3));
    c.restore();
  }

  // ---------------- Schwanz ----------------

  static void _tail(Canvas c, _Spec s, Color g, Color core, double t, double sway) {
    final base = s.upright ? Offset(-6, s.body.bottom - 3) : Offset(s.body.left + 3, s.body.center.dy - 1);
    final dir = s.upright ? 2.3 : pi;

    /// Spitz auslaufender Lichtstreifen von [base] in Richtung [ang], Länge [len], Breite [w].
    void streamer(double ang, double len, double w, {double amp = 3, double phase = 0, double alpha = 0.7}) {
      const n = 12;
      final top = <Offset>[], bottom = <Offset>[];
      for (var i = 0; i <= n; i++) {
        final f = i / n;
        final wave = sin(t * 4 - f * 4.5 + phase) * amp * f + sway * f * 5;
        final p = base + Offset(cos(ang) * len * f - sin(ang) * wave, sin(ang) * len * f + cos(ang) * wave);
        final ww = w * (1 - f) * (1 - f) + 0.3;
        final nrm = Offset(-sin(ang), cos(ang)) * ww;
        top.add(p - nrm);
        bottom.add(p + nrm);
      }
      final path = Path()..moveTo(top.first.dx, top.first.dy);
      for (final p in top.skip(1)) {
        path.lineTo(p.dx, p.dy);
      }
      for (final p in bottom.reversed) {
        path.lineTo(p.dx, p.dy);
      }
      path.close();
      c.drawPath(
        path,
        Paint()
          ..blendMode = BlendMode.plus
          ..shader = ui.Gradient.linear(base, base + Offset(cos(ang), sin(ang)) * len,
              [core.withValues(alpha: alpha), g.withValues(alpha: alpha * 0.5), g.withValues(alpha: 0)], const [0, 0.5, 1]),
      );
    }

    switch (s.tail) {
      case _Tail.flow:
        streamer(dir, 30, 4.5);
        streamer(dir - 0.12, 26, 1.2, amp: 6, phase: 1.4, alpha: 0.5);
      case _Tail.fork:
        streamer(dir - 0.3, 34, 2.6, amp: 2);
        streamer(dir + 0.3, 34, 2.6, amp: 2, phase: 0.6);
      case _Tail.long:
        streamer(dir - 0.05, 40, 3.6, amp: 4);
        streamer(dir + 0.06, 34, 2, amp: 5, phase: 1);
      case _Tail.fan:
        for (var i = -2; i <= 2; i++) {
          streamer(dir + i * 0.17, 18, 3, amp: 1, phase: i * 0.4, alpha: 0.75);
        }
      case _Tail.sickle:
        for (var i = 0; i < 3; i++) {
          streamer(dir + 0.75 + i * 0.25, 18 + i * 3, 3, amp: 2, phase: i.toDouble());
        }
      case _Tail.stub:
        streamer(dir, 12, 3.5, amp: 1);
      case _Tail.plume:
        for (var i = 0; i < 3; i++) {
          Glow.draw(c, base.dx - 4 - i * 2, base.dy - 3 + i * 3.0 + sway * 2, 10, Colors.white.withValues(alpha: 0.7));
        }
      case _Tail.wedge:
        for (var i = -1; i <= 1; i++) {
          streamer(dir + i * 0.12, 22, 3.2, amp: 1.5, phase: i.toDouble());
        }
    }
  }

  // ---------------- Kopf ----------------

  static void _beak(Canvas c, _Spec s) {
    final base = s.head + Offset(s.headR * 0.78, s.headR * 0.1);
    final path = Path()
      ..moveTo(base.dx - 1, base.dy - s.beakH)
      ..quadraticBezierTo(base.dx + s.beakLen * 0.6, base.dy - s.beakH * 0.75, base.dx + s.beakLen, base.dy + s.beakDroop)
      ..quadraticBezierTo(base.dx + s.beakLen * 0.4, base.dy + s.beakH * 0.8, base.dx - 1, base.dy + s.beakH * 0.6)
      ..close();
    c.drawPath(path, Paint()..color = s.beakColor);
    Glow.draw(c, base.dx + s.beakLen * 0.5, base.dy, 4 + s.beakLen * 0.4, s.beakColor.withValues(alpha: 0.45));
  }

  static void _eyes(Canvas c, CharacterDef ch, _Spec s, BirdPose pose) {
    final look = Offset(pose.look.dx.clamp(-1.0, 1.0), pose.look.dy.clamp(-1.0, 1.0));
    final open = 1 - pose.blink;

    void almond(Offset at, double r, Color col, {bool glow = false}) {
      if (glow) Glow.draw(c, at.dx, at.dy, r * 4.5, col.withValues(alpha: 0.6));
      c.save();
      c.translate(at.dx, at.dy);
      c.scale(1, max(0.12, open));
      final eye = Path()
        ..moveTo(-r * 1.15, r * 0.1)
        ..quadraticBezierTo(0, -r * 1.25, r * 1.3, -r * 0.15)
        ..quadraticBezierTo(0, r, -r * 1.15, r * 0.1)
        ..close();
      c.drawPath(eye, Paint()..color = col);
      c.restore();
      if (open > 0.5) c.drawCircle(at + Offset(r * 0.38, -r * 0.35), r * 0.32, Paint()..color = Colors.white);
    }

    final e = s.head + Offset(s.headR * 0.3, -s.headR * 0.22) + look * 0.6;
    switch (ch.look) {
      case BirdLook.owl:
        for (final dx in [-4.3, 4.3]) {
          final at = s.head + Offset(dx + 1, -0.5);
          Glow.draw(c, at.dx, at.dy, 9, const Color(0x55FFE6B0));
          almond(at + look * 0.6, s.eye, const Color(0xFFFFB347), glow: true);
          c.drawCircle(at + look * 0.9, s.eye * 0.38, Paint()..color = const Color(0xFF1A1020));
        }
      case BirdLook.raven:
        almond(e, s.eye, const Color(0xFFD9A8FF), glow: true);
      case BirdLook.eagle:
        almond(e, s.eye, const Color(0xFFFFB347), glow: true);
        c.drawCircle(e + look * 0.3, s.eye * 0.4, Paint()..color = const Color(0xFF1A1020));
        // Strenge Braue als Lichtkante
        _stroke
          ..strokeWidth = 1.4
          ..color = const Color(0xCCFFF0D0);
        c.drawLine(e + Offset(-s.eye * 1.6, -s.eye * 1.1), e + Offset(s.eye * 1.6, -s.eye * 1.6), _stroke);
      default:
        almond(e, s.eye, const Color(0xFF14102A));
    }
  }

  /// Leuchtakzente, die im Körper liegen (werden auf die Silhouette beschnitten).
  static void _accentsInside(Canvas c, CharacterDef ch, _Spec s, double t) {
    final add = Paint()..blendMode = BlendMode.plus;
    void spot(Offset at, double w, double h, Color col, double a) {
      c.drawOval(
        Rect.fromCenter(center: at, width: w, height: h),
        add
          ..shader = ui.Gradient.radial(at, max(w, h) / 2, [col.withValues(alpha: a), col.withValues(alpha: 0)]),
      );
    }

    final throat = s.head + Offset(s.headR * 0.4, s.headR * 0.9);
    switch (ch.look) {
      case BirdLook.robin:
        spot(s.head + const Offset(1, 10), 20, 16, const Color(0xFFFF6A3D), 0.85);
      case BirdLook.swallow:
        spot(throat, 9, 7, const Color(0xFFE0603A), 0.8);
      case BirdLook.hummingbird:
        spot(throat, 10, 8, Color.lerp(const Color(0xFFFF5AD2), const Color(0xFF6AFFC0), 0.5 + 0.5 * sin(t * 3))!, 0.9);
      case BirdLook.penguin:
        spot(const Offset(4, 4), 18, 30, Colors.white, 0.55);
        c.drawCircle(s.head, s.headR, Paint()..color = const Color(0xAA141C30));
      case BirdLook.magpie:
        spot(const Offset(-6, -1), 13, 9, Colors.white, 0.8);
      case BirdLook.eagle:
        c.drawCircle(s.head, s.headR + 0.5, Paint()..color = const Color(0xCCF6F2EA));
        spot(s.head + Offset(-s.headR * 0.9, s.headR * 0.8), 10, 8, const Color(0xFFFFD27A), 0.6);
      case BirdLook.woodpecker:
        spot(s.head + Offset(-1, s.headR * 0.45), s.headR * 1.8, 3.5, Colors.white, 0.6);
      default:
    }
  }

  /// Leuchtakzente außerhalb der Silhouette (Haube, Kamm, Federohren, Brille, Kehllappen).
  static void _accentsOutside(Canvas c, CharacterDef ch, _Spec s, double t) {
    final h = s.head, r = s.headR;
    switch (ch.look) {
      case BirdLook.sparrow:
        _stroke
          ..strokeWidth = 2.6
          ..color = const Color(0x8899E8FF);
        c.drawPath(
            Path()
              ..moveTo(h.dx - r * 0.9, h.dy - r * 0.45)
              ..quadraticBezierTo(h.dx, h.dy - r * 0.75, h.dx + r * 0.85, h.dy - r * 0.4),
            _stroke);
      case BirdLook.woodpecker:
        final crest = Path()
          ..moveTo(h.dx - r * 0.9, h.dy - r * 0.3)
          ..quadraticBezierTo(h.dx - r * 0.7, h.dy - r * 1.7, h.dx + r * 0.4, h.dy - r * 0.9)
          ..close();
        c.drawPath(crest, Paint()..color = const Color(0xFFFF4A4A));
        Glow.draw(c, h.dx - r * 0.3, h.dy - r, 14, const Color(0x99FF4A4A));
      case BirdLook.owl:
        for (final dx in [-6.0, 5.0]) {
          final tip = h + Offset(dx * 1.3, -r * 1.55);
          c.drawPath(
              Path()
                ..moveTo(h.dx + dx - 2.5, h.dy - r * 0.7)
                ..lineTo(tip.dx, tip.dy)
                ..lineTo(h.dx + dx + 2.5, h.dy - r * 0.7)
                ..close(),
              Paint()..color = Color.lerp(ch.body, ch.glow, 0.3)!);
          Glow.draw(c, tip.dx, tip.dy, 5, ch.glow.withValues(alpha: 0.6));
        }
      case BirdLook.hen:
        for (var i = 0; i < 3; i++) {
          final at = h + Offset(-3 + i * 3.6, -r * 0.9 - (i == 1 ? 1.5 : 0));
          c.drawCircle(at, 2.8, Paint()..color = const Color(0xFFFF4A4A));
        }
        Glow.draw(c, h.dx, h.dy - r, 12, const Color(0x88FF4A4A));
        c.drawOval(Rect.fromCenter(center: h + Offset(r * 0.75, r * 0.9), width: 4, height: 6.5),
            Paint()..color = const Color(0xFFFF4A4A));
      case BirdLook.raven:
        _stroke
          ..strokeWidth = 1
          ..color = ch.glow.withValues(alpha: 0.5);
        for (var i = 0; i < 4; i++) {
          final x = h.dx + 1 + i * 2.2, y = h.dy + r * 0.75;
          c.drawLine(Offset(x, y), Offset(x - 0.6, y + 4 + (i.isEven ? 1 : 0)), _stroke);
        }
      default:
    }
  }

  // ---------------- Beine ----------------

  /// Beine als Lichtfäden: am Boden laufend, in der Luft eingezogen bzw. die Waffe haltend.
  /// Der Strauß hat immer sichtbare lange Beine.
  static void _legs(Canvas c, CharacterDef ch, _Spec s, BirdPose pose, Color g) {
    final ostrich = ch.look == BirdLook.ostrich;
    final walk = pose.walk;
    if (!ostrich && walk == null && !pose.holding) return;
    final hipY = ostrich ? 2.0 : s.body.bottom - 3;
    final footY = ostrich ? 15.0 : s.body.bottom + 4;
    for (final (i, hx) in [(0, -2.0), (1, 3.0)]) {
      final ph = (walk ?? 0) + i * pi;
      final swing = walk != null ? sin(ph) * (ostrich ? 7 : 4) : (pose.holding ? 1.5 : -2.0 + i * 3);
      final lift = walk != null ? max(0.0, cos(ph)) * (ostrich ? 4 : 2.5) : 0.0;
      final foot = Offset(hx + swing, footY - lift);
      final knee = Offset(hx - 3 + swing * 0.3, (hipY + footY) / 2 - lift * 0.5);
      _stroke
        ..strokeWidth = ostrich ? 2.6 : 1.6
        ..color = Color.lerp(g, Colors.white, 0.4)!.withValues(alpha: i == 0 ? 0.6 : 0.9);
      final leg = Path()
        ..moveTo(hx, hipY)
        ..quadraticBezierTo(knee.dx, knee.dy, foot.dx, foot.dy);
      c.drawPath(leg, _stroke);
      c.drawLine(foot, foot + const Offset(3.5, 0.5), _stroke);
    }
  }

  // ---------------- Funken ----------------

  static void _motes(Canvas c, CharacterDef ch, _Spec s, double t) {
    final col = ch.look == BirdLook.robin ? const Color(0xFFFFA060) : Color.lerp(ch.glow, Colors.white, 0.5)!;
    for (var i = 0; i < 6; i++) {
      final ph = (t * 0.45 + i / 6) % 1;
      final x = s.body.left + 4 + (i * 37 % 22) + sin(t * 2 + i) * 2;
      final y = s.body.bottom - ph * 28;
      final a = sin(ph * pi);
      Glow.draw(c, x, y, 3 + 2 * a, col.withValues(alpha: 0.7 * a));
    }
  }
}
