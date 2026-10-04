part of 'glyph_art.dart';

/// Items, Aktionen und Werte als kleine leuchtende Objekte in ihren eigenen Farben:
/// gefüllt mit Lichtverlauf, Lichtkante und Glanzpunkt. Aktionen liegen auf einem
/// runden Medaillon mit Ring in ihrer Aktionsfarbe, Evolutionen auf einem goldenen
/// Doppelring. Feld −12…12.
class _Obj {
  _Obj._();

  static final _fill = Paint();
  static final _rim = Paint()
    ..style = PaintingStyle.stroke
    ..strokeCap = StrokeCap.round
    ..strokeJoin = StrokeJoin.round;
  static final _line = Paint()
    ..style = PaintingStyle.stroke
    ..strokeCap = StrokeCap.round
    ..strokeJoin = StrokeJoin.round;
  static final _add = Paint()
    ..style = PaintingStyle.stroke
    ..strokeCap = StrokeCap.round
    ..strokeJoin = StrokeJoin.round
    ..blendMode = BlendMode.plus;

  static const _gold = Color(0xFFFFC94A);
  static const _bolt = Color(0xFFFFE04A);

  // ---------------- Pinsel ----------------

  /// Gefüllte Form: hell oben links, dunkel unten rechts, helle Lichtkante.
  static void part(Canvas c, Path p, Color col, {double rim = 0.8, double light = 0.45, double dark = 0.5}) {
    final b = p.getBounds();
    _fill.shader = LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [Color.lerp(col, Colors.white, light)!, col, Color.lerp(col, Colors.black, dark)!],
      stops: const [0, 0.5, 1],
    ).createShader(b);
    c.drawPath(p, _fill);
    _fill.shader = null;
    if (rim > 0) {
      _rim
        ..strokeWidth = rim
        ..color = Color.lerp(col, Colors.white, 0.65)!.withValues(alpha: col.a * 0.85);
      c.drawPath(p, _rim);
    }
  }

  /// Dicker Strich mit Verlauf (Bügel, Henkel, Stiele).
  static void band(Canvas c, Path p, Color col, double w) {
    final b = p.getBounds().inflate(w);
    _line
      ..strokeWidth = w
      ..shader = LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [Color.lerp(col, Colors.white, 0.45)!, Color.lerp(col, Colors.black, 0.3)!],
      ).createShader(b);
    c.drawPath(p, _line);
    _line.shader = null;
  }

  static void line(Canvas c, Path p, Color col, double w) {
    _line
      ..strokeWidth = w
      ..color = col;
    c.drawPath(p, _line);
  }

  /// Leuchtende Linie (Dampf, Funken, Schallwellen).
  static void beam(Canvas c, Path p, Color col, double w) {
    _add
      ..strokeWidth = w * 2.4
      ..color = col.withValues(alpha: 0.42);
    c.drawPath(p, _add);
    _line
      ..strokeWidth = w
      ..color = Color.lerp(col, Colors.white, 0.5)!;
    c.drawPath(p, _line);
  }

  static void shine(Canvas c, double x, double y, double rx, double ry, {double a = 0.75}) {
    c.drawOval(Rect.fromCenter(center: Offset(x, y), width: rx * 2, height: ry * 2),
        _fill..color = Colors.white.withValues(alpha: a));
  }

  static void dot(Canvas c, double x, double y, double r, Color col) => c.drawCircle(Offset(x, y), r, _fill..color = col);

  static void glow(Canvas c, double x, double y, double r, Color col, [double a = 0.33]) =>
      Glow.draw(c, x, y, r, col.withValues(alpha: a));

  static Path circle(double x, double y, double r) => Path()..addOval(Rect.fromCircle(center: Offset(x, y), radius: r));
  static Path oval(double x, double y, double rx, double ry) =>
      Path()..addOval(Rect.fromCenter(center: Offset(x, y), width: rx * 2, height: ry * 2));
  static Path rrect(double l, double t, double r, double b, double rad) =>
      Path()..addRRect(RRect.fromLTRBR(l, t, r, b, Radius.circular(rad)));
  static Path poly(List<(double, double)> pts) => GlyphArt._poly(pts, close: true);
  static Path seg(List<(double, double)> pts) => GlyphArt._poly(pts);

  /// Zeichnet [f] verschoben, gedreht und skaliert.
  static void at(Canvas c, double x, double y, double s, void Function() f, {double rot = 0}) {
    c.save();
    c.translate(x, y);
    if (rot != 0) c.rotate(rot);
    c.scale(s);
    f();
    c.restore();
  }

  /// Medaillon einer Aktion.
  static void medal(Canvas c, Color col, {bool evolved = false}) {
    glow(c, 0, 0, 17, col, evolved ? 0.4 : 0.3);
    _fill.shader = RadialGradient(
      center: const Alignment(-0.3, -0.4),
      colors: [Color.lerp(col, const Color(0xFF1A1E36), 0.72)!, const Color(0xFF0E1122)],
    ).createShader(const Rect.fromLTRB(-11.5, -11.5, 11.5, 11.5));
    c.drawCircle(Offset.zero, 11.5, _fill);
    _fill.shader = null;
    _add
      ..strokeWidth = 2.6
      ..color = col.withValues(alpha: 0.4);
    c.drawCircle(Offset.zero, 11.2, _add);
    _rim
      ..strokeWidth = 1
      ..color = Color.lerp(col, Colors.white, 0.4)!;
    c.drawCircle(Offset.zero, 11.2, _rim);
    if (evolved) {
      _rim
        ..strokeWidth = 0.6
        ..color = col.withValues(alpha: 0.7);
      c.drawCircle(Offset.zero, 9.6, _rim);
    }
  }

  // ---------------- Motive (Feld etwa −9…9) ----------------

  static void bolt(Canvas c, [Color col = _bolt]) {
    glow(c, 0, 0, 9, col, 0.3);
    part(c, poly([(0, -9), (-5, 1), (-0.5, 1), (-3, 9), (5.5, -2.5), (1, -2.5), (5, -9)]), col, rim: 0.6, dark: 0.25);
  }

  static void bubble(Canvas c, double t, {double r = 8, double a = 0.65}) {
    final rect = Rect.fromCircle(center: Offset.zero, radius: r);
    final al = (a * 255).round();
    _fill.shader = RadialGradient(
      center: const Alignment(-0.3, -0.35),
      colors: [Color.fromARGB((a * 90).round(), 230, 245, 255), Color.fromARGB((a * 40).round(), 160, 200, 255)],
    ).createShader(rect);
    c.drawOval(rect, _fill);
    _fill.shader = SweepGradient(
      transform: GradientRotation(t * 0.8),
      colors: [
        Color.fromARGB(al, 255, 154, 205),
        Color.fromARGB(al, 127, 224, 255),
        Color.fromARGB(al, 176, 255, 154),
        Color.fromARGB(al, 255, 224, 122),
        Color.fromARGB(al, 255, 154, 205),
      ],
    ).createShader(rect);
    c.drawOval(rect, _fill);
    _fill.shader = null;
    _rim
      ..strokeWidth = 1.1
      ..color = const Color(0xDDEAF6FF);
    c.drawOval(rect, _rim);
    shine(c, -r * 0.44, -r * 0.5, r * 0.28, r * 0.17, a: 0.85);
    dot(c, r * 0.44, r * 0.5, r * 0.11, const Color(0x99FFFFFF));
  }

  static void cloud(Canvas c, [Color col = const Color(0xFF8A94B8)]) {
    final p = Path.combine(
        PathOperation.union,
        Path.combine(PathOperation.union, circle(-4, 1, 4), circle(0.5, -2, 5)),
        Path.combine(PathOperation.union, circle(5, 1, 3.6), rrect(-4, 1, 5, 5, 0)));
    part(c, p, col, rim: 0.5, light: 0.5);
    shine(c, -1.5, -4.5, 2, 1, a: 0.4);
  }

  static Path _eggPath() => Path()
    ..moveTo(0, -8.5)
    ..cubicTo(6, -8.5, 7, 3, 6, 5)
    ..cubicTo(4.5, 9, -4.5, 9, -6, 5)
    ..cubicTo(-7, 3, -6, -8.5, 0, -8.5)
    ..close();

  static void egg(Canvas c, {Color col = const Color(0xFFF6EAD0), bool spots = true}) {
    part(c, _eggPath(), col, dark: 0.35);
    if (spots) {
      for (final (x, y) in [(2.0, -3.0), (-2.5, 1.0), (3.0, 3.5), (-1.0, -5.5), (0.5, 5.5)]) {
        dot(c, x, y, 0.7, const Color(0xFFB08A60));
      }
    }
    shine(c, -2.5, -4, 1.4, 2.4, a: 0.7);
  }

  static void horn(Canvas c, [Color col = const Color(0xFFF0B43A)]) {
    part(c, poly([(-9, -1.4), (-1, -3), (3.5, -7), (3.5, 7), (-1, 3), (-9, 1.4)]), col);
    part(c, oval(3.5, 0, 1.6, 7), Color.lerp(col, Colors.black, 0.35)!, rim: 0.6);
    part(c, rrect(-10.5, -2.2, -8, 2.2, 0.8), const Color(0xFF3A2A1A), rim: 0);
    shine(c, 0, -2.5, 1.2, 1.6, a: 0.55);
  }

  static void soundArcs(Canvas c, double x, Color col, {int n = 2}) {
    for (var k = 0; k < n; k++) {
      beam(c, Path()..addArc(Rect.fromCircle(center: Offset(x, 0), radius: 3 + k * 3), -0.7, 1.4), col, 0.8);
    }
  }

  static void clock(Canvas c, double t) {
    part(c, rrect(-1.6, -10, 1.6, -7, 0.8), const Color(0xFFE0B050), rim: 0);
    part(c, circle(0, 1, 8), const Color(0xFFE6B44A));
    part(c, circle(0, 1, 6.2), const Color(0xFFF8F2E2), rim: 0, dark: 0.15);
    for (var k = 0; k < 12; k++) {
      final a = k * pi / 6;
      dot(c, sin(a) * 5, 1 - cos(a) * 5, k % 3 == 0 ? 0.6 : 0.35, const Color(0xFF6A5A40));
    }
    final a = t * 2;
    line(c, Path()..moveTo(0, 1)..lineTo(sin(a) * 4.2, 1 - cos(a) * 4.2), const Color(0xFF3A2E22), 0.8);
    line(c, Path()..moveTo(0, 1)..lineTo(2.5, 2.5), const Color(0xFF3A2E22), 1.1);
    dot(c, 0, 1, 0.8, const Color(0xFFD84A3A));
    shine(c, -3, -2.5, 1.6, 1, a: 0.5);
  }

  static void swoosh(Canvas c, [Color col = const Color(0xFF7FE0FF)]) {
    for (final (y, l) in [(-4.0, 7.0), (0.0, 9.0), (4.0, 6.0)]) {
      beam(c, Path()..moveTo(-8, y)..lineTo(-8 + l, y), col, 1);
    }
    part(c, Path()..moveTo(-1, -6)..quadraticBezierTo(5, -6, 9, 0)..quadraticBezierTo(5, 6, -1, 6)..quadraticBezierTo(3, 0, -1, -6)..close(),
        const Color(0xFFE6F8FF), dark: 0.3);
  }

  static void magnetU(Canvas c, [Color col = const Color(0xFFF04548)]) {
    band(c, Path()..moveTo(-6, -7)..lineTo(-6, 1)..arcToPoint(const Offset(6, 1), radius: const Radius.circular(6), clockwise: false)..lineTo(6, -7),
        col, 5);
    part(c, rrect(-8.5, -10.5, -3.5, -6.5, 0.8), const Color(0xFFDDE3EE), rim: 0.5);
    part(c, rrect(3.5, -10.5, 8.5, -6.5, 0.8), const Color(0xFFDDE3EE), rim: 0.5);
    shine(c, -7.2, -1, 0.8, 3, a: 0.55);
  }

  static void drum(Canvas c) {
    for (final s in [-1.0, 1.0]) {
      band(c, Path()..moveTo(s * 9, -10)..lineTo(s * 2.5, -4), const Color(0xFFC89060), 1.5);
      dot(c, s * 9, -10, 1.3, const Color(0xFFF2E2C0));
    }
    part(c, Path()..moveTo(-7.5, -2)..lineTo(-7.5, 5)..quadraticBezierTo(0, 9.5, 7.5, 5)..lineTo(7.5, -2)..close(), const Color(0xFFD8443A));
    line(c, seg([(-7, 0), (-4, 5), (-1, 0.5), (2, 6), (5, 0.5), (7, 4)]), const Color(0xFFFFD86A), 0.7);
    part(c, oval(0, -2, 7.5, 2.4), const Color(0xFFF4E6C8), rim: 0.6, dark: 0.15);
  }

  static void glove(Canvas c, Color col) {
    final p = Path.combine(
        PathOperation.union,
        Path.combine(PathOperation.union, rrect(-5, -2, 5, 8, 3), oval(-6.5, 1.5, 2, 3.6)),
        Path.combine(PathOperation.union,
            Path.combine(PathOperation.union, rrect(-4.6, -9, -1.8, 0, 1.4), rrect(-1.4, -10, 1.4, 0, 1.4)),
            rrect(1.8, -9, 4.6, 0, 1.4)));
    part(c, p, col);
    part(c, rrect(-5.5, 6.5, 5.5, 9.5, 1.2), Color.lerp(col, Colors.white, 0.35)!, rim: 0);
  }

  static void foot(Canvas c) {
    band(c, Path()..moveTo(-6, -9)..lineTo(-4, 1), const Color(0xFFE0A07A), 2.6);
    part(c, Path()..moveTo(-5.5, -1)..lineTo(3, 0)..quadraticBezierTo(4.5, 1, 3, 2.4)..lineTo(-4, 4)..quadraticBezierTo(-7, 3, -5.5, -1)..close(),
        const Color(0xFFE8A884), rim: 0.6);
    line(c, Path()..moveTo(-3, 1.2)..lineTo(2.5, 1.2), const Color(0x88804030), 0.7);
  }

  static void burst(Canvas c, double x, double y, double r, Color col) {
    final p = Path();
    for (var i = 0; i < 16; i++) {
      final an = i * pi / 8, rr = i.isEven ? r : r * 0.45;
      final q = Offset(x + cos(an) * rr, y + sin(an) * rr);
      i == 0 ? p.moveTo(q.dx, q.dy) : p.lineTo(q.dx, q.dy);
    }
    part(c, p..close(), col, rim: 0, dark: 0.1);
  }

  static void sun(Canvas c, double t) {
    glow(c, 0, 0, 13, const Color(0xFFFFB03A), 0.45);
    final rays = Path();
    for (var k = 0; k < 10; k++) {
      final a = k * pi / 5 + t * 0.3;
      rays.addPolygon([Offset(cos(a - 0.17) * 5.8, sin(a - 0.17) * 5.8), Offset(cos(a) * 9.5, sin(a) * 9.5), Offset(cos(a + 0.17) * 5.8, sin(a + 0.17) * 5.8)], true);
    }
    part(c, rays, const Color(0xFFFFB43A), rim: 0, dark: 0.2);
    part(c, circle(0, 0, 6), const Color(0xFFFFD84A), rim: 0.6, light: 0.6, dark: 0.25);
    shine(c, -2, -2.4, 1.6, 1.1, a: 0.6);
  }

  static void eagleHead(Canvas c) {
    part(c, Path()..moveTo(-8, 9)..quadraticBezierTo(-9, 0, -4, -3)..lineTo(2, 2)..quadraticBezierTo(0, 7, 2, 9)..close(), const Color(0xFF8A5A30));
    part(c, Path()..moveTo(-6, 4)..cubicTo(-9, -4, -5, -9, 0, -9)..cubicTo(4, -9, 6, -6, 6, -3.5)..lineTo(1, 1)..quadraticBezierTo(-2, 3, -6, 4)..close(),
        const Color(0xFFF6F2EA), dark: 0.3);
    part(c, Path()..moveTo(4, -6)..quadraticBezierTo(10, -6, 10, -1)..quadraticBezierTo(9.5, 1.5, 8, 2)..quadraticBezierTo(8.5, -1, 5.5, -1.5)..lineTo(3.5, -2.5)..close(),
        const Color(0xFFFFC23A), rim: 0.5);
    dot(c, 1.5, -5.2, 1.1, const Color(0xFF2A1A0E));
    dot(c, 1.8, -5.5, 0.35, Colors.white);
    line(c, Path()..moveTo(-1, -6.8)..lineTo(3.5, -6.4), const Color(0xAA6A5030), 0.8);
  }

  static void penguin(Canvas c) {
    part(c, oval(-1, 0, 8, 4.2), const Color(0xFF2E3550), light: 0.35);
    part(c, oval(-1, 1.8, 6.5, 2.2), const Color(0xFFF2F4F8), rim: 0, dark: 0.15);
    part(c, circle(6.5, -1.5, 3.4), const Color(0xFF2E3550), light: 0.35);
    part(c, poly([(9.4, -2.2), (12, -1), (9.4, 0)]), const Color(0xFFFF9A3A), rim: 0);
    dot(c, 7.4, -2.4, 0.8, Colors.white);
  }

  static void rocket(Canvas c) {
    part(c, poly([(-1.8, 5), (0, 10), (1.8, 5)]), const Color(0xFFFFA03A), rim: 0, light: 0.6, dark: 0.1);
    for (final s in [-1.0, 1.0]) {
      part(c, poly([(s * 3, 1), (s * 6, 6.5), (s * 3, 5)]), const Color(0xFFE84A4A), rim: 0.5);
    }
    part(c, Path()..moveTo(0, -9)..cubicTo(4.2, -6, 4, 3, 3, 5.5)..lineTo(-3, 5.5)..cubicTo(-4, 3, -4.2, -6, 0, -9)..close(), const Color(0xFFEFF2F8), dark: 0.35);
    part(c, circle(0, -2, 1.9), const Color(0xFF6FD0FF), rim: 0.5);
  }

  static void spark(Canvas c, double x, double y, double r, Color col) {
    part(c, GlyphArt._star(r, r * 0.3, 4).shift(Offset(x, y)), col, rim: 0, light: 0.7, dark: 0.1);
  }

  static void coin(Canvas c, double x, double y, double r) {
    part(c, circle(x, y, r), const Color(0xFFFFC23A), rim: 0.6);
    _rim
      ..strokeWidth = 0.5
      ..color = const Color(0xAA8A5A10);
    c.drawCircle(Offset(x, y), r * 0.62, _rim);
  }

  static void crystal(Canvas c, double x, double y, double s, Color col) {
    part(c, poly([(x, y - 7 * s), (x + 4.5 * s, y - 1 * s), (x, y + 7 * s), (x - 4.5 * s, y - 1 * s)]), col, rim: 0.6, light: 0.6);
    line(c, seg([(x - 4.5 * s, y - s), (x, y + s), (x + 4.5 * s, y - s)]), Colors.white.withValues(alpha: 0.4), 0.5);
  }

  static Path _shield() => Path()
    ..moveTo(0, -10)
    ..quadraticBezierTo(5, -7, 9, -7.5)
    ..quadraticBezierTo(9, 5, 0, 11)
    ..quadraticBezierTo(-9, 5, -9, -7.5)
    ..quadraticBezierTo(-5, -7, 0, -10)
    ..close();

  static Path _feather() => Path()
    ..moveTo(-8, 9)
    ..quadraticBezierTo(-7, -3, 7, -10)
    ..quadraticBezierTo(4, 5, -8, 9)
    ..close();

  static void feather(Canvas c, Color col) {
    part(c, _feather(), col);
    line(c, Path()..moveTo(-10, 11)..quadraticBezierTo(-2, 1, 6, -9), Color.lerp(col, Colors.white, 0.7)!, 0.9);
    for (final k in [0.3, 0.5, 0.7]) {
      final x = -10 + 16 * k, y = 11 - 20 * k;
      line(c, Path()..moveTo(x, y)..lineTo(x + 2.5, y + 1.5), Color.lerp(col, Colors.black, 0.3)!.withValues(alpha: 0.6), 0.5);
    }
  }

  // ---------------- Items ----------------

  static bool item(Canvas c, String id, double t) {
    switch (id) {
      case 'helm':
        const steel = Color(0xFF9AA6BC);
        glow(c, 0, -2, 14, const Color(0xFF9AB4E0), 0.27);
        part(c, Path()..moveTo(-9, 3)..cubicTo(-9, -11, 9, -11, 9, 3)..close(), steel);
        part(c, rrect(-11.5, 2, 11.5, 6, 2), const Color(0xFF7E8AA2));
        for (final x in [-6.0, 0.0, 6.0]) {
          dot(c, x, 4, 0.9, const Color(0xFFE6ECF8));
        }
        line(c, Path()..moveTo(0, -8)..lineTo(0, 2), const Color(0x55FFFFFF), 1);
        shine(c, -4.5, -4, 2, 3.2, a: 0.6);
      case 'apfel':
        glow(c, 0, 1, 14, const Color(0xFFFF5A4A));
        final body = Path()
          ..moveTo(0, -5)
          ..cubicTo(-5, -9, -11, -5, -10, 1)
          ..cubicTo(-9, 8, -4, 11, 0, 9)
          ..cubicTo(4, 11, 9, 8, 10, 1)
          ..cubicTo(11, -5, 5, -9, 0, -5)
          ..close();
        part(c, body, const Color(0xFFE23B32));
        band(c, Path()..moveTo(0, -5)..quadraticBezierTo(0.5, -8, 2, -10), const Color(0xFF7A4A2A), 1.6);
        part(c, Path()..moveTo(1.5, -8)..quadraticBezierTo(5, -12, 9, -9.5)..quadraticBezierTo(5, -6, 1.5, -8)..close(),
            const Color(0xFF55D06A), rim: 0.6);
        shine(c, -5, -1.5, 2, 3.2);
      case 'pflaster':
        glow(c, 0, 0, 13, const Color(0xFFF0C89A), 0.25);
        at(c, 0, 0, 1, rot: -0.6, () {
          part(c, rrect(-11, -3.8, 11, 3.8, 3.8), const Color(0xFFF0C08A));
          part(c, rrect(-3.5, -3, 3.5, 3, 1), const Color(0xFFFFE8D4), rim: 0, dark: 0.1);
          for (final x in [-8.0, -6.0, 6.0, 8.0]) {
            for (final y in [-1.3, 1.3]) {
              dot(c, x, y, 0.45, const Color(0xFFB88A60));
            }
          }
        });
      case 'fernglas':
        glow(c, 0, 2, 13, const Color(0xFF6FD0FF), 0.25);
        for (final s in [-1.0, 1.0]) {
          part(c, rrect(s * 5 - 2.5, -10, s * 5 + 2.5, -6, 1), const Color(0xFF2E3850), rim: 0.5);
          part(c, rrect(s * 5 - 4, -7, s * 5 + 4, 6, 2.5), const Color(0xFF4A5A7E));
          part(c, circle(s * 5, 6.5, 3.3), const Color(0xFF6FD0FF), rim: 0.6, light: 0.6);
          shine(c, s * 5 - 1.2, 5.4, 1, 0.7, a: 0.8);
        }
        part(c, rrect(-1.6, -4, 1.6, 1, 1), const Color(0xFF3A4660), rim: 0);
      case 'feder':
        glow(c, 0, 0, 14, const Color(0xFFFFC23A), 0.35);
        feather(c, const Color(0xFFFFC23A));
        spark(c, 7, 5, 2.4, const Color(0xFFFFF4C0));
      case 'magnet':
        glow(c, 0, 0, 14, const Color(0xFFFF5050));
        magnetU(c);
        for (final s in [-1.0, 1.0]) {
          beam(c, Path()..moveTo(s * 9.5, -1)..lineTo(s * 11.5, -2.5), const Color(0xFF8FD8FF), 0.8);
        }
      case 'hantel':
        glow(c, 0, 0, 13, const Color(0xFF9AA6C0), 0.25);
        band(c, Path()..moveTo(-10, 0)..lineTo(10, 0), const Color(0xFFD0D8E4), 2);
        for (final s in [-1.0, 1.0]) {
          part(c, rrect(s * 6.5 - 1.6, -7, s * 6.5 + 1.6, 7, 1), const Color(0xFF3E4560));
          part(c, rrect(s * 9.5 - 1.2, -4.5, s * 9.5 + 1.2, 4.5, 0.8), const Color(0xFF545C7A));
        }
      case 'kaffee':
        glow(c, 0, 0, 14, const Color(0xFFFFD9B0), 0.27);
        for (final dx in [-3.0, 1.5]) {
          final w = sin(t * 3 + dx) * 1.2;
          beam(c, Path()..moveTo(dx, -5)..cubicTo(dx - 2 + w, -7, dx + 2 + w, -9, dx + w, -12), const Color(0xFFFFFFFF), 0.9);
        }
        band(c, Path()..addArc(Rect.fromCircle(center: const Offset(7, 1.5), radius: 3.6), -pi / 2, pi), const Color(0xFFE8E2D8), 2);
        part(c, Path()..moveTo(-8, -4)..lineTo(7, -4)..lineTo(5.5, 7)..quadraticBezierTo(-0.5, 10, -6.5, 7)..close(),
            const Color(0xFFF2ECE2), dark: 0.35);
        part(c, oval(-0.5, -4, 7.5, 1.8), const Color(0xFF6A3A1E), rim: 0.5);
        part(c, rrect(-6, 0, 3.5, 2.6, 1), const Color(0xFFD9483A), rim: 0);
        shine(c, -5.5, 1, 1, 2.5, a: 0.6);
      case 'zahn':
        glow(c, 0, 0, 13, const Color(0xFFFF4A5A), 0.25);
        part(c, Path()
          ..moveTo(-7, -6)
          ..cubicTo(-7, -11, -2, -10, 0, -8)
          ..cubicTo(2, -10, 7, -11, 7, -6)
          ..cubicTo(7, -2, 5, 0, 4.5, 4)
          ..quadraticBezierTo(4, 10, 2, 10)
          ..quadraticBezierTo(0.5, 10, 0, 4)
          ..quadraticBezierTo(-0.5, 10, -2, 10)
          ..quadraticBezierTo(-4, 10, -4.5, 4)
          ..cubicTo(-5, 0, -7, -2, -7, -6)
          ..close(), const Color(0xFFF4F0EA), dark: 0.3);
        part(c, Path()..moveTo(7, 4)..quadraticBezierTo(10, 8.5, 7, 10.5)..quadraticBezierTo(4, 8.5, 7, 4)..close(), const Color(0xFFE0283A), rim: 0.5);
        shine(c, -3.5, -6, 1.4, 1.8, a: 0.7);
      case 'klee':
        glow(c, 0, 0, 14, const Color(0xFF50E070));
        band(c, Path()..moveTo(0, 2)..quadraticBezierTo(2, 8, 6, 11), const Color(0xFF3E9A48), 1.6);
        for (var k = 0; k < 4; k++) {
          at(c, 0, 0, 1, rot: k * pi / 2 + pi / 4, () {
            part(c, Path()..moveTo(0, 0)..cubicTo(-5, -2, -5, -8, -1.5, -8.5)..quadraticBezierTo(0, -7, 0, -6)..quadraticBezierTo(0, -7, 1.5, -8.5)..cubicTo(5, -8, 5, -2, 0, 0)..close(),
                const Color(0xFF4CC85C), rim: 0.6);
          });
        }
        dot(c, 0, 0, 1.4, const Color(0xFFB8FFB0));
      case 'glas':
        glow(c, 0, -2, 14, const Color(0xFFA88AFF), 0.4);
        part(c, poly([(-6, 10), (6, 10), (4, 4.5), (-4, 4.5)]), const Color(0xFFD8A040));
        part(c, circle(0, -2.5, 7.5), const Color(0xCC8A70E8), light: 0.6, dark: 0.4);
        beam(c, Path()..moveTo(-3, -1)..cubicTo(-1, -6, 3, -4, 2, 0)..cubicTo(1, 2, -2, 1, -1, -2), const Color(0xFFE0D0FF), 0.7);
        shine(c, -3.5, -6, 2, 1.4, a: 0.8);
      case 'panzer':
        glow(c, 0, 0, 14, const Color(0xFF5ACD60), 0.3);
        part(c, oval(10, 2.5, 2.6, 2.2), const Color(0xFF9ACD80), rim: 0.5);
        part(c, Path()..moveTo(-10, 4)..cubicTo(-10, -10, 10, -10, 10, 4)..close(), const Color(0xFF4F9A50));
        final dk = const Color(0xFF2E6A34);
        line(c, poly([(-3, -4), (3, -4), (5, 0), (3, 4), (-3, 4), (-5, 0)]), dk, 0.8);
        for (final (a, b) in [((-3.0, -4.0), (-5.0, -7.0)), ((3.0, -4.0), (5.0, -7.0)), ((-5.0, 0.0), (-9.5, 0.0)), ((5.0, 0.0), (9.5, 0.0))]) {
          line(c, Path()..moveTo(a.$1, a.$2)..lineTo(b.$1, b.$2), dk, 0.8);
        }
        part(c, rrect(-11, 3, 11, 6, 2), const Color(0xFF8AC070), rim: 0.5);
        shine(c, -4, -5, 2, 1.2, a: 0.45);
      case 'dose':
        glow(c, 0, 0, 14, const Color(0xFF26E6B8), 0.3);
        part(c, rrect(-5.5, -9, 5.5, 10, 2), const Color(0xFF22B89C));
        part(c, oval(0, -9, 5.5, 1.6), const Color(0xFFD8E2EC), rim: 0.5);
        at(c, 0.5, 1, 0.55, () => bolt(c));
        shine(c, -3.5, 0, 0.9, 6, a: 0.45);
      case 'wurm':
        glow(c, 0, 0, 13, const Color(0xFFFF8FA8), 0.3);
        final body = Path()..moveTo(-9, 7)..cubicTo(-5, -4, 0, 10, 4, 0)..quadraticBezierTo(6, -5, 9, -6);
        band(c, body, const Color(0xFFFF8FA8), 5);
        for (final m in body.computeMetrics()) {
          for (var k = 1; k < 6; k++) {
            final tg = m.getTangentForOffset(m.length * k / 6)!;
            final n = Offset(-tg.vector.dy, tg.vector.dx) * 2.2;
            line(c, Path()..moveTo(tg.position.dx - n.dx, tg.position.dy - n.dy)..lineTo(tg.position.dx + n.dx, tg.position.dy + n.dy), const Color(0x88B0506A), 0.6);
          }
        }
        dot(c, 9.2, -7, 0.8, const Color(0xFF2A1426));
      case 'knochen':
        glow(c, 0, 0, 13, const Color(0xFFF2E8D0), 0.25);
        at(c, 0, 0, 1, rot: -0.7, () {
          var p = rrect(-7, -2, 7, 2, 1);
          for (final (x, y) in [(-7.5, -2.3), (-7.5, 2.3), (7.5, -2.3), (7.5, 2.3)]) {
            p = Path.combine(PathOperation.union, p, circle(x, y, 2.8));
          }
          part(c, p, const Color(0xFFF2E8D0), dark: 0.35);
        });
      case 'segelfeder':
        glow(c, 0, -2, 13, const Color(0xFF5AC8FF), 0.3);
        beam(c, Path()..moveTo(0, 8)..cubicTo(-3, 10, 1, 12, -4, 12), const Color(0xFFFFFFFF), 0.6);
        for (final (x, y) in [(-1.5, 10.0), (-3.5, 12.0)]) {
          part(c, poly([(x - 1.5, y - 1), (x + 1.5, y + 1), (x + 1.5, y - 1), (x - 1.5, y + 1)]), const Color(0xFFFFD84A), rim: 0);
        }
        part(c, poly([(0, -11), (0, 8), (-7, -2)]), const Color(0xFFFF6A5A), rim: 0.6);
        part(c, poly([(0, -11), (7, -2), (0, 8)]), const Color(0xFF5AC8FF), rim: 0.6);
        line(c, Path()..moveTo(-7, -2)..lineTo(7, -2)..moveTo(0, -11)..lineTo(0, 8), const Color(0x99FFFFFF), 0.6);
      case 'windfahne':
        glow(c, 2, -5, 12, const Color(0xFFFF5A4A), 0.3);
        band(c, Path()..moveTo(-7, -11)..lineTo(-7, 11), const Color(0xFFB8BCC8), 1.8);
        final w = sin(t * 4) * 1;
        part(c, Path()..moveTo(-7, -10)..quadraticBezierTo(0, -13 + w, 10, -8)..quadraticBezierTo(7, -5, 10, -1)..quadraticBezierTo(0, -4 - w, -7, -2)..close(),
            const Color(0xFFE8403A));
        dot(c, -7, -11.5, 1.4, const Color(0xFFFFD86A));
      case 'regenmantel':
        glow(c, 0, 0, 14, const Color(0xFFFFC83A), 0.3);
        part(c, Path()..moveTo(-4, -9)..quadraticBezierTo(0, -12.5, 4, -9)..lineTo(5, -6)..lineTo(9, 9)..lineTo(-9, 9)..lineTo(-5, -6)..close(),
            const Color(0xFFFFC23A));
        part(c, oval(0, -8, 2.6, 2.2), const Color(0xFF6A4A1A), rim: 0);
        line(c, Path()..moveTo(0, -5)..lineTo(0, 9), const Color(0x88A07010), 0.7);
        for (final y in [-2.0, 2.0, 6.0]) {
          dot(c, 1.3, y, 0.6, const Color(0xFF6A4A1A));
        }
        for (final (x, y) in [(-10.5, -5.0), (10.5, -2.0)]) {
          part(c, Path()..moveTo(x, y - 2.5)..quadraticBezierTo(x + 1.6, y + 0.5, x, y + 1.3)..quadraticBezierTo(x - 1.6, y + 0.5, x, y - 2.5)..close(),
              const Color(0xFF6FC8FF), rim: 0);
        }
      case 'gummiente':
        glow(c, 0, 1, 14, const Color(0xFFFFD040));
        part(c, Path()..moveTo(-10, 2)..quadraticBezierTo(-11, 10, 0, 10)..quadraticBezierTo(10, 10, 10, 3)..quadraticBezierTo(4, 5, 0, 1)..quadraticBezierTo(-6, 0, -10, 2)..close(),
            const Color(0xFFFFCC2E));
        part(c, circle(3, -4, 5), const Color(0xFFFFD43E));
        part(c, Path()..moveTo(7, -4)..quadraticBezierTo(12, -4.5, 12, -2)..quadraticBezierTo(10, -0.5, 7, -1.5)..close(), const Color(0xFFFF8A2A), rim: 0.5);
        dot(c, 4.5, -5.5, 1, const Color(0xFF1A1426));
        line(c, Path()..moveTo(-6, 4)..quadraticBezierTo(-2, 7, 2, 4), const Color(0x66B07A00), 1);
        shine(c, 1, -6.5, 1.2, 1.6);
      case 'socke':
        glow(c, 0, 0, 13, const Color(0xFFFF6A7A), 0.25);
        final sock = Path()
          ..moveTo(-4.5, -10)
          ..lineTo(3.5, -10)
          ..lineTo(3.5, 1)
          ..cubicTo(3.5, 3.5, 10, 3, 10, 7)
          ..quadraticBezierTo(10, 11, 5, 10.5)
          ..lineTo(-1, 9.5)
          ..quadraticBezierTo(-4.5, 8.5, -4.5, 4)
          ..close();
        part(c, sock, const Color(0xFFEDEFF5), dark: 0.3);
        c.save();
        c.clipPath(sock);
        for (final y in [-8.5, -5.0, -1.5]) {
          c.drawRect(Rect.fromLTRB(-6, y, 6, y + 1.6), _fill..color = const Color(0xFFE8404A));
        }
        c.drawCircle(const Offset(8, 9), 3, _fill..color = const Color(0xFFE8404A));
        c.restore();
        part(c, oval(5, 8.3, 1.7, 1.2), const Color(0xFF1A1426), rim: 0);
      case 'sparschwein':
        glow(c, 0, 1, 14, const Color(0xFFFF9DBA));
        for (final x in [-6.0, -2.0, 3.0, 7.0]) {
          part(c, rrect(x - 1.3, 5, x + 1.3, 10, 1), const Color(0xFFE07898), rim: 0);
        }
        part(c, oval(0, 1.5, 10, 7), const Color(0xFFFF9DBA));
        part(c, poly([(-4, -4), (-6, -9), (-1, -5.5)]), const Color(0xFFF58AAA), rim: 0.5);
        part(c, oval(9.5, 2, 2.2, 2.6), const Color(0xFFF07FA0), rim: 0.5);
        dot(c, 9.3, 1.3, 0.5, const Color(0xFF8A3050));
        dot(c, 9.3, 2.8, 0.5, const Color(0xFF8A3050));
        dot(c, 5.5, -1, 0.9, const Color(0xFF2A1426));
        part(c, rrect(-3, -5.6, 2, -4.6, 0.5), const Color(0xFF6A2A40), rim: 0);
        coin(c, -0.5, -8.5, 2.6);
        shine(c, -4, -1.5, 3, 1.6, a: 0.5);
      case 'glueckskeks':
        glow(c, 0, 0, 13, const Color(0xFFFFB04A), 0.3);
        part(c, poly([(0, 3), (11, 5.5), (10.5, 8), (-0.5, 5.5)]), const Color(0xFFFFFFFF), rim: 0, dark: 0.15);
        line(c, Path()..moveTo(3, 5)..lineTo(8.5, 6.4), const Color(0x88E04A3A), 0.6);
        part(c, Path()..moveTo(-10, 3)..cubicTo(-9, -9, 9, -9, 10, 3)..quadraticBezierTo(5, -1, 0, 4.5)..quadraticBezierTo(-5, -1, -10, 3)..close(),
            const Color(0xFFE8A84A));
        line(c, Path()..moveTo(0, -6)..quadraticBezierTo(-1, -1, 0, 4), const Color(0x669A6020), 0.8);
        shine(c, -5, -3, 2, 1.2, a: 0.5);
      case 'brennglas':
        glow(c, -2, -2, 13, const Color(0xFFFFB03A), 0.35);
        band(c, Path()..moveTo(3, 3)..lineTo(10, 10), const Color(0xFF9A6A3A), 3.2);
        part(c, circle(-2, -2, 6), const Color(0x889FE0FF), rim: 0, light: 0.6);
        band(c, Path()..addOval(Rect.fromCircle(center: const Offset(-2, -2), radius: 6.5)), const Color(0xFFE0B050), 1.8);
        glow(c, -3, -3, 5, const Color(0xFFFFE04A), 0.7);
        spark(c, -3, -3, 2.6, const Color(0xFFFFF0A0));
      case 'giesskanne':
        glow(c, 0, 0, 14, const Color(0xFF4CD87A), 0.3);
        band(c, Path()..moveTo(-7, -2)..quadraticBezierTo(-12, -2, -10, 5)..lineTo(-7, 6), const Color(0xFF3A9A56), 1.8);
        band(c, Path()..moveTo(3, 3)..lineTo(9, -5), const Color(0xFF3A9A56), 2.2);
        part(c, oval(9.5, -5.5, 1.6, 2.4), const Color(0xFF6ACF8A), rim: 0.5);
        part(c, rrect(-7, -4, 4, 9, 2), const Color(0xFF4CB86A));
        part(c, oval(-1.5, -4, 5.5, 1.4), const Color(0xFF7ADC96), rim: 0.5);
        for (final (x, y) in [(11.0, -1.5), (12.0, 2.0), (10.0, 4.0)]) {
          dot(c, x, y, 0.9, const Color(0xFF8FD8FF));
        }
        shine(c, -4.5, 1, 0.9, 3, a: 0.45);
      case 'kiesel':
        glow(c, 0, 0, 13, const Color(0xFF9AD0FF), 0.25);
        for (final (x, y, r, col) in [
          (-3.5, 6.5, 2.6, const Color(0xFF9AA0B0)),
          (2.0, 6.8, 2.4, const Color(0xFFC07A50)),
          (-0.5, 2.5, 2.3, const Color(0xFF6A9ACF)),
          (4.0, 2.0, 2.0, const Color(0xFFD8B860)),
          (-4.0, 1.5, 1.8, const Color(0xFF8ACF8A)),
        ]) {
          part(c, oval(x, y, r, r * 0.8), col, rim: 0);
        }
        part(c, rrect(-7, -7, 7, 10, 3), const Color(0x44A0D8FF), rim: 0.8, light: 0.6, dark: 0.1);
        part(c, rrect(-7.5, -10.5, 7.5, -7, 1), const Color(0xFFB08050));
        shine(c, -4.5, -1, 0.9, 4, a: 0.5);
      case 'spiegel':
        glow(c, 0, 0, 14, const Color(0xFFB8E0FF), 0.35);
        final shard = poly([(-6, -10), (6, -8), (8, 2), (1, 10), (-7, 5)]);
        part(c, shard, const Color(0xFFA8C8E8), light: 0.7, dark: 0.35);
        c.save();
        c.clipPath(shard);
        beam(c, Path()..moveTo(-8, 0)..lineTo(4, -12), Colors.white, 1.4);
        beam(c, Path()..moveTo(-4, 6)..lineTo(8, -6), Colors.white, 0.6);
        c.restore();
        line(c, seg([(-1, -9), (0, -2), (5, 1)]), const Color(0x99506A88), 0.5);
      case 'dornenkleid':
        glow(c, 0, 0, 14, const Color(0xFF4CD860), 0.3);
        band(c, Path()..moveTo(-3, 3)..lineTo(-7.5, 3)..lineTo(-7.5, -3), const Color(0xFF4CAF50), 3.6);
        band(c, Path()..moveTo(3, 0)..lineTo(7.5, 0)..lineTo(7.5, -6), const Color(0xFF4CAF50), 3.6);
        part(c, rrect(-3.2, -10, 3.2, 10, 3.2), const Color(0xFF4CAF50));
        line(c, Path()..moveTo(0, -8)..lineTo(0, 9), const Color(0x662E6A34), 0.7);
        for (final (x, y, dx) in [(-3.0, -6.0, -1.0), (3.0, -3.0, 1.0), (-3.0, 6.0, -1.0), (3.0, 5.0, 1.0), (-9.5, -1.0, -1.0), (9.5, -4.0, 1.0), (-1.0, -10.0, 0.0)]) {
          line(c, Path()..moveTo(x, y)..lineTo(x + dx * 2, y - (dx == 0 ? 2 : 1)), const Color(0xFFFFF0C0), 0.6);
        }
        spark(c, 0, -11, 2, const Color(0xFFFF7AB0));
      case 'sternenstaub':
        glow(c, 0, 0, 14, const Color(0xFFE0B0FF), 0.35);
        spark(c, -3, -2, 7, const Color(0xFFFFD86A));
        spark(c, 5.5, -6, 3.5, const Color(0xFFD8A0FF));
        spark(c, 5, 6, 4, const Color(0xFF8FE0FF));
        for (final (x, y) in [(-8.0, 7.0), (-9.0, -8.0), (1.0, 9.5), (9.5, 0.0)]) {
          dot(c, x, y, 0.8, const Color(0xFFFFF4E0));
        }
      case 'lichtschild':
        glow(c, 0, 0, 15, const Color(0xFFFFE08A), 0.45);
        part(c, _shield(), const Color(0xFFFFD86A), light: 0.6, dark: 0.35);
        at(c, 0, 0.5, 0.72, () => part(c, _shield(), const Color(0xFFFFF4D0), rim: 0, dark: 0.15));
        spark(c, 0, 0, 4.5, const Color(0xFFFFC23A));
      case 'kompass':
        glow(c, 0, 0, 14, const Color(0xFFFFD08A), 0.3);
        part(c, circle(0, 0, 10), const Color(0xFFD8A848));
        part(c, circle(0, 0, 7.8), const Color(0xFFF4EEDC), rim: 0.5, dark: 0.15);
        for (var k = 0; k < 4; k++) {
          final a = k * pi / 2;
          dot(c, sin(a) * 6.3, -cos(a) * 6.3, 0.6, const Color(0xFF6A5A40));
        }
        at(c, 0, 0, 1, rot: 0.6 + sin(t * 1.5) * 0.12, () {
          part(c, poly([(0, -6.5), (1.8, 0), (-1.8, 0)]), const Color(0xFFE84040), rim: 0);
          part(c, poly([(0, 6.5), (1.8, 0), (-1.8, 0)]), const Color(0xFFB8C0D0), rim: 0);
        });
        dot(c, 0, 0, 1, const Color(0xFF6A5A40));
      case 'goldgier':
        glow(c, 0, 0, 14, const Color(0xFFFFC23A), 0.35);
        part(c, Path()..moveTo(-3, -6)..cubicTo(-11, 0, -10, 10, 0, 10)..cubicTo(10, 10, 11, 0, 3, -6)..close(), const Color(0xFFB07A3A));
        part(c, poly([(-3, -6), (-5.5, -10), (0, -8.5), (5.5, -10), (3, -6)]), const Color(0xFFC08A48), rim: 0.5);
        band(c, Path()..moveTo(-3.5, -6)..lineTo(3.5, -6), const Color(0xFFFFC23A), 1.4);
        coin(c, 6.5, 7.5, 3.2);
        coin(c, 9, 3.5, 2.6);
        shine(c, -4, -0.5, 1.5, 2.8, a: 0.4);
      case 'phoenix':
        glow(c, 0, 0, 16, const Color(0xFFFF6A2A), 0.4);
        final outer = Path()
          ..moveTo(0, 11)
          ..cubicTo(-9, 10, -11, 1, -6, -4)
          ..quadraticBezierTo(-5, 0, -3, 1)
          ..cubicTo(-5, -5, -1, -9, 1, -12)
          ..cubicTo(2, -7, 7, -6, 7, -1)
          ..quadraticBezierTo(8, -3, 9, -5)
          ..cubicTo(12, 2, 8, 10, 0, 11)
          ..close();
        part(c, outer, const Color(0xFFFF4A2A), light: 0.3, dark: 0.35);
        part(c, Path()..moveTo(0, 10)..cubicTo(-5, 9, -6, 3, -2, -1)..cubicTo(-1, 2, 2, 2, 2, -3)..cubicTo(6, 1, 6, 9, 0, 10)..close(),
            const Color(0xFFFFB02A), rim: 0, light: 0.5, dark: 0.1);
        part(c, oval(0, 6.5, 2.2, 3), const Color(0xFFFFF0B0), rim: 0, dark: 0);
      default:
        return false;
    }
    return true;
  }

  // ---------------- Aktionen ----------------

  static Color actionColor(ActionId a) => switch (a) {
        ActionId.dash => const Color(0xFF7FE0FF),
        ActionId.horn => const Color(0xFFFFC24A),
        ActionId.bubbleShield => const Color(0xFFB8A0FF),
        ActionId.flash => const Color(0xFFFFF27A),
        ActionId.storm => const Color(0xFF9FB4FF),
        ActionId.magnet => const Color(0xFFFF6A6A),
        ActionId.clock => const Color(0xFFE8C88A),
        ActionId.bellySlide => const Color(0xFF8AD8FF),
        ActionId.drumroll => const Color(0xFFFF9A5A),
        ActionId.steal => const Color(0xFFB0F08A),
        ActionId.egg => const Color(0xFFFFE6B8),
        ActionId.kick => const Color(0xFFFF8A4A),
        ActionId.screech => const Color(0xFFFFD46A),
        _ => _gold,
      };

  static void action(Canvas c, ActionId a, double t) {
    medal(c, actionColor(a), evolved: a.evolved);
    // Inhalt etwas kleiner, damit er im Ring Platz hat
    c.save();
    c.scale(0.86);
    _actionInner(c, a, t);
    c.restore();
  }

  static void _actionInner(Canvas c, ActionId a, double t) {
    final col = actionColor(a);
    switch (a) {
      case ActionId.dash:
        swoosh(c, col);
      case ActionId.horn:
        at(c, -1.5, 0, 1, () => horn(c));
        soundArcs(c, 3, col);
      case ActionId.bubbleShield:
        bubble(c, t, r: 9);
      case ActionId.flash:
        for (var k = 0; k < 8; k++) {
          final an = k * pi / 4 + pi / 8, l = k.isEven ? 10.0 : 8.0;
          beam(c, Path()..moveTo(cos(an) * 5.5, sin(an) * 5.5)..lineTo(cos(an) * l, sin(an) * l), col, 0.9);
        }
        glow(c, 0, 0, 9, col, 0.6);
        spark(c, 0, 0, 6.5, const Color(0xFFFFF8D0));
      case ActionId.storm:
        at(c, 0.5, 5, 0.65, () => bolt(c));
        at(c, 0, -2.5, 1, () => cloud(c));
      case ActionId.magnet:
        at(c, -3, -2, 0.6, () => magnetU(c), rot: -0.5);
        part(c, Path()..addRRect(RRect.fromLTRBR(-1, -1, 9, 6, const Radius.circular(3.5))), const Color(0xFFD8DEE8));
        part(c, rrect(-9, 0, 0, 3, 1), const Color(0xFFC0C8D6), rim: 0.5);
        dot(c, 4, 1.5, 1.3, const Color(0xFF3A4058));
        for (final y in [-6.0, -3.5]) {
          beam(c, Path()..moveTo(6, y)..lineTo(9.5, y - 1.5), col, 0.7);
        }
      case ActionId.clock:
        clock(c, t);
      case ActionId.bellySlide:
        beam(c, Path()..moveTo(-10, 5.5)..lineTo(10, 5.5), const Color(0xFF8AD8FF), 0.9);
        for (final y in [-3.0, 1.0]) {
          beam(c, Path()..moveTo(-11, y)..lineTo(-8, y), col, 0.7);
        }
        at(c, -1, 0.5, 1, () => penguin(c));
      case ActionId.drumroll:
        drum(c);
      case ActionId.steal:
        crystal(c, 0, 4, 0.85, const Color(0xFF6AE88A));
        band(c, Path()..moveTo(0, -11)..lineTo(0, -5), const Color(0xFFE8A050), 2.6);
        for (final s in [-1.0, 1.0]) {
          band(c, Path()..moveTo(0, -5)..quadraticBezierTo(s * 8, -3, s * 5, 5), const Color(0xFFE8A050), 2);
          dot(c, s * 5, 5, 1.1, const Color(0xFF2A1A0E));
        }
        part(c, circle(0, -5, 2.2), const Color(0xFFE8A050), rim: 0.5);
      case ActionId.egg:
        egg(c);
      case ActionId.kick:
        burst(c, 6, -2, 4.5, const Color(0xFFFFE04A));
        foot(c);
      case ActionId.screech:
        at(c, -2, 0.5, 0.9, () => eagleHead(c));
        soundArcs(c, 7, col);
      // ---- Evolutionen
      case ActionId.sonicBoom:
        at(c, -2, 0, 0.75, () => swoosh(c));
        for (final r in [4.0, 7.0, 10.0]) {
          beam(c, Path()..addArc(Rect.fromCircle(center: const Offset(3, 0), radius: r), -0.9, 1.8), const Color(0xFF7FE0FF), 0.8);
        }
      case ActionId.bubbleRocket:
        at(c, 0, 0, 0.8, () => rocket(c), rot: pi / 4);
        bubble(c, t, r: 9.5, a: 0.42);
      case ActionId.sunStorm:
        sun(c, t);
        at(c, 3.5, 3.5, 0.55, () => bolt(c));
      case ActionId.snapshot:
        part(c, rrect(-4, -8, 2, -4, 1), const Color(0xFF2E3448), rim: 0);
        part(c, rrect(-9.5, -5, 9.5, 7, 2), const Color(0xFF3E4660));
        part(c, circle(0, 1, 4.8), const Color(0xFF1E2234), rim: 0.6);
        part(c, circle(0, 1, 3.2), const Color(0xFF6FC8FF), rim: 0, light: 0.6);
        shine(c, -1, 0, 1, 0.7, a: 0.8);
        part(c, rrect(5, -3.5, 8, -1.5, 0.5), const Color(0xFFFFFFFF), rim: 0);
        glow(c, 7, -8, 6, Colors.white, 0.5);
        spark(c, 7, -8, 3, const Color(0xFFFFFFFF));
      case ActionId.timeBubble:
        at(c, 0, -0.5, 0.65, () => clock(c, t));
        bubble(c, t, r: 9.5, a: 0.42);
      case ActionId.vacuum:
        final p = Path();
        for (var k = 0; k <= 40; k++) {
          final a = k * 0.32 + t * 2, r = 10 - k * 0.22;
          final q = Offset(cos(a) * r, sin(a) * r);
          k == 0 ? p.moveTo(q.dx, q.dy) : p.lineTo(q.dx, q.dy);
        }
        beam(c, p, const Color(0xFFA0C8FF), 1);
        for (final (x, y) in [(-7.0, 6.0), (7.5, -5.0)]) {
          crystal(c, x, y, 0.3, const Color(0xFF6AE88A));
        }
        glow(c, 0, 0, 5, const Color(0xFFFFFFFF), 0.5);
      case ActionId.goldenHour:
        c.save();
        c.clipRect(const Rect.fromLTRB(-12, -12, 12, 3));
        at(c, 0, 3, 1, () => sun(c, t));
        c.restore();
        beam(c, Path()..moveTo(-10, 3)..lineTo(10, 3), const Color(0xFFFF9A3A), 1);
        coin(c, -4, 7, 2.3);
        coin(c, 3, 7.5, 2);
      case ActionId.thunderHorn:
        at(c, -1, 1, 0.9, () => horn(c));
        at(c, 5.5, -5, 0.5, () => bolt(c));
      case ActionId.stormEgg:
        egg(c, spots: false);
        line(c, seg([(-6, 0), (-3, -2), (-1, 1), (2, -2), (4, 1), (6.2, -1)]), const Color(0xFF6A5A40), 0.7);
        at(c, 4, 4, 0.5, () => bolt(c));
      case ActionId.torpedo:
        for (final (x, y, r) in [(-10.0, -3.0, 1.2), (-11.5, 1.0, 0.8), (-9.0, 3.0, 1.0)]) {
          _rim
            ..strokeWidth = 0.5
            ..color = const Color(0xCCBFE8FF);
          c.drawCircle(Offset(x, y), r, _rim);
        }
        part(c, poly([(-8, -1), (-10, -5), (-5, -1)]), const Color(0xFF3E5A88), rim: 0);
        part(c, poly([(-8, 1), (-10, 5), (-5, 1)]), const Color(0xFF3E5A88), rim: 0);
        part(c, Path()..moveTo(-8, -3.2)..lineTo(4, -3.2)..quadraticBezierTo(10, -3, 10, 0)..quadraticBezierTo(10, 3, 4, 3.2)..lineTo(-8, 3.2)..close(), const Color(0xFF6A88B8));
        part(c, rrect(3, -3.2, 4.5, 3.2, 0), const Color(0xFFFFC23A), rim: 0);
        shine(c, 2, -1.8, 4, 0.7, a: 0.45);
      case ActionId.drumSolo:
        at(c, 0, 2.5, 0.75, () => drum(c));
        for (final r in [3.0, 6.0, 9.0]) {
          beam(c, Path()..addArc(Rect.fromCircle(center: const Offset(0, -2), radius: r), -pi * 0.85, pi * 0.7), const Color(0xFFFF9A5A), 0.7);
        }
      case ActionId.magpieHoard:
        glow(c, 0, 0, 10, const Color(0xFF6AE0FF), 0.4);
        part(c, poly([(-8, -3), (-4, -8), (4, -8), (8, -3), (0, 9)]), const Color(0xFF6AE0FF), light: 0.6);
        line(c, seg([(-8, -3), (8, -3)]), Colors.white.withValues(alpha: 0.5), 0.5);
        line(c, seg([(-4, -8), (-2.5, -3), (0, 9), (2.5, -3), (4, -8)]), Colors.white.withValues(alpha: 0.4), 0.5);
        spark(c, 6.5, -8, 2.5, Colors.white);
      case ActionId.comet:
        part(c, Path()..moveTo(2.5, -8.5)..quadraticBezierTo(-4, 1, -10, 10)..quadraticBezierTo(0, 4, 8.5, -2.5)..close(), const Color(0xAA7FD8FF), rim: 0, light: 0.6, dark: 0.1);
        beam(c, Path()..moveTo(4, -5)..quadraticBezierTo(-2, 2, -7, 7), Colors.white, 0.6);
        glow(c, 5, -5, 7, const Color(0xFFFFF0A0), 0.6);
        part(c, circle(5, -5, 3.6), const Color(0xFFFFF4C0), rim: 0, dark: 0.15);
      case ActionId.timeJump:
        part(c, rrect(-7, -10, 7, -8, 1), const Color(0xFFA06A3A), rim: 0);
        part(c, rrect(-7, 8, 7, 10, 1), const Color(0xFFA06A3A), rim: 0);
        final glass = Path()..moveTo(-5.5, -8)..lineTo(5.5, -8)..quadraticBezierTo(5, -3, 0.8, 0)..quadraticBezierTo(5, 3, 5.5, 8)..lineTo(-5.5, 8)..quadraticBezierTo(-5, 3, -0.8, 0)..quadraticBezierTo(-5, -3, -5.5, -8)..close();
        part(c, poly([(-3.5, -4.5), (3.5, -4.5), (0, -0.5)]), const Color(0xFFFFC23A), rim: 0);
        part(c, Path()..moveTo(-5, 8)..quadraticBezierTo(0, 2.5, 5, 8)..close(), const Color(0xFFFFC23A), rim: 0);
        line(c, Path()..moveTo(0, -0.5)..lineTo(0, 6), const Color(0xFFFFD86A), 0.6);
        part(c, glass, const Color(0x44CFEFFF), rim: 0.8, dark: 0);
      case ActionId.bounceBubble:
        part(c, circle(0, 0, 5), const Color(0xFFFFB04A));
        line(c, Path()..moveTo(-5, 0)..quadraticBezierTo(0, -2, 5, 0)..moveTo(0, -5)..quadraticBezierTo(-2, 0, 0, 5), const Color(0xFFFFF0D0), 0.7);
        bubble(c, t, r: 9.5, a: 0.42);
      case ActionId.fanfare:
        at(c, -1, 1, 0.9, () => horn(c, const Color(0xFFFFD04A)), rot: -0.35);
        for (final (x, y, col) in [
          (6.0, -7.0, const Color(0xFFFF6A9A)),
          (9.0, -2.0, const Color(0xFF6AD0FF)),
          (2.0, -9.0, const Color(0xFF8AF08A)),
          (8.0, 4.0, const Color(0xFFFFE04A)),
          (-3.0, -8.0, const Color(0xFFC08AFF)),
        ]) {
          at(c, x, y, 1, () => part(c, rrect(-1.2, -0.6, 1.2, 0.6, 0.2), col, rim: 0), rot: x * 0.7);
        }
      case ActionId.stormBubble:
        at(c, 0, 0, 0.75, () => bolt(c));
        bubble(c, t, r: 9.5, a: 0.42);
      case ActionId.bubbleTrap:
        for (final (x, y, r) in [(-6.5, -6.0, 2.6), (7.0, -6.5, 2.0)]) {
          at(c, x, y, 1, () => bubble(c, t, r: r, a: 0.35));
        }
        part(c, oval(0, 2.5, 4.2, 3.4), const Color(0xFF221A30), rim: 0, light: 0.2);
        for (final s in [-1.0, 1.0]) {
          dot(c, s * 1.6, 1.8, 0.8, const Color(0xFFC77DFF));
        }
        at(c, 0, 1.5, 1, () => bubble(c, t, r: 7.5, a: 0.3));
      case ActionId.electroMagnet:
        at(c, 0, 2, 0.95, () => magnetU(c));
        at(c, 0, -6, 0.45, () => bolt(c, const Color(0xFF9FE0FF)));
      case ActionId.endlessStorm:
        for (var k = 0; k < 5; k++) {
          final y = -7 + k * 3.6, w = 9 - k * 1.7, x = sin(t * 3 + k) * 0.8 + k * 0.4;
          band(c, Path()..addArc(Rect.fromCenter(center: Offset(x, y), width: w * 2, height: 3.2), 0, pi * 2), const Color(0xFF8A9AC8), 1.6);
        }
        at(c, 6.5, -6, 0.4, () => bolt(c));
      case ActionId.goldenEgg:
        glow(c, 0, 0, 11, _gold, 0.45);
        egg(c, col: const Color(0xFFFFC83A), spots: false);
        spark(c, 6.5, -6, 2.6, Colors.white);
        spark(c, -6.5, 5, 1.8, Colors.white);
      case ActionId.sledRide:
        band(c, Path()..moveTo(-9, 6)..lineTo(6, 6)..quadraticBezierTo(10, 6, 9, 2), const Color(0xFFD0D8E4), 1.4);
        for (final x in [-5.0, 2.0]) {
          line(c, Path()..moveTo(x, 6)..lineTo(x, 3), const Color(0xFFD0D8E4), 1);
        }
        part(c, rrect(-8, 0, 6, 3.5, 1), const Color(0xFFB0703A));
        for (var k = 0; k < 3; k++) {
          final a = k * pi / 3;
          beam(c, Path()..moveTo(cos(a) * 4.5, -5.5 + sin(a) * 4.5)..lineTo(-cos(a) * 4.5, -5.5 - sin(a) * 4.5), const Color(0xFFBFEFFF), 0.8);
        }
      case ActionId.strobe:
        _fill.shader = const LinearGradient(colors: [Color(0xCCFFF4C0), Color(0x00FFF4C0)]).createShader(const Rect.fromLTRB(1, -9, 12, 9));
        c.drawPath(poly([(2, -3), (12, -9), (12, 9), (2, 3)]), _fill..blendMode = BlendMode.plus);
        _fill
          ..shader = null
          ..blendMode = BlendMode.srcOver;
        part(c, rrect(-10, -2, -1, 2, 1), const Color(0xFF4A5470));
        part(c, poly([(-2, -2.5), (3, -4.5), (3, 4.5), (-2, 2.5)]), const Color(0xFF6A7898));
        part(c, oval(3, 0, 0.9, 4.2), const Color(0xFFFFF4C0), rim: 0, dark: 0);
      case ActionId.pickpocket:
        glove(c, const Color(0xFF6A5AA8));
        coin(c, 6.5, 6.5, 2.6);
      case ActionId.sprintKick:
        for (final y in [-6.0, -2.0, 2.0]) {
          beam(c, Path()..moveTo(-11, y)..lineTo(-7, y), const Color(0xFFFF9A5A), 0.8);
        }
        at(c, 1, 0, 1, () => foot(c));
        burst(c, 7, 2, 3, const Color(0xFFFFE04A));
      case ActionId.dustCloud:
        at(c, 0, 1, 1, () => cloud(c, const Color(0xFFB89A70)));
        beam(c, Path()..moveTo(-8, 7)..quadraticBezierTo(0, 10, 8, 7), const Color(0xFFD8C090), 0.7);
        for (final (x, y) in [(-6.0, -6.0), (6.5, -6.5)]) {
          spark(c, x, y, 2, const Color(0xFFFFE07A));
        }
      case ActionId.sunEagle:
        at(c, 3, -3, 0.75, () => sun(c, t));
        at(c, -2, 1.5, 0.85, () => eagleHead(c));
      case ActionId.thunderbird:
        glow(c, 0, 0, 10, const Color(0xFF5AB8FF), 0.45);
        for (final s in [-1.0, 1.0]) {
          part(c, Path()..moveTo(s * 1.5, -1)..quadraticBezierTo(s * 6, -9, s * 11, -7)..lineTo(s * 8, -4)..lineTo(s * 10, -2)..lineTo(s * 6, 0)..quadraticBezierTo(s * 4, 2, s * 1.5, 2)..close(),
              const Color(0xFF5AB8FF), rim: 0.6);
        }
        part(c, oval(0, 1, 2.6, 5), const Color(0xFF3A7ACF));
        part(c, circle(0, -4.5, 2.4), const Color(0xFF3A7ACF));
        part(c, poly([(-0.8, -3.5), (0, -1.5), (0.8, -3.5)]), const Color(0xFFFFC23A), rim: 0);
        at(c, 0, 3, 0.4, () => bolt(c));
    }
  }

  // ---------------- Werte ----------------

  static void stat(Canvas c, Stat s, double t) {
    switch (s) {
      case Stat.maxHp:
        glow(c, 0, 0, 13, const Color(0xFFFF4A5A), 0.4);
        at(c, 0, 1, 1.3, () => part(c, GlyphArt._heart(1), const Color(0xFFFF4A5A), rim: 0.6));
        shine(c, -4, -3, 1.4, 1.8, a: 0.6);
      case Stat.regen:
        glow(c, 0, 0, 13, const Color(0xFF4AD87A), 0.4);
        at(c, 0, 1, 1.3, () => part(c, GlyphArt._heart(1), const Color(0xFF4AD87A), rim: 0.6));
        part(c, Path()..addRect(const Rect.fromLTRB(-1, -3, 1, 4))..addRect(const Rect.fromLTRB(-3.5, -0.5, 3.5, 1.5)), Colors.white, rim: 0, dark: 0.1);
      case Stat.dmg:
        glow(c, 0, 0, 13, const Color(0xFFFF7A3A), 0.4);
        for (final dx in [-5.0, 0.0, 5.0]) {
          part(c, Path()..moveTo(dx + 4, -10)..quadraticBezierTo(dx + 1, 0, dx - 4, 10)..quadraticBezierTo(dx + 3, 0, dx + 4, -10)..close(),
              const Color(0xFFFF7A3A), rim: 0.5, light: 0.6);
        }
      case Stat.atk:
        glow(c, 0, 0, 13, const Color(0xFFFFD04A), 0.35);
        for (final dx in [-5.0, 2.0]) {
          part(c, poly([(dx - 2, -8), (dx + 3, -8), (dx + 8, 0), (dx + 3, 8), (dx - 2, 8), (dx + 3, 0)]), const Color(0xFFFFD04A), rim: 0.5);
        }
      case Stat.range:
        glow(c, 0, 0, 13, const Color(0xFF6AD0FF), 0.35);
        for (final (r, col) in [(9.5, const Color(0xFFE84A4A)), (6.5, const Color(0xFFF4F4F8)), (3.5, const Color(0xFFE84A4A))]) {
          part(c, circle(0, 0, r), col, rim: 0, dark: 0.3);
        }
        part(c, poly([(10, -10), (0.5, -0.5), (-0.5, 0.5)]), const Color(0xFF6AD0FF), rim: 0);
        band(c, Path()..moveTo(11, -11)..lineTo(1, -1), const Color(0xFFA06A3A), 1.2);
        part(c, poly([(8, -12), (12, -12), (12, -8), (10, -10)]), const Color(0xFF6AD0FF), rim: 0);
      case Stat.speed:
        glow(c, 0, 0, 13, const Color(0xFF7FE0FF), 0.35);
        for (final y in [-3.0, 1.0, 5.0]) {
          beam(c, Path()..moveTo(-11, y)..lineTo(-6, y), const Color(0xFF7FE0FF), 0.8);
        }
        at(c, 2, 0, 0.9, () => feather(c, const Color(0xFFBFEFFF)), rot: 0.6);
      case Stat.armor:
        glow(c, 0, 0, 13, const Color(0xFF9AB4E0), 0.3);
        part(c, _shield(), const Color(0xFF8A98B4), light: 0.55);
        at(c, 0, 0.5, 0.7, () => part(c, _shield(), const Color(0xFF5A6888), rim: 0));
        line(c, Path()..moveTo(0, -7)..lineTo(0, 8), const Color(0x66FFFFFF), 0.8);
      case Stat.lifesteal:
        glow(c, 0, 0, 13, const Color(0xFFE0283A), 0.4);
        part(c, Path()..moveTo(0, -10)..quadraticBezierTo(8, 0, 7, 4)..quadraticBezierTo(5, 10, 0, 10)..quadraticBezierTo(-5, 10, -7, 4)..quadraticBezierTo(-8, 0, 0, -10)..close(),
            const Color(0xFFE0283A));
        at(c, 0, 4.5, 0.45, () => part(c, GlyphArt._heart(1), const Color(0xFFFFB0B8), rim: 0));
        shine(c, -3, 1, 1, 2.2, a: 0.55);
      case Stat.crit:
        glow(c, 0, 0, 14, const Color(0xFFFFC83A), 0.45);
        part(c, GlyphArt._star(11, 4.5, 8, rot: t * 0.4), const Color(0xFFFFC83A), rim: 0.5, light: 0.6);
        dot(c, 0, 0, 2, const Color(0xFFFFF8E0));
      case Stat.pickup:
        for (final r in [6.5, 10.0]) {
          beam(c, circle(0, 0, r), const Color(0xFF6AE8A0), 0.7);
        }
        crystal(c, 0, 0, 0.75, const Color(0xFF6AE8A0));
      case Stat.thrust:
        glow(c, 0, 4, 12, const Color(0xFFFF8A3A), 0.4);
        part(c, Path()..moveTo(-4, 2)..quadraticBezierTo(0, 16, 4, 2)..close(), const Color(0xFFFF8A3A), rim: 0, light: 0.6, dark: 0.1);
        part(c, poly([(0, -11), (7, -3), (2.5, -3), (2.5, 3), (-2.5, 3), (-2.5, -3), (-7, -3)]), const Color(0xFFFFE6A0), rim: 0.6);
      case Stat.glide:
        glow(c, 0, 0, 13, const Color(0xFFBFEFFF), 0.3);
        for (final (y, x) in [(-7.0, -10.0), (8.0, -3.0)]) {
          beam(c, Path()..moveTo(x, y)..quadraticBezierTo(x + 4, y - 2, x + 8, y), const Color(0xFFBFEFFF), 0.7);
        }
        at(c, 0, 0, 1, () => feather(c, const Color(0xFFF4F8FF)), rot: 0.9);
    }
  }

  // ---------------- Bedien-Symbole ----------------

  /// Feine Lichtlinie in der Textfarbe.
  static void stroke(Canvas c, Path p, Color col, {double w = 2}) {
    _add
      ..strokeWidth = w * 2.2
      ..color = col.withValues(alpha: 0.28);
    c.drawPath(p, _add);
    _line
      ..strokeWidth = w
      ..color = Color.lerp(col, Colors.white, 0.3)!;
    c.drawPath(p, _line);
  }

  static void _arrow(Canvas c, Color col, double rot) => at(c, 0, 0, 1, rot: rot, () {
        stroke(c, Path()..moveTo(-8, 0)..lineTo(7, 0), col, w: 2.2);
        stroke(c, seg([(1.5, -5.5), (7.5, 0), (1.5, 5.5)]), col, w: 2.2);
      });

  static void _tri(Canvas c, Color col, double rot) => at(c, 0, 0, 1, rot: rot, () {
        glow(c, 1, 0, 11, col, 0.25);
        part(c, Path()..moveTo(-5, -7.5)..quadraticBezierTo(-6, -8.5, -4, -7.4)..lineTo(7.5, -1)..quadraticBezierTo(9, 0, 7.5, 1)..lineTo(-4, 7.4)..quadraticBezierTo(-6, 8.5, -5, 7.5)..close(),
            col, rim: 0.6, light: 0.6, dark: 0.25);
      });

  static void ui(Canvas c, UiIcon i, Color col, double t) {
    switch (i) {
      case UiIcon.play:
        _tri(c, col, 0);
      case UiIcon.left:
        _tri(c, col, pi);
      case UiIcon.up:
        _tri(c, col, -pi / 2);
      case UiIcon.down:
        _tri(c, col, pi / 2);
      case UiIcon.arrowRight:
        _arrow(c, col, 0);
      case UiIcon.arrowLeft:
        _arrow(c, col, pi);
      case UiIcon.arrowUp:
        _arrow(c, col, -pi / 2);
      case UiIcon.arrowDown:
        _arrow(c, col, pi / 2);
      case UiIcon.arrowDownRight:
        _arrow(c, col, pi / 4);
      case UiIcon.fall:
        glow(c, 0, 0, 11, const Color(0xFF8FD8FF), 0.3);
        part(c, poly([(-3, -9), (3, -9), (3, 0), (8, 0), (0, 9.5), (-8, 0), (-3, 0)]), const Color(0xFF8FD8FF), rim: 0.6, light: 0.6);
      case UiIcon.upgrade:
        stroke(c, Path()..moveTo(-7, 8)..quadraticBezierTo(-7, -3, 5, -3), col, w: 2.2);
        stroke(c, seg([(0, -8), (5.5, -3), (0, 2)]), col, w: 2.2);
      case UiIcon.restart || UiIcon.reset:
        final s = i == UiIcon.reset ? -1.0 : 1.0;
        at(c, 0, 0, 1, () {
          c.scale(s, 1);
          stroke(c, Path()..addArc(Rect.fromCircle(center: Offset.zero, radius: 7), -pi / 2 + 0.5, pi * 1.6), col, w: 2.2);
          stroke(c, seg([(-1.5, -10.5), (1.8, -7), (-1.5, -3.5)]), col, w: 2.2);
        });
      case UiIcon.star:
        glow(c, 0, 0, 12, const Color(0xFFFFC83A), 0.4);
        part(c, GlyphArt._star(10.5, 4.4, 5), const Color(0xFFFFC83A), rim: 0.6, light: 0.6);
      case UiIcon.sparkle:
        glow(c, 0, 0, 11, col, 0.35);
        spark(c, 0, 0, 10, Color.lerp(col, Colors.white, 0.3)!);
      case UiIcon.heart:
        glow(c, 0, 0, 12, const Color(0xFFFF4A5A), 0.4);
        at(c, 0, 1, 1.3, () => part(c, GlyphArt._heart(1), const Color(0xFFFF4A5A), rim: 0.6));
        shine(c, -4, -3, 1.4, 1.8, a: 0.6);
      case UiIcon.crystal:
        glow(c, 0, 0, 11, const Color(0xFF7CF29C), 0.4);
        crystal(c, 0, 0, 1.35, const Color(0xFF7CF29C));
      case UiIcon.check:
        stroke(c, seg([(-8, 0), (-2.5, 6), (8, -6.5)]), col, w: 2.6);
      case UiIcon.plus:
        stroke(c, Path()..moveTo(0, -7.5)..lineTo(0, 7.5)..moveTo(-7.5, 0)..lineTo(7.5, 0), col, w: 2.6);
      case UiIcon.lock || UiIcon.unlock:
        glow(c, 0, 2, 11, const Color(0xFFFFC23A), 0.3);
        final shackle = i == UiIcon.lock
            ? (Path()..moveTo(-4.5, 0)..lineTo(-4.5, -4)..arcToPoint(const Offset(4.5, -4), radius: const Radius.circular(4.5))..lineTo(4.5, 0))
            : (Path()..moveTo(-4.5, 0)..lineTo(-4.5, -6)..arcToPoint(const Offset(4.5, -6), radius: const Radius.circular(4.5))..lineTo(4.5, -4));
        band(c, shackle, const Color(0xFFC8D0DC), 2.4);
        part(c, rrect(-7.5, -1, 7.5, 9.5, 2), const Color(0xFFFFC23A));
        dot(c, 0, 3.5, 1.5, const Color(0xFF5A3A10));
        part(c, rrect(-0.6, 3.5, 0.6, 6.5, 0.3), const Color(0xFF5A3A10), rim: 0);
      case UiIcon.flag:
        band(c, Path()..moveTo(-7, -10)..lineTo(-7, 10), const Color(0xFFC8CCD8), 1.8);
        final flag = Path()..moveTo(-7, -9)..quadraticBezierTo(0, -11, 9, -8)..lineTo(9, 0)..quadraticBezierTo(0, -3, -7, -1)..close();
        part(c, flag, const Color(0xFFF4F4F8), rim: 0.6, dark: 0.2);
        c.save();
        c.clipPath(flag);
        for (var x = 0; x < 4; x++) {
          for (var y = 0; y < 3; y++) {
            if ((x + y).isOdd) c.drawRect(Rect.fromLTWH(-7 + x * 4, -11 + y * 4, 4, 4), _fill..color = const Color(0xFF1E2234));
          }
        }
        c.restore();
      case UiIcon.map:
        glow(c, 0, 0, 11, const Color(0xFFE8D8A8), 0.25);
        part(c, poly([(-10, -7), (-4, -9), (-4, 8), (-10, 10)]), const Color(0xFFE8D8A8), rim: 0.5, dark: 0.25);
        part(c, poly([(-4, -9), (3, -7), (3, 10), (-4, 8)]), const Color(0xFFCFC090), rim: 0.5, dark: 0.25);
        part(c, poly([(3, -7), (10, -9), (10, 8), (3, 10)]), const Color(0xFFE8D8A8), rim: 0.5, dark: 0.25);
        line(c, Path()..moveTo(-8, 6)..quadraticBezierTo(-4, -2, 1, 2)..quadraticBezierTo(4, 4, 6, -3), const Color(0xFFE8504A), 0.9);
        line(c, Path()..moveTo(5, -6)..lineTo(8, -3)..moveTo(8, -6)..lineTo(5, -3), const Color(0xFFE8504A), 1.1);
      case UiIcon.dice:
        glow(c, 0, 0, 11, Colors.white, 0.25);
        at(c, 0, 0, 1, rot: 0.2, () {
          part(c, rrect(-8.5, -8.5, 8.5, 8.5, 2.5), const Color(0xFFF4F2F8), dark: 0.3);
          for (final (x, y) in [(-4.0, -4.0), (4.0, -4.0), (0.0, 0.0), (-4.0, 4.0), (4.0, 4.0)]) {
            dot(c, x, y, 1.5, const Color(0xFFD8404A));
          }
        });
      case UiIcon.trophy:
        glow(c, 0, -2, 12, const Color(0xFFFFC23A), 0.4);
        for (final sx in [-1.0, 1.0]) {
          band(c, Path()..moveTo(sx * 6, -7)..quadraticBezierTo(sx * 11, -7, sx * 10, -3)..quadraticBezierTo(sx * 9, 0, sx * 5, 0), const Color(0xFFE0A830), 1.6);
        }
        part(c, Path()..moveTo(-7, -9)..lineTo(7, -9)..lineTo(6, -2)..quadraticBezierTo(4, 3, 0, 3)..quadraticBezierTo(-4, 3, -6, -2)..close(), const Color(0xFFFFC23A));
        part(c, rrect(-1.4, 3, 1.4, 7, 0), const Color(0xFFE0A830), rim: 0);
        part(c, rrect(-6, 7, 6, 10, 1), const Color(0xFFB07A2A), rim: 0.5);
        shine(c, -3.5, -5.5, 1, 2.2, a: 0.6);
      case UiIcon.hand:
        glow(c, 0, 0, 11, const Color(0xFFF0C8A0), 0.25);
        glove(c, const Color(0xFFF0C8A0));
      case UiIcon.backpack:
        glow(c, 0, 0, 11, const Color(0xFFC08A50), 0.3);
        band(c, Path()..moveTo(-3.5, -7)..quadraticBezierTo(0, -11, 3.5, -7), const Color(0xFF8A5A30), 1.6);
        part(c, rrect(-7.5, -7, 7.5, 10, 3), const Color(0xFFC08A50));
        part(c, Path()..moveTo(-7.5, -3)..quadraticBezierTo(0, -9.5, 7.5, -3)..lineTo(7.5, -1)..lineTo(-7.5, -1)..close(), const Color(0xFFA06A38), rim: 0.5);
        part(c, rrect(-4.5, 3, 4.5, 8.5, 1.5), const Color(0xFFA06A38), rim: 0.5);
        dot(c, 0, -1.5, 1, const Color(0xFFFFD86A));
      case UiIcon.cart:
        stroke(c, seg([(-10, -8), (-7, -8), (-4, 4), (7, 4), (9, -4), (-6, -4)]), col, w: 2);
        for (final x in [-3.0, 6.0]) {
          stroke(c, circle(x, 7.5, 1.6), col, w: 1.6);
        }
      case UiIcon.stopwatch:
        at(c, 0, 0, 1.05, () => clock(c, t));
      case UiIcon.microscope:
        stroke(c, Path()..moveTo(-8, 9)..lineTo(8, 9)..moveTo(-2, 9)..quadraticBezierTo(6, 6, 4, -1), col, w: 2);
        stroke(c, Path()..moveTo(-4, -9)..lineTo(2, 1), col, w: 3.4);
        stroke(c, Path()..moveTo(-6, 4)..lineTo(4, 4), col, w: 1.6);
      case UiIcon.keyboard:
        stroke(c, rrect(-10, -6, 10, 7, 2), col, w: 1.6);
        for (var y = 0; y < 2; y++) {
          for (var x = 0; x < 5; x++) {
            dot(c, -6.4 + x * 3.2, -2.5 + y * 3.2, 0.9, Color.lerp(col, Colors.white, 0.3)!);
          }
        }
        stroke(c, Path()..moveTo(-4, 4)..lineTo(4, 4), col, w: 1.2);
      case UiIcon.gamepad:
        glow(c, 0, 0, 12, const Color(0xFF8A9AD8), 0.3);
        part(c, Path()..moveTo(-6, -6)..lineTo(6, -6)..cubicTo(11, -6, 12, 8, 9, 8)..cubicTo(6.5, 8, 5, 3, 3, 3)..lineTo(-3, 3)..cubicTo(-5, 3, -6.5, 8, -9, 8)..cubicTo(-12, 8, -11, -6, -6, -6)..close(),
            const Color(0xFF5A6488));
        line(c, Path()..moveTo(-6, -1.5)..lineTo(-6, 2.5)..moveTo(-8, 0.5)..lineTo(-4, 0.5), const Color(0xFFE6ECF8), 1.3);
        dot(c, 5, -1.5, 1.1, const Color(0xFF7CF29C));
        dot(c, 7.2, 0.6, 1.1, const Color(0xFFFF6A6A));
        dot(c, 2.8, 0.6, 1.1, const Color(0xFF6AC8FF));
      case UiIcon.fullscreen:
        for (final (sx, sy) in [(-1.0, -1.0), (1.0, -1.0), (-1.0, 1.0), (1.0, 1.0)]) {
          stroke(c, seg([(sx * 8, sy * 3), (sx * 8, sy * 8), (sx * 3, sy * 8)]), col, w: 2);
        }
      case UiIcon.exitFullscreen:
        for (final (sx, sy) in [(-1.0, -1.0), (1.0, -1.0), (-1.0, 1.0), (1.0, 1.0)]) {
          stroke(c, seg([(sx * 8, sy * 3), (sx * 3, sy * 3), (sx * 3, sy * 8)]), col, w: 2);
        }
    }
  }
}
