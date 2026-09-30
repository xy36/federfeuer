import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:federfeuer/game/federfeuer_game.dart';
import 'package:federfeuer/ui/controls_overlay.dart';
import 'package:federfeuer/ui/overlays.dart';
import 'package:federfeuer/ui/shop_overlay.dart';
import 'package:gamepads/gamepads.dart';
import 'package:shared_preferences/shared_preferences.dart';

NormalizedGamepadEvent _button(GamepadButton b, double v) => NormalizedGamepadEvent(
      gamepadId: '1',
      timestamp: 0,
      button: b,
      value: v,
      rawEvent: GamepadEvent(gamepadId: '1', timestamp: 0, type: KeyType.button, key: b.name, value: v),
    );

void main() {
  testWidgets('Controller erreicht alle Karten im Level-up', (tester) async {
    SharedPreferences.setMockInitialValues({});
    tester.view.physicalSize = const Size(1280, 720);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    final game = FederfeuerGame();
    await tester.pumpWidget(MaterialApp(
      home: GameWidget<FederfeuerGame>(
        game: game,
        focusNode: game.focusNode,
        autofocus: true,
        overlayBuilderMap: {
          'menu': (context, game) => MenuOverlay(game: game),
          'levelUp': (context, game) => LevelUpOverlay(game: game),
          'shop': (context, game) => ShopOverlay(game: game),
          'pause': (context, game) => PauseOverlay(game: game),
          'gameOver': (context, game) => GameOverOverlay(game: game),
          'controls': (context, game) => ControlsOverlay(game: game),
        },
      ),
    ));
    Future<void> frames() async {
      for (var i = 0; i < 4; i++) {
        await tester.pump(const Duration(milliseconds: 50));
      }
    }

    await frames();
    game.pad.used = true;
    game.startRun('pistol');
    await tester.pump();
    game.run!.gain(20); // genug XP für ein Level-up
    game.endWave();
    await frames();
    expect(game.phase, Phase.levelUp);

    Future<FocusNode?> press(GamepadButton b) async {
      game.pad.handle(_button(b, 1));
      game.pad.handle(_button(b, 0));
      await frames();
      return FocusManager.instance.primaryFocus;
    }

    final first = FocusManager.instance.primaryFocus;
    final visited = {first};
    for (var i = 0; i < 3; i++) {
      visited.add(await press(GamepadButton.dpadRight));
    }
    expect(visited.length, 4, reason: 'alle vier Karten nach rechts erreichbar');
    expect(visited, isNot(contains(game.focusNode)));

    for (var i = 0; i < 3; i++) {
      await press(GamepadButton.dpadLeft);
    }
    expect(FocusManager.instance.primaryFocus, first, reason: 'zurück bis zur ersten Karte');
  });
}
