import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:federfeuer/game/config.dart';
import 'package:federfeuer/game/federfeuer_game.dart';
import 'package:federfeuer/game/run_state.dart';
import 'package:federfeuer/main.dart' show buildOverlayMap;
import 'package:shared_preferences/shared_preferences.dart';

import 'helpers/fonts.dart';

void main() {
  testWidgets('Aktions-Karte mit mehreren Rezepten und vollen Plätzen läuft nicht über', (t) async {
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
    final r = game.run!..addAction(ActionId.magnet); // Sturzflug + Magnetpfiff: Blase passt zu beiden
    r.offers = [Offer.item('a_shield', 20)];
    game.phase = Phase.shop;
    game.overlays.add('shop');
    for (var i = 0; i < 4; i++) {
      await t.pump(const Duration(milliseconds: 50));
    }
    expect(find.textContaining('(+1)'), findsOneWidget);
    game.overlays.remove('shop');
    game.toMenu();
    await t.pump(const Duration(seconds: 1));
  });
}
