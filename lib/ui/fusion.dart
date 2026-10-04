import 'dart:math';

import 'package:flutter/material.dart';
import 'package:gamepads/gamepads.dart';

import '../game/config.dart';
import 'widgets.dart';

/// Verschmelz-Animation: beide Aktionen kreisen aufeinander zu, Lichtblitz, dann erscheint
/// die Evolution mit goldenem Ring und großem Namen. Klick, Enter oder A überspringt.
class FusionAnimation extends StatefulWidget {
  const FusionAnimation({super.key, required this.a, required this.b, required this.result, required this.onDone});
  final ActionId a, b, result;
  final VoidCallback onDone;

  /// Gesamtdauer inklusive kurzer Pause am Ende.
  static const duration = Duration(milliseconds: 2300);

  @override
  State<FusionAnimation> createState() => _FusionAnimationState();
}

class _FusionAnimationState extends State<FusionAnimation> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(vsync: this, duration: FusionAnimation.duration)
    ..addStatusListener((s) {
      if (s == AnimationStatus.completed) _finish();
    })
    ..forward();
  final _focus = FocusNode(debugLabel: 'Verschmelzen');
  bool _done = false;

  static const _gold = Color(0xFFFFC94A);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _focus.requestFocus();
    });
  }

  @override
  void dispose() {
    _c.dispose();
    _focus.dispose();
    super.dispose();
  }

  void _finish() {
    if (_done) return;
    _done = true;
    widget.onDone();
  }

  @override
  Widget build(BuildContext context) => Pressable(
        onPressed: _finish,
        builder: (context, _) => Focus(
          focusNode: _focus,
          child: AnimatedBuilder(animation: _c, builder: (context, _) => _frame(_c.value * 2.3)),
        ),
      );

  /// [s] = Sekunden seit Start: 0–0,9 Annähern, 0,9–1,2 Blitz, ab 1,1 Ergebnis.
  Widget _frame(double s) {
    final approach = Curves.easeIn.transform((s / 0.9).clamp(0, 1));
    final flash = s < 0.85 ? 0.0 : (s < 1.0 ? (s - 0.85) / 0.15 : (1 - (s - 1.0) / 0.35).clamp(0.0, 1.0));
    final reveal = Curves.elasticOut.transform(((s - 1.05) / 0.7).clamp(0, 1));
    final textIn = ((s - 1.25) / 0.35).clamp(0.0, 1.0);
    final orbit = s * 7;
    final dist = 170 * (1 - approach);

    Widget orb(ActionId a, double size, Color color) => Container(
          width: size,
          height: size,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: Color.alphaBlend(color.withAlpha(60), const Color(0xFF0A0F24)),
            border: Border.all(color: color, width: 2.5),
            boxShadow: [BoxShadow(color: color.withAlpha(150), blurRadius: size * 0.6, spreadRadius: 2)],
          ),
          child: Glyph(ActionGlyph(a), size: size * 0.75),
        );

    return ColoredBox(
      color: Color.fromRGBO(2, 4, 16, 0.55 + 0.2 * approach),
      child: Stack(alignment: Alignment.center, children: [
        // Zutaten kreisen aufeinander zu
        if (s < 1.0)
          for (final (i, a) in [(0, widget.a), (1, widget.b)])
            Transform.translate(
              offset: Offset(cos(orbit + i * pi) * dist, sin(orbit + i * pi) * dist * 0.55),
              child: Opacity(opacity: (1 - flash).clamp(0, 1), child: orb(a, 64, const Color(0xFFBFE3FF))),
            ),
        // Lichtstrahlen und Funken nach dem Blitz
        if (s > 0.95)
          for (var k = 0; k < 12; k++)
            Transform.translate(
              offset: Offset.fromDirection(k / 12 * pi * 2 + s * 0.6, 60 + 160 * ((s - 0.95) / 1.3).clamp(0, 1)),
              child: Opacity(
                opacity: (1 - (s - 0.95) / 1.2).clamp(0, 1),
                child: Container(
                  width: 8,
                  height: 8,
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                    color: Color(0xFFFFF4D6),
                    boxShadow: [BoxShadow(color: _gold, blurRadius: 10, spreadRadius: 2)],
                  ),
                ),
              ),
            ),
        // Evolution mit rotierendem Goldring
        if (s > 1.0)
          Transform.scale(
            scale: 0.3 + 0.7 * reveal,
            child: Stack(alignment: Alignment.center, children: [
              Transform.rotate(
                angle: s * 1.5,
                child: Container(
                  width: 150,
                  height: 150,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: _gold.withAlpha(200), width: 3),
                    gradient: SweepGradient(colors: [_gold.withAlpha(0), _gold.withAlpha(120), _gold.withAlpha(0)]),
                  ),
                ),
              ),
              orb(widget.result, 104, _gold),
            ]),
          ),
        // Blitz
        if (flash > 0)
          IgnorePointer(
            child: Container(
              decoration: BoxDecoration(
                gradient: RadialGradient(colors: [
                  Colors.white.withValues(alpha: flash),
                  const Color(0xFFFFE6A0).withValues(alpha: flash * 0.6),
                  Colors.transparent,
                ], stops: const [0, 0.25, 0.7]),
              ),
            ),
          ),
        // Name und Wirkung
        if (textIn > 0)
          Transform.translate(
            offset: Offset(0, 150 + 12 * (1 - textIn)),
            child: Opacity(
              opacity: textIn,
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                Text('EVOLUTION', style: displayStyle(14, Ui.muted).copyWith(letterSpacing: 4)),
                OutlinedLabel('${widget.result.label.toUpperCase()}!', size: 40, color: _gold, align: TextAlign.center),
                const SizedBox(height: 6),
                SizedBox(
                  width: 420,
                  child: Text(widget.result.desc, textAlign: TextAlign.center, style: bodyText(14, color: Ui.text)),
                ),
                const SizedBox(height: 14),
                const ControllerHints([(GamepadButton.a, 'Weiter')]),
              ]),
            ),
          ),
      ]),
    );
  }
}
