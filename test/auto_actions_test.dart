import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:federfeuer/game/components/projectiles.dart';
import 'package:federfeuer/game/config.dart';
import 'package:federfeuer/game/federfeuer_game.dart';
import 'package:federfeuer/game/run_state.dart';
import 'package:federfeuer/main.dart' show buildOverlayMap;
import 'package:shared_preferences/shared_preferences.dart';

/// Aktionen lösen automatisch aus, sobald sie bereit sind und es sich lohnt.
Future<FederfeuerGame> _game(WidgetTester t, ActionId action) async {
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
  game.run!.weapons.clear();
  game.run!.actions
    ..clear()
    ..add(OwnedAction(action));
  game.debugInvincible = true;
  game.player.position.setValues(600, 300);
  game.actionCds.fillRange(0, game.actionCds.length, 0);
  return game;
}

Future<void> _run(WidgetTester t, FederfeuerGame game, double seconds) async {
  for (var i = 0; i < seconds * 20; i++) {
    game.waveTime = 99;
    await t.pump(const Duration(milliseconds: 50));
  }
}

void main() {
  testWidgets('Hupe löst aus, wenn mehrere Gegner nah sind', (t) async {
    final game = await _game(t, ActionId.horn);
    await _run(t, game, 0.3);
    expect(game.actionCds[0], 0, reason: 'ohne Gegner in der Nähe wartet sie');
    game.addEnemy(EnemyType.rock, Vector2(680, 300));
    game.addEnemy(EnemyType.rock, Vector2(520, 300));
    await _run(t, game, 0.2);
    expect(game.actionCds[0], greaterThan(0));
  });

  testWidgets('Sturzflug weicht einer Kugel aus – weg von ihr', (t) async {
    final game = await _game(t, ActionId.dash);
    game.player.face = 1;
    game.world.add(EnemyBullet(Vector2(640, 300), Vector2(-200, 0), 6, 1, const Color(0xFFFFFFFF)));
    await _run(t, game, 0.1);
    expect(game.actionCds[0], greaterThan(0));
    expect(game.player.face, -1);
  });

  testWidgets('Magnetpfiff wartet auf genug Material im Bild', (t) async {
    final game = await _game(t, ActionId.magnet);
    await _run(t, game, 0.3);
    expect(game.actionCds[0], 0);
    game.dropMaterial(Vector2(800, 250), kAutoMaterial + 3);
    await _run(t, game, 0.3);
    expect(game.actionCds[0], greaterThan(0));
  });

  testWidgets('Kampf-Aktionen lösen spätestens nach der Rückfallzeit aus', (t) async {
    final game = await _game(t, ActionId.horn);
    game.addEnemy(EnemyType.rock, Vector2(900, 200));
    await _run(t, game, 1);
    expect(game.actionCds[0], 0, reason: 'ein einzelner Gegner weit weg lohnt sich nicht sofort');
    await _run(t, game, kAutoFallback);
    expect(game.actionCds[0], greaterThan(0));
  });
}
