import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:gamepads/gamepads.dart';

import 'input_bindings.dart';

/// Wird gerade mit Controller gespielt? Global, damit Menüs ihre Knopf-Hinweise ein- und ausblenden.
final controllerActive = ValueNotifier<bool>(false);

/// Übersetzt Controller-Eingaben (Xbox-Standardbelegung) in Spielsteuerung
/// und Menü-Navigation. Mehrere Controller werden zusammengefasst.
class GamepadInput {
  GamepadInput({
    required this.onNavigate,
    required this.onConfirm,
    required this.onBack,
    required this.onStart,
    this.onAction,
    this.onMenuButton,
    InputBindings? bindings,
  }) : bindings = bindings ?? InputBindings();

  /// Belegung der Spielaktionen; Menüs bleiben fest (Steuerkreuz/Stick, A, B).
  InputBindings bindings;

  /// Fest belegte Menü-Knöpfe neben A/B/Steuerkreuz (X, Y, LB, RB, Start) – z. B. Shop-Kurztasten.
  /// Gibt true zurück, wenn der Knopf verbraucht wurde.
  final bool Function(GamepadButton)? onMenuButton;

  /// Während der Neubelegung: der nächste gedrückte Knopf geht hierhin statt ins Spiel.
  ValueChanged<GamepadButton>? onCapture;

  /// Ab diesem Stick-Ausschlag zählt eine Richtung als gedrückt.
  static const double deadZone = 0.35;

  /// Ab diesem Ausschlag bewegt der Stick den Menüfokus.
  static const double navThreshold = 0.6;

  final ValueChanged<TraversalDirection> onNavigate;
  final VoidCallback onConfirm, onBack, onStart;

  /// Aktionstasten: Platz 0 = X oder LB, Platz 1 = Y.
  final ValueChanged<int>? onAction;

  final _buttons = <GamepadButton>{};
  double _stickX = 0, _stickY = 0;
  TraversalDirection? _stickDir;
  StreamSubscription<NormalizedGamepadEvent>? _sub;
  StreamSubscription<GamepadConnectionEvent>? _disconnectSub;

  /// Spielt der Nutzer gerade mit Controller? (Tastatur setzt es zurück; Menüs zeigen dann Knopf-Hinweise.)
  bool get used => controllerActive.value;
  set used(bool v) => controllerActive.value = v;

  bool get left => bindings.padHeld(InputAction.left, _buttons) || _stickX < -deadZone;
  bool get right => bindings.padHeld(InputAction.right, _buttons) || _stickX > deadZone;

  /// Sinkflug: belegte Knöpfe oder Stick nach unten (Stick-Konvention: oben = +1).
  bool get down => bindings.padHeld(InputAction.down, _buttons) || _stickY < -deadZone;
  bool get fly => bindings.padHeld(InputAction.fly, _buttons);

  /// Analoge Richtung für freien Flug (−1 … 1); belegte Knöpfe zählen voll, oben = negativ.
  double get horizontal {
    if (bindings.padHeld(InputAction.left, _buttons)) return -1;
    if (bindings.padHeld(InputAction.right, _buttons)) return 1;
    return _stickX.abs() > deadZone ? _stickX.clamp(-1.0, 1.0) : 0;
  }

  double get vertical {
    if (fly) return -1;
    if (bindings.padHeld(InputAction.down, _buttons)) return 1;
    return _stickY.abs() > deadZone ? (-_stickY).clamp(-1.0, 1.0) : 0;
  }

  void start() {
    try {
      _sub = Gamepads.normalizedEvents.listen(
        handle,
        onError: (Object e) {
          debugPrint('Controller-Fehler: $e');
        },
      );
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
    _stickX = _stickY = 0;
    _stickDir = null;
  }

  @visibleForTesting
  void handle(NormalizedGamepadEvent e) {
    used = true;
    final button = e.button;
    if (button != null) {
      _button(button, e.value > 0.5);
      return;
    }
    switch (e.axis!) {
      case GamepadAxis.leftStickX:
        _stickX = e.value;
      case GamepadAxis.leftStickY:
        _stickY = e.value;
      // Trigger zählen ab halbem Druck als Knopf (frei belegbar)
      case GamepadAxis.rightTrigger:
        _button(GamepadButton.rightTrigger, e.value > 0.5);
        return;
      case GamepadAxis.leftTrigger:
        _button(GamepadButton.leftTrigger, e.value > 0.5);
        return;
      default:
        return;
    }
    _updateStickNav();
  }

  void _button(GamepadButton button, bool down) {
    final wasDown = _buttons.contains(button);
    if (down) {
      _buttons.add(button);
    } else {
      _buttons.remove(button);
    }
    if (down && !wasDown) _pressed(button);
  }

  void _pressed(GamepadButton b) {
    final capture = onCapture;
    if (capture != null) {
      capture(b);
      return;
    }
    // Menüs: fest belegt
    switch (b) {
      case GamepadButton.a:
        onConfirm();
      case GamepadButton.b:
        onBack();
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
    if (onMenuButton?.call(b) ?? false) return;
    // Spiel: frei belegt
    if (bindings.padMatches(InputAction.pause, b)) onStart();
    if (bindings.padMatches(InputAction.action1, b)) onAction?.call(0);
    if (bindings.padMatches(InputAction.action2, b)) onAction?.call(1);
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
