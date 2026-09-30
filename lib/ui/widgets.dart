import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../game/config.dart';

const kCardWidth = 180.0;

bool get isTouchPlatform =>
    defaultTargetPlatform == TargetPlatform.android || defaultTargetPlatform == TargetPlatform.iOS;

const headingStyle = TextStyle(fontSize: 24, fontWeight: FontWeight.w900, color: Palette.ink, height: 1.1);
const bodyStyle = TextStyle(fontSize: 15, color: Palette.ink, height: 1.45);
const mutedStyle = TextStyle(fontSize: 13, color: Palette.muted);

Widget sectionTitle(String text) => Padding(
      padding: const EdgeInsets.only(top: 16, bottom: 8),
      child: Text(text, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: Palette.muted)),
    );

/// Abgedunkelter Hintergrund + zentrierte, scrollbare Karte.
class Panel extends StatelessWidget {
  const Panel({super.key, required this.child, this.maxWidth = 560});
  final Widget child;
  final double maxWidth;

  @override
  Widget build(BuildContext context) {
    return SizedBox.expand(
      child: ColoredBox(
        color: const Color(0x99120A24),
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(10),
            child: ConstrainedBox(
              constraints: BoxConstraints(maxWidth: maxWidth),
              child: Container(
                decoration: BoxDecoration(
                  color: Palette.panel,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: Palette.ink, width: 3),
                  boxShadow: const [BoxShadow(color: Palette.ink, offset: Offset(0, 6))],
                ),
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(18, 18, 18, 20),
                  child: DefaultTextStyle.merge(style: bodyStyle, child: child),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Tipp-, Tastatur- und Controller-bedienbare Fläche mit Fokusrahmen.
/// Enter/Leertaste bzw. Controller-A lösen [onPressed] über [ActivateIntent] aus.
class Pressable extends StatefulWidget {
  const Pressable({super.key, required this.onPressed, required this.child, this.radius = 12});
  final VoidCallback? onPressed;
  final Widget child;
  final double radius;

  @override
  State<Pressable> createState() => _PressableState();
}

class _PressableState extends State<Pressable> {
  bool _focused = false;

  @override
  Widget build(BuildContext context) {
    final onPressed = widget.onPressed;
    return FocusableActionDetector(
      enabled: onPressed != null,
      onFocusChange: (v) => setState(() => _focused = v),
      actions: {
        ActivateIntent: CallbackAction<ActivateIntent>(onInvoke: (_) => onPressed?.call()),
        ButtonActivateIntent: CallbackAction<ButtonActivateIntent>(onInvoke: (_) => onPressed?.call()),
      },
      child: GestureDetector(
        onTap: onPressed,
        child: DecoratedBox(
          position: DecorationPosition.foreground,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(widget.radius + 3),
            border: _focused ? Border.all(color: Palette.purple, width: 3) : null,
          ),
          child: Padding(padding: const EdgeInsets.all(3), child: widget.child),
        ),
      ),
    );
  }
}

class GameButton extends StatelessWidget {
  const GameButton({super.key, required this.label, required this.onPressed, this.color = Palette.sun});
  final String label;
  final VoidCallback? onPressed;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: onPressed == null ? 0.4 : 1,
      child: Pressable(
        onPressed: onPressed,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Palette.ink, width: 3),
            boxShadow: const [BoxShadow(color: Palette.ink, offset: Offset(0, 3))],
          ),
          child: Text(label, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w900, color: Palette.ink)),
        ),
      ),
    );
  }
}

/// Karte für Waffen, Items und Level-up-Optionen. Farbstreifen oben = Stufe/Seltenheit.
class InfoCard extends StatelessWidget {
  const InfoCard({
    super.key,
    required this.accent,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.body,
    required this.action,
  });

  final Color accent;
  final String icon, title, subtitle;
  final Widget body, action;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: kCardWidth,
      child: Container(
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          color: Palette.card,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: Palette.line, width: 2),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(height: 6, color: accent),
            Padding(
              padding: const EdgeInsets.all(10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(children: [
                    Text(icon, style: const TextStyle(fontSize: 26)),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text(title, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14)),
                        if (subtitle.isNotEmpty) Text(subtitle, style: mutedStyle.copyWith(fontSize: 12)),
                      ]),
                    ),
                  ]),
                  const SizedBox(height: 6),
                  DefaultTextStyle.merge(style: const TextStyle(fontSize: 13, height: 1.35), child: body),
                  const SizedBox(height: 10),
                  action,
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class ModsText extends StatelessWidget {
  const ModsText(this.mods, {super.key});
  final Map<Stat, double> mods;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final e in mods.entries)
          Text(
            '${e.value > 0 ? '+' : ''}${fmtNum(e.value)}${e.key.unit} ${e.key.label}',
            style: TextStyle(color: e.value < 0 ? Palette.bad : Palette.good, fontWeight: FontWeight.w600),
          ),
      ],
    );
  }
}

class MoneyPill extends StatelessWidget {
  const MoneyPill(this.amount, {super.key});
  final int amount;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(10, 5, 12, 5),
      decoration: BoxDecoration(color: Palette.ink, borderRadius: BorderRadius.circular(999)),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Transform.rotate(angle: 0.785, child: Container(width: 11, height: 11, color: Palette.mint)),
        const SizedBox(width: 8),
        Text('$amount', style: const TextStyle(color: Palette.mint, fontWeight: FontWeight.w900, fontSize: 18)),
      ]),
    );
  }
}

/// Schrift mit Kontur für das Logo.
class OutlinedLabel extends StatelessWidget {
  const OutlinedLabel(this.text, {super.key, this.size = 48});
  final String text;
  final double size;

  @override
  Widget build(BuildContext context) {
    final base = TextStyle(fontSize: size, fontWeight: FontWeight.w900, height: 0.95, letterSpacing: 1);
    return Stack(children: [
      Transform.translate(
        offset: const Offset(0, 5),
        child: Text(text, style: base.copyWith(color: Palette.ink)),
      ),
      Text(text,
          style: base.copyWith(
              foreground: Paint()
                ..style = PaintingStyle.stroke
                ..strokeWidth = 4
                ..color = Palette.ink)),
      Text(text, style: base.copyWith(color: Palette.sun)),
    ]);
  }
}
