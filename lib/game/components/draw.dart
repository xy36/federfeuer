import 'package:flutter/material.dart';

import '../config.dart';

final Map<Color, Paint> _paints = {};
Paint fillOf(Color c) => _paints.putIfAbsent(c, () => Paint()..color = c);

void drawCircle(Canvas c, double x, double y, double r, Color col) =>
    c.drawCircle(Offset(x, y), r, fillOf(col));

void drawRect(Canvas c, double x, double y, double w, double h, Color col) =>
    c.drawRect(Rect.fromLTWH(x, y, w, h), fillOf(col));

void drawOval(Canvas c, double x, double y, double rx, double ry, Color col, [double rot = 0]) {
  if (rot == 0) {
    c.drawOval(Rect.fromCenter(center: Offset(x, y), width: rx * 2, height: ry * 2), fillOf(col));
    return;
  }
  c.save();
  c.translate(x, y);
  c.rotate(rot);
  c.drawOval(Rect.fromCenter(center: Offset.zero, width: rx * 2, height: ry * 2), fillOf(col));
  c.restore();
}

void drawTri(Canvas c, double ax, double ay, double bx, double by, double cx, double cy, Color col) {
  final p = Path()
    ..moveTo(ax, ay)
    ..lineTo(bx, by)
    ..lineTo(cx, cy)
    ..close();
  c.drawPath(p, fillOf(col));
}

/// Schatten auf dem Boden – gibt den leichten Schrägsicht-Effekt.
void drawShadow(Canvas c, double worldY, double r) {
  final h = clampD(1 - (kGround - worldY) / 480, 0.25, 1);
  c.drawOval(
    Rect.fromCenter(center: Offset(0, kGround + 8 - worldY), width: (r * 1.3 * h + 3) * 2, height: (4 * h + 1.5) * 2),
    Paint()..color = Color.fromRGBO(20, 10, 30, 0.3 * h),
  );
}

/// Text mit dunkler Kontur, gecacht (TextPainter-Layout ist teuer).
class OutlineText {
  static final _cache = <String, (TextPainter, TextPainter)>{};

  static void draw(Canvas c, String s, Offset at,
      {double size = 15, Color color = const Color(0xFFFFFFFF), bool center = true}) {
    if (_cache.length > 300) _cache.clear();
    final pair = _cache.putIfAbsent('$s|$size|${color.hashCode}', () {
      final fill = TextPainter(
        text: TextSpan(text: s, style: TextStyle(fontSize: size, fontWeight: FontWeight.w900, color: color)),
        textDirection: TextDirection.ltr,
      )..layout();
      final stroke = TextPainter(
        text: TextSpan(
          text: s,
          style: TextStyle(
            fontSize: size,
            fontWeight: FontWeight.w900,
            foreground: Paint()
              ..style = PaintingStyle.stroke
              ..strokeWidth = size / 5 < 3 ? 3.0 : size / 5
              ..strokeJoin = StrokeJoin.round
              ..color = Palette.ink,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      return (fill, stroke);
    });
    final w = pair.$1.width, h = pair.$1.height;
    final o = Offset(center ? at.dx - w / 2 : at.dx, at.dy - h / 2);
    pair.$2.paint(c, o);
    pair.$1.paint(c, o);
  }
}
