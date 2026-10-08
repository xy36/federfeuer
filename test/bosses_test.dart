import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:federfeuer/game/components/enemy.dart';
import 'package:federfeuer/game/components/projectiles.dart';
import 'package:federfeuer/game/config.dart';
import 'package:federfeuer/game/federfeuer_game.dart';
import 'package:federfeuer/main.dart' show buildOverlayMap;
import 'package:shared_preferences/shared_preferences.dart';

/// Neue Torwächter (Moorgolem, Laternenmann, Dornenwurm) und der Aschephönix.
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
  game.run!.weapons.clear();
  return game;
}

Future<void> _run(WidgetTester t, FederfeuerGame game, double seconds, {void Function()? each}) async {
  for (var i = 0; i < seconds * 20; i++) {
    game.waveTime = 99;
    each?.call();
    await t.pump(const Duration(milliseconds: 50));
  }
}

void main() {
  test('Torwächter wachsen gemeinsam mit der Welle; Endbosse ohne Wellenskalierung', () {
    // Alle Torwächter haben ähnliche Grund-HP, damit jeder in Welle 4 wie 12 passt
    final hps = [for (final g in kGatekeepers) enemyDefs[g]!.hp];
    expect(hps.reduce((a, b) => a > b ? a : b) / hps.reduce((a, b) => a < b ? a : b), lessThan(1.3));
    for (final b in kFinalBosses) {
      expect(enemyDefs[b]!.hp, greaterThan(4000));
    }
  });

  testWidgets('Moorgolem: Stampfen schickt Bodenwellen – tief getroffen, hoch sicher', (t) async {
    final game = await _game(t);
    game.addEnemy(EnemyType.moorGolem, Vector2(900, kGround - enemyDefs[EnemyType.moorGolem]!.radius));
    final golem = game.enemies.last;
    expect(golem.gatekeeper, isTrue);
    // Hoch fliegen: die Welle läuft darunter durch
    golem.stateT = 0.01;
    final hp = game.run!.hp;
    await _run(t, game, 2.5, each: () {
      game.player.position.setValues(700, kCeil + 60);
      game.player.vel.setZero();
      game.player.iframe = 0;
      for (final b in game.world.children.whereType<EnemyBullet>().toList()) {
        b.removeFromParent();
      }
    });
    expect(game.world.children.whereType<GroundWave>(), isNotEmpty, reason: 'Bodenwellen unterwegs');
    expect(game.run!.hp, hp, reason: 'über der Welle');
    // Am Boden: die nächste Welle trifft
    golem.stateT = 0.01;
    golem.state = 0;
    await _run(t, game, 2.5, each: () {
      game.player.position.setValues(700, kGround - game.player.r);
      game.player.iframe = 0;
      for (final b in game.world.children.whereType<EnemyBullet>().toList()) {
        b.removeFromParent();
      }
    });
    expect(game.run!.hp, lessThan(hp));
    game.toMenu();
    await t.pump(const Duration(seconds: 1));
  });

  testWidgets('Laternenmann: Lichtstrahl erst Warnlinie, dann brennt er; verschwindet und taucht woanders auf', (t) async {
    final game = await _game(t);
    game.addEnemy(EnemyType.lanternMan, Vector2(900, 200));
    final lantern = game.enemies.last;
    lantern
      ..jumpT = 0.01
      ..stateT = 99
      ..shootT = 99
      ..summonT = 99;
    final hp = game.run!.hp;
    await _run(t, game, 0.5, each: () {
      game.player.position.setValues(500, 200);
      game.player.vel.setZero();
      game.player.iframe = 0;
    });
    expect(game.world.children.whereType<LanternBeam>(), isNotEmpty);
    expect(game.run!.hp, hp, reason: 'Warnlinie schadet nicht');
    await _run(t, game, 1.2, each: () {
      game.player.position.setValues(500, 200);
      game.player.vel.setZero();
      game.player.iframe = 0;
    });
    expect(game.run!.hp, lessThan(hp), reason: 'brennender Strahl trifft');
    // Verschwinden und Auftauchen
    final before = lantern.position.clone();
    lantern.stateT = 0.01;
    await _run(t, game, 1.5);
    expect(lantern.position.distanceTo(before), greaterThan(60));
    game.toMenu();
    await t.pump(const Duration(seconds: 1));
  });

  testWidgets('Dornenwurm: unter der Erde unverwundbar, bricht unter dem Spieler hervor', (t) async {
    final game = await _game(t);
    game.godMode = true;
    game.addEnemy(EnemyType.thornWorm, Vector2(1000, kGround - enemyDefs[EnemyType.thornWorm]!.radius));
    final worm = game.enemies.last;
    expect(worm.burrowed, isTrue);
    game.hurtEnemy(worm, 50, false, 0);
    expect(worm.hp, worm.maxHp, reason: 'Treffer prallen am Erdhügel ab');
    // Gräbt sich zum Spieler und bricht hervor
    var emerged = false;
    await _run(t, game, 5, each: () {
      game.player.position.setValues(850, kGround - game.player.r);
      if (worm.state == 2) emerged = true;
    });
    expect(emerged, isTrue);
    expect((worm.x - 850).abs(), lessThan(80), reason: 'unter dem Spieler hervorgebrochen');
    worm
      ..state = 2
      ..stateT = 2;
    game.hurtEnemy(worm, 50, false, 0);
    expect(worm.hp, lessThan(worm.maxHp), reason: 'oben verwundbar');
    game.toMenu();
    await t.pump(const Duration(seconds: 1));
  });

  testWidgets('Aschephönix: Endboss mit Flammensäulen (Phase 2) und Feuerwand (Phase 3); Sieg beendet den Run', (t) async {
    final game = await _game(t);
    game.run!
      ..wave = kMaxWave
      ..finalBoss = EnemyType.ashPhoenix;
    game.startWave();
    game.godMode = true;
    for (var i = 0; i < 60 && !game.enemies.any((e) => e.type == EnemyType.ashPhoenix); i++) {
      await t.pump(const Duration(milliseconds: 50));
    }
    final boss = game.enemies.firstWhere((e) => e.type == EnemyType.ashPhoenix);
    expect(boss.finalBoss, isTrue);
    expect(boss.bossPhase, 1);
    boss.hp = boss.maxHp * 0.6;
    var pillars = false, wall = false;
    await _run(t, game, 3, each: () => pillars |= game.world.children.whereType<FlamePillars>().isNotEmpty);
    expect(boss.bossPhase, 2);
    expect(pillars, isTrue);
    boss.hp = boss.maxHp * 0.2;
    await _run(t, game, 3.5, each: () => wall |= game.world.children.whereType<FireWall>().isNotEmpty);
    expect(boss.bossPhase, 3);
    expect(wall, isTrue);
    game.hurtEnemy(boss, 1e9, false, 0);
    await _run(t, game, 4);
    expect(game.phase, isNot(Phase.play));
    game.toMenu();
    await t.pump(const Duration(seconds: 1));
  });
}
