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
  testWidgets('Felsbeben löst aus, wenn mehrere Gegner nah sind', (t) async {
    final game = await _game(t, ActionId.quake);
    await _run(t, game, 0.3);
    expect(game.actionCds[0], 0, reason: 'ohne Gegner in der Nähe wartet es');
    game.addEnemy(EnemyType.rock, Vector2(680, 300));
    game.addEnemy(EnemyType.rock, Vector2(520, 300));
    // Erst ankündigen (Aufladen sichtbar), dann auslösen
    await _run(t, game, 0.2);
    expect(game.announcing, ActionId.quake);
    expect(game.actionCds[0], 0, reason: 'noch am Aufladen');
    await _run(t, game, kActionWindup);
    expect(game.actionCds[0], greaterThan(0));
    expect(game.announcing, isNull);
    expect(game.shoutAction, ActionId.quake, reason: 'Name wird eingeblendet');
  });

  testWidgets('Seifenblase schützt vor einer anfliegenden Kugel', (t) async {
    final game = await _game(t, ActionId.bubbleShield);
    game.world.add(EnemyBullet(Vector2(640, 300), Vector2(-200, 0), 6, 1, const Color(0xFFFFFFFF)));
    await _run(t, game, kShieldWindup + 0.1);
    expect(game.actionCds[0], greaterThan(0));
    expect(game.shieldT, greaterThan(0));
  });

  testWidgets('Wirbelsturm wartet auf eine Gruppe oder genug Material', (t) async {
    final game = await _game(t, ActionId.whirlwind);
    await _run(t, game, 0.3);
    expect(game.actionCds[0], 0);
    game.dropMaterial(Vector2(800, 250), kAutoMaterial + 3);
    await _run(t, game, kActionWindup + 0.3);
    expect(game.actionCds[0], greaterThan(0));
  });

  testWidgets('Kampf-Kräfte lösen spätestens nach der Rückfallzeit aus', (t) async {
    final game = await _game(t, ActionId.quake);
    game.addEnemy(EnemyType.rock, Vector2(900, 200));
    await _run(t, game, 1);
    expect(game.actionCds[0], 0, reason: 'ein einzelner Gegner weit weg lohnt sich nicht sofort');
    await _run(t, game, kAutoFallback);
    expect(game.actionCds[0], greaterThan(0));
  });

  testWidgets('Platzregen macht alle Gegner im Bild nass, Glutbombe setzt in Brand', (t) async {
    final game = await _game(t, ActionId.downpour);
    game.addEnemy(EnemyType.rock, Vector2(800, 250));
    final e = game.enemies.last;
    game.useAction(0);
    expect(e.wet, isTrue);
    game.run!.actions[0] = OwnedAction(ActionId.fireBomb);
    game.actionCds[0] = 0;
    e.wetT = 0;
    game.useAction(0);
    expect(e.burning, isTrue);
  });
}
