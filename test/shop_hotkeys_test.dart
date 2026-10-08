import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:federfeuer/game/config.dart';
import 'package:federfeuer/game/federfeuer_game.dart';
import 'package:federfeuer/game/gamepad_input.dart';
import 'package:federfeuer/main.dart' show buildOverlayMap;
import 'package:federfeuer/ui/inspect.dart' show InfoCard;
import 'package:federfeuer/ui/widgets.dart' show ChoiceCard;
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

Future<FederfeuerGame> _shop(WidgetTester t) async {
  await t.runAsync(loadGameFonts);
  SharedPreferences.setMockInitialValues({});
  t.view.physicalSize = const Size(1280, 720);
  t.view.devicePixelRatio = 1;
  addTearDown(t.view.reset);
  addTearDown(() => controllerActive.value = false);
  final game = FederfeuerGame();
  await t.pumpWidget(MaterialApp(
    home: GameWidget<FederfeuerGame>(game: game, focusNode: game.focusNode, overlayBuilderMap: buildOverlayMap()),
  ));
  for (var i = 0; i < 4; i++) {
    await t.pump(const Duration(milliseconds: 50));
  }
  game.debugStartAtWave(3, shopFirst: true, equip: false);
  game.run!.money = 500;
  for (var i = 0; i < 4; i++) {
    await t.pump(const Duration(milliseconds: 50));
  }
  // Sperre nach dem Öffnen abwarten
  await t.runAsync(() => Future<void>.delayed(const Duration(milliseconds: kMenuConfirmGraceMs + 50)));
  await t.pump();
  return game;
}

void main() {
  testWidgets('Tastatur: R würfelt neu, L hält das gewählte Angebot zurück, N startet die Welle', (t) async {
    final game = await _shop(t);
    final r = game.run!;
    final before = r.offers.first;
    game.focusNode.requestFocus();
    await t.pump();
    await t.sendKeyEvent(LogicalKeyboardKey.keyR);
    await t.pump();
    expect(r.rerolls, 1);
    expect(r.offers.first, isNot(same(before)));

    // Erstes Angebot über den Bereichssprung anwählen, dann zurückhalten
    await t.sendKeyEvent(LogicalKeyboardKey.pageDown);
    await t.sendKeyEvent(LogicalKeyboardKey.pageUp);
    await t.pump();
    await t.sendKeyEvent(LogicalKeyboardKey.keyL);
    await t.pump();
    expect(r.offers.where((o) => o.locked).length, 1);

    await t.sendKeyEvent(LogicalKeyboardKey.keyN);
    await t.pump();
    expect(game.phase, Phase.play);
    expect(r.wave, 3);
    game.toMenu();
    await t.pump(const Duration(seconds: 1));
  });

  testWidgets('Controller: X würfelt, Start startet die Welle', (t) async {
    final game = await _shop(t);
    final r = game.run!;
    game.pad.handle(_button(GamepadButton.x, 1));
    game.pad.handle(_button(GamepadButton.x, 0));
    await t.pump();
    expect(r.rerolls, 1);
    game.pad.handle(_button(GamepadButton.start, 1));
    await t.pump();
    expect(game.phase, Phase.play);
    game.toMenu();
    await t.pump(const Duration(seconds: 1));
  });

  testWidgets('Direkt nach dem Öffnen startet N nicht aus Versehen die Welle', (t) async {
    await t.runAsync(loadGameFonts);
    SharedPreferences.setMockInitialValues({});
    t.view.physicalSize = const Size(1280, 720);
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.reset);
    final game = FederfeuerGame();
    await t.pumpWidget(MaterialApp(
      home: GameWidget<FederfeuerGame>(game: game, focusNode: game.focusNode, overlayBuilderMap: buildOverlayMap()),
    ));
    for (var i = 0; i < 4; i++) {
      await t.pump(const Duration(milliseconds: 50));
    }
    game.debugStartAtWave(3, shopFirst: true, equip: false);
    await t.pump();
    game.focusNode.requestFocus();
    await t.sendKeyEvent(LogicalKeyboardKey.keyN);
    await t.pump();
    expect(game.phase, Phase.shop);
    game.toMenu();
    await t.pump(const Duration(seconds: 1));
  });

  testWidgets('Controller: B schließt das Info-Panel, Weiterbewegen zeigt es wieder', (t) async {
    final game = await _shop(t);
    void press(GamepadButton b) {
      game.pad
        ..handle(_button(b, 1))
        ..handle(_button(b, 0));
    }

    // Erstes Angebot ansteuern, dann per Steuerkreuz zum nächsten
    final card = find.byType(ChoiceCard).first;
    Focus.of(t.element(find.descendant(of: card, matching: find.byType(Text)).first)).requestFocus();
    await t.pump();
    press(GamepadButton.dpadRight);
    await t.pump();
    expect(find.byType(InfoCard), findsOneWidget);
    press(GamepadButton.b);
    await t.pump();
    expect(find.byType(InfoCard), findsNothing);
    expect(game.phase, Phase.shop, reason: 'B verlässt den Shop nicht');
    press(GamepadButton.dpadLeft);
    await t.pump();
    expect(find.byType(InfoCard), findsOneWidget);
    expect(t.takeException(), isNull, reason: 'Hinweiszeile ohne Überlauf');
    game.toMenu();
    await t.pump(const Duration(seconds: 1));
  });

  testWidgets('Controller-Hinweiszeile im Shop passt auch auf kleine Bildschirme', (t) async {
    final game = await _shop(t);
    t.view.physicalSize = const Size(844, 390);
    controllerActive.value = true;
    await t.pump();
    await t.pump();
    expect(find.text('Info schließen'), findsOneWidget);
    expect(t.takeException(), isNull);
    game.toMenu();
    await t.pump(const Duration(seconds: 1));
  });
}
