import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:gamepads/gamepads.dart';

import '../game/gamepad_input.dart' show controllerActive;
import '../game/components/glyph_art.dart';

export '../game/components/glyph_art.dart'
    show Glyph, GlyphRef, WeaponGlyph, ItemGlyph, ActionGlyph, StatGlyph, EnemyGlyph, BirdGlyph, UiGlyph, UiIcon, GlyphText, iconWidget;
import '../game/input_bindings.dart' show padLabel;

import '../game/config.dart';

bool get isTouchPlatform =>
    defaultTargetPlatform == TargetPlatform.android || defaultTargetPlatform == TargetPlatform.iOS;

// ---------------- Farben & Schrift ----------------

/// UI-Farben der Menüs: dunkles, durchscheinendes Glas mit Lichtkanten.
class Ui {
  static const panel = Color(0xD90A0F24);
  static const glass = Color(0xE60D1430);
  static const edge = Color(0x66CFE3FF);
  static const panelLine = Color(0x33CFE3FF);
  static const text = Color(0xFFF2F6FF);
  static const muted = Color(0xFF9FB0D0);
  static const cardText = Color(0xFFF2F6FF);
  static const cardMuted = Color(0xFF9FB0D0);
  static const badge = Color(0xCC050814);
  static const slot = Color(0x14CFE3FF);

  /// Neutraler Akzent für Knöpfe und Karten ohne eigene Farbe.
  static const card = Color(0xFFBFD4FF);
}

const _display = 'Cinzel';
const _body = 'Nunito';

/// Titel und Zahlen: elegante Versalien.
TextStyle displayStyle(double size, [Color color = Ui.text]) => TextStyle(
      fontFamily: _display,
      fontSize: size,
      color: color,
      height: 1.1,
      letterSpacing: size * 0.04,
      fontWeight: FontWeight.w700,
      fontVariations: const [FontVariation('wght', 700)],
    );

TextStyle bodyText(double size, {Color color = Ui.text, double weight = 700}) => TextStyle(
      fontFamily: _body,
      fontSize: size,
      color: color,
      height: 1.3,
      fontWeight: weight >= 800 ? FontWeight.w800 : FontWeight.w700,
      fontVariations: [FontVariation('wght', weight)],
    );

final mutedStyle = bodyText(13, color: Ui.muted);

/// Zahlen: klare, sehr fette Ziffern (Cinzel zeichnet die 1 wie ein römisches I).
TextStyle numberStyle(double size, [Color color = Ui.text]) => bodyText(size, color: color, weight: 900);

/// Weicher Schein um Text in Akzentfarbe.
List<Shadow> glowShadows(Color color, [double strength = 1]) => [
      Shadow(color: color.withAlpha((150 * strength).round()), blurRadius: 14),
      Shadow(color: color.withAlpha((90 * strength).round()), blurRadius: 4),
    ];

/// Kleine Überschrift über einem Abschnitt im Panel, mit feiner Lichtlinie.
Widget sectionTitle(String text, {EdgeInsets padding = const EdgeInsets.only(top: 14, bottom: 8)}) => Padding(
      padding: padding,
      child: Row(children: [
        Text(text.toUpperCase(), style: displayStyle(12.5, Ui.muted).copyWith(letterSpacing: 2.2)),
        const SizedBox(width: 10),
        Expanded(child: Container(height: 1, color: Ui.panelLine)),
      ]),
    );

// ---------------- Skalierung ----------------

/// Skaliert ein Overlay auf großen Bildschirmen gleichmäßig hoch: Layout in
/// Bezugsgröße (siehe [uiScaleFor]), dann auf den ganzen Bildschirm gestreckt.
class UiScale extends StatelessWidget {
  const UiScale({super.key, required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) => ValueListenableBuilder<double>(
        valueListenable: uiScaleSetting,
        builder: (context, _, _) => LayoutBuilder(builder: (context, box) {
          final k = uiScaleFor(box.maxWidth, box.maxHeight);
          // Immer dieselbe Struktur (auch bei k = 1), sonst ginge beim Umschalten,
          // z. B. durch eine andere Fenstergröße, der Zustand des Menüs verloren.
          // Feste Größe nötig: Flame gibt Overlays lockere Vorgaben, sonst bliebe die
          // FittedBox in Bezugsgröße und das Menü säße klein oben links.
          return SizedBox(
            width: box.maxWidth,
            height: box.maxHeight,
            child: FittedBox(
              fit: BoxFit.fill,
              child: SizedBox(width: box.maxWidth / k, height: box.maxHeight / k, child: child),
            ),
          );
        }),
      );
}

// ---------------- Panel ----------------

/// Abgedunkelter Hintergrund + zentriertes, scrollbares Glas-Panel.
class Panel extends StatelessWidget {
  const Panel({
    super.key,
    required this.child,
    this.maxWidth = 560,
    this.padding = const EdgeInsets.all(20),
    this.footer,
    this.hints = const [],
  });
  final Widget child;

  /// Controller-Hinweise unten im Panel (nur sichtbar, wenn mit Controller gespielt wird).
  final List<PadHint> hints;

  /// Feste Leiste unter dem Scrollbereich (z. B. „Welle starten“), immer sichtbar.
  final Widget? footer;
  final double maxWidth;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) {
    return SizedBox.expand(
      child: ColoredBox(
        color: const Color(0x73020410),
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(10),
            child: ConstrainedBox(
              constraints: BoxConstraints(maxWidth: maxWidth),
              child: Container(
                decoration: BoxDecoration(
                  color: Ui.panel,
                  borderRadius: BorderRadius.circular(22),
                  border: Border.all(color: Ui.edge, width: 1.2),
                  boxShadow: const [
                    BoxShadow(color: Color(0x2E9FD8FF), blurRadius: 40, spreadRadius: 2),
                    BoxShadow(color: Color(0x99000000), blurRadius: 30, offset: Offset(0, 10)),
                  ],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(21),
                  child: DecoratedBox(
                    // Lichtschimmer oben, als fiele Licht auf das Glas
                    decoration: const BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [Color(0x1FBFE3FF), Color(0x00BFE3FF)],
                        stops: [0, 0.4],
                      ),
                    ),
                    child: Column(mainAxisSize: MainAxisSize.min, children: [
                      Flexible(
                        child: SingleChildScrollView(
                          padding: padding,
                          child: DefaultTextStyle.merge(style: bodyText(14), child: child),
                        ),
                      ),
                      if (footer != null)
                        Container(
                          width: double.infinity,
                          padding: EdgeInsets.fromLTRB(padding.left, 8, padding.right, 6),
                          decoration: const BoxDecoration(
                            color: Color(0x660A0F24),
                            border: Border(top: BorderSide(color: Ui.panelLine, width: 1.2)),
                          ),
                          child: footer,
                        ),
                      if (hints.isNotEmpty)
                        ValueListenableBuilder<bool>(
                          valueListenable: controllerActive,
                          builder: (context, on, _) => !on
                              ? const SizedBox.shrink()
                              : Container(
                                  width: double.infinity,
                                  padding: EdgeInsets.fromLTRB(padding.left, 6, padding.right, 8),
                                  decoration: const BoxDecoration(
                                    color: Color(0x660A0F24),
                                    border: Border(top: BorderSide(color: Ui.panelLine, width: 1.2)),
                                  ),
                                  child: ControllerHints(hints),
                                ),
                        ),
                    ]),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Leuchtender Titel (Logo, Überschriften).
class OutlinedLabel extends StatelessWidget {
  const OutlinedLabel(this.text, {super.key, this.size = 48, this.color = Palette.sun, this.align = TextAlign.start});
  final String text;
  final double size;
  final Color color;
  final TextAlign align;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      textAlign: align,
      style: displayStyle(size, Color.lerp(color, Colors.white, 0.35)!).copyWith(
        height: 1.0,
        shadows: [
          Shadow(color: color.withAlpha(200), blurRadius: size * 0.45),
          Shadow(color: color.withAlpha(120), blurRadius: size * 0.12),
        ],
      ),
    );
  }
}

/// Kopfzeile eines Panels: großer Titel, optionale Zeile darunter, rechts etwas (z. B. Geld).
class PanelHeader extends StatelessWidget {
  const PanelHeader({super.key, required this.title, this.subtitle, this.trailing, this.color = Palette.sun});
  final String title;
  final Widget? subtitle;
  final Widget? trailing;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Expanded(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          OutlinedLabel(title, size: 28, color: color),
          if (subtitle != null) Padding(padding: const EdgeInsets.only(top: 8), child: subtitle),
        ]),
      ),
      ?trailing,
    ]);
  }
}

// ---------------- Bedienbare Flächen ----------------

class PressState {
  const PressState({required this.enabled, required this.focused, required this.hovered, required this.pressed});
  final bool enabled, focused, hovered, pressed;
  bool get highlighted => enabled && (focused || hovered);
}

/// Tipp-, Maus-, Tastatur- und Controller-bedienbare Fläche.
/// Enter/Leertaste bzw. Controller-A lösen [onPressed] über [ActivateIntent] aus.
class Pressable extends StatefulWidget {
  const Pressable(
      {super.key, required this.onPressed, required this.builder, this.focusNode, this.focusableWhenDisabled = false});
  final VoidCallback? onPressed;
  final FocusNode? focusNode;

  /// Auch ohne [onPressed] ansteuerbar (z. B. zu teure Angebote: ansehen, aber nicht kaufen).
  final bool focusableWhenDisabled;
  final Widget Function(BuildContext context, PressState state) builder;

  @override
  State<Pressable> createState() => _PressableState();
}

class _PressableState extends State<Pressable> {
  bool _focused = false, _hovered = false, _pressed = false;

  @override
  Widget build(BuildContext context) {
    final onPressed = widget.onPressed;
    final enabled = onPressed != null;
    return FocusableActionDetector(
      focusNode: widget.focusNode,
      enabled: enabled || widget.focusableWhenDisabled,
      mouseCursor: enabled ? SystemMouseCursors.click : SystemMouseCursors.basic,
      onFocusChange: (v) => setState(() => _focused = v),
      onShowHoverHighlight: (v) => setState(() => _hovered = v),
      actions: {
        ActivateIntent: CallbackAction<ActivateIntent>(onInvoke: (_) => onPressed?.call()),
        ButtonActivateIntent: CallbackAction<ButtonActivateIntent>(onInvoke: (_) => onPressed?.call()),
      },
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapDown: enabled ? (_) => setState(() => _pressed = true) : null,
        onTapCancel: () => setState(() => _pressed = false),
        onTapUp: (_) => setState(() => _pressed = false),
        onTap: onPressed,
        child: widget.builder(
          context,
          PressState(enabled: enabled, focused: _focused, hovered: _hovered, pressed: _pressed),
        ),
      ),
    );
  }
}

/// Leuchtendes Glas in Akzentfarbe [color]: Lichtkante und Schein werden bei
/// Fokus/Hover heller, das Glas hebt sich leicht; beim Tippen sinkt es ein.
/// Fokus zeigt zusätzlich einen weißen Lichtrand.
class Sticker extends StatelessWidget {
  const Sticker({
    super.key,
    required this.state,
    required this.child,
    this.color = Ui.card,
    this.radius = 16,
    this.depth = 5,
    this.padding = EdgeInsets.zero,
  });
  final PressState state;
  final Widget child;
  final Color color;
  final double radius, depth;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) {
    final on = state.highlighted;
    final accent = state.enabled ? color : const Color(0xFF6C7590);
    final lift = state.pressed ? 1.0 : (on ? -3.0 : 0.0);
    return AnimatedContainer(
      duration: const Duration(milliseconds: 120),
      curve: Curves.easeOut,
      transform: Matrix4.translationValues(0, lift, 0),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(radius),
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Color.alphaBlend(accent.withAlpha(on ? 70 : 46), Ui.glass),
            Color.alphaBlend(accent.withAlpha(on ? 26 : 12), Ui.glass),
          ],
        ),
        border: Border.all(
          color: state.focused ? Colors.white : accent.withAlpha(on ? 230 : 140),
          width: state.focused ? 2 : 1.4,
        ),
        boxShadow: [
          BoxShadow(color: accent.withAlpha(on ? 110 : (state.enabled ? 40 : 0)), blurRadius: on ? 22 : 12),
          if (state.focused) const BoxShadow(color: Color(0x66FFFFFF), blurRadius: 16),
        ],
      ),
      padding: padding,
      child: Opacity(opacity: state.enabled ? 1 : 0.55, child: child),
    );
  }
}

/// Knopf aus leuchtendem Glas; [color] ist der Akzent.
class GameButton extends StatelessWidget {
  const GameButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.color = Palette.sun,
    this.icon,
    this.glyph,
    this.size = 18,
  });
  final String label;
  final VoidCallback? onPressed;
  final Color color;
  final String? icon;

  /// Lichtsymbol statt [icon].
  final GlyphRef? glyph;
  final double size;

  @override
  Widget build(BuildContext context) {
    final textColor = Color.lerp(color, Colors.white, 0.55)!;
    return Pressable(
      onPressed: onPressed,
      builder: (context, s) => Padding(
        padding: const EdgeInsets.only(top: 4, bottom: 8),
        child: Sticker(
          state: s,
          color: color,
          radius: size * 1.4,
          padding: EdgeInsets.symmetric(horizontal: size * 1.0, vertical: size * 0.5),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            if (glyph != null)
              Padding(padding: const EdgeInsets.only(right: 8), child: Glyph(glyph!, size: size * 1.4))
            else if (icon != null)
              Padding(padding: const EdgeInsets.only(right: 8), child: iconWidget(icon!, size, color: textColor)),
            GlyphText(label, style: displayStyle(size * 0.9, textColor).copyWith(shadows: glowShadows(color, s.highlighted ? 1 : 0.5))),
          ]),
        ),
      ),
    );
  }
}

/// Text, in dem jeder Klassenname (Licht, Glut, Wind, Böse, Wasser, Stein) in seiner
/// Klassenfarbe erscheint – für Info-Panels, Waffenslots und Listen.
Widget classText(String text, TextStyle style, {int? maxLines, TextOverflow? overflow, TextAlign? textAlign}) {
  final spans = <InlineSpan>[];
  var last = 0;
  for (final m in _classPattern.allMatches(text)) {
    if (m.start > last) spans.add(TextSpan(text: text.substring(last, m.start)));
    final c = WeaponClass.values.firstWhere((c) => c.label == m[0]);
    spans.add(TextSpan(text: m[0], style: TextStyle(color: c.color, fontWeight: FontWeight.w900, shadows: glowShadows(c.color, 0.35))));
    last = m.end;
  }
  if (spans.isEmpty) return Text(text, style: style, maxLines: maxLines, overflow: overflow, textAlign: textAlign);
  if (last < text.length) spans.add(TextSpan(text: text.substring(last)));
  return Text.rich(TextSpan(children: spans), style: style, maxLines: maxLines, overflow: overflow, textAlign: textAlign);
}

final _classPattern = RegExp('(?<![A-Za-zÄÖÜäöüß])(${WeaponClass.values.map((c) => c.label).join('|')})(?![a-zäöüß])');

/// Zeichen einer Elementar-Reaktion: zwei leuchtende Kugeln in den Klassenfarben, die
/// ineinanderfließen, mit hellem Funken in der Mitte.
class ReactionBadge extends StatelessWidget {
  const ReactionBadge(this.reaction, {super.key, this.size = 40});
  final Reaction reaction;
  final double size;

  @override
  Widget build(BuildContext context) => CustomPaint(size: Size.square(size), painter: _ReactionPainter(reaction));
}

class _ReactionPainter extends CustomPainter {
  _ReactionPainter(this.re);
  final Reaction re;

  @override
  void paint(Canvas c, Size size) {
    final s = size.shortestSide, m = size.center(Offset.zero);
    for (final (dx, col) in [(-0.17, re.a.color), (0.17, re.b.color)]) {
      final at = m + Offset(dx * s, 0);
      c.drawCircle(
          at,
          s * 0.34,
          Paint()
            ..shader = RadialGradient(colors: [col, col.withAlpha(110), col.withAlpha(0)], stops: const [0, 0.55, 1])
                .createShader(Rect.fromCircle(center: at, radius: s * 0.34))
            ..blendMode = BlendMode.plus);
    }
    c.drawCircle(m, s * 0.09, Paint()..color = Color.lerp(re.color, Colors.white, 0.6)!);
  }

  @override
  bool shouldRepaint(_ReactionPainter old) => old.re != re;
}

/// Auswahlliste im Glas-Stil: Knopf mit aktuellem Wert, darunter klappt die Liste auf.
/// Bedienbar mit Maus, Tastatur und Controller; Esc bzw. Controller-B schließt nur die Liste.
class GameDropdown<T> extends StatefulWidget {
  const GameDropdown({
    super.key,
    required this.value,
    required this.items,
    required this.labelOf,
    required this.onChanged,
    this.width = 220,
  });
  final T value;
  final List<T> items;
  final String Function(T) labelOf;
  final ValueChanged<T> onChanged;
  final double width;

  /// Schließt eine offene Liste; true, wenn eine offen war (für Controller-B).
  static bool closeOpen() {
    final open = _GameDropdownState._open;
    if (open == null) return false;
    open._close();
    return true;
  }

  @override
  State<GameDropdown<T>> createState() => _GameDropdownState<T>();
}

class _GameDropdownState<T> extends State<GameDropdown<T>> {
  static _GameDropdownState<dynamic>? _open;

  final _portal = OverlayPortalController();
  final _link = LayerLink();
  final _buttonFocus = FocusNode();
  final _tapGroup = Object();
  List<FocusNode> _itemFocus = [];

  @override
  void dispose() {
    if (identical(_open, this)) _open = null;
    _buttonFocus.dispose();
    for (final f in _itemFocus) {
      f.dispose();
    }
    super.dispose();
  }

  void _toggle() => _portal.isShowing ? _close() : _show();

  void _show() {
    GameDropdown.closeOpen();
    for (final f in _itemFocus) {
      f.dispose();
    }
    _itemFocus = [for (final _ in widget.items) FocusNode()];
    _open = this;
    setState(_portal.show);
    final i = widget.items.indexOf(widget.value);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && _portal.isShowing) _itemFocus[i < 0 ? 0 : i].requestFocus();
    });
  }

  void _close({bool refocus = true}) {
    if (identical(_open, this)) _open = null;
    if (!_portal.isShowing) return;
    setState(_portal.hide);
    if (refocus) _buttonFocus.requestFocus();
  }

  void _select(T item) {
    _close();
    if (item != widget.value) widget.onChanged(item);
  }

  @override
  Widget build(BuildContext context) => TapRegion(
        groupId: _tapGroup,
        child: CompositedTransformTarget(
          link: _link,
          child: OverlayPortal(
            controller: _portal,
            overlayChildBuilder: _menu,
            child: SizedBox(
              width: widget.width,
              child: Pressable(
                focusNode: _buttonFocus,
                onPressed: _toggle,
                builder: (context, s) => Padding(
                  padding: const EdgeInsets.only(top: 4, bottom: 8),
                  child: Sticker(
                    state: s,
                    radius: 14,
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                    child: Row(children: [
                      Expanded(
                        child: Text(widget.labelOf(widget.value),
                            style: numberStyle(13.5), maxLines: 1, overflow: TextOverflow.ellipsis),
                      ),
                      Glyph(UiGlyph(_portal.isShowing ? UiIcon.up : UiIcon.down, color: Ui.muted), size: 14),
                    ]),
                  ),
                ),
              ),
            ),
          ),
        ),
      );

  Widget _menu(BuildContext context) => Align(
        alignment: Alignment.topLeft,
        child: CompositedTransformFollower(
          link: _link,
          targetAnchor: Alignment.bottomLeft,
          offset: const Offset(0, -4),
          showWhenUnlinked: false,
          child: TapRegion(
            groupId: _tapGroup,
            onTapOutside: (_) => _close(refocus: false),
            child: CallbackShortcuts(
              bindings: {const SingleActivator(LogicalKeyboardKey.escape): _close},
              // Eigener Bereich: Pfeiltasten bleiben in der Liste.
              child: FocusScope(
                child: Container(
                  width: widget.width,
                  constraints: const BoxConstraints(maxHeight: 300),
                  decoration: BoxDecoration(
                    color: Ui.glass,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: Ui.edge, width: 1.4),
                    boxShadow: const [BoxShadow(color: Color(0xAA000000), blurRadius: 18)],
                  ),
                  padding: const EdgeInsets.all(4),
                  child: SingleChildScrollView(
                    child: Column(mainAxisSize: MainAxisSize.min, children: [
                      for (var i = 0; i < widget.items.length; i++) _option(i),
                    ]),
                  ),
                ),
              ),
            ),
          ),
        ),
      );

  Widget _option(int i) {
    final item = widget.items[i];
    final selected = item == widget.value;
    return Pressable(
      focusNode: _itemFocus[i],
      onPressed: () => _select(item),
      builder: (context, s) => AnimatedContainer(
        duration: const Duration(milliseconds: 100),
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
        decoration: BoxDecoration(
          color: s.highlighted ? Ui.card.withAlpha(46) : Colors.transparent,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: s.focused ? Colors.white : Colors.transparent, width: 1.4),
        ),
        child: Text(widget.labelOf(item),
            style: numberStyle(13.5, selected ? Palette.sun : (s.highlighted ? Ui.text : Ui.muted))),
      ),
    );
  }
}

/// Auswahlkarte (Waffe, Item, Level-up). Die ganze Karte ist der Knopf.
/// Oben ein leuchtendes Band in Akzentfarbe (Stufe/Seltenheit), unten eine Fußzeile.
class ChoiceCard extends StatelessWidget {
  const ChoiceCard({
    super.key,
    required this.accent,
    required this.icon,
    this.glyph,
    required this.title,
    required this.body,
    required this.footer,
    required this.onPressed,
    this.badge,
    this.badgeColor = Ui.badge,
    this.width = 176,
    this.height = 196,
    this.focusableWhenDisabled = false,
  });

  final Color accent;
  final String icon, title;

  /// Lichtsymbol statt [icon].
  final GlyphRef? glyph;
  final String? badge;
  final Color badgeColor;
  final Widget body, footer;
  final VoidCallback? onPressed;
  final double width, height;

  /// Auch ohne [onPressed] ansteuerbar (Info-Panel ansehen).
  final bool focusableWhenDisabled;

  @override
  Widget build(BuildContext context) {
    return Pressable(
      onPressed: onPressed,
      focusableWhenDisabled: focusableWhenDisabled,
      builder: (context, s) => Padding(
        padding: const EdgeInsets.only(top: 4, bottom: 10),
        child: SizedBox(
          width: width,
          height: height,
          child: Sticker(
            state: s,
            color: accent,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(15),
              child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                Container(
                  height: 44,
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [accent.withAlpha(120), accent.withAlpha(20)],
                    ),
                  ),
                  child: Row(children: [
                    if (glyph != null)
                      Glyph(glyph!, size: glyph is WeaponGlyph ? 28 : 36)
                    else
                      Container(
                        width: 32,
                        height: 32,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: const Color(0x66050814),
                          boxShadow: [BoxShadow(color: accent.withAlpha(140), blurRadius: 12)],
                        ),
                        child: Text(icon, style: const TextStyle(fontSize: 18)),
                      ),
                    const Spacer(),
                    if (badge != null) Pill(badge!, color: badgeColor, textColor: Colors.white, size: 10.5),
                  ]),
                ),
                Container(height: 1.2, color: accent.withAlpha(170)),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(10, 8, 10, 0),
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: Alignment.centerLeft,
                        child: Text(title, maxLines: 1, style: displayStyle(15, Ui.cardText)),
                      ),
                      const SizedBox(height: 4),
                      Expanded(
                        child: DefaultTextStyle.merge(
                          style: bodyText(12.5, color: Ui.cardText),
                          child: body,
                        ),
                      ),
                    ]),
                  ),
                ),
                Padding(padding: const EdgeInsets.fromLTRB(10, 0, 10, 10), child: footer),
              ]),
            ),
          ),
        ),
      ),
    );
  }
}

/// Fußzeile einer Karte: leuchtendes Etikett über die ganze Breite.
class CardFooter extends StatelessWidget {
  const CardFooter(this.child, {super.key, this.color = Palette.sun});
  final Widget child;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final text = Color.lerp(color, Colors.white, 0.6)!;
    return Container(
      height: 32,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: color.withAlpha(46),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withAlpha(170), width: 1.2),
      ),
      child: DefaultTextStyle.merge(
        style: displayStyle(14, text).copyWith(shadows: glowShadows(color, 0.6)),
        child: child,
      ),
    );
  }
}

// ---------------- Kleinteile ----------------

/// Materialsymbol (leuchtender Mint-Kristall).
class MaterialGem extends StatelessWidget {
  const MaterialGem({super.key, this.size = 11});
  final double size;

  @override
  Widget build(BuildContext context) => Transform.rotate(
        angle: 0.785,
        child: Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            color: Palette.mint,
            border: Border.all(color: const Color(0xFFE6FFF0), width: 1.2),
            boxShadow: [BoxShadow(color: Palette.mint.withAlpha(180), blurRadius: size)],
          ),
        ),
      );
}

/// Preis mit Materialsymbol.
class PriceTag extends StatelessWidget {
  const PriceTag(this.price, {super.key});
  final int price;

  @override
  Widget build(BuildContext context) => Row(mainAxisSize: MainAxisSize.min, children: [
        const MaterialGem(size: 9),
        const SizedBox(width: 8),
        Text('$price', style: numberStyle(15, DefaultTextStyle.of(context).style.color ?? Ui.text)),
      ]);
}

/// Kleines abgerundetes Etikett.
class Pill extends StatelessWidget {
  const Pill(this.text,
      {super.key, this.color = Ui.slot, this.textColor = Ui.text, this.size = 12, this.icon, this.glyph});
  final String text;
  final Color color, textColor;
  final double size;
  final String? icon;

  /// Lichtsymbol statt [icon].
  final GlyphRef? glyph;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: size * 0.8, vertical: size * 0.32),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: Ui.panelLine, width: 1),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        if (glyph != null)
          Padding(padding: const EdgeInsets.only(right: 5), child: Glyph(glyph!, size: size * 1.5))
        else if (icon != null)
          Padding(padding: const EdgeInsets.only(right: 5), child: iconWidget(icon!, size, color: textColor)),
        GlyphText(text, style: bodyText(size, color: textColor, weight: 850)),
      ]),
    );
  }
}

class MoneyPill extends StatelessWidget {
  const MoneyPill(this.amount, {super.key});
  final int amount;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 6, 16, 6),
      decoration: BoxDecoration(
        color: Ui.glass,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: Palette.mint.withAlpha(170), width: 1.4),
        boxShadow: [BoxShadow(color: Palette.mint.withAlpha(60), blurRadius: 18)],
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        const MaterialGem(size: 12),
        const SizedBox(width: 11),
        Text('$amount', style: numberStyle(22, const Color(0xFFCFFFE0)).copyWith(shadows: glowShadows(Palette.mint, 0.7))),
      ]),
    );
  }
}

/// Werte-Änderungen einer Karte (+ grün, − rot).
class ModsText extends StatelessWidget {
  const ModsText(this.mods, {super.key, this.size = 13});
  final Map<Stat, double> mods;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final e in mods.entries)
          Text(
            '${e.value > 0 ? '+' : ''}${fmtNum(e.value)}${e.key.unit} ${e.key.label}',
            style: bodyText(size, color: e.value < 0 ? const Color(0xFFFF8A9A) : const Color(0xFF8CF5B0), weight: 850),
          ),
      ],
    );
  }
}

/// Kachel mit großer Zahl und Beschriftung (Game Over).
class StatTile extends StatelessWidget {
  const StatTile({super.key, required this.value, required this.label, this.color = Palette.sun});
  final String value, label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 104,
      padding: const EdgeInsets.symmetric(vertical: 10),
      decoration: BoxDecoration(
        color: Ui.slot,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withAlpha(110), width: 1.2),
        boxShadow: [BoxShadow(color: color.withAlpha(40), blurRadius: 16)],
      ),
      child: Column(children: [
        Text(value, style: numberStyle(28, Color.lerp(color, Colors.white, 0.4)!).copyWith(shadows: glowShadows(color, 0.8))),
        const SizedBox(height: 2),
        Text(label, style: mutedStyle),
      ]),
    );
  }
}

// ---------------- Controller-Hinweise ----------------

/// Controller-Knopf in Xbox-Farben (A grün, B rot, X blau, Y gelb), Schultertasten als Kapsel.
class PadGlyph extends StatelessWidget {
  const PadGlyph(this.button, {super.key});
  final GamepadButton button;

  static Color? _face(GamepadButton b) => switch (b) {
        GamepadButton.a => const Color(0xFF5DBB63),
        GamepadButton.b => const Color(0xFFE05252),
        GamepadButton.x => const Color(0xFF3D8BFF),
        GamepadButton.y => const Color(0xFFF2C230),
        _ => null,
      };

  @override
  Widget build(BuildContext context) {
    final face = _face(button);
    if (face != null) {
      return Container(
        width: 24,
        height: 24,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: const Color(0xFF14182A),
          border: Border.all(color: face, width: 2),
          boxShadow: [BoxShadow(color: face.withAlpha(90), blurRadius: 8)],
        ),
        child: Text(padLabel(button), style: bodyText(12, color: face, weight: 900)),
      );
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: const Color(0xFF14182A),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Ui.edge, width: 1.2),
      ),
      child: Text(padLabel(button), style: bodyText(12, color: Ui.cardText, weight: 900)),
    );
  }
}

/// Linker Stick als Symbol.
class StickGlyph extends StatelessWidget {
  const StickGlyph({super.key});

  @override
  Widget build(BuildContext context) => Container(
        width: 24,
        height: 24,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: const Color(0xFF14182A),
          border: Border.all(color: Ui.edge, width: 2),
        ),
        child: Text('L', style: bodyText(11, color: Ui.cardText, weight: 900)),
      );
}

/// Hinweis: Knopf (null = Steuerkreuz/Stick) und was er tut.
typedef PadHint = (GamepadButton?, String);

/// Zeile mit Knopf-Hinweisen; nur sichtbar, solange mit Controller gespielt wird.
class ControllerHints extends StatelessWidget {
  const ControllerHints(this.hints, {super.key, this.center = true});
  final List<PadHint> hints;
  final bool center;

  @override
  Widget build(BuildContext context) => ValueListenableBuilder<bool>(
        valueListenable: controllerActive,
        builder: (context, on, _) {
          if (!on || hints.isEmpty) return const SizedBox.shrink();
          return Wrap(
            alignment: center ? WrapAlignment.center : WrapAlignment.end,
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 14,
            runSpacing: 4,
            children: [
              for (final (b, label) in hints)
                Row(mainAxisSize: MainAxisSize.min, children: [
                  b == null ? const DpadGlyph() : PadGlyph(b),
                  const SizedBox(width: 6),
                  Text(label, style: bodyText(12, color: Ui.muted, weight: 800)),
                ]),
            ],
          );
        },
      );
}

/// Steuerkreuz als Symbol (Navigation).
class DpadGlyph extends StatelessWidget {
  const DpadGlyph({super.key});

  @override
  Widget build(BuildContext context) => Container(
        width: 24,
        height: 24,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: const Color(0xFF14182A),
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: Ui.edge, width: 1.2),
        ),
        child: const Glyph(UiGlyph(UiIcon.plus, color: Ui.cardText), size: 14),
      );
}
