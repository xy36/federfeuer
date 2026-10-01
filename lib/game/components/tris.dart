import 'dart:math';
import 'dart:typed_data';
import 'dart:ui';

/// Sammelt einfarbige Silhouetten als Dreiecke und zeichnet sie in einem
/// `drawVertices`-Aufruf. Gleiche Bausteine wie ein Path (Rechteck, Oval,
/// konvexes Polygon, Bogen, Streifen), aber ohne Pfad-Füllung: Impeller füllt
/// große zusammengesetzte Pfade per Stencil über die ganze Hüllbox, was bei
/// Silhouetten über die volle Bildbreite teuer ist.
class TriBatch {
  Float32List _v = Float32List(4096);
  int _n = 0; // belegte Floats (2 je Eckpunkt)

  bool get isEmpty => _n == 0;

  /// Belegte Eckpunkte (x, y, x, y, …) – drei Punkte je Dreieck.
  Float32List get vertexData => Float32List.sublistView(_v, 0, _n);

  void clear() => _n = 0;

  void _grow(int more) {
    if (_n + more <= _v.length) return;
    var len = _v.length * 2;
    while (len < _n + more) {
      len *= 2;
    }
    _v = Float32List(len)..setRange(0, _n, _v);
  }

  void tri(double ax, double ay, double bx, double by, double cx, double cy) {
    _grow(6);
    _v[_n++] = ax;
    _v[_n++] = ay;
    _v[_n++] = bx;
    _v[_n++] = by;
    _v[_n++] = cx;
    _v[_n++] = cy;
  }

  void addRect(Rect r) {
    tri(r.left, r.top, r.right, r.top, r.right, r.bottom);
    tri(r.left, r.top, r.right, r.bottom, r.left, r.bottom);
  }

  /// Einfaches Polygon: konvex als Fächer, sonst per Ohrenschneiden (Ear Clipping).
  void addPoly(List<Offset> pts) {
    final n = pts.length;
    if (n < 3) return;
    if (_isConvex(pts)) {
      for (var i = 1; i < n - 1; i++) {
        tri(pts[0].dx, pts[0].dy, pts[i].dx, pts[i].dy, pts[i + 1].dx, pts[i + 1].dy);
      }
      return;
    }
    final sign = _area(pts) >= 0 ? 1.0 : -1.0;
    final idx = List<int>.generate(n, (i) => i);
    var guard = n * n;
    while (idx.length > 3 && guard-- > 0) {
      for (var k = 0; k < idx.length; k++) {
        final a = pts[idx[(k - 1 + idx.length) % idx.length]], b = pts[idx[k]], c = pts[idx[(k + 1) % idx.length]];
        if (_cross(a, b, c) * sign <= 0) continue; // spitze Ecke nach innen
        var inside = false;
        for (final j in idx) {
          final p = pts[j];
          if (p == a || p == b || p == c) continue;
          if (_inTri(p, a, b, c)) {
            inside = true;
            break;
          }
        }
        if (inside) continue;
        tri(a.dx, a.dy, b.dx, b.dy, c.dx, c.dy);
        idx.removeAt(k);
        break;
      }
    }
    if (idx.length == 3) {
      final a = pts[idx[0]], b = pts[idx[1]], c = pts[idx[2]];
      tri(a.dx, a.dy, b.dx, b.dy, c.dx, c.dy);
    }
  }

  static double _cross(Offset a, Offset b, Offset c) => (b.dx - a.dx) * (c.dy - b.dy) - (b.dy - a.dy) * (c.dx - b.dx);

  static double _area(List<Offset> pts) {
    var s = 0.0;
    for (var i = 0; i < pts.length; i++) {
      final a = pts[i], b = pts[(i + 1) % pts.length];
      s += a.dx * b.dy - b.dx * a.dy;
    }
    return s;
  }

  static bool _isConvex(List<Offset> pts) {
    var sign = 0.0;
    for (var i = 0; i < pts.length; i++) {
      final c = _cross(pts[i], pts[(i + 1) % pts.length], pts[(i + 2) % pts.length]);
      if (c == 0) continue;
      if (sign == 0) {
        sign = c.sign;
      } else if (c.sign != sign) {
        return false;
      }
    }
    return true;
  }

  static bool _inTri(Offset p, Offset a, Offset b, Offset c) {
    final d1 = _cross(a, b, p), d2 = _cross(b, c, p), d3 = _cross(c, a, p);
    final neg = d1 < 0 || d2 < 0 || d3 < 0, pos = d1 > 0 || d2 > 0 || d3 > 0;
    return !(neg && pos);
  }

  /// Oval als Fächer; Segmentzahl wächst mit der Größe, damit große Ovale rund bleiben.
  void addOval(Rect r, [int? segments]) {
    final cx = r.center.dx, cy = r.center.dy, rx = r.width / 2, ry = r.height / 2;
    segments ??= ((rx + ry) / 3).round().clamp(12, 72);
    var px = cx + rx, py = cy;
    for (var i = 1; i <= segments; i++) {
      final a = i / segments * pi * 2;
      final nx = cx + cos(a) * rx, ny = cy + sin(a) * ry;
      tri(cx, cy, px, py, nx, ny);
      px = nx;
      py = ny;
    }
  }

  /// Kreisbogen samt Sehne als gefüllte Fläche (z. B. Pilzhut).
  void addArc(Rect r, double start, double sweep, [int segments = 10]) {
    final cx = r.center.dx, cy = r.center.dy, rx = r.width / 2, ry = r.height / 2;
    final pts = <Offset>[
      for (var i = 0; i <= segments; i++)
        Offset(cx + cos(start + sweep * i / segments) * rx, cy + sin(start + sweep * i / segments) * ry),
    ];
    addPoly(pts);
  }

  /// Fläche zwischen zwei Linien gleicher Länge (oben/unten), z. B. Gelände oder Schnee.
  void addStrip(List<Offset> top, List<Offset> bottom) {
    for (var i = 0; i < top.length - 1; i++) {
      final a = top[i], b = top[i + 1], c = bottom[i + 1], d = bottom[i];
      tri(a.dx, a.dy, b.dx, b.dy, c.dx, c.dy);
      tri(a.dx, a.dy, c.dx, c.dy, d.dx, d.dy);
    }
  }

  /// Gelände: Fläche von der Linie [top] senkrecht hinunter bis [bottom].
  void addTerrain(List<Offset> top, double bottom) {
    for (var i = 0; i < top.length - 1; i++) {
      final a = top[i], b = top[i + 1];
      tri(a.dx, a.dy, b.dx, b.dy, b.dx, bottom);
      tri(a.dx, a.dy, b.dx, bottom, a.dx, bottom);
    }
  }

  void draw(Canvas c, Paint paint) {
    if (_n == 0) return;
    c.drawVertices(Vertices.raw(VertexMode.triangles, Float32List.sublistView(_v, 0, _n)), BlendMode.srcOver, paint);
  }
}
