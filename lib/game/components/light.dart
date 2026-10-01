import 'dart:ui' as ui;

import 'package:flutter/material.dart';

/// Weiche Leuchtpunkte: eine einmal gerenderte radiale Textur, die eingefärbt
/// und additiv (BlendMode.plus) gezeichnet wird. Viel günstiger als Blur pro Frame.
class Glow {
  Glow._();

  static const _size = 128.0;
  static ui.Image? _image;
  static final _src = Rect.fromLTWH(0, 0, _size, _size);
  static final _paint = Paint()
    ..blendMode = BlendMode.plus
    ..filterQuality = FilterQuality.medium;

  static ui.Image get image => _image ??= _render();

  static ui.Image _render() {
    final rec = ui.PictureRecorder();
    final c = Canvas(rec);
    const r = _size / 2;
    c.drawCircle(
      const Offset(r, r),
      r,
      Paint()
        ..shader = const RadialGradient(
          colors: [
            Color(0xFFFFFFFF),
            Color(0x99FFFFFF),
            Color(0x26FFFFFF),
            Color(0x00FFFFFF),
          ],
          stops: [0, 0.18, 0.5, 1],
        ).createShader(Rect.fromCircle(center: const Offset(r, r), radius: r)),
    );
    return rec.endRecording().toImageSync(_size.toInt(), _size.toInt());
  }

  /// Leuchtpunkt mit Radius [r]; die Deckkraft steckt im Alpha von [color].
  static void draw(Canvas c, double x, double y, double r, Color color) {
    _paint.colorFilter = ColorFilter.mode(color, BlendMode.modulate);
    c.drawImageRect(
      image,
      _src,
      Rect.fromCircle(center: Offset(x, y), radius: r),
      _paint,
    );
  }

  /// Viele Leuchtpunkte auf einmal (Partikel): je Punkt (x, y, Radius, Farbe).
  static void drawMany(
    Canvas c,
    List<RSTransform> transforms,
    List<Color> colors,
  ) {
    if (transforms.isEmpty) return;
    c.drawAtlas(
      image,
      transforms,
      List.filled(transforms.length, _src),
      colors,
      BlendMode.modulate,
      null,
      Paint()
        ..blendMode = BlendMode.plus
        ..filterQuality = FilterQuality.medium,
    );
  }

  /// Transform für [drawMany]: Punkt bei (x, y) mit Radius r.
  static RSTransform at(double x, double y, double r) {
    final scale = r * 2 / _size;
    return RSTransform.fromComponents(
      rotation: 0,
      scale: scale,
      anchorX: _size / 2,
      anchorY: _size / 2,
      translateX: x,
      translateY: y,
    );
  }
}

/// Sammelt Leuchtpunkte und zeichnet sie in einem einzigen Aufruf ([Glow.drawMany]).
/// Viele einzelne Leuchtaufrufe mit wechselnder Mischart sind auf der GPU teuer.
class GlowBatch {
  final _t = <RSTransform>[];
  final _c = <Color>[];

  void add(double x, double y, double r, Color color) {
    _t.add(Glow.at(x, y, r));
    _c.add(color);
  }

  void flush(Canvas c) {
    Glow.drawMany(c, _t, _c);
    clear();
  }

  void clear() {
    _t.clear();
    _c.clear();
  }
}

/// Lichtstrahl-Textur: verjüngt, quer weich auslaufend, nach unten verblassend.
/// Einmal gerendert (mit Weichzeichner – nur beim Erzeugen, nicht pro Frame);
/// gezeichnet werden alle Strahlen gesammelt per [drawAtlas], additiv.
class Rays {
  Rays._();

  static const w = 160.0, h = 768.0;
  static ui.Image? _image;
  static final _src = Rect.fromLTWH(0, 0, w, h);
  static final _paint = Paint()
    ..blendMode = BlendMode.plus
    ..filterQuality = FilterQuality.medium;

  static ui.Image get image => _image ??= _render();

  static ui.Image _render() {
    final rec = ui.PictureRecorder();
    final c = Canvas(rec);
    // Schmal am Ursprung, breit am Ende; die Mitte heller als die Ränder
    final shape = Path()
      ..moveTo(w / 2 - 6, 0)
      ..lineTo(w / 2 + 6, 0)
      ..lineTo(w - 22, h)
      ..lineTo(22, h)
      ..close();
    final fade = const LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: [Color(0x00FFFFFF), Color(0xFFFFFFFF), Color(0xCCFFFFFF), Color(0x00FFFFFF)],
      stops: [0, 0.05, 0.5, 1],
    ).createShader(_src);
    c.drawPath(
      shape,
      Paint()
        ..shader = fade
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 11),
    );
    // Heller Kern
    final core = Path()
      ..moveTo(w / 2 - 2, 0)
      ..lineTo(w / 2 + 2, 0)
      ..lineTo(w / 2 + 26, h * 0.8)
      ..lineTo(w / 2 - 26, h * 0.8)
      ..close();
    c.drawPath(
      core,
      Paint()
        ..shader = fade
        ..color = const Color(0x66FFFFFF)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8),
    );
    return rec.endRecording().toImageSync(w.toInt(), h.toInt());
  }

  /// Strahl ab ([x], [y]) mit Winkel [angle] (0 = senkrecht nach unten), Länge [len].
  static RSTransform at(double x, double y, double angle, double len) => RSTransform.fromComponents(
        rotation: angle,
        scale: len / h,
        anchorX: w / 2,
        anchorY: 0,
        translateX: x,
        translateY: y,
      );

  static void drawMany(Canvas c, List<RSTransform> transforms, List<Color> colors) {
    if (transforms.isEmpty) return;
    c.drawAtlas(image, transforms, List.filled(transforms.length, _src), colors, BlendMode.modulate, null, _paint);
  }
}
