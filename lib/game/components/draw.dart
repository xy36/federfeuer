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
final _shadowPaint = Paint();

void drawShadow(Canvas c, double worldY, double r) {
  final h = clampD(1 - (kGround - worldY) / 480, 0.25, 1);
  _shadowPaint.color = Color.fromRGBO(20, 10, 30, 0.3 * h);
  c.drawOval(
    Rect.fromCenter(center: Offset(0, kGround + 8 - worldY), width: (r * 1.3 * h + 3) * 2, height: (4 * h + 1.5) * 2),
    _shadowPaint,
  );
}

/// Text im Spiel mit weichem Schein statt Kontur, gecacht (TextPainter-Layout ist teuer).
/// [display]: Cinzel-Versalien (Banner, Zahlen im HUD); sonst kräftiges Nunito (Schadenszahlen).
class OutlineText {
  static final _cache = <String, TextPainter>{};

  static void draw(Canvas c, String s, Offset at,
      {double size = 15,
      Color color = const Color(0xFFFFFFFF),
      bool center = true,
      bool display = true,
      bool glow = true}) {
    if (_cache.length > 300) _cache.clear();
    final tp = _cache.putIfAbsent('$s|$size|${color.toARGB32()}|$display|$glow', () {
      return TextPainter(
        text: TextSpan(
          text: s,
          style: TextStyle(
            fontFamily: display ? 'Cinzel' : 'Nunito',
            fontSize: size,
            color: Color.lerp(color, const Color(0xFFFFFFFF), 0.25),
            fontWeight: FontWeight.w800,
            fontVariations: [FontVariation('wght', display ? 700 : 900)],
            letterSpacing: display ? size * 0.05 : 0,
            // Schein kostet pro Glyphe Rasterzeit – bei vielen Texten (Schadenszahlen)
            // nur ein scharfer dunkler Versatzschatten.
            shadows: glow
                ? [
                    const Shadow(color: Color(0xB3000000), blurRadius: 3, offset: Offset(0, 1)),
                    Shadow(color: color.withAlpha(170), blurRadius: size * 0.6),
                  ]
                : const [Shadow(color: Color(0xCC05030C), offset: Offset(1, 1.5))],
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
    });
    tp.paint(c, Offset(center ? at.dx - tp.width / 2 : at.dx, at.dy - tp.height / 2));
  }
}
