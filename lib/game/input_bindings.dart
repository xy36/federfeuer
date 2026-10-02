import 'package:flutter/services.dart';
import 'package:gamepads/gamepads.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Frei belegbare Spielaktionen. Menüsteuerung, Esc, Vollbild und der linke Stick bleiben fest.
enum InputAction {
  left('Links'),
  right('Rechts'),
  fly('Fliegen / hoch'),
  down('Sinkflug / runter'),
  action1('Aktion 1'),
  action2('Aktion 2'),
  pause('Pause');

  const InputAction(this.label);
  final String label;
}

/// Belegung für Tastatur und Controller: je Aktion bis zu [slots] Tasten.
class InputBindings {
  InputBindings() {
    resetKeys();
    resetPad();
  }

  static const slots = 3;

  static const Map<InputAction, List<LogicalKeyboardKey?>> defaultKeys = {
    InputAction.left: [LogicalKeyboardKey.keyA, LogicalKeyboardKey.arrowLeft, null],
    InputAction.right: [LogicalKeyboardKey.keyD, LogicalKeyboardKey.arrowRight, null],
    InputAction.fly: [LogicalKeyboardKey.keyW, LogicalKeyboardKey.arrowUp, LogicalKeyboardKey.space],
    InputAction.down: [LogicalKeyboardKey.keyS, LogicalKeyboardKey.arrowDown, null],
    InputAction.action1: [LogicalKeyboardKey.keyQ, LogicalKeyboardKey.shiftLeft, null],
    InputAction.action2: [LogicalKeyboardKey.keyE, null, null],
    InputAction.pause: [LogicalKeyboardKey.keyP, null, null],
  };

  static const Map<InputAction, List<GamepadButton?>> defaultPad = {
    InputAction.left: [GamepadButton.dpadLeft, null, null],
    InputAction.right: [GamepadButton.dpadRight, null, null],
    InputAction.fly: [GamepadButton.a, GamepadButton.rightBumper, GamepadButton.rightTrigger],
    InputAction.down: [GamepadButton.dpadDown, null, null],
    InputAction.action1: [GamepadButton.x, GamepadButton.leftBumper, null],
    InputAction.action2: [GamepadButton.y, null, null],
    InputAction.pause: [GamepadButton.start, null, null],
  };

  final keys = <InputAction, List<LogicalKeyboardKey?>>{};
  final pad = <InputAction, List<GamepadButton?>>{};

  void resetKeys() {
    for (final a in InputAction.values) {
      keys[a] = [...defaultKeys[a]!];
    }
  }

  void resetPad() {
    for (final a in InputAction.values) {
      pad[a] = [...defaultPad[a]!];
    }
  }

  bool keyMatches(InputAction a, LogicalKeyboardKey k) => keys[a]!.contains(k);
  bool keyHeld(InputAction a, Set<LogicalKeyboardKey> pressed) => keys[a]!.any((k) => k != null && pressed.contains(k));
  bool padMatches(InputAction a, GamepadButton b) => pad[a]!.contains(b);
  bool padHeld(InputAction a, Set<GamepadButton> held) => pad[a]!.any((b) => b != null && held.contains(b));

  /// Belegt einen Platz; dieselbe Taste wird überall sonst entfernt (keine Doppelbelegung).
  void setKey(InputAction a, int slot, LogicalKeyboardKey? k) {
    if (k != null) {
      for (final list in keys.values) {
        for (var i = 0; i < list.length; i++) {
          if (list[i] == k) list[i] = null;
        }
      }
    }
    keys[a]![slot] = k;
  }

  void setPad(InputAction a, int slot, GamepadButton? b) {
    if (b != null) {
      for (final list in pad.values) {
        for (var i = 0; i < list.length; i++) {
          if (list[i] == b) list[i] = null;
        }
      }
    }
    pad[a]![slot] = b;
  }

  /// Erste belegte Taste (für Hinweise im HUD).
  LogicalKeyboardKey? firstKey(InputAction a) => keys[a]!.firstWhere((k) => k != null, orElse: () => null);
  GamepadButton? firstPad(InputAction a) => pad[a]!.firstWhere((b) => b != null, orElse: () => null);

  static String _keyPref(InputAction a) => 'bindKey_${a.name}';
  static String _padPref(InputAction a) => 'bindPad_${a.name}';

  void loadFrom(SharedPreferences prefs) {
    for (final a in InputAction.values) {
      final k = prefs.getStringList(_keyPref(a));
      if (k != null && k.length == slots) {
        keys[a] = [for (final s in k) s.isEmpty ? null : LogicalKeyboardKey.findKeyByKeyId(int.tryParse(s) ?? -1)];
      }
      final p = prefs.getStringList(_padPref(a));
      if (p != null && p.length == slots) {
        pad[a] = [for (final s in p) GamepadButton.values.where((b) => b.name == s).firstOrNull];
      }
    }
  }

  Future<void> saveTo(SharedPreferences prefs) async {
    for (final a in InputAction.values) {
      await prefs.setStringList(_keyPref(a), [for (final k in keys[a]!) k == null ? '' : '${k.keyId}']);
      await prefs.setStringList(_padPref(a), [for (final b in pad[a]!) b?.name ?? '']);
    }
  }
}

/// Kurzer, lesbarer Name einer Taste.
final _keyNames = <LogicalKeyboardKey, String>{
  LogicalKeyboardKey.space: 'Leertaste',
  LogicalKeyboardKey.arrowUp: '↑',
  LogicalKeyboardKey.arrowDown: '↓',
  LogicalKeyboardKey.arrowLeft: '←',
  LogicalKeyboardKey.arrowRight: '→',
  LogicalKeyboardKey.shiftLeft: 'Shift',
  LogicalKeyboardKey.shiftRight: 'Shift rechts',
  LogicalKeyboardKey.controlLeft: 'Strg',
  LogicalKeyboardKey.controlRight: 'Strg rechts',
  LogicalKeyboardKey.altLeft: 'Alt',
  LogicalKeyboardKey.altRight: 'Alt Gr',
  LogicalKeyboardKey.metaLeft: 'Cmd',
  LogicalKeyboardKey.metaRight: 'Cmd rechts',
  LogicalKeyboardKey.enter: 'Enter',
  LogicalKeyboardKey.tab: 'Tab',
  LogicalKeyboardKey.capsLock: 'Feststell',
  LogicalKeyboardKey.backspace: 'Rücktaste',
  LogicalKeyboardKey.delete: 'Entf',
  LogicalKeyboardKey.escape: 'Esc',
};

String keyLabel(LogicalKeyboardKey k) {
  final n = _keyNames[k];
  if (n != null) return n;
  final l = k.keyLabel;
  return l.isEmpty ? k.debugName ?? '?' : (l.length == 1 ? l.toUpperCase() : l);
}

/// Kurzer Name eines Controller-Knopfs (Xbox-Beschriftung).
String padLabel(GamepadButton b) => switch (b) {
      GamepadButton.a => 'A',
      GamepadButton.b => 'B',
      GamepadButton.x => 'X',
      GamepadButton.y => 'Y',
      GamepadButton.leftBumper => 'LB',
      GamepadButton.rightBumper => 'RB',
      GamepadButton.leftTrigger => 'LT',
      GamepadButton.rightTrigger => 'RT',
      GamepadButton.back => 'View',
      GamepadButton.start => 'Menü',
      GamepadButton.home => 'Home',
      GamepadButton.leftStick => 'L3',
      GamepadButton.rightStick => 'R3',
      GamepadButton.dpadUp => '✚ ↑',
      GamepadButton.dpadDown => '✚ ↓',
      GamepadButton.dpadLeft => '✚ ←',
      GamepadButton.dpadRight => '✚ →',
      GamepadButton.touchpad => 'Touchpad',
    };
