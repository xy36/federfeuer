import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:federfeuer/game/components/enemy.dart';
import 'package:federfeuer/game/components/pickups.dart';
import 'package:federfeuer/game/components/projectiles.dart';
import 'package:federfeuer/game/config.dart';
import 'package:federfeuer/game/federfeuer_game.dart';
import 'package:federfeuer/main.dart' show buildOverlayMap;
import 'package:shared_preferences/shared_preferences.dart';

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
  return game;
}

Future<void> _run(WidgetTester t, FederfeuerGame game, double seconds) async {
  for (var i = 0; i < seconds * 20; i++) {
    game.waveTime = 99;
    await t.pump(const Duration(milliseconds: 50));
  }
}

void main() {
  test('Jede Welt bringt eigene Gegner, frühere bleiben', () {
    Set<EnemyType> types(int w) => {for (final (t, _) in spawnPool(w)) t};
    expect(types(1), {EnemyType.crow});
    expect(types(4), containsAll([EnemyType.puffball, EnemyType.scarecrow]));
    expect(types(6), containsAll([EnemyType.bat, EnemyType.weathercock, EnemyType.puffball]));
    expect(types(10), containsAll([EnemyType.spider, EnemyType.wisp]));
    expect(types(13), containsAll([EnemyType.eagle, EnemyType.avalanche, EnemyType.spider]));
    for (final t in EnemyType.values) {
      expect(t.label, isNotEmpty);
      expect(enemyDefs[t], isNotNull);
    }
  });

  testWidgets('Alle Gegner laufen ohne Fehler; stationäre bleiben stehen', (t) async {
    final game = await _game(t);
    game.startRun('pistol');
    game.run!.weapons.clear();
    game.godMode = true;
    final p = game.player.position..setValues(400, 300);
    final list = <Enemy>[];
    for (final ty in EnemyType.values.where((e) => e != EnemyType.boss)) {
      final d = enemyDefs[ty]!;
      game.addEnemy(ty, Vector2(p.x + 250, d.flying ? 200 : kGround - d.radius));
      list.add(game.enemies.last);
    }
    final scare = list.firstWhere((e) => e.type == EnemyType.scarecrow);
    final home = scare.position.clone();
    await _run(t, game, 4);
    expect(scare.position, home);
  });

  testWidgets('Pusteling hinterlässt Giftwolke, Spinnennetz verlangsamt, Irrlicht explodiert', (t) async {
    final game = await _game(t);
    game.startRun('pistol');
    game.run!.weapons.clear();
    final p = game.player.position..setValues(400, 300);
    game.addEnemy(EnemyType.puffball, Vector2(800, 300));
    final puff = game.enemies.last;
    game.hurtEnemy(puff, 999, false, 0);
    await t.pump(const Duration(milliseconds: 50));
    expect(game.world.children.whereType<PoisonCloud>(), isNotEmpty);

    game.player.webT = 0;
    game.player.iframe = 0;
    game.godMode = false;
    game.world.add(EnemyBullet(p.clone(), Vector2.zero(), 8, 1, const Color(0xFFFFFFFF), web: true));
    await t.pump(const Duration(milliseconds: 50));
    expect(game.player.webT, greaterThan(0));

    game.godMode = true;
    game.addEnemy(EnemyType.wisp, Vector2(p.x + 150, p.y));
    final wisp = game.enemies.last;
    await _run(t, game, 10);
    expect(wisp.dead, isTrue, reason: 'nach ein paar Sprüngen explodiert es');
  });

  testWidgets('Elite: gepanzert halber Schaden, teilend zerfällt, explosiv hinterlässt Sprengsatz, mehr Material', (t) async {
    final game = await _game(t);
    game.startRun('pistol');
    game.run!
      ..weapons.clear()
      ..wave = 6;
    game.godMode = true;
    game.player.position.setValues(200, 300);

    game.addEnemy(EnemyType.beetle, Vector2(800, kGround - 18), elite: EliteMod.armored);
    final armored = game.enemies.last;
    final hp = armored.hp;
    game.hurtEnemy(armored, 10, false, 0);
    expect(hp - armored.hp, closeTo(5, 0.001));

    game.addEnemy(EnemyType.crow, Vector2(900, 200), elite: EliteMod.splitting);
    final split = game.enemies.last;
    final before = game.enemies.length;
    game.hurtEnemy(split, 1e6, false, 0);
    await t.pump(const Duration(milliseconds: 50)); // Kopien erscheinen nach dem Frame
    expect(game.enemies.where((e) => e.mini && !e.dead).length, 2);
    expect(game.enemies.length, greaterThanOrEqualTo(before + 1));

    game.addEnemy(EnemyType.crow, Vector2(1000, 200), elite: EliteMod.volatile);
    game.hurtEnemy(game.enemies.last, 1e6, false, 0);
    await t.pump(const Duration(milliseconds: 50));
    expect(game.world.children.whereType<VolatileRemnant>(), isNotEmpty);
    expect(game.world.children.whereType<Drop>().where((d) => d.material).length, greaterThanOrEqualTo(kEliteDrops));
    expect(game.progress.hasSeen('x:volatile'), isTrue);
  });

  test('Elite-Chance steigt ab Welle 5 und bleibt gedeckelt', () {
    expect(eliteChance(4), 0);
    expect(eliteChance(5), greaterThan(0));
    expect(eliteChance(14), lessThanOrEqualTo(0.15));
  });

  testWidgets('Torwächter erscheint vor dem Ziel, versperrt es und gibt es nach dem Sieg frei', (t) async {
    final game = await _game(t);
    game.startRun('pistol');
    game.run!
      ..weapons.clear()
      ..wave = 4;
    game.startWave();
    game.godMode = true;
    final goal = game.goalX!;
    expect(game.goalLocked, isTrue);
    game.player.position.x = goal - kGateTriggerDist + 50;
    await t.pump(const Duration(milliseconds: 50));
    final gate = game.gate!;
    expect(gate.type, EnemyType.strawKing);
    // Am Ziel: wird zurückgeschoben, Welle läuft weiter
    for (var i = 0; i < 10; i++) {
      game.player.position.x = goal + 5;
      game.waveTime = 99;
      await t.pump(const Duration(milliseconds: 50));
    }
    expect(game.phase, Phase.play);
    expect(game.player.x, lessThan(goal));
    game.hurtEnemy(gate, 1e9, false, 0);
    expect(game.goalLocked, isFalse);
    game.player.position.x = goal + 5;
    await t.pump(const Duration(milliseconds: 50));
    expect(game.phase, isNot(Phase.play), reason: 'Ziel erreicht');
    game.toMenu();
    await t.pump(const Duration(seconds: 1));
  });

  test('Torwächter nur am Ende von Felder, Dorf und Wald', () {
    expect([for (var w = 1; w <= kMaxWave; w++) gatekeeperForWave(w)].whereType<EnemyType>().toList(),
        [EnemyType.strawKing, EnemyType.bell, EnemyType.spiderMother]);
    expect(gatekeeperForWave(4), isNotNull);
    expect(biomeForWave(4), Biome.fields);
    expect(biomeForWave(8), Biome.village);
    expect(biomeForWave(12), Biome.forest);
  });

  testWidgets('Geierkönig wechselt bei 66 % und 33 % HP die Phase', (t) async {
    final game = await _game(t);
    game.startRun('pistol');
    game.run!
      ..weapons.clear()
      ..wave = kMaxWave;
    game.startWave();
    game.godMode = true;
    for (var i = 0; i < 50 && !game.enemies.any((e) => e.type == EnemyType.boss); i++) {
      await t.pump(const Duration(milliseconds: 50));
    }
    final boss = game.enemies.firstWhere((e) => e.type == EnemyType.boss);
    expect(boss.bossPhase, 1);
    boss.hp = boss.maxHp * 0.6;
    await t.pump(const Duration(milliseconds: 50));
    expect(boss.bossPhase, 2);
    for (var i = 0; i < 40; i++) {
      await t.pump(const Duration(milliseconds: 50));
    }
    expect(game.world.children.whereType<FeatherRain>().isNotEmpty || game.world.children.whereType<EnemyBullet>().isNotEmpty, isTrue);
    boss.hp = boss.maxHp * 0.2;
    for (var i = 0; i < 80; i++) {
      await t.pump(const Duration(milliseconds: 50));
    }
    expect(boss.bossPhase, 3);
    game.toMenu();
    await t.pump(const Duration(seconds: 1));
  });
}
