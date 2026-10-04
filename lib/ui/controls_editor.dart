import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:gamepads/gamepads.dart';

import '../game/config.dart';
import '../game/federfeuer_game.dart';
import '../game/gamepad_input.dart' show controllerActive;
import '../game/input_bindings.dart';
import '../platform/desktop_window.dart';
import 'widgets.dart';

/// Übersicht und Neubelegung der Steuerung: Tastatur oder Controller umschaltbar.
/// Feld wählen, dann Taste drücken; Esc bricht ab, Entf/Rücktaste leert das Feld.
class ControlsEditor extends StatefulWidget {
  const ControlsEditor({super.key, required this.game});
  final FederfeuerGame game;

  @override
  State<ControlsEditor> createState() => _ControlsEditorState();
}

class _ControlsEditorState extends State<ControlsEditor> {
  FederfeuerGame get game => widget.game;
  InputBindings get bindings => game.settings.bindings;

  late bool _pad = game.pad.used;

  /// Gerade neu belegtes Feld (Aktion, Platz) und Restzeit beim Controller.
  (InputAction, int)? _capture;
  Timer? _timeout;
  int _left = 0;

  @override
  void dispose() {
    _stopCapture();
    super.dispose();
  }

  void _startCapture(InputAction a, int slot) {
    _stopCapture();
    setState(() => _capture = (a, slot));
    game.inputCapture = true;
    if (_pad) {
      // Kurz warten, damit der Bestätigen-Druck (A) nicht gleich belegt wird
      Future.delayed(const Duration(milliseconds: 250), () {
        if (mounted && _capture == (a, slot)) game.pad.onCapture = _onPadButton;
      });
      _left = 5;
      _timeout = Timer.periodic(const Duration(seconds: 1), (t) {
        if (!mounted) return;
        setState(() => _left--);
        if (_left <= 0) _stopCapture(rebuild: true);
      });
    } else {
      HardwareKeyboard.instance.addHandler(_onKey);
    }
  }

  void _stopCapture({bool rebuild = false}) {
    _timeout?.cancel();
    _timeout = null;
    HardwareKeyboard.instance.removeHandler(_onKey);
    game.pad.onCapture = null;
    // Erst nach dem aktuellen Tastendruck wieder ans Spiel geben (sonst löst Esc noch „zurück“ aus)
    if (game.inputCapture) scheduleMicrotask(() => game.inputCapture = false);
    _capture = null;
    if (rebuild && mounted) setState(() {});
  }

  bool _onKey(KeyEvent e) {
    final c = _capture;
    if (c == null || e is! KeyDownEvent) return true;
    final k = e.logicalKey;
    if (k == LogicalKeyboardKey.escape) {
      _stopCapture(rebuild: true);
    } else if (k == LogicalKeyboardKey.backspace || k == LogicalKeyboardKey.delete) {
      bindings.setKey(c.$1, c.$2, null);
      _done();
    } else if (k == LogicalKeyboardKey.f11 || k == LogicalKeyboardKey.f3) {
      // fest belegt
    } else {
      bindings.setKey(c.$1, c.$2, k);
      _done();
    }
    return true;
  }

  void _onPadButton(GamepadButton b) {
    final c = _capture;
    if (c == null) return;
    bindings.setPad(c.$1, c.$2, b);
    _done();
  }

  void _done() {
    _stopCapture();
    game.settings.save();
    if (mounted) setState(() {});
  }

  void _reset() {
    _stopCapture();
    setState(() => _pad ? bindings.resetPad() : bindings.resetKeys());
    game.settings.save();
  }

  @override
  Widget build(BuildContext context) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        _tab('Tastatur', '⌨', !_pad, () => setState(() {
              _stopCapture();
              _pad = false;
            })),
        const SizedBox(width: 8),
        _tab('Controller', '🎮', _pad, () => setState(() {
              _stopCapture();
              _pad = true;
            })),
        const Spacer(),
        GameButton(label: 'Standard', icon: '↺', size: 13, color: Ui.card, onPressed: _reset),
      ]),
      const SizedBox(height: 6),
      Container(
        padding: const EdgeInsets.fromLTRB(12, 6, 12, 6),
        decoration: BoxDecoration(
          color: Ui.slot,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: Ui.panelLine, width: 2),
        ),
        child: Column(children: [
          for (final a in InputAction.values) _row(a),
        ]),
      ),
      const SizedBox(height: 6),
      Text(
        _capture != null
            ? (_pad ? 'Controller-Taste drücken … ($_left s)' : 'Taste drücken … · Esc bricht ab · Entf/Rücktaste leert')
            : 'Feld wählen, dann neue Taste drücken. Eine Taste gilt immer nur für eine Aktion.',
        style: bodyText(12, color: _capture != null ? Palette.sun : Ui.muted),
      ),
      const SizedBox(height: 8),
      Wrap(spacing: 8, runSpacing: 6, children: _pad ? _fixedPad() : _fixedKeys()),
    ]);
  }

  Widget _tab(String label, String icon, bool on, VoidCallback onTap) => GameButton(
        label: label,
        icon: icon,
        size: 13,
        color: on ? Palette.sun : Ui.card,
        onPressed: on ? () {} : onTap,
      );

  Widget _row(InputAction a) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 2),
        child: Row(children: [
          SizedBox(width: 150, child: Text(a.label, style: displayStyle(14))),
          for (var i = 0; i < InputBindings.slots; i++)
            Expanded(child: Padding(padding: const EdgeInsets.symmetric(horizontal: 3), child: _slot(a, i))),
        ]),
      );

  Widget _slot(InputAction a, int i) {
    final capturing = _capture == (a, i);
    final key = bindings.keys[a]![i], btn = bindings.pad[a]![i];
    final Widget content;
    if (capturing) {
      content = Text('…', style: numberStyle(14, Palette.sun));
    } else if (_pad) {
      content = btn == null ? Text('–', style: bodyText(13, color: Ui.muted)) : PadGlyph(btn);
    } else {
      content = key == null ? Text('–', style: bodyText(13, color: Ui.muted)) : KeyCap(keyLabel(key));
    }
    return Pressable(
      onPressed: () => capturing ? _stopCapture(rebuild: true) : _startCapture(a, i),
      builder: (context, s) => Sticker(
        state: s,
        color: capturing ? Palette.sun : Ui.card,
        radius: 10,
        depth: 2,
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: SizedBox(height: 28, child: Center(child: content)),
      ),
    );
  }

  List<Widget> _fixedKeys() => [
        _fixed([const KeyCap('Esc')], 'Pause / zurück'),
        if (isDesktop) _fixed([const KeyCap('F11'), const KeyCap('Alt+Enter')], 'Vollbild'),
        _fixed([const KeyCap('↑↓←→'), const KeyCap('Tab'), const KeyCap('Enter')], 'Menüs'),
      ];

  List<Widget> _fixedPad() => [
        _fixed([const StickGlyph()], 'bewegen, Kolibri frei fliegen'),
        _fixed([const PadGlyph(GamepadButton.a), const PadGlyph(GamepadButton.b)], 'Menü: bestätigen / zurück'),
        _fixed([const PadGlyph(GamepadButton.dpadUp)], 'Menü-Navigation'),
      ];

  Widget _fixed(List<Widget> glyphs, String what) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(color: Ui.glass, borderRadius: BorderRadius.circular(10)),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          for (final g in glyphs) Padding(padding: const EdgeInsets.only(right: 4), child: g),
          const SizedBox(width: 4),
          Text('$what (fest)', style: bodyText(11.5, color: Ui.muted)),
        ]),
      );
}

/// Tastenkappe für Tastatur-Tasten.
class KeyCap extends StatelessWidget {
  const KeyCap(this.label, {super.key});
  final String label;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
        decoration: BoxDecoration(
          color: const Color(0xFF1A2244),
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: Ui.edge, width: 1.2),
          boxShadow: const [BoxShadow(color: Color(0xFF050814), offset: Offset(0, 2))],
        ),
        child: GlyphText(label, style: bodyText(12, color: Ui.cardText, weight: 900)),
      );
}


/// Kurztasten-Hinweis neben einem Knopf: Tastenkappe bzw. Controller-Knopf, je nach Eingabegerät.
/// Auf Touch-Geräten ohne Controller unsichtbar.
class ShortcutHint extends StatelessWidget {
  const ShortcutHint({super.key, required this.keyLabel, required this.pad});
  final String keyLabel;
  final GamepadButton pad;

  @override
  Widget build(BuildContext context) => ValueListenableBuilder<bool>(
        valueListenable: controllerActive,
        builder: (context, usePad, _) {
          if (!usePad && isTouchPlatform) return const SizedBox.shrink();
          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 6),
            child: usePad ? PadGlyph(pad) : KeyCap(keyLabel),
          );
        },
      );
}
