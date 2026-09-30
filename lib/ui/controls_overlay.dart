import 'package:flutter/material.dart';

import '../game/federfeuer_game.dart';
import 'widgets.dart';

/// Pause-Button und (auf Handys) Touch-Steuerung.
class ControlsOverlay extends StatelessWidget {
  const ControlsOverlay({super.key, required this.game});
  final FederfeuerGame game;

  @override
  Widget build(BuildContext context) {
    final touch = isTouchPlatform;
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
              color: const Color(0x802A1D3A),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0x99FFFFFF), width: 3),
            ),
            child: const Text('II', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 16)),
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
          child: HoldButton(label: 'Flug', size: 100, fontSize: 16, onChanged: (v) => game.touchFly = v),
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
          color: _down ? const Color(0x80FFD23F) : const Color(0x24FFFFFF),
          border: Border.all(color: const Color(0x8CFFFFFF), width: 3),
        ),
        child: Text(widget.label,
            style: TextStyle(color: Colors.white, fontSize: widget.fontSize, fontWeight: FontWeight.w900)),
      ),
    );
  }
}
