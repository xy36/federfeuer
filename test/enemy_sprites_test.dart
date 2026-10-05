import 'dart:math';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:federfeuer/game/components/enemy.dart';
import 'package:federfeuer/game/config.dart';

/// Vorgerenderte Gegner: Jede Phase, Pulsstufe und Variante muss vollständig in
/// [EnemySpriteDef.bounds] liegen, sonst würde sie im Atlas abgeschnitten.
void main() {
  // Treffer-Blitz: Nur der Körper wird hell, nicht die ganze Zelle (sonst ein Rechteck).
  testWidgets('Treffer-Blitz färbt nur den Körper, nicht die Zelle', (tester) async {
    await tester.runAsync(() async {
      final rec = ui.PictureRecorder();
      Canvas(rec).drawCircle(const Offset(16, 16), 8, Paint()..color = const Color(0xFF200A30));
      final sprite = rec.endRecording().toImageSync(32, 32);
      for (final paint in [EnemyBodyPass.normalPaint, EnemyBodyPass.hitPaint]) {
        final r2 = ui.PictureRecorder();
        Canvas(r2).drawAtlas(sprite, [RSTransform(1, 0, 0, 0)], [const Rect.fromLTWH(0, 0, 32, 32)], null, null,
            null, paint);
        final img = await r2.endRecording().toImage(32, 32);
        final px = (await img.toByteData())!;
        int at(int x, int y, int ch) => px.getUint8((y * 32 + x) * 4 + ch);
        expect(at(1, 1, 3), 0, reason: 'Ecke der Zelle muss durchsichtig bleiben');
        expect(at(16, 16, 3), 255);
        if (identical(paint, EnemyBodyPass.hitPaint)) expect(at(16, 16, 0), greaterThan(200));
        img.dispose();
      }
      sprite.dispose();
    });
  });

  for (final MapEntry(key: type, value: def) in enemySpriteDefs.entries) {
    testWidgets('Sprite ${type.name} liegt in seinen Grenzen', (tester) async {
      const s = 2.0, pad = 6;
      final b = def.bounds;
      final w = (b.width * s).ceil() + 2 * pad, h = (b.height * s).ceil() + 2 * pad;
      final period = def.omega > 0 ? 2 * pi / def.omega : 0.0;
      final r = enemyDefs[type]!.radius;
      final outside = <String>[];
      await tester.runAsync(() async {
        for (var v = 0; v < def.variants; v++) {
          for (var pl = 0; pl < def.pulseLevels; pl++) {
            for (var f = 0; f < def.frames; f++) {
              final rec = ui.PictureRecorder();
              final c = Canvas(rec);
              c.translate(pad - b.left * s, pad - b.top * s);
              c.scale(s);
              def.draw(c, period * f / def.frames, (pl + 0.5) / def.pulseLevels, v, r);
              final img = await rec.endRecording().toImage(w, h);
              final px = (await img.toByteData())!;
              img.dispose();
              // Alles außerhalb der Grenzen (Rand der Breite [pad]) muss durchsichtig sein.
              var minX = w, minY = h, maxX = -1, maxY = -1, drawn = 0;
              for (var y = 0; y < h; y++) {
                for (var x = 0; x < w; x++) {
                  final inside = x >= pad && y >= pad && x < w - pad && y < h - pad;
                  final opaque = px.getUint8((y * w + x) * 4 + 3) >= 8;
                  if (inside && opaque) drawn++;
                  if (inside || !opaque) continue;
                  minX = min(minX, x);
                  minY = min(minY, y);
                  maxX = max(maxX, x);
                  maxY = max(maxY, y);
                }
              }
              if (drawn == 0) outside.add('v$v p$pl f$f: leer');
              if (maxX >= 0) {
                String u(int p, double o) => ((p - pad) / s + o).toStringAsFixed(1);
                outside.add('v$v p$pl f$f: x ${u(minX, b.left)}…${u(maxX, b.left)}, '
                    'y ${u(minY, b.top)}…${u(maxY, b.top)}');
              }
            }
          }
        }
      });
      expect(outside, isEmpty, reason: 'Zeichnung ragt über ${def.bounds} hinaus');
    });

    if (def.omega > 0) {
      // Nahtlose Schleife: Nach einer Periode sieht der Gegner wieder genauso aus.
      testWidgets('Sprite ${type.name} wiederholt sich nach einer Periode', (tester) async {
        const s = 2.0;
        final b = def.bounds;
        final w = (b.width * s).ceil(), h = (b.height * s).ceil();
        final r = enemyDefs[type]!.radius, period = 2 * pi / def.omega;
        Future<List<int>> pixels(double t) async {
          final rec = ui.PictureRecorder();
          final c = Canvas(rec);
          c.translate(-b.left * s, -b.top * s);
          c.scale(s);
          def.draw(c, t, 0.5, 0, r);
          final img = await rec.endRecording().toImage(w, h);
          final px = (await img.toByteData())!.buffer.asUint8List();
          img.dispose();
          return px;
        }

        var maxDiff = 0;
        await tester.runAsync(() async {
          for (final t0 in [0.0, period * 0.37]) {
            final a = await pixels(t0), z = await pixels(t0 + period);
            for (var i = 0; i < a.length; i++) {
              maxDiff = max(maxDiff, (a[i] - z[i]).abs());
            }
          }
        });
        expect(maxDiff, lessThan(24), reason: 'Phase nach 2π/${def.omega} weicht ab');
      });
    }
  }
}
