import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:federfeuer/game/components/tris.dart';

double _triArea(TriBatch t) {
  final v = t.vertexData;
  var sum = 0.0;
  for (var i = 0; i < v.length; i += 6) {
    sum += ((v[i + 2] - v[i]) * (v[i + 5] - v[i + 1]) - (v[i + 4] - v[i]) * (v[i + 3] - v[i + 1])).abs() / 2;
  }
  return sum;
}

double _polyArea(List<Offset> p) {
  var s = 0.0;
  for (var i = 0; i < p.length; i++) {
    s += p[i].dx * p[(i + 1) % p.length].dy - p[(i + 1) % p.length].dx * p[i].dy;
  }
  return s.abs() / 2;
}

void main() {
  test('Rechteck und konvexes Polygon', () {
    final t = TriBatch()..addRect(const Rect.fromLTWH(0, 0, 10, 4));
    expect(_triArea(t), closeTo(40, 1e-6));
    final pts = [const Offset(0, 0), const Offset(10, 0), const Offset(12, 5), const Offset(5, 9), const Offset(-2, 5)];
    final u = TriBatch()..addPoly(pts);
    expect(_triArea(u), closeTo(_polyArea(pts), 1e-6));
  });

  test('Konkave Stammform (ausgestellte Wurzeln) ohne Fläche außerhalb', () {
    const x = 100.0, y = 400.0, w = 30.0, top = -50.0;
    final pts = [
      const Offset(x - w * 1.8, y),
      const Offset(x - w * 0.55, y - 40),
      const Offset(x - w * 0.45, top),
      const Offset(x + w * 0.45, top),
      const Offset(x + w * 0.6, y - 50),
      const Offset(x + w * 1.6, y),
    ];
    for (final order in [pts, pts.reversed.toList()]) {
      final t = TriBatch()..addPoly(order);
      expect(_triArea(t), closeTo(_polyArea(pts), 1e-3), reason: 'beide Umlaufrichtungen');
    }
  });

  test('Gelände- und Streifenfläche', () {
    final top = [const Offset(0, 10), const Offset(10, 0), const Offset(20, 10)];
    final t = TriBatch()..addTerrain(top, 20);
    expect(_triArea(t), closeTo(10 * 15 + 10 * 15, 1e-6));
    final s = TriBatch()..addStrip(top, [for (final p in top) p.translate(0, 3)]);
    expect(_triArea(s), closeTo(60, 1e-6));
  });
}
