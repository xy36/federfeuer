
import 'package:flame/game.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:federfeuer/game/config.dart';
import 'package:federfeuer/game/federfeuer_game.dart';
import 'package:federfeuer/main.dart' show buildOverlayMap;
import 'package:federfeuer/ui/inspect.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'helpers/fonts.dart';


void main() {
  testWidgets('Verschmelzen zeigt Vorschau – bei Aktionen und bei Waffen', (t) async {
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
    game.startRun('pistol');
    final r = game.run!;
    r.addWeapon('pistol', 0);
    r.addAction(ActionId.horn);
    r.actions[1].level = 1;
    r.offers = [];
    game.phase = Phase.shop;
    game.overlays.add('shop');
    await t.pump(const Duration(milliseconds: 50));
    final mouse = await t.createGesture(kind: PointerDeviceKind.mouse);
    await mouse.addPointer(location: Offset.zero);
    await mouse.moveTo(t.getCenter(find.textContaining('Verschmelzen →')));
    await t.pump(const Duration(milliseconds: 150));
    expect(find.byType(InfoCard), findsOneWidget);
    expect(find.textContaining('Aktionsplatz 2 wird frei'), findsOneWidget);
    await mouse.moveTo(t.getCenter(find.text('verschmelzen').first));
    await t.pump(const Duration(milliseconds: 150));
    expect(find.byType(InfoCard), findsOneWidget);
    expect(find.textContaining('Verschmelzen: Stufe I + I → II'), findsOneWidget);
    await mouse.removePointer();
    game.overlays.remove('shop');
    game.toMenu();
    await t.pump(const Duration(seconds: 1));
  });
}
