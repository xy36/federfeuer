import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:federfeuer/game/federfeuer_game.dart';
import 'package:federfeuer/main.dart' show buildOverlayMap;
import 'package:gamepads/gamepads.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'helpers/fonts.dart';

NormalizedGamepadEvent _button(GamepadButton b, double v) => NormalizedGamepadEvent(
      gamepadId: '1',
      timestamp: 0,
      button: b,
      value: v,
      rawEvent: GamepadEvent(gamepadId: '1', timestamp: 0, type: KeyType.button, key: b.name, value: v),
    );

void main() {
  setUpAll(loadGameFonts);

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
        overlayBuilderMap: buildOverlayMap(),
      ),
    ));
    Future<void> frames([int n = 4]) async {
      for (var i = 0; i < n; i++) {
        await tester.pump(const Duration(milliseconds: 50));
      }
    }

    await frames();
    game.pad.used = true;
    game.startRun('pistol');
    await tester.pump();
    game.run!.gain(20); // genug XP für ein Level-up
    game.endWave();
    // Erst die Einblendung „Welle geschafft“, dann das Level-up.
    expect(game.phase, Phase.cleared);
    await frames();
    expect(game.phase, Phase.cleared);
    await frames(30); // 1,5 s in 50-ms-Schritten (Spiel-dt ist auf 0,05 s begrenzt)
    expect(game.phase, Phase.levelUp);

    Future<FocusNode?> press(GamepadButton b) async {
      game.pad.handle(_button(b, 1));
      game.pad.handle(_button(b, 0));
      await frames();
      return FocusManager.instance.primaryFocus;
    }

    // A direkt nach dem Öffnen (noch vom Fliegen) wählt nichts aus.
    final levelBefore = game.run!.pendingLevels;
    await press(GamepadButton.a);
    expect(game.phase, Phase.levelUp);
    expect(game.run!.pendingLevels, levelBefore);

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

    // Nach Ablauf der Sperre wählt A die fokussierte Karte.
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 600)));
    await press(GamepadButton.a);
    expect(game.run!.pendingLevels, levelBefore - 1);
  });
}
