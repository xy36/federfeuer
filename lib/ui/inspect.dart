import 'package:flutter/material.dart';

import '../game/config.dart';
import 'widgets.dart';

/// Macht ein Element im Menü ansteuerbar (Tastatur, Controller, Maus) und zeigt bei
/// Fokus oder Maus darüber ein Info-Panel daneben. Es ist immer nur ein Panel offen.
/// [focusable]: selbst fokussierbar (für Anzeigen ohne eigenen Knopf); sonst reagiert
/// es auf den Fokus eines Knopfes darin (z. B. einer Angebotskarte).
class Inspectable extends StatefulWidget {
  const Inspectable({
    super.key,
    required this.info,
    required this.child,
    this.focusable = false,
    this.radius = 12,
    this.onShow,
  });
  final WidgetBuilder info;

  /// Meldet, wenn das Info-Panel dieses Elements auf- bzw. zugeht (z. B. zum Hervorheben).
  final ValueChanged<bool>? onShow;
  final Widget child;
  final bool focusable;
  final double radius;

  @override
  State<Inspectable> createState() => _InspectableState();
}

class _InspectableState extends State<Inspectable> {
  /// Das Element, dessen Panel gerade offen ist, und das zuletzt fokussierte.
  static final _active = ValueNotifier<_InspectableState?>(null);
  static _InspectableState? _focused;

  final _portal = OverlayPortalController();
  final _key = GlobalKey();
  bool _focus = false, _hover = false;

  /// Eigener Fokusknoten: Selbst fokussierbare Elemente reagieren nur auf eigenen Fokus,
  /// damit ein Knopf darin (z. B. „Verschmelzen“ im Waffenslot) sein eigenes Panel zeigt.
  final _node = FocusNode(debugLabel: 'Inspectable');

  void _onNode() {
    final f = widget.focusable ? _node.hasPrimaryFocus : _node.hasFocus;
    if (f != _focus) _onFocus(f);
  }

  @override
  void initState() {
    super.initState();
    _node.addListener(_onNode);
    _active.addListener(_sync);
  }

  @override
  void dispose() {
    _node
      ..removeListener(_onNode)
      ..dispose();
    _active.removeListener(_sync);
    if (_focused == this) _focused = null;
    if (_active.value == this) {
      // Nicht während des Abbaus benachrichtigen
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_active.value == this) _active.value = null;
      });
    }
    super.dispose();
  }

  void _sync() {
    if (!mounted) return;
    final show = _active.value == this;
    if (show && !_portal.isShowing) {
      _portal.show();
      widget.onShow?.call(true);
    }
    if (!show && _portal.isShowing) {
      _portal.hide();
      widget.onShow?.call(false);
    }
  }

  void _onFocus(bool v) {
    setState(() => _focus = v);
    if (v) {
      _focused = this;
      _active.value = this;
    } else {
      if (_focused == this) _focused = null;
      if (_active.value == this && !_hover) _active.value = null;
    }
  }

  void _onHover(bool v) {
    _hover = v;
    if (v) {
      _active.value = this;
    } else if (_active.value == this) {
      _active.value = _focused;
    }
  }

  @override
  Widget build(BuildContext context) {
    Widget child = KeyedSubtree(key: _key, child: widget.child);
    if (widget.focusable) {
      // Eigener Fokusrahmen für Anzeigen ohne Knopf
      child = AnimatedContainer(
        duration: const Duration(milliseconds: 100),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(widget.radius),
          border: Border.all(color: _focus ? Colors.white : Colors.transparent, width: 2),
          boxShadow: [if (_focus) const BoxShadow(color: Color(0x66FFFFFF), blurRadius: 14)],
        ),
        child: child,
      );
    }
    return OverlayPortal(
      controller: _portal,
      overlayChildBuilder: _overlay,
      child: Focus(
        canRequestFocus: widget.focusable,
        skipTraversal: !widget.focusable,
        focusNode: _node,
        child: MouseRegion(onEnter: (_) => _onHover(true), onExit: (_) => _onHover(false), child: child),
      ),
    );
  }

  Widget _overlay(BuildContext context) {
    final box = _key.currentContext?.findRenderObject();
    if (box is! RenderBox || !box.attached || !box.hasSize) return const SizedBox.shrink();
    final rect = Rect.fromPoints(box.localToGlobal(Offset.zero), box.localToGlobal(box.size.bottomRight(Offset.zero)));
    final screen = MediaQuery.sizeOf(context);
    final k = uiScaleFor(screen.width, screen.height);
    return IgnorePointer(
      child: CustomSingleChildLayout(
        delegate: _InfoLayout(rect, k),
        child: Transform.scale(
          scale: k,
          alignment: Alignment.topLeft,
          child: InfoCard(child: Builder(builder: widget.info)),
        ),
      ),
    );
  }
}

/// Setzt das Panel rechts neben das Element, sonst links, sonst darunter; immer im Bild.
class _InfoLayout extends SingleChildLayoutDelegate {
  _InfoLayout(this.target, this.k);
  final Rect target;
  final double k;

  @override
  BoxConstraints getConstraintsForChild(BoxConstraints constraints) => const BoxConstraints(maxWidth: InfoCard.width);

  @override
  Offset getPositionForChild(Size size, Size child) {
    final w = child.width * k, h = child.height * k;
    const gap = 10.0, margin = 8.0;
    double x, y;
    if (target.right + gap + w <= size.width - margin) {
      x = target.right + gap;
      y = target.top;
    } else if (target.left - gap - w >= margin) {
      x = target.left - gap - w;
      y = target.top;
    } else {
      x = target.center.dx - w / 2;
      y = target.bottom + gap;
      if (y + h > size.height - margin) y = target.top - gap - h;
    }
    x = x.clamp(margin, (size.width - w - margin).clamp(margin, double.infinity));
    y = y.clamp(margin, (size.height - h - margin).clamp(margin, double.infinity));
    return Offset(x, y);
  }

  @override
  bool shouldRelayout(_InfoLayout old) => old.target != target || old.k != k;
}

/// Glas-Panel für Detail-Infos.
class InfoCard extends StatelessWidget {
  const InfoCard({super.key, required this.child});
  static const width = 300.0;
  final Widget child;

  @override
  Widget build(BuildContext context) => Material(
        type: MaterialType.transparency,
        child: Container(
          width: width,
          padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
          decoration: BoxDecoration(
            color: const Color(0xF20A0F24),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: Ui.edge, width: 1.4),
            boxShadow: const [
              BoxShadow(color: Color(0x99000000), blurRadius: 24, offset: Offset(0, 6)),
              BoxShadow(color: Color(0x339FD8FF), blurRadius: 18),
            ],
          ),
          child: child,
        ),
      );
}
