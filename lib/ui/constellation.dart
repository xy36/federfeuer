import 'dart:math';

import 'package:flutter/material.dart';

import '../game/config.dart';
import '../game/progress.dart';
import '../game/run_state.dart';
import '../game/components/light.dart';
import 'inspect.dart';
import 'inspect_info.dart';
import 'widgets.dart';

/// Sternbild der Verschmelzungen: Aktionen als Sterne auf einem Kreis, jedes Rezept
/// als Lichtlinie zwischen den Zutaten mit der Evolution als goldenem Stern in der Mitte.
/// Unentdeckt gestrichelt, gesehen schwach leuchtend, selbst verschmolzen golden mit
/// wandernden Lichtpartikeln. Ein angewählter Stern hebt seine Verbindungen hervor.
class ActionConstellation extends StatefulWidget {
  const ActionConstellation({super.key, required this.progress, required this.reference, this.height = 500});
  final Progress progress;

  /// Neutraler Run für die Info-Panels.
  final RunState reference;
  final double height;

  /// Reihenfolge auf dem Kreis: Rezeptpartner möglichst nebeneinander.
  /// Jede Vogel-Aktion sitzt zwischen ihren beiden Rezeptpartnern.
  static const order = [
    ActionId.whirlwind, // zwischen Lichtblitz (am Kreis vorn) und Platzregen
    ActionId.downpour,
    ActionId.bubbleShield,
    ActionId.egg,
    ActionId.quake,
    ActionId.fireBomb,
    ActionId.screech,
    ActionId.flash,
  ];

  @override
  State<ActionConstellation> createState() => _ActionConstellationState();
}

class _ActionConstellationState extends State<ActionConstellation> with SingleTickerProviderStateMixin {
  late final AnimationController _t = AnimationController(vsync: this, duration: const Duration(seconds: 3))..repeat();

  /// Angewählter Stern (Aktion oder Evolution).
  ActionId? _hot;

  Progress get p => widget.progress;

  @override
  void dispose() {
    _t.dispose();
    super.dispose();
  }

  void _setHot(ActionId id, bool on) => setState(() {
        if (on) {
          _hot = id;
        } else if (_hot == id) {
          _hot = null;
        }
      });

  @override
  Widget build(BuildContext context) => LayoutBuilder(builder: (context, box) {
        final w = box.maxWidth, h = widget.height;
        final center = Offset(w / 2, h / 2);
        // Ellipse über die volle Breite, damit Nachbarn und ihre Evolutionen Platz haben
        final rx = w / 2 - 70, ry = h / 2 - 46;
        final pos = <ActionId, Offset>{};
        const order = ActionConstellation.order;
        for (var i = 0; i < order.length; i++) {
          final a = -pi / 2 + i / order.length * pi * 2;
          pos[order[i]] = center + Offset(cos(a) * rx, sin(a) * ry);
        }
        final mids = _layoutStars(pos, center, Size(w, h));
        final links = [
          for (final r in actionRecipes)
            _Link(r, pos[r.a]!, pos[r.b]!, mids[r.result]!, p.hasSeen('r:${r.result.name}'), p.hasEvolved(r.result)),
        ];
        final nodes = [
          for (final a in order) _Node(pos[a]!, p.hasSeen('a:${a.name}'), _isHot(a)),
        ];
        final evolved = actionRecipes.where((r) => p.hasEvolved(r.result)).length;
        return SizedBox(
          width: w,
          height: h,
          child: Stack(clipBehavior: Clip.none, children: [
            Positioned.fill(
              child: AnimatedBuilder(
                animation: _t,
                builder: (context, _) => CustomPaint(
                  painter: _LinksPainter(links, nodes, _hot, _t.value, center, rx, ry),
                ),
              ),
            ),
            Positioned(
              left: 16,
              top: 12,
              child: Text('$evolved / ${actionRecipes.length} verschmolzen',
                  style: displayStyle(12, const Color(0xFFFFE6A0)).copyWith(letterSpacing: 2)),
            ),
            for (final l in links) _evoStar(l),
            for (final a in order) _node(a, pos[a]!),
          ]),
        );
      });

  /// Startpunkte der Evolutionen, dann einige Schritte Abstoßung untereinander und von den
  /// Aktions-Sternen, damit nichts überlappt; jeder Stern bleibt nah an seiner Linie.
  Map<ActionId, Offset> _layoutStars(Map<ActionId, Offset> pos, Offset center, Size size) {
    final start = {for (final r in actionRecipes) r.result: _evoPos(pos[r.a]!, pos[r.b]!, center)};
    final cur = Map.of(start);
    const minStar = 44.0, minNode = 58.0;
    for (var it = 0; it < 60; it++) {
      for (final a in actionRecipes) {
        var push = Offset.zero;
        final pa = cur[a.result]!;
        for (final b in actionRecipes) {
          if (identical(a, b)) continue;
          final d = pa - cur[b.result]!;
          final len = d.distance;
          if (len < minStar) push += (len < 0.1 ? const Offset(1, 0) : d / len) * (minStar - len) * 0.5;
        }
        for (final n in pos.values) {
          final d = pa - n;
          final len = d.distance;
          if (len < minNode) push += (len < 0.1 ? const Offset(0, 1) : d / len) * (minNode - len) * 0.5;
        }
        // Leichter Zug zurück zum Startpunkt auf der Linie
        push += (start[a.result]! - pa) * 0.05;
        cur[a.result] = Offset((pa + push).dx.clamp(24, size.width - 24), (pa + push).dy.clamp(24, size.height - 24));
      }
    }
    return cur;
  }

  /// Evolution auf der Linie; Linien quer durch die Mitte rücken etwas zur kürzeren Seite.
  Offset _evoPos(Offset a, Offset b, Offset center) {
    final m = (a + b) / 2;
    final d = m - center;
    if (d.distance < 40) {
      final n = d.distance < 1 ? Offset(-(b - a).dy, (b - a).dx) / (b - a).distance : d / d.distance;
      return m + n * 34;
    }
    // Sonst etwas nach innen, damit der Stern nicht auf den Beschriftungen sitzt
    return m - d / d.distance * 20;
  }

  bool _isHot(ActionId a) =>
      _hot == a || (_hot != null && actionRecipes.any((r) => r.result == _hot && (r.a == a || r.b == a)));

  Widget _node(ActionId a, Offset at) {
    final known = p.hasSeen('a:${a.name}');
    final hot = _isHot(a);
    const size = 46.0;
    return Positioned(
      left: at.dx - 50,
      top: at.dy - size / 2,
      width: 100,
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Inspectable(
          focusable: true,
          radius: 999,
          onShow: (v) => _setHot(a, v),
          info: (_) => known
              ? actionInfo(widget.reference, OwnedAction(a), 0)
              : unknownInfo(itemDefs.any((it) => it.action == a) ? 'Taucht im Aktions-Feld des Shops auf.' : 'Startfähigkeit eines Vogels.'),
          child: _orb(known ? ActionGlyph(a) : '?', size, hot ? Palette.sun : (known ? const Color(0xFFBFE3FF) : Ui.muted), known),
        ),
        const SizedBox(height: 3),
        Text(known ? a.label : '',
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: bodyText(10.5, color: hot ? Palette.sun : (known ? Ui.text : Ui.muted), weight: 900)),
      ]),
    );
  }

  Widget _evoStar(_Link l) {
    final r = l.recipe;
    const size = 34.0;
    const gold = Color(0xFFFFC94A);
    final hot = _hot == r.result || _hot == r.a || _hot == r.b;
    return Positioned(
      left: l.mid.dx - size / 2,
      top: l.mid.dy - size / 2,
      child: Inspectable(
        focusable: true,
        radius: 999,
        onShow: (v) => _setHot(r.result, v),
        info: (_) => l.seen
            ? recipeInfo(widget.reference, r, evolved: l.evolved)
            : unknownInfo('Besitze eine passende Aktion, um das Rezept zu sehen.'),
        child: _orb(l.seen ? ActionGlyph(r.result) : '?', size,
            hot ? Palette.sun : (l.evolved ? gold : (l.seen ? const Color(0xFFE8D9A8) : Ui.muted)), l.seen,
            star: true),
      ),
    );
  }

  Widget _orb(Object icon, double size, Color color, bool known, {bool star = false}) => Container(
        width: size,
        height: size,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: Color.alphaBlend(color.withAlpha(known ? 50 : 18), const Color(0xFF0A0F24)),
          border: Border.all(color: color.withAlpha(known ? (star ? 200 : 230) : 110), width: star ? 1.4 : 2),
          boxShadow: [if (known) BoxShadow(color: color.withAlpha(star ? 70 : 110), blurRadius: star ? 10 : 18)],
        ),
        child: icon is GlyphRef
            ? Glyph(icon, size: size * 0.78)
            : Text('$icon', style: TextStyle(fontSize: size * 0.45, color: known ? null : Ui.muted)),
      );
}

class _Link {
  _Link(this.recipe, this.a, this.b, this.mid, this.seen, this.evolved);
  final ActionRecipe recipe;
  final Offset a, b, mid;
  final bool seen, evolved;
}

class _Node {
  _Node(this.pos, this.known, this.hot);
  final Offset pos;
  final bool known, hot;
}

class _LinksPainter extends CustomPainter {
  _LinksPainter(this.links, this.nodes, this.hot, this.t, this.center, this.rx, this.ry);
  final List<_Link> links;
  final List<_Node> nodes;
  final ActionId? hot;
  final double t, rx, ry;
  final Offset center;

  static final _line = Paint()
    ..style = PaintingStyle.stroke
    ..strokeCap = StrokeCap.round
    ..blendMode = BlendMode.plus;

  /// Feste Hintergrundsterne (x, y relativ, Größe, Phase).
  static final _sky = () {
    final rng = Random(11);
    return [for (var i = 0; i < 110; i++) (rng.nextDouble(), rng.nextDouble(), 0.6 + rng.nextDouble() * 1.4, rng.nextDouble())];
  }();

  @override
  void paint(Canvas c, Size size) {
    const gold = Color(0xFFFFC94A), pale = Color(0xFFBFE3FF);
    final tau = t * pi * 2;

    // Nachthimmel: abgerundete Fläche mit Nebel in der Mitte
    final sky = RRect.fromRectAndRadius(Offset.zero & size, const Radius.circular(18));
    c.drawRRect(
      sky,
      Paint()
        ..shader = RadialGradient(
          center: Alignment.center,
          radius: 0.9,
          colors: const [Color(0xFF1C2350), Color(0xFF0D1230), Color(0xFF070A1C)],
          stops: const [0, 0.55, 1],
        ).createShader(Offset.zero & size),
    );
    c.save();
    c.clipRRect(sky);
    Glow.draw(c, center.dx - rx * 0.35, center.dy - ry * 0.2, ry * 1.1, const Color(0x2E7A5CFF));
    Glow.draw(c, center.dx + rx * 0.4, center.dy + ry * 0.25, ry * 0.9, const Color(0x2442B4FF));
    for (final (x, y, r, ph) in _sky) {
      final tw = 0.35 + 0.65 * (0.5 + 0.5 * sin(tau + ph * 6.28));
      c.drawCircle(Offset(x * size.width, y * size.height), r * 0.6,
          Paint()..color = Colors.white.withValues(alpha: 0.5 * tw));
    }
    c.restore();

    // Umlaufbahn: feine Ellipse durch alle Sterne
    _line
      ..strokeWidth = 1
      ..color = pale.withValues(alpha: 0.12);
    c.drawOval(Rect.fromCenter(center: center, width: rx * 2, height: ry * 2), _line);

    // Lichthöfe unter den Sternen, atmend
    for (var i = 0; i < nodes.length; i++) {
      final n = nodes[i];
      final breathe = 0.8 + 0.2 * sin(tau + i * 0.9);
      final col = n.hot ? gold : (n.known ? pale : const Color(0xFF8A94B8));
      Glow.draw(c, n.pos.dx, n.pos.dy, (n.known ? 60 : 40) * breathe, col.withValues(alpha: n.known || n.hot ? 0.45 : 0.18));
    }

    for (final l in links) {
      final r = l.recipe;
      final isHot = hot != null && (hot == r.a || hot == r.b || hot == r.result);
      final col = isHot || l.evolved ? gold : (l.seen ? pale : const Color(0xFF6C7590));
      final alpha = isHot ? 1.0 : (l.evolved ? 0.55 : (l.seen ? 0.4 : 0.3));
      // Leicht gebogene Lichtbahnen statt starrer Linien
      for (final (from, to) in [(l.a, l.mid), (l.b, l.mid)]) {
        final path = _arc(from, to);
        if (l.seen || isHot) {
          _line
            ..strokeWidth = isHot ? 10 : 6
            ..color = col.withValues(alpha: 0.16 * alpha);
          c.drawPath(path, _line);
          _line
            ..strokeWidth = isHot ? 2.4 : 1.5
            ..color = col.withValues(alpha: alpha);
          c.drawPath(path, _line);
        } else {
          _dashed(c, path, col.withValues(alpha: alpha));
        }
        if (l.evolved || isHot) {
          final metric = path.computeMetrics().first;
          for (var k = 0; k < 3; k++) {
            final f = (t + k / 3) % 1;
            final pt = metric.getTangentForOffset(metric.length * f)!.position;
            Glow.draw(c, pt.dx, pt.dy, 10, col.withValues(alpha: 0.9 * sin(f * pi)));
          }
        }
      }
      // Schein um die Evolution
      if (l.evolved || isHot) {
        Glow.draw(c, l.mid.dx, l.mid.dy, 26, gold.withValues(alpha: isHot ? 0.3 : 0.15));
      }
    }
  }

  /// Sanfter Bogen von [a] nach [b] (zur Mitte der Ellipse hin gekrümmt).
  Path _arc(Offset a, Offset b) {
    final m = (a + b) / 2;
    final toCenter = center - m;
    final bend = toCenter.distance < 1 ? Offset.zero : toCenter / toCenter.distance * min(18.0, (b - a).distance * 0.12);
    return Path()
      ..moveTo(a.dx, a.dy)
      ..quadraticBezierTo(m.dx + bend.dx, m.dy + bend.dy, b.dx, b.dy);
  }

  void _dashed(Canvas c, Path path, Color col) {
    _line
      ..strokeWidth = 1.2
      ..color = col;
    for (final m in path.computeMetrics()) {
      for (var d = 0.0; d < m.length; d += 9) {
        c.drawPath(m.extractPath(d, min(m.length, d + 4)), _line);
      }
    }
  }

  @override
  bool shouldRepaint(_LinksPainter old) => old.t != t || old.hot != hot || old.links != links;
}
