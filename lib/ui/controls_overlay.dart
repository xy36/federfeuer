import 'package:flutter/material.dart';

import '../game/federfeuer_game.dart';
import 'widgets.dart';

/// Pause-Button und (auf Handys) Touch-Steuerung.
class ControlsOverlay extends StatelessWidget {
  const ControlsOverlay({super.key, required this.game});
  final FederfeuerGame game;

  @override
  Widget build(BuildContext context) {
    // Sobald ein Controller benutzt wurde, stören die Touch-Buttons nur.
    final touch = isTouchPlatform && !game.pad.used;
    return Stack(children: [
      Positioned(
        top: 8,
        right: 8,
        child: GestureDetector(
          onTap: game.togglePause,
          child: Container(
            width: 44,
            height: 44,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: const Color(0x990A0F24),
              shape: BoxShape.circle,
              border: Border.all(color: const Color(0x80CFE3FF), width: 1.4),
              boxShadow: const [BoxShadow(color: Color(0x339FD8FF), blurRadius: 14)],
            ),
            child: Text('II', style: displayStyle(14, const Color(0xFFE6F2FF))),
          ),
        ),
      ),
      if (touch)
        Positioned(
          left: 18,
          bottom: 14,
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            HoldButton(label: '◀', onChanged: (v) => game.touchLeft = v),
            const SizedBox(width: 12),
            HoldButton(label: '▶', onChanged: (v) => game.touchRight = v),
          ]),
        ),
      if (touch)
        Positioned(
          right: 18,
          bottom: 14,
          child: HoldButton(label: game.player.character.freeFlight ? '▲' : 'Flug', size: 100, fontSize: 16, onChanged: (v) => game.touchFly = v),
        ),
      // Kolibri fliegt frei: eigener Knopf nach unten über „Flug“
      if (touch && game.player.character.freeFlight)
        Positioned(
          right: 36,
          bottom: 124,
          child: HoldButton(label: '▼', size: 64, fontSize: 22, onChanged: (v) => game.touchDown = v),
        ),
      if (touch)
        for (var i = 0; i < (game.run?.actions.length ?? 0); i++)
          Positioned(
            right: 130 + i * 76.0,
            bottom: 24,
            child: HoldButton(
              label: game.run!.actions[i].id.icon,
              size: 64,
              fontSize: 24,
              onChanged: (v) {
                if (v) game.useAction(i);
              },
            ),
          ),
    ]);
  }
}

/// Button, der gedrückt gehalten wird (Multitouch-fähig über Listener).
class HoldButton extends StatefulWidget {
  const HoldButton({super.key, required this.label, required this.onChanged, this.size = 74, this.fontSize = 26});
  final String label;
  final ValueChanged<bool> onChanged;
  final double size, fontSize;

  @override
  State<HoldButton> createState() => _HoldButtonState();
}

class _HoldButtonState extends State<HoldButton> {
  bool _down = false;

  void _set(bool v) {
    if (_down == v) return;
    setState(() => _down = v);
    widget.onChanged(v);
  }

  @override
  void dispose() {
    if (_down) widget.onChanged(false);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Listener(
      onPointerDown: (_) => _set(true),
      onPointerUp: (_) => _set(false),
      onPointerCancel: (_) => _set(false),
      child: Container(
        width: widget.size,
        height: widget.size,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: _down ? const Color(0x59FFD27A) : const Color(0x4D0A0F24),
          border: Border.all(color: _down ? const Color(0xE6FFE6A0) : const Color(0x66CFE3FF), width: 1.6),
          boxShadow: [BoxShadow(color: _down ? const Color(0x80FFD27A) : const Color(0x229FD8FF), blurRadius: _down ? 26 : 12)],
        ),
        child: Text(widget.label,
            style: displayStyle(widget.fontSize * 0.85, const Color(0xFFF2F6FF))
                .copyWith(shadows: _down ? glowShadows(const Color(0xFFFFD27A)) : null)),
      ),
    );
  }
}
