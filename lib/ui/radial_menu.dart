import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';

import '../game/gamepad_input.dart' show ModalMenu, openModalMenu;
import 'widgets.dart';

/// Eine Wahl im Kreismenü.
class RadialOption {
  const RadialOption({
    this.icon = '',
    required this.label,
    required this.color,
    required this.onPressed,
    this.price,
    this.gain = false,
  });
  final String icon;
  final String label;
  final Color color;

  /// null: grau und ohne Wirkung (z. B. „zu teuer“) – bleibt sichtbar, damit klar ist, warum.
  final VoidCallback? onPressed;

  /// Preis bzw. Erlös mit Material-Kristall statt [icon]; [gain]: mit „+“ (Verkaufen).
  final int? price;
  final bool gain;
}

/// Kreismenü: Ist [open], legt sich ein Ring aus leuchtenden Glas-Segmenten um [child] –
/// ein Segment je Option (2: oben/unten, 3: Drittel ab oben, …). Das gewählte Segment
/// rückt nach außen und leuchtet, ein Lichtbogen am Innenrand zeigt darauf. Modal: Solange
/// es offen ist, lässt sich nichts anderes anwählen oder überfahren. Klick daneben, Esc oder
/// Controller-B schließt es; eine Wahl schließt es ebenfalls und führt sie dann aus.
class RadialMenu extends StatefulWidget {
  const RadialMenu({
    super.key,
    required this.open,
    required this.options,
    required this.onClose,
    required this.child,
    this.innerRadius = 38,
    this.thickness = 52,
  });
  final bool open;
  final List<RadialOption> options;
  final VoidCallback onClose;
  final Widget child;
  final double innerRadius, thickness;

  @override
  State<RadialMenu> createState() => _RadialMenuState();
}

class _RadialMenuState extends State<RadialMenu> implements ModalMenu {
  final _portal = OverlayPortalController();
  final _link = LayerLink();
  final _scope = FocusScopeNode(debugLabel: 'RadialMenu');
  List<FocusNode> _nodes = [];
  FocusNode? _restore;

  /// Gewähltes Segment (Fokus; die Maus wählt beim Überfahren).
  int _focused = -1;

  bool get _showing => widget.open && widget.options.isNotEmpty;

  /// Erste wählbare Option (sonst die erste) – dort beginnt der Fokus.
  int get _firstEnabled => max(0, widget.options.indexWhere((o) => o.onPressed != null)).clamp(0, _nodes.length - 1);

  @override
  void initState() {
    super.initState();
    _sync();
  }

  @override
  void didUpdateWidget(RadialMenu old) {
    super.didUpdateWidget(old);
    if (widget.options.length != _nodes.length) {
      _resetNodes();
      // Offen geblieben: Fokus auf die neuen Segmente
      if (_portal.isShowing) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted && _portal.isShowing && _nodes.isNotEmpty) _nodes[_firstEnabled].requestFocus();
        });
      }
    }
    _sync();
  }

  /// Öffnen/Schließen nach dem Frame – das Overlay darf nicht während des Bauens wechseln.
  void _sync() => WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        if (_showing && !_portal.isShowing) _show();
        if (!_showing && _portal.isShowing) _hide();
      });

  @override
  void dispose() {
    if (identical(openModalMenu, this)) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (identical(openModalMenu, this)) openModalMenu = null;
      });
    }
    for (final n in _nodes) {
      n.dispose();
    }
    _scope.dispose();
    super.dispose();
  }

  @override
  void close() => widget.onClose();

  @override
  bool get hidesInfo => true;

  /// Controller/Pfeile: das Segment, das in dieser Richtung liegt. Steht man schon dort
  /// (oder gleich nah daneben, z. B. „unten“ bei drei Segmenten), bleibt die Auswahl.
  @override
  void navigate(TraversalDirection dir) {
    final n = _nodes.length;
    if (n == 0) return;
    final target = switch (dir) {
      TraversalDirection.up => -pi / 2,
      TraversalDirection.right => 0.0,
      TraversalDirection.down => pi / 2,
      TraversalDirection.left => pi,
    };
    double diff(int k) {
      final x = (-pi / 2 + k * 2 * pi / n - target) % (2 * pi);
      return x > pi ? 2 * pi - x : x;
    }

    final cur = _nodes.indexWhere((f) => f.hasPrimaryFocus);
    final closest = [for (var k = 0; k < n; k++) diff(k)].reduce(min);
    final best = [for (var k = 0; k < n; k++) if (diff(k) < closest + 1e-6) k];
    if (!best.contains(cur)) _nodes[best.first].requestFocus();
  }

  void _resetNodes() {
    final old = _nodes;
    _nodes = [
      for (var k = 0; k < widget.options.length; k++)
        FocusNode(debugLabel: 'RadialOption')..addListener(() => _onFocus(k)),
    ];
    // Erst nach dem Frame freigeben, die alten Knoten hängen noch im Baum
    WidgetsBinding.instance.addPostFrameCallback((_) {
      for (final n in old) {
        n.dispose();
      }
    });
  }

  void _onFocus(int k) {
    if (!mounted || k >= _nodes.length) return;
    final now = _nodes[k].hasPrimaryFocus ? k : (_focused == k ? -1 : _focused);
    if (now != _focused) setState(() => _focused = now);
  }

  void _show() {
    if (_nodes.length != widget.options.length) _resetNodes();
    _restore = FocusManager.instance.primaryFocus;
    openModalMenu = this;
    setState(_portal.show);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && _portal.isShowing && _nodes.isNotEmpty) _nodes[_firstEnabled].requestFocus();
    });
  }

  void _hide() {
    if (identical(openModalMenu, this)) openModalMenu = null;
    setState(() {
      _portal.hide();
      _focused = -1;
    });
    final r = _restore;
    _restore = null;
    if (r != null && r.context != null && r.canRequestFocus) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (r.context != null) r.requestFocus();
      });
    }
  }

  @override
  Widget build(BuildContext context) => CompositedTransformTarget(
        link: _link,
        child: OverlayPortal(controller: _portal, overlayChildBuilder: _ring, child: widget.child),
      );

  /// Rand um den Ring für Schein und Hintergrund-Scheibe (malt über die Segmente hinaus).
  static const _pad = 40.0;

  Widget _ring(BuildContext context) {
    final opts = widget.options;
    final ri = widget.innerRadius, ro = ri + widget.thickness;
    final size = (ro + _pad) * 2, c = Offset(size / 2, size / 2);
    final n = opts.length, sweep = 2 * pi / n;
    Color colorOf(RadialOption o) => o.onPressed == null ? _disabled : o.color;
    final f = _focused;
    // Sperrfläche über allem anderen: kein Hover, kein Klick dahinter; Klick schließt
    return Stack(
      fit: StackFit.expand,
      children: [
        Positioned.fill(
          child: MouseRegion(
            opaque: true,
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTapDown: (_) => widget.onClose(),
              onSecondaryTapDown: (_) => widget.onClose(),
              child: const ColoredBox(color: Color(0x30050814)),
            ),
          ),
        ),
        Align(
          alignment: Alignment.topLeft,
          child: CompositedTransformFollower(
            link: _link,
            targetAnchor: Alignment.center,
            followerAnchor: Alignment.center,
            showWhenUnlinked: false,
            // Eigener Fokusbereich: Tab und Pfeile bleiben im Ring
            child: FocusScope(
              node: _scope,
              child: CallbackShortcuts(
                bindings: {
                  const SingleActivator(LogicalKeyboardKey.escape): widget.onClose,
                  const SingleActivator(LogicalKeyboardKey.arrowRight): () => navigate(TraversalDirection.right),
                  const SingleActivator(LogicalKeyboardKey.arrowDown): () => navigate(TraversalDirection.down),
                  const SingleActivator(LogicalKeyboardKey.arrowLeft): () => navigate(TraversalDirection.left),
                  const SingleActivator(LogicalKeyboardKey.arrowUp): () => navigate(TraversalDirection.up),
                },
                child: FocusTraversalGroup(
                  policy: WidgetOrderTraversalPolicy(),
                  child: SizedBox(
                    width: size,
                    height: size,
                    child: Stack(
                      children: [
                        // Dunkle Scheibe und Zeiger-Bogen zum gewählten Segment
                        Positioned.fill(
                          child: IgnorePointer(
                            child: TweenAnimationBuilder<double>(
                              tween: Tween(begin: 0, end: 1),
                              duration: const Duration(milliseconds: 180),
                              builder: (context, t, _) => TweenAnimationBuilder<double>(
                                tween: Tween(end: f < 0 ? -pi / 2 : -pi / 2 + f * sweep),
                                duration: const Duration(milliseconds: 140),
                                curve: Curves.easeOutCubic,
                                builder: (context, angle, _) => CustomPaint(
                                  painter: _BackdropPainter(
                                    c,
                                    ri,
                                    ro,
                                    t,
                                    pointer: f < 0 ? null : angle,
                                    pointerSweep: n == 1 ? 0.9 : sweep * 0.55,
                                    pointerColor: f < 0 || f >= n ? _disabled : colorOf(opts[f]),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                        for (var k = 0; k < n; k++)
                          Positioned.fill(
                            child: _segment(
                              opts[k],
                              k,
                              k < _nodes.length ? _nodes[k] : null,
                              c,
                              // Erstes Segment oben mittig, dann im Uhrzeigersinn
                              -pi / 2 + k * sweep - sweep / 2,
                              sweep,
                              colorOf(opts[k]),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  static const _disabled = Color(0xFF6C7590);

  Widget _segment(RadialOption o, int k, FocusNode? node, Offset c, double a0, double sweep, Color color) {
    final ri = widget.innerRadius, ro = ri + widget.thickness;
    final full = sweep >= 2 * pi - 1e-6;
    final mid = full ? -pi / 2 : a0 + sweep / 2, rm = (ri + ro) / 2;
    final dir = Offset(cos(mid), sin(mid));
    final labelW = min(92.0, max(58.0, (full ? 1.2 : sweep) * rm * 0.85));
    final enabled = o.onPressed != null;
    final path = _segmentPath(c, ri, ro, a0, a0 + sweep, full: full);
    final button = Pressable(
      focusNode: node,
      focusableWhenDisabled: true,
      onPressed: enabled
          ? () {
              widget.onClose();
              o.onPressed!();
            }
          : null,
      builder: (context, s) => TweenAnimationBuilder<double>(
        tween: Tween(end: s.focused ? 1 : 0),
        duration: const Duration(milliseconds: 130),
        curve: Curves.easeOut,
        builder: (context, h, _) {
          final shift = dir * (5 * h);
          final at = c + dir * rm + shift;
          final textColor = enabled ? Color.lerp(const Color(0xFFE4ECFF), Colors.white, h)! : Ui.muted;
          final glow = enabled ? glowShadows(color, 0.5 * h) : const <Shadow>[];
          return CustomPaint(
            painter: _SegmentPainter(path, c, ri, ro, color, h, enabled, shift),
            child: Stack(children: [
              Positioned(
                left: at.dx - labelW / 2,
                top: at.dy - 20,
                width: labelW,
                child: Column(mainAxisSize: MainAxisSize.min, children: [
                  SizedBox(
                    height: 21,
                    child: Center(
                      child: o.price != null
                          ? Row(mainAxisSize: MainAxisSize.min, children: [
                              Opacity(opacity: enabled ? 1 : 0.5, child: const MaterialGem(size: 7)),
                              const SizedBox(width: 5),
                              Text('${o.gain ? '+' : ''}${o.price}',
                                  style: numberStyle(16, textColor).copyWith(shadows: glow)),
                            ])
                          : GlyphText(o.icon, style: numberStyle(17, textColor).copyWith(shadows: glow)),
                    ),
                  ),
                  Text(
                    o.label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                    style: bodyText(10.5, color: textColor, weight: 900).copyWith(shadows: glow, letterSpacing: 0.2),
                  ),
                ]),
              ),
            ]),
          );
        },
      ),
    );
    // Segmente fächern beim Öffnen nacheinander auf
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: Duration(milliseconds: 200 + 45 * k),
      curve: Curves.easeOutBack,
      builder: (context, t, child) {
        final p = ((t * (200 + 45 * k) - 45 * k) / 200).clamp(0.0, 1.0);
        return Opacity(
          opacity: p,
          child: Transform.rotate(
            angle: (1 - p) * -0.35,
            child: Transform.scale(scale: 0.8 + 0.2 * t, child: child),
          ),
        );
      },
      // Treffer nur auf dem Segment; gezeichnet wird ohne Beschnitt (Schein, Beschriftung)
      child: _PathHit(
        path: path,
        // Maus darüber wählt das Segment (gleiche Hervorhebung wie mit Tastatur/Controller)
        child: MouseRegion(onEnter: (_) => node?.requestFocus(), child: button),
      ),
    );
  }
}

/// Ring-Segment mit gleich breiten Fugen und abgerundeten Ecken.
Path _segmentPath(Offset c, double ri, double ro, double a0, double a1, {bool full = false, double gap = 6, double cr = 7}) {
  if (full) {
    return Path()
      ..fillType = PathFillType.evenOdd
      ..addOval(Rect.fromCircle(center: c, radius: ro))
      ..addOval(Rect.fromCircle(center: c, radius: ri));
  }
  Offset at(double r, double a) => c + Offset(cos(a), sin(a)) * r;
  double hg(double r) => gap / 2 / r;
  final oa0 = a0 + hg(ro), oa1 = a1 - hg(ro), ia0 = a0 + hg(ri), ia1 = a1 - hg(ri);
  final co0 = at(ro, oa0), co1 = at(ro, oa1), ci0 = at(ri, ia0), ci1 = at(ri, ia1);
  final e1 = (ci1 - co1) / (ci1 - co1).distance, e0 = (co0 - ci0) / (co0 - ci0).distance;
  final corner = Radius.circular(cr);
  final rect = Rect.fromCircle(center: c, radius: ro), irect = Rect.fromCircle(center: c, radius: ri);
  return Path()
    ..moveTo(at(ro, oa0 + cr / ro).dx, at(ro, oa0 + cr / ro).dy)
    ..arcTo(rect, oa0 + cr / ro, (oa1 - cr / ro) - (oa0 + cr / ro), false)
    ..arcToPoint(co1 + e1 * cr, radius: corner)
    ..lineTo((ci1 - e1 * cr).dx, (ci1 - e1 * cr).dy)
    ..arcToPoint(at(ri, ia1 - cr / ri), radius: corner)
    ..arcTo(irect, ia1 - cr / ri, (ia0 + cr / ri) - (ia1 - cr / ri), false)
    ..arcToPoint(ci0 + e0 * cr, radius: corner)
    ..lineTo((co0 - e0 * cr).dx, (co0 - e0 * cr).dy)
    ..arcToPoint(at(ro, oa0 + cr / ro), radius: corner)
    ..close();
}

/// Nimmt Treffer (Klick, Maus) nur innerhalb von [path] an, beschneidet aber nichts.
class _PathHit extends SingleChildRenderObjectWidget {
  const _PathHit({required this.path, super.child});
  final Path path;

  @override
  RenderObject createRenderObject(BuildContext context) => _RenderPathHit(path);

  @override
  void updateRenderObject(BuildContext context, _RenderPathHit renderObject) => renderObject.path = path;
}

class _RenderPathHit extends RenderProxyBox {
  _RenderPathHit(this.path);
  Path path;

  @override
  bool hitTest(BoxHitTestResult result, {required Offset position}) =>
      path.contains(position) && super.hitTest(result, position: position);
}

/// Glas-Segment: dunkler Grund, Innenleuchten in der Segmentfarbe, feine Lichtkante;
/// gewählt ([h] → 1) heller, mit Schein und nach außen gerückt ([shift]).
class _SegmentPainter extends CustomPainter {
  _SegmentPainter(this.path, this.c, this.ri, this.ro, this.color, this.h, this.enabled, this.shift);
  final Path path;
  final Offset c, shift;
  final double ri, ro, h;
  final Color color;
  final bool enabled;

  static const _glass = Color(0xF20B1230);

  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.translate(shift.dx, shift.dy);
    final a = enabled ? 1.0 : 0.6;
    if (h > 0.01) {
      canvas.drawPath(
        path,
        Paint()
          ..color = color.withAlpha((120 * h * a).round())
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 12),
      );
    }
    canvas.drawPath(
      path,
      Paint()
        ..shader = RadialGradient(
          colors: [
            Color.alphaBlend(color.withAlpha(((22 + 40 * h) * a).round()), _glass),
            Color.alphaBlend(color.withAlpha(((60 + 80 * h) * a).round()), _glass),
          ],
          stops: [ri / (ro + 8), 1],
        ).createShader(Rect.fromCircle(center: c, radius: ro + 8)),
    );
    canvas.drawPath(
      path,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.2 + 0.8 * h
        ..color = Color.lerp(color.withAlpha((150 * a).round()), Color.lerp(color, Colors.white, 0.45)!, h)!,
    );
    canvas.restore();
  }

  @override
  bool shouldRepaint(_SegmentPainter old) =>
      old.h != h || old.color != color || old.enabled != enabled || old.path != path || old.shift != shift;
}

/// Weiche dunkle Scheibe hinter dem Ring (Lesbarkeit), feine Bahn am Innenrand und ein
/// leuchtender Zeiger-Bogen, der zum gewählten Segment zeigt.
class _BackdropPainter extends CustomPainter {
  _BackdropPainter(this.c, this.ri, this.ro, this.t,
      {required this.pointer, required this.pointerSweep, required this.pointerColor});
  final Offset c;
  final double ri, ro, t, pointerSweep;
  final double? pointer;
  final Color pointerColor;

  @override
  void paint(Canvas canvas, Size size) {
    final outer = ro + 30;
    canvas.drawCircle(
      c,
      outer,
      Paint()
        ..shader = RadialGradient(
          colors: [
            const Color(0x00050814),
            Color.fromARGB((150 * t).round(), 5, 8, 20),
            Color.fromARGB((120 * t).round(), 5, 8, 20),
            const Color(0x00050814),
          ],
          stops: [max(0.0, (ri - 14) / outer), ri / outer, ro / outer, 1],
        ).createShader(Rect.fromCircle(center: c, radius: outer)),
    );
    final rr = ri - 4;
    canvas.drawCircle(
      c,
      rr,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1
        ..color = Color.fromARGB((60 * t).round(), 207, 227, 255),
    );
    final p = pointer;
    if (p == null) return;
    final rect = Rect.fromCircle(center: c, radius: rr);
    canvas.drawArc(
      rect,
      p - pointerSweep / 2,
      pointerSweep,
      false,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 6
        ..strokeCap = StrokeCap.round
        ..color = pointerColor.withAlpha((130 * t).round())
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 5),
    );
    canvas.drawArc(
      rect,
      p - pointerSweep / 2,
      pointerSweep,
      false,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.5
        ..strokeCap = StrokeCap.round
        ..color = Color.lerp(pointerColor, Colors.white, 0.4)!.withAlpha((255 * t).round()),
    );
  }

  @override
  bool shouldRepaint(_BackdropPainter old) =>
      old.t != t || old.pointer != pointer || old.pointerColor != pointerColor || old.ri != ri || old.ro != ro;
}
