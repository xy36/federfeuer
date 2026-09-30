import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:gamepads/gamepads.dart';

/// Übersetzt Controller-Eingaben (Xbox-Standardbelegung) in Spielsteuerung
/// und Menü-Navigation. Mehrere Controller werden zusammengefasst.
class GamepadInput {
  GamepadInput({
    required this.onNavigate,
    required this.onConfirm,
    required this.onBack,
    required this.onStart,
  });

  /// Ab diesem Stick-Ausschlag zählt eine Richtung als gedrückt.
  static const double deadZone = 0.35;

  /// Ab diesem Ausschlag bewegt der Stick den Menüfokus.
  static const double navThreshold = 0.6;

  final ValueChanged<TraversalDirection> onNavigate;
  final VoidCallback onConfirm, onBack, onStart;

  final _buttons = <GamepadButton>{};
  double _stickX = 0, _stickY = 0, _triggerR = 0;
  TraversalDirection? _stickDir;
  StreamSubscription<NormalizedGamepadEvent>? _sub;
  StreamSubscription<GamepadConnectionEvent>? _disconnectSub;

  /// Wurde in dieser Sitzung schon ein Controller benutzt?
  bool used = false;

  bool get left => _buttons.contains(GamepadButton.dpadLeft) || _stickX < -deadZone;
  bool get right => _buttons.contains(GamepadButton.dpadRight) || _stickX > deadZone;
  bool get fly =>
      _buttons.contains(GamepadButton.a) ||
      _buttons.contains(GamepadButton.rightBumper) ||
      _buttons.contains(GamepadButton.rightTrigger) ||
      _triggerR > 0.5;

  void start() {
    try {
      _sub = Gamepads.normalizedEvents.listen(handle, onError: (Object e) {
        debugPrint('Controller-Fehler: $e');
      });
      _disconnectSub = Gamepads.onDisconnected.listen((_) => clear());
    } catch (e) {
      // Plattform ohne Plugin-Implementierung (z. B. Tests).
      debugPrint('Controller nicht verfügbar: $e');
    }
  }

  void stop() {
    _sub?.cancel();
    _disconnectSub?.cancel();
    _sub = _disconnectSub = null;
  }

  /// Setzt gehaltene Eingaben zurück (z. B. beim Trennen eines Controllers).
  void clear() {
    _buttons.clear();
    _stickX = _stickY = _triggerR = 0;
    _stickDir = null;
  }

  @visibleForTesting
  void handle(NormalizedGamepadEvent e) {
    used = true;
    final button = e.button;
    if (button != null) {
      final down = e.value > 0.5;
      final wasDown = _buttons.contains(button);
      if (down) {
        _buttons.add(button);
      } else {
        _buttons.remove(button);
      }
      if (down && !wasDown) _pressed(button);
      return;
    }
    switch (e.axis!) {
      case GamepadAxis.leftStickX:
        _stickX = e.value;
      case GamepadAxis.leftStickY:
        _stickY = e.value;
      case GamepadAxis.rightTrigger:
        _triggerR = e.value;
      default:
        return;
    }
    _updateStickNav();
  }

  void _pressed(GamepadButton b) {
    switch (b) {
      case GamepadButton.a:
        onConfirm();
      case GamepadButton.b:
        onBack();
      case GamepadButton.start:
        onStart();
      case GamepadButton.dpadUp:
        onNavigate(TraversalDirection.up);
      case GamepadButton.dpadDown:
        onNavigate(TraversalDirection.down);
      case GamepadButton.dpadLeft:
        onNavigate(TraversalDirection.left);
      case GamepadButton.dpadRight:
        onNavigate(TraversalDirection.right);
      default:
    }
  }

  /// Stick als Steuerkreuz: feuert einmal pro Auslenkung, nicht dauerhaft.
  void _updateStickNav() {
    TraversalDirection? dir;
    if (_stickX.abs() >= _stickY.abs()) {
      if (_stickX > navThreshold) dir = TraversalDirection.right;
      if (_stickX < -navThreshold) dir = TraversalDirection.left;
    } else {
      // Stick-Konvention des Pakets: oben = +1.
      if (_stickY > navThreshold) dir = TraversalDirection.up;
      if (_stickY < -navThreshold) dir = TraversalDirection.down;
    }
    if (dir != null && dir != _stickDir) onNavigate(dir);
    _stickDir = dir;
  }
}
