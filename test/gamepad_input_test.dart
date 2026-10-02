import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:federfeuer/game/gamepad_input.dart';
import 'package:federfeuer/game/input_bindings.dart';
import 'package:gamepads/gamepads.dart';

NormalizedGamepadEvent _button(GamepadButton b, double v) => NormalizedGamepadEvent(
      gamepadId: '1',
      timestamp: 0,
      button: b,
      value: v,
      rawEvent: GamepadEvent(gamepadId: '1', timestamp: 0, type: KeyType.button, key: b.name, value: v),
    );

NormalizedGamepadEvent _axis(GamepadAxis a, double v) => NormalizedGamepadEvent(
      gamepadId: '1',
      timestamp: 0,
      axis: a,
      value: v,
      rawEvent: GamepadEvent(gamepadId: '1', timestamp: 0, type: KeyType.analog, key: a.name, value: v),
    );

void main() {
  group('GamepadInput', () {
    late List<TraversalDirection> nav;
    late int confirms, backs, starts;
    late GamepadInput pad;

    setUp(() {
      nav = [];
      confirms = backs = starts = 0;
      pad = GamepadInput(
        onNavigate: nav.add,
        onConfirm: () => confirms++,
        onBack: () => backs++,
        onStart: () => starts++,
      );
    });

    test('Stick mit Totzone steuert links/rechts', () {
      pad.handle(_axis(GamepadAxis.leftStickX, 0.2));
      expect(pad.left || pad.right, isFalse);
      pad.handle(_axis(GamepadAxis.leftStickX, -0.8));
      expect(pad.left, isTrue);
      pad.handle(_axis(GamepadAxis.leftStickX, 0.8));
      expect(pad.right, isTrue);
      expect(pad.left, isFalse);
    });

    test('A, RB und RT lassen fliegen', () {
      pad.handle(_button(GamepadButton.a, 1));
      expect(pad.fly, isTrue);
      pad.handle(_button(GamepadButton.a, 0));
      expect(pad.fly, isFalse);
      pad.handle(_button(GamepadButton.rightBumper, 1));
      expect(pad.fly, isTrue);
      pad.handle(_button(GamepadButton.rightBumper, 0));
      pad.handle(_axis(GamepadAxis.rightTrigger, 0.9));
      expect(pad.fly, isTrue);
    });

    test('Tasten feuern nur beim Drücken, nicht beim Halten', () {
      pad.handle(_button(GamepadButton.a, 1));
      pad.handle(_button(GamepadButton.a, 1));
      pad.handle(_button(GamepadButton.a, 0));
      pad.handle(_button(GamepadButton.start, 1));
      pad.handle(_button(GamepadButton.b, 1));
      expect(confirms, 1);
      expect(starts, 1);
      expect(backs, 1);
    });

    test('Steuerkreuz und Stick navigieren einmal pro Auslenkung', () {
      pad.handle(_button(GamepadButton.dpadDown, 1));
      pad.handle(_axis(GamepadAxis.leftStickY, 0.9));
      pad.handle(_axis(GamepadAxis.leftStickY, 1.0));
      pad.handle(_axis(GamepadAxis.leftStickY, 0));
      pad.handle(_axis(GamepadAxis.leftStickX, -0.9));
      expect(nav, [TraversalDirection.down, TraversalDirection.up, TraversalDirection.left]);
    });

    test('clear lässt nichts hängen', () {
      pad.handle(_button(GamepadButton.a, 1));
      pad.handle(_axis(GamepadAxis.leftStickX, 1));
      pad.clear();
      expect(pad.fly || pad.right, isFalse);
    });

    test('Neu belegte Knöpfe steuern Fliegen und Aktionen; Menü-A bleibt fest', () {
      final actions = <int>[];
      final p = GamepadInput(
        onNavigate: nav.add,
        onConfirm: () => confirms++,
        onBack: () => backs++,
        onStart: () => starts++,
        onAction: actions.add,
      );
      p.bindings.setPad(InputAction.fly, 0, GamepadButton.b);
      p.bindings.setPad(InputAction.action2, 0, GamepadButton.a);
      p.handle(_button(GamepadButton.b, 1));
      expect(p.fly, isTrue);
      p.handle(_button(GamepadButton.a, 1));
      expect(actions, [1]);
      expect(confirms, 1, reason: 'A bestätigt in Menüs weiterhin');
      p.handle(_button(GamepadButton.y, 1));
      expect(actions, [1], reason: 'Y ist nicht mehr belegt');
    });

    test('Während der Neubelegung geht der Knopf nur an die Erfassung', () {
      GamepadButton? got;
      pad.onCapture = (b) => got = b;
      pad.handle(_button(GamepadButton.start, 1));
      expect(got, GamepadButton.start);
      expect(starts, 0);
    });
  });
}
