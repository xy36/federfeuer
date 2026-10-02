import 'dart:math';

import 'package:flutter/material.dart';

import '../game/components/light.dart';
import '../game/components/player.dart';
import '../game/config.dart';

/// Vorschau eines Vogels im Menü: leuchtender Geistvogel, auf Wunsch mit Flügelschlag.
class BirdPreview extends StatefulWidget {
  const BirdPreview({super.key, required this.character, this.size = 64, this.animate = false, this.locked = false});
  final CharacterDef character;
  final double size;
  final bool animate, locked;

  @override
  State<BirdPreview> createState() => _BirdPreviewState();
}

class _BirdPreviewState extends State<BirdPreview> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(vsync: this, duration: const Duration(seconds: 2));

  @override
  void initState() {
    super.initState();
    if (widget.animate) _c.repeat();
  }

  @override
  void didUpdateWidget(BirdPreview old) {
    super.didUpdateWidget(old);
    if (widget.animate && !_c.isAnimating) _c.repeat();
    if (!widget.animate && _c.isAnimating) _c.stop();
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => SizedBox.square(
        dimension: widget.size,
        child: AnimatedBuilder(
          animation: _c,
          builder: (context, _) => CustomPaint(painter: _BirdPainter(widget.character, _c.value, widget.locked)),
        ),
      );
}

class _BirdPainter extends CustomPainter {
  _BirdPainter(this.ch, this.t, this.locked) : body = Player.bodyPaint(ch);
  final CharacterDef ch;
  final double t;
  final bool locked;
  final Paint body;

  @override
  void paint(Canvas c, Size size) {
    final k = size.shortestSide / 56;
    c.save();
    c.translate(size.width / 2, size.height / 2 + sin(t * pi * 2) * 2 * k);
    c.scale(k);
    if (locked) {
      // Gesperrt: nur dunkle Silhouette
      c.saveLayer(null, Paint()..colorFilter = const ColorFilter.mode(Color(0xFF1A1630), BlendMode.srcIn));
    } else {
      Glow.draw(c, 0, 0, 40, ch.glow.withValues(alpha: 0.55));
    }
    c.scale(ch.scale, ch.scale);
    final fl = sin(t * pi * 2 * (ch.look == BirdLook.hummingbird ? 8 : 3)) * 0.9;
    Player.drawBird(c, ch, body, fl, ch.look == BirdLook.penguin);
    if (locked) c.restore();
    c.restore();
  }

  @override
  bool shouldRepaint(_BirdPainter old) => old.t != t || old.ch != ch || old.locked != locked;
}
