import 'dart:math';

import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:federfeuer/game/components/pickups.dart';
import 'package:federfeuer/game/config.dart';
import 'package:federfeuer/game/federfeuer_game.dart';
import 'package:federfeuer/main.dart' show buildOverlayMap;
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  test('Küken und Spatz: schwebt; ab Falke sinkt es, je höher die Stufe desto schneller', () {
    expect([for (final d in difficultyDefs) d.dropFallSpeed], [0, 0, 12, 35, 70]);
  });

  testWidgets('Schwebendes Material bleibt am Todesort, fallendes landet am Boden', (tester) async {
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
    // Weit weg vom Spieler (Start links), damit nichts eingesammelt wird
    final floating = Drop(Vector2(1500, 200), material: true, rng: Random(1), fallSpeed: 0);
    final slow = Drop(Vector2(1550, 200), material: true, rng: Random(1), fallSpeed: 12);
    final falling = Drop(Vector2(1600, 200), material: true, rng: Random(1));
    game.world.addAll([floating, slow, falling]);
    for (var i = 0; i < 120; i++) {
      await tester.pump(const Duration(milliseconds: 50)); // 6 s
    }
    expect(floating.isMounted, isTrue);
    expect((floating.y - 200).abs(), lessThan(60), reason: 'schwebt ungefähr am Todesort');
    expect((floating.x - 1500).abs(), lessThan(40));
    expect(falling.y, closeTo(kGround - 5, 0.5), reason: 'liegt am Boden');
    expect(slow.y, greaterThan(floating.y + 20), reason: 'sinkt langsam');
    expect(slow.y, lessThan(kGround - 100), reason: 'nach 6 s noch weit über dem Boden');
  });
}
