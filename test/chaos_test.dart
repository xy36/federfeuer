import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:federfeuer/game/components/enemy.dart';
import 'package:federfeuer/game/config.dart';
import 'package:federfeuer/game/federfeuer_game.dart';
import 'package:federfeuer/main.dart' show buildOverlayMap;
import 'package:shared_preferences/shared_preferences.dart';

/// Chaos: Zustände des Spielers, Wirrling, Wirrkraut, Hühnerzauber, Gummiflügel.
Future<FederfeuerGame> _game(WidgetTester t) async {
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
  game.run!
    ..weapons.clear()
    ..wave = 6;
  game.player.position.setValues(600, 300);
  // Unverwundbar, aber Chaos wirkt (godMode würde Chaos abschalten)
  game.debugInvincible = true;
  return game;
}

/// Spielzeit laufen lassen (Welle endet nicht, keine neuen Gegner stören).
Future<void> _run(WidgetTester t, FederfeuerGame game, double seconds) async {
  for (var i = 0; i < seconds * 20; i++) {
    game.waveTime = 99;
    await t.pump(const Duration(milliseconds: 50));
  }
}

void main() {
  testWidgets('Chaos läuft ab, danach kurz immun', (t) async {
    final game = await _game(t);
    game.applyChaos(ChaosEffect.sticky);
    expect(game.chaos(ChaosEffect.sticky), isTrue);
    await _run(t, game, ChaosEffect.sticky.duration + 0.3);
    expect(game.chaos(ChaosEffect.sticky), isFalse);
    game.applyChaos(ChaosEffect.sticky);
    expect(game.chaos(ChaosEffect.sticky), isFalse, reason: 'immun nach dem Ende');
    await _run(t, game, kChaosImmunity + 0.3);
    game.applyChaos(ChaosEffect.sticky);
    expect(game.chaos(ChaosEffect.sticky), isTrue);
  });

  testWidgets('Verwirrt: rechts drücken fliegt nach links', (t) async {
    final game = await _game(t);
    game.applyChaos(ChaosEffect.confused);
    final x0 = game.player.x;
    await t.sendKeyDownEvent(LogicalKeyboardKey.arrowRight);
    await _run(t, game, 0.6);
    await t.sendKeyUpEvent(LogicalKeyboardKey.arrowRight);
    expect(game.player.x, lessThan(x0 - 20));
  });

  testWidgets('Kopfüber: ohne Eingabe steigt der Vogel', (t) async {
    final game = await _game(t);
    game.applyChaos(ChaosEffect.upsideDown);
    final y0 = game.player.y;
    await _run(t, game, 0.8);
    expect(game.player.y, lessThan(y0 - 20));
  });

  testWidgets('Spiegelwelt spiegelt die Kamera', (t) async {
    final game = await _game(t);
    await _run(t, game, 0.1);
    expect(game.camera.viewfinder.transform.scale.x, greaterThan(0));
    game.applyChaos(ChaosEffect.mirror);
    await _run(t, game, 0.1);
    expect(game.camera.viewfinder.transform.scale.x, lessThan(0));
  });

  testWidgets('Wirrling stößt Chaos-Wolken aus', (t) async {
    final game = await _game(t);
    game.godMode = true;
    game.addEnemy(EnemyType.wirrling, Vector2(800, 250));
    var seen = false;
    for (var i = 0; i < 6 * 20 && !seen; i++) {
      game.waveTime = 99;
      await t.pump(const Duration(milliseconds: 50));
      seen = game.world.children.whereType<ChaosCloud>().isNotEmpty;
    }
    expect(seen, isTrue);
  });

  testWidgets('Huhn: harmlos, verwundbarer, ohne Sprite', (t) async {
    final game = await _game(t);
    game.addEnemy(EnemyType.rock, Vector2(900, 200));
    final e = game.enemies.last;
    e.chickenT = kChickenTime;
    expect(e.disabled, isTrue);
    expect(e.spriteDef, isNull);
    final hp = e.hp;
    game.hurtEnemy(e, 10, false, 0);
    expect(hp - e.hp, closeTo(10 * (1 + kChickenVuln), 1e-9));
  });

  testWidgets('Verwirrter Gegner greift einen anderen an', (t) async {
    final game = await _game(t);
    game.addEnemy(EnemyType.crow, Vector2(900, 200));
    final mad = game.enemies.last;
    game.addEnemy(EnemyType.rock, Vector2(960, 200));
    final victim = game.enemies.last;
    mad.confusedT = kConfuseTime;
    final hp = victim.hp;
    await _run(t, game, 1.5);
    expect(victim.hp, lessThan(hp));
  });

  testWidgets('Gummiflügel: gegen die Decke prallt man ab und löst eine Schockwelle aus', (t) async {
    final game = await _game(t);
    game.godMode = true;
    game.run!.items['gummifluegel'] = 1;
    game.player.position.setValues(600, kCeil + game.player.r + 2);
    game.player.vel.y = -320;
    game.addEnemy(EnemyType.rock, Vector2(640, kCeil + 40));
    final e = game.enemies.last;
    final hp = e.hp;
    await _run(t, game, 0.1);
    expect(e.hp, lessThan(hp));
    expect(game.player.vel.y, greaterThanOrEqualTo(0));
  });
}
