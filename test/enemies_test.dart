import 'dart:math';

import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:federfeuer/game/components/enemy.dart';
import 'package:federfeuer/game/components/pickups.dart';
import 'package:federfeuer/game/components/projectiles.dart';
import 'package:federfeuer/game/config.dart';
import 'package:federfeuer/game/federfeuer_game.dart';
import 'package:federfeuer/game/run_state.dart';
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
    final value = game.world.children.whereType<Drop>().where((d) => d.material).fold(0, (a, d) => a + d.value);
    expect(value, greaterThanOrEqualTo(kEliteDrops), reason: 'Elite: dreifaches Material');
    expect(game.progress.hasSeen('x:volatile'), isTrue);
  });

  test('Weniger, aber zähere Gegner: Zähigkeit und Spawn-Takt je Welle', () {
    expect(enemyToughness(1), 1);
    expect(enemyToughness(5), closeTo(2, 1e-9));
    expect(enemyDmgBonus(1), 1);
    expect(spawnInterval(1), closeTo(2.9, 1e-9));
    expect(spawnInterval(30), kSpawnIntervalMin);
  });

  testWidgets('Schlussphase: in den letzten Sekunden keine neuen Gegner', (t) async {
    final game = await _game(t);
    game.startRun('pistol');
    game.run!.weapons.clear();
    game.godMode = true;
    int markers() => game.world.children.whereType<SpawnMarker>().length;
    Future<void> pump(double seconds) async {
      for (var i = 0; i < seconds * 20; i++) {
        await t.pump(const Duration(milliseconds: 50));
      }
    }

    // Kurz vor Schluss: nichts Neues
    game.waveTime = kWaveSpawnStop - 0.2;
    final before = markers();
    await pump(1);
    expect(markers(), lessThanOrEqualTo(before));
    expect(game.waveTime, greaterThan(0));

    // Mit genug Restzeit wird wieder gespawnt
    game.waveTime = 30;
    await pump(4);
    expect(markers() + game.enemies.length, greaterThan(0));
  });

  test('Elite-Chance steigt ab Welle 5 und bleibt gedeckelt', () {
    expect(eliteChance(4), 0);
    expect(eliteChance(5), greaterThan(0));
    expect(eliteChance(14), lessThanOrEqualTo(kEliteChanceMax));
    expect(eliteChance(60), kEliteChanceMax);
  });

  testWidgets('Torwächter-Welle: kein Zeitlimit, endet erst nach dem Sieg über den Torwächter', (t) async {
    final game = await _game(t);
    game.startRun('pistol');
    game.run!
      ..weapons.clear()
      ..wave = 4
      ..gatekeepers[4] = EnemyType.strawKing;
    game.startWave();
    game.godMode = true;
    expect(game.gateWave, isTrue);
    final goal = game.goalX!;
    expect(game.goalLocked, isTrue);
    game.player.position.x = goal - kGateTriggerDist + 50;
    await t.pump(const Duration(milliseconds: 50));
    final gate = game.gate!;
    expect(gate.type, EnemyType.strawKing);
    // Am Ziel: wird zurückgeschoben; abgelaufene Zeit beendet die Welle nicht
    for (var i = 0; i < 10; i++) {
      game.player.position.x = goal + 5;
      game.waveTime = -5;
      await t.pump(const Duration(milliseconds: 50));
    }
    expect(game.phase, Phase.play, reason: 'kein Zeitlimit');
    expect(game.player.x, lessThan(goal));
    // Sieg: Welle läuft noch kurz aus, Material und Geschenk fliegen herbei
    final money = game.run!.money;
    final items = game.run!.items.values.fold(0, (a, b) => a + b);
    game.hurtEnemy(gate, 1e9, false, 0);
    expect(game.gateEndT, kGateWaveEndDelay);
    await t.pump(const Duration(milliseconds: 50));
    expect(game.phase, Phase.play, reason: 'Auslaufzeit');
    for (var i = 0; i < (kGateWaveEndDelay / 0.05).ceil() + 4 && game.phase == Phase.play; i++) {
      await t.pump(const Duration(milliseconds: 50));
    }
    expect(game.phase, isNot(Phase.play), reason: 'Welle nach dem Sieg vorbei');
    expect(game.run!.money, greaterThanOrEqualTo(money + kGateDrops), reason: 'Material des Torwächters');
    expect(game.run!.items.values.fold(0, (a, b) => a + b), items + 1, reason: 'Geschenk');
    expect(game.run!.goalBonus, isNull);
    game.toMenu();
    await t.pump(const Duration(seconds: 1));
  });

  testWidgets('Torwächter-Welle: normale Gegner nur so lange wie in einer normalen Welle', (t) async {
    final game = await _game(t);
    game.startRun('pistol');
    game.run!
      ..weapons.clear()
      ..wave = 4;
    game.startWave();
    game.godMode = true;
    game.waveTime = kWaveSpawnStop - 1; // Zeit einer normalen Welle fast um
    game.enemies.clear();
    for (var i = 0; i < 60; i++) {
      await t.pump(const Duration(milliseconds: 50));
    }
    expect(game.phase, Phase.play);
    expect(game.enemies.where((e) => !e.gatekeeper), isEmpty, reason: 'keine neuen Gegner mehr');
    game.toMenu();
    await t.pump(const Duration(seconds: 1));
  });

  test('Torwächter am Ende von Felder, Dorf und Wald: je Run drei verschiedene aus dem Pool', () {
    expect([for (var w = 1; w <= kMaxWave; w++) if (isGateWave(w)) w], [4, 8, 12]);
    final seen = <EnemyType>{}, bosses = <EnemyType>{};
    for (var seed = 0; seed < 60; seed++) {
      final r = RunState('pistol', rng: Random(seed));
      final gates = [for (final w in kGateWaves) r.gatekeeperFor(w)!];
      expect(gates.toSet().length, 3, reason: 'keine Wiederholung im Run');
      expect(kGatekeepers, containsAll(gates));
      expect(r.gatekeeperFor(5), isNull);
      seen.addAll(gates);
      bosses.add(r.finalBoss);
    }
    expect(seen, kGatekeepers.toSet(), reason: 'alle Torwächter kommen vor');
    expect(bosses, kFinalBosses.toSet(), reason: 'beide Endbosse kommen vor');
    expect(biomeForWave(4), Biome.fields);
    expect(biomeForWave(8), Biome.village);
    expect(biomeForWave(12), Biome.forest);
  });

  testWidgets('Geierkönig wechselt bei 66 % und 33 % HP die Phase', (t) async {
    final game = await _game(t);
    game.startRun('pistol');
    game.run!
      ..weapons.clear()
      ..wave = kMaxWave
      ..finalBoss = EnemyType.boss;
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

  test('Material wird in wenige wertvolle Kristalle zerlegt', () {
    expect(splitMaterial(1), [1]);
    expect(splitMaterial(3), [3]);
    expect(splitMaterial(9), [5, 3, 1]);
    expect(splitMaterial(15), [10, 5]);
    for (var n = 0; n < 40; n++) {
      expect(splitMaterial(n).fold(0, (a, b) => a + b), n);
    }
    expect(materialColor(10), isNot(materialColor(1)));
  });

  testWidgets('Debug: Start direkt in einer Welle oder mit Shop davor; Unverwundbar', (t) async {
    final game = await _game(t);
    game.debugStartAtWave(8);
    expect(game.run!.wave, 8);
    expect(game.phase, Phase.play);
    game.debugInvincible = true;
    final hp = game.run!.hp;
    game.player.iframe = 0;
    game.hurtPlayer(5);
    expect(game.run!.hp, hp);
    game.debugInvincible = false;
    game.debugStartAtWave(12, shopFirst: true);
    expect(game.phase, Phase.shop);
    expect(game.run!.wave, 11);
    expect(game.run!.money, kStartMoney + 30 * 11);
    game.nextWave();
    expect(game.run!.wave, 12);
    game.toMenu();
    await t.pump(const Duration(seconds: 1));
  });

  test('Debug-Ausrüstung wächst mit der Welle', () {
    for (final seed in [1, 2, 3]) {
      final early = RunState('pistol', rng: Random(seed))..debugEquip(4, Random(seed));
      final late = RunState('pistol', rng: Random(seed))..debugEquip(14, Random(seed));
      expect(late.level, greaterThan(early.level));
      expect(late.weapons.length, greaterThan(early.weapons.length));
      expect(late.weapons.length, lessThanOrEqualTo(late.maxWeapons));
      int itemCount(RunState r) => r.items.values.fold<int>(0, (a, b) => a + b);
      expect(itemCount(late), greaterThan(itemCount(early)));
      expect(late.weapons.map((w) => w.tier).reduce(max), greaterThanOrEqualTo(2));
      expect(late.weapons.map((w) => w.def.cls).toSet().length, lessThanOrEqualTo(2), reason: 'zwei Klassen für Set-Boni');
      expect(late.hp, late.maxHp);
    }
    // Glitzer hat nur 4 Slots, Henriette startet ohne Waffe
    final g = RunState(null, characterId: 'glitzer')..debugEquip(15, Random(1));
    expect(g.weapons.length, g.maxWeapons);
    final h = RunState(null, characterId: 'henriette')..debugEquip(10, Random(1));
    expect(h.weapons, isNotEmpty);
  });

  testWidgets('Spawner erzeugen Kinder mit Obergrenze; Kinder geben kein Material', (t) async {
    final game = await _game(t);
    game.startRun('pistol');
    game.run!
      ..weapons.clear()
      ..wave = 10;
    game.godMode = true;
    game.player.position.setValues(200, 300);
    Iterable<Enemy> kids(Enemy p) => game.enemies.where((e) => !e.dead && identical(e.spawnedBy, p));

    game.addEnemy(EnemyType.crowNest, Vector2(900, kGround - 20));
    final nest = game.enemies.last;
    game.addEnemy(EnemyType.sporeShroom, Vector2(1100, kGround - 20));
    final shroom = game.enemies.last;
    game.addEnemy(EnemyType.waspNest, Vector2(700, kCeil + 26));
    final wasps = game.enemies.last;
    game.addEnemy(EnemyType.beetleQueen, Vector2(1300, kGround - 26));
    final queen = game.enemies.last;
    await _run(t, game, 20);
    expect(kids(nest).length, inInclusiveRange(1, 3));
    expect(kids(shroom).length, inInclusiveRange(3, 9));
    expect(kids(wasps), isEmpty, reason: 'Wespennest wartet auf Treffer');
    expect(kids(queen).where((e) => e.type == EnemyType.avalanche), isNotEmpty, reason: 'aus Eiern geschlüpft');

    for (var i = 0; i < 12; i++) {
      game.hurtEnemy(wasps, 0.1, false, 0);
      await _run(t, game, 0.4);
    }
    expect(kids(wasps).length, inInclusiveRange(1, 6));

    // Kind stirbt: kein Material
    final kid = kids(nest).first;
    final before = game.world.children.whereType<Drop>().length;
    game.hurtEnemy(kid, 1e6, false, 0);
    await t.pump(const Duration(milliseconds: 50));
    expect(game.world.children.whereType<Drop>().length, before);
    // Spawner selbst gibt Material
    game.hurtEnemy(nest, 1e6, false, 0);
    await t.pump(const Duration(milliseconds: 50));
    expect(game.world.children.whereType<Drop>().length, greaterThan(before));
  });

  testWidgets('Fäulnisriss spuckt Gegner aus und schließt sich nach 12 s', (t) async {
    final game = await _game(t);
    game.startRun('pistol');
    game.run!
      ..weapons.clear()
      ..wave = 8;
    game.godMode = true;
    game.player.position.setValues(200, 300);
    game.addEnemy(EnemyType.rift, Vector2(900, 250));
    final rift = game.enemies.last;
    await _run(t, game, 7);
    expect(game.enemies.where((e) => identical(e.spawnedBy, rift)), isNotEmpty);
    await _run(t, game, 7);
    expect(rift.dead, isTrue);
  });
}
