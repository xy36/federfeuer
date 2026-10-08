import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:federfeuer/game/config.dart' show ActionId;
import 'package:federfeuer/game/federfeuer_game.dart';
import 'package:federfeuer/game/input_bindings.dart';
import 'package:federfeuer/main.dart' show buildOverlayMap;
import 'package:gamepads/gamepads.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  test('Eine Taste gilt nur für eine Aktion', () {
    final b = InputBindings();
    b.setKey(InputAction.action1, 2, LogicalKeyboardKey.keyW);
    expect(b.keyMatches(InputAction.action1, LogicalKeyboardKey.keyW), isTrue);
    expect(b.keyMatches(InputAction.fly, LogicalKeyboardKey.keyW), isFalse);
    b.setPad(InputAction.pause, 1, GamepadButton.a);
    expect(b.padMatches(InputAction.fly, GamepadButton.a), isFalse);
  });

  test('Belegung wird gespeichert und geladen, Standard stellt zurück', () async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final a = InputBindings()
      ..setKey(InputAction.fly, 0, LogicalKeyboardKey.keyJ)
      ..setPad(InputAction.action1, 0, GamepadButton.rightStick);
    await a.saveTo(prefs);
    final b = InputBindings()..loadFrom(prefs);
    expect(b.keys[InputAction.fly]![0], LogicalKeyboardKey.keyJ);
    expect(b.pad[InputAction.action1]![0], GamepadButton.rightStick);
    b.resetKeys();
    expect(b.keys[InputAction.fly]![0], LogicalKeyboardKey.keyW);
  });

  test('Tastennamen sind lesbar', () {
    expect(keyLabel(LogicalKeyboardKey.space), 'Leertaste');
    expect(keyLabel(LogicalKeyboardKey.keyQ), 'Q');
    expect(padLabel(GamepadButton.rightTrigger), 'RT');
  });

  testWidgets('Spiel nutzt die neue Belegung', (tester) async {
    SharedPreferences.setMockInitialValues({});
    tester.view.physicalSize = const Size(1280, 720);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final game = FederfeuerGame();
    await tester.pumpWidget(MaterialApp(
      home: GameWidget<FederfeuerGame>(game: game, focusNode: game.focusNode, overlayBuilderMap: buildOverlayMap()),
    ));
    for (var i = 0; i < 4; i++) {
      await tester.pump(const Duration(milliseconds: 50));
    }
    game.startRun('pistol');
    await tester.pump(const Duration(milliseconds: 50));
    game.settings.bindings.setKey(InputAction.fly, 0, LogicalKeyboardKey.keyJ);
    game.focusNode.requestFocus();
    await tester.pump();
    await tester.sendKeyDownEvent(LogicalKeyboardKey.keyJ);
    expect(game.keyFly, isTrue);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.keyJ);
    expect(game.keyFly, isFalse);
    await tester.sendKeyDownEvent(LogicalKeyboardKey.keyW);
    expect(game.keyFly, isFalse, reason: 'W ist nicht mehr belegt');
    await tester.sendKeyUpEvent(LogicalKeyboardKey.keyW);
    // Aktion 1 auf neue Taste (Seifenblase löst ohne Gefahr nicht von selbst aus)
    game.run!.addAction(ActionId.bubbleShield);
    game.settings.bindings.setKey(InputAction.action1, 0, LogicalKeyboardKey.keyK);
    await tester.sendKeyDownEvent(LogicalKeyboardKey.keyK);
    expect(game.actionCds[0], greaterThan(0));
    await tester.sendKeyUpEvent(LogicalKeyboardKey.keyK);
    game.toMenu();
    await tester.pump(const Duration(seconds: 1));
  });
}
