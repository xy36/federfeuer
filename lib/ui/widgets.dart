import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../game/config.dart';

bool get isTouchPlatform =>
    defaultTargetPlatform == TargetPlatform.android || defaultTargetPlatform == TargetPlatform.iOS;

// ---------------- Farben & Schrift ----------------

/// UI-Farben der Menüs: dunkle Panels, cremefarbene Sticker-Karten.
class Ui {
  static const panel = Color(0xF2221736);
  static const panelEdge = Color(0xFF110A20);
  static const panelLine = Color(0x33FFFFFF);
  static const text = Color(0xFFF6F0FF);
  static const muted = Color(0xFFB9A9DA);
  static const card = Color(0xFFFFF6E6);
  static const cardMuted = Color(0xFF7A6A8E);
  static const slot = Color(0x1FFFFFFF);
}

const _display = 'LilitaOne';
const _body = 'Nunito';

TextStyle displayStyle(double size, [Color color = Ui.text]) =>
    TextStyle(fontFamily: _display, fontSize: size, color: color, height: 1.05, letterSpacing: 0.5);

TextStyle bodyText(double size, {Color color = Ui.text, double weight = 700}) => TextStyle(
      fontFamily: _body,
      fontSize: size,
      color: color,
      height: 1.3,
      fontWeight: weight >= 800 ? FontWeight.w800 : FontWeight.w700,
      fontVariations: [FontVariation('wght', weight)],
    );

final mutedStyle = bodyText(13, color: Ui.muted);

/// Kleine Überschrift über einem Abschnitt im Panel.
Widget sectionTitle(String text, {EdgeInsets padding = const EdgeInsets.only(top: 14, bottom: 8)}) => Padding(
      padding: padding,
      child: Text(text.toUpperCase(), style: displayStyle(14, Ui.muted).copyWith(letterSpacing: 1.5)),
    );

// ---------------- Panel ----------------

/// Abgedunkelter Hintergrund + zentriertes, scrollbares Panel.
class Panel extends StatelessWidget {
  const Panel({super.key, required this.child, this.maxWidth = 560, this.padding = const EdgeInsets.all(20)});
  final Widget child;
  final double maxWidth;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) {
    return SizedBox.expand(
      child: ColoredBox(
        color: const Color(0x8C0B0616),
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(10),
            child: ConstrainedBox(
              constraints: BoxConstraints(maxWidth: maxWidth),
              child: Container(
                decoration: BoxDecoration(
                  color: Ui.panel,
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: Ui.panelEdge, width: 3),
                  boxShadow: const [BoxShadow(color: Color(0x99000000), offset: Offset(0, 8), blurRadius: 24)],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(21),
                  child: DecoratedBox(
                    // Leichter Glanz oben, damit das Panel nicht flach wirkt
                    decoration: const BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [Color(0x14FFFFFF), Color(0x00FFFFFF)],
                        stops: [0, 0.35],
                      ),
                    ),
                    child: SingleChildScrollView(
                      padding: padding,
                      child: DefaultTextStyle.merge(style: bodyText(14), child: child),
                    ),
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

/// Titel mit dunkler Kontur und Versatzschatten (Logo, Überschriften).
class OutlinedLabel extends StatelessWidget {
  const OutlinedLabel(this.text, {super.key, this.size = 48, this.color = Palette.sun, this.align = TextAlign.start});
  final String text;
  final double size;
  final Color color;
  final TextAlign align;

  @override
  Widget build(BuildContext context) {
    final base = displayStyle(size, color).copyWith(height: 0.95);
    final stroke = size / 7;
    return Stack(children: [
      Transform.translate(
        offset: Offset(0, size / 11),
        child: Text(text, textAlign: align, style: base.copyWith(
          color: null,
          foreground: Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = stroke
            ..strokeJoin = StrokeJoin.round
            ..color = Palette.ink,
        )),
      ),
      Text(text, textAlign: align, style: base.copyWith(
        color: null,
        foreground: Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = stroke
          ..strokeJoin = StrokeJoin.round
          ..color = Palette.ink,
      )),
      Text(text, textAlign: align, style: base),
    ]);
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
          OutlinedLabel(title, size: 32, color: color),
          if (subtitle != null) Padding(padding: const EdgeInsets.only(top: 6), child: subtitle),
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
  const Pressable({super.key, required this.onPressed, required this.builder});
  final VoidCallback? onPressed;
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
      enabled: enabled,
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

/// Sticker-Optik: Tinten-Kontur, Versatzschatten; hebt sich bei Fokus/Hover,
/// drückt sich beim Tippen ein. Fokus zeigt zusätzlich einen hellen Rahmen.
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
    final lift = state.pressed ? -depth + 1 : (state.highlighted ? 3.0 : 0.0);
    final shadow = state.pressed ? 1.0 : depth + (state.highlighted ? 3 : 0);
    return AnimatedContainer(
      duration: const Duration(milliseconds: 90),
      curve: Curves.easeOut,
      transform: Matrix4.translationValues(0, -lift, 0),
      decoration: BoxDecoration(
        color: state.enabled ? color : Color.lerp(color, const Color(0xFF8C8499), 0.55),
        borderRadius: BorderRadius.circular(radius),
        border: Border.all(color: Palette.ink, width: 3),
        boxShadow: [
          if (state.focused) const BoxShadow(color: Colors.white, spreadRadius: 4),
          BoxShadow(color: Palette.ink, offset: Offset(0, shadow)),
        ],
      ),
      padding: padding,
      child: Opacity(opacity: state.enabled ? 1 : 0.6, child: child),
    );
  }
}

/// Knopf im Sticker-Stil.
class GameButton extends StatelessWidget {
  const GameButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.color = Palette.sun,
    this.icon,
    this.size = 18,
  });
  final String label;
  final VoidCallback? onPressed;
  final Color color;
  final String? icon;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Pressable(
      onPressed: onPressed,
      builder: (context, s) => Padding(
        padding: const EdgeInsets.only(top: 4, bottom: 8),
        child: Sticker(
          state: s,
          color: color,
          radius: 14,
          depth: 4,
          padding: EdgeInsets.symmetric(horizontal: size * 0.9, vertical: size * 0.45),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            if (icon != null) Padding(padding: const EdgeInsets.only(right: 8), child: Text(icon!, style: TextStyle(fontSize: size))),
            Text(label, style: displayStyle(size, Palette.ink)),
          ]),
        ),
      ),
    );
  }
}

/// Auswahlkarte (Waffe, Item, Level-up). Die ganze Karte ist der Knopf.
/// Oben ein Farbband (Stufe/Seltenheit), unten eine Fußzeile (Preis, Aktion).
class ChoiceCard extends StatelessWidget {
  const ChoiceCard({
    super.key,
    required this.accent,
    required this.icon,
    required this.title,
    required this.body,
    required this.footer,
    required this.onPressed,
    this.badge,
    this.badgeColor = Palette.ink,
    this.width = 176,
    this.height = 196,
  });

  final Color accent;
  final String icon, title;
  final String? badge;
  final Color badgeColor;
  final Widget body, footer;
  final VoidCallback? onPressed;
  final double width, height;

  @override
  Widget build(BuildContext context) {
    return Pressable(
      onPressed: onPressed,
      builder: (context, s) => Padding(
        padding: const EdgeInsets.only(top: 4, bottom: 10),
        child: SizedBox(
          width: width,
          height: height,
          child: Sticker(
            state: s,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(13),
              child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                Container(
                  height: 44,
                  color: accent,
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  child: Row(children: [
                    Text(icon, style: const TextStyle(fontSize: 24)),
                    const Spacer(),
                    if (badge != null) Pill(badge!, color: badgeColor, textColor: Colors.white, size: 11),
                  ]),
                ),
                Container(height: 3, color: Palette.ink),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(10, 8, 10, 0),
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: Alignment.centerLeft,
                        child: Text(title, maxLines: 1, style: displayStyle(17, Palette.ink)),
                      ),
                      const SizedBox(height: 4),
                      Expanded(
                        child: DefaultTextStyle.merge(
                          style: bodyText(12.5, color: Palette.ink),
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

/// Fußzeile einer Karte: farbiges Etikett über die ganze Breite.
class CardFooter extends StatelessWidget {
  const CardFooter(this.child, {super.key, this.color = Palette.sun});
  final Widget child;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 34,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Palette.ink, width: 2.5),
      ),
      child: DefaultTextStyle.merge(style: displayStyle(16, Palette.ink), child: child),
    );
  }
}

// ---------------- Kleinteile ----------------

/// Materialsymbol (Mint-Raute).
class MaterialGem extends StatelessWidget {
  const MaterialGem({super.key, this.size = 11});
  final double size;

  @override
  Widget build(BuildContext context) => Transform.rotate(
        angle: 0.785,
        child: Container(
          width: size,
          height: size,
          decoration: BoxDecoration(color: Palette.mint, border: Border.all(color: Palette.ink, width: 1.5)),
        ),
      );
}

/// Preis mit Materialsymbol.
class PriceTag extends StatelessWidget {
  const PriceTag(this.price, {super.key});
  final int price;

  @override
  Widget build(BuildContext context) => Row(mainAxisSize: MainAxisSize.min, children: [
        const MaterialGem(size: 10),
        const SizedBox(width: 7),
        Text('$price'),
      ]);
}

/// Kleines abgerundetes Etikett.
class Pill extends StatelessWidget {
  const Pill(this.text, {super.key, this.color = Ui.slot, this.textColor = Ui.text, this.size = 12, this.icon});
  final String text;
  final Color color, textColor;
  final double size;
  final String? icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: size * 0.75, vertical: size * 0.3),
      decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(999)),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        if (icon != null) Padding(padding: const EdgeInsets.only(right: 5), child: Text(icon!, style: TextStyle(fontSize: size))),
        Text(text, style: bodyText(size, color: textColor, weight: 850)),
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
        color: Palette.ink,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: Palette.mint, width: 2.5),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        const MaterialGem(size: 13),
        const SizedBox(width: 10),
        Text('$amount', style: displayStyle(24, Palette.mint)),
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
            style: bodyText(size, color: e.value < 0 ? Palette.bad : Palette.good, weight: 850),
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
        border: Border.all(color: Ui.panelLine, width: 2),
      ),
      child: Column(children: [
        Text(value, style: displayStyle(30, color)),
        const SizedBox(height: 2),
        Text(label, style: mutedStyle),
      ]),
    );
  }
}
