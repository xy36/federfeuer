import 'dart:math';

import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:federfeuer/game/config.dart';
import 'package:federfeuer/game/federfeuer_game.dart';
import 'package:federfeuer/game/progress.dart';
import 'package:federfeuer/game/run_state.dart';
import 'package:federfeuer/main.dart' show buildOverlayMap;
import 'package:shared_preferences/shared_preferences.dart';

RunState _withItem(RunState r, String id) {
  final it = itemById[id]!;
  r.applyMods(it.mods);
  r.items[id] = (r.items[id] ?? 0) + 1;
  if (it.action != null) r.addAction(it.action!);
  return r;
}

Future<FederfeuerGame> _startGame(WidgetTester tester) async {
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
  return game;
}

void main() {
  group('Inhalt', () {
    test('18 Waffen, je 3 pro Klasse', () {
      expect(weaponDefs.length, 18);
      for (final c in WeaponClass.values) {
        expect(weaponDefs.values.where((w) => w.cls == c).length, 3, reason: c.label);
      }
    });

    test('Zehn Vögel, alle Startwaffen existieren, nur der Spatz ist frei', () {
      expect(characterDefs.length, 10);
      for (final c in characterDefs) {
        if (c.startWeapon != null) expect(weaponDefs.containsKey(c.startWeapon), isTrue, reason: c.id);
      }
      expect(characterDefs.where((c) => c.unlock.kind == UnlockKind.start).map((c) => c.id), ['spatz']);
    });

    test('Sieben Aktions-Items, jedes setzt eine Aktion', () {
      final actions = itemDefs.where((it) => it.action != null).toList();
      expect(actions.length, 7);
      expect(actions.map((it) => it.action).toSet().length, 7);
    });

    test('Jede Seltenheit ist im Shop vertreten', () {
      for (final r in Rarity.values) {
        expect(itemDefs.any((it) => it.rarity == r), isTrue, reason: r.label);
      }
    });
  });

  group('Startwaffen', () {
    test('Jeder Vogel außer Henriette hat drei verschiedene Startwaffen', () {
      for (final c in characterDefs) {
        if (c.id == 'henriette') {
          expect(c.startWeapons, isEmpty);
          continue;
        }
        expect(c.startWeapons.length, 3, reason: c.id);
        expect(c.startWeapons.toSet().length, 3, reason: c.id);
        for (final id in c.startWeapons) {
          expect(weaponDefs.containsKey(id), isTrue, reason: '${c.id}: $id');
        }
      }
    });

    testWidgets('Gewählte Startwaffe wird je Vogel gemerkt und im Run benutzt', (tester) async {
      final game = await _startGame(tester);
      final russ = characterById['russ']!;
      expect(game.progress.startWeaponFor(russ), 'vine');
      game.progress.setStartWeapon(russ, 'lantern');
      game.progress.setStartWeapon(russ, 'pistol'); // nicht in Ruß' Auswahl → ignoriert
      expect(game.progress.startWeaponFor(russ), 'lantern');
      game.startRun(null, 1, 'russ');
      expect(game.run!.weapons.single.id, 'lantern');
      game.startRun(null, 1, 'spatz');
      expect(game.run!.weapons.single.id, 'pistol', reason: 'andere Vögel behalten ihre eigene Wahl');
      await game.progress.save();
      final p = Progress();
      await p.load();
      expect(p.startWeaponFor(russ), 'lantern');
      game.toMenu();
      await tester.pump(const Duration(seconds: 1));
    });
  });

  group('Set-Boni', () {
    test('Schwellen bei 2, 4 und 6 Waffen', () {
      expect([for (var n = 0; n <= 6; n++) setLevel(n)], [0, 0, 1, 1, 2, 2, 3]);
    });

    test('Licht-Set erhöht Krit, Stein-Set Rüstung', () {
      final r = RunState('pistol');
      final crit = r.stat(Stat.crit);
      r.addWeapon('rail', 0);
      expect(r.stat(Stat.crit), crit + kSetCrit[1]);
      final armor = r.stat(Stat.armor);
      r
        ..addWeapon('pebble', 0)
        ..addWeapon('gnome', 0);
      expect(r.stat(Stat.armor), armor + kSetArmor[1]);
    });

    test('Kieselsammlung: +1 Rüstung je Stein-Waffe', () {
      final r = RunState('pebble')..addWeapon('bowling', 0);
      final before = r.stat(Stat.armor);
      _withItem(r, 'kiesel');
      expect(r.stat(Stat.armor), before + 2);
    });

    test('Glut-Set vergrößert Explosionen', () {
      final r = RunState('rocket');
      final small = r.weaponStats('rocket', 0).explosion;
      r.addWeapon('shotgun', 0);
      expect(r.weaponStats('rocket', 0).explosion, closeTo(small * (1 + kSetEmber[1]), 0.001));
    });
  });

  group('Charaktere', () {
    test('Startwerte: Frack zäh, Schillerchen zerbrechlich, Henriette ohne Waffe', () {
      final base = RunState(null).maxHp;
      expect(RunState(null, characterId: 'frack').maxHp, (base * 1.5).roundToDouble());
      expect(RunState(null, characterId: 'schillerchen').maxHp, (base * 0.6).roundToDouble());
      final hen = RunState(null, characterId: 'henriette');
      expect(hen.weapons, isEmpty);
      expect(hen.actions.single.id, ActionId.egg);
      expect(RunState(null).weapons.single.id, 'pistol');
      expect(RunState(null).actions.single.id, ActionId.dash);
    });

    test('Klassenbonus: Ruß macht mit Böse-Waffen 25 % mehr Schaden', () {
      final spatz = RunState('vine'), russ = RunState(null, characterId: 'russ');
      expect(russ.weaponStats('vine', 0).dmg, closeTo(spatz.weaponStats('vine', 0).dmg * 1.25, 0.001));
    });

    test('Professor Uhu: nachts stärker, tagsüber schwächer', () {
      final r = RunState(null, characterId: 'uhu');
      r.biome = Biome.fields;
      final day = r.weaponStats('pistol', 0).dmg;
      r.biome = Biome.forest;
      final night = r.weaponStats('pistol', 0).dmg;
      expect(night / day, closeTo(1.2 / 0.9, 0.001));
    });

    test('Glitzer: Shop 15 % günstiger, nur 4 Slots', () {
      final s = RunState(null), g = RunState(null, characterId: 'glitzer');
      expect(g.weaponPrice('rail', 0), (s.weaponPrice('rail', 0) / 1 * 0.85).round());
      expect(g.maxWeapons, 4);
    });
  });

  group('Items', () {
    test('Zweite Aktion kommt in Platz 2, gleiche Aktion wird Stufe II', () {
      final r = _withItem(RunState(null), 'a_horn');
      expect(r.actions.map((a) => a.id), [ActionId.dash, ActionId.horn]);
      expect(r.actionBuy(ActionId.horn), ActionBuy.upgrade);
      _withItem(r, 'a_horn');
      expect(r.actions[1].level, 1);
      expect(r.actions[1].cooldown, closeTo(ActionId.horn.cooldown * kActionLv2Cooldown, 1e-9));
      expect(r.itemAvailable(itemById['a_horn']!), isFalse, reason: 'Stufe II ist das Maximum');
      expect(r.actionBuy(ActionId.clock), ActionBuy.replace);
      r.addAction(ActionId.clock, replaceSlot: 1);
      expect(r.actions.map((a) => a.id), [ActionId.dash, ActionId.clock]);
    });

    test('Passende Aktionen verschmelzen und geben einen Platz frei', () {
      final r = RunState(null); // Sturzflug
      expect(r.evolution, isNull);
      _withItem(r, 'a_horn');
      expect(r.evolution!.result, ActionId.sonicBoom);
      expect(r.evolve(), isTrue);
      expect(r.actions.single.id, ActionId.sonicBoom);
      expect(r.actions.length, 1);
    });

    test('Jede Aktion außer Evolutionen steckt in mindestens einem Rezept, Ergebnisse sind Evolutionen', () {
      for (final a in ActionId.values.where((a) => !a.evolved)) {
        expect(recipesWith(a), isNotEmpty, reason: a.label);
      }
      for (final rec in actionRecipes) {
        expect(rec.result.evolved, isTrue);
        expect(rec.a.evolved || rec.b.evolved, isFalse);
      }
      expect(actionRecipes.map((r) => r.result).toSet().length, actionRecipes.length);
    });

    test('Glückskeks: erstes Neu-Würfeln gratis', () {
      final r = _withItem(RunState(null)..wave = 5, 'glueckskeks');
      expect(r.rerollCost, 0);
      r.rerolls = 1;
      expect(r.rerollCost, greaterThan(0));
    });

    test('Sparschwein: 10 % Zinsen, höchstens 25', () {
      final r = _withItem(RunState(null), 'sparschwein')..money = 120;
      expect(r.interest(), 12);
      r.money = 900;
      expect(r.interest(), 25);
    });

    test('Spiegelscherbe: −30 % Schaden für Projektilwaffen, nicht für Nahkampf', () {
      final r = RunState(null);
      final shot = r.weaponStats('pistol', 0).dmg, whip = r.weaponStats('vine', 0).dmg;
      _withItem(r, 'spiegel');
      expect(r.weaponStats('pistol', 0).dmg, closeTo(shot * 0.7, 0.001));
      expect(r.weaponStats('vine', 0).dmg, closeTo(whip, 0.001));
    });

    test('Seltenheit: frühe Wellen fast nur gewöhnlich/selten, später auch legendär', () {
      final rng = Random(3);
      final early = RunState(null)..wave = 1, late = RunState(null)..wave = 14;
      final e = [for (var i = 0; i < 2000; i++) early.rollRarity(rng)];
      final l = [for (var i = 0; i < 2000; i++) late.rollRarity(rng)];
      expect(e.where((x) => x == Rarity.legendary), isEmpty);
      expect(l.where((x) => x == Rarity.legendary), isNotEmpty);
    });
  });

  group('Freischalten', () {
    test('Glutkehlchen nach 500 Brand-Kills über alle Runs', () {
      final p = Progress();
      final r = RunState(null)..burnKills = 300;
      p.recordRun(difficulty: 1, wave: 3, won: false, burnKills: 300);
      expect(p.checkUnlocks(r, won: false).map((c) => c.id), isNot(contains('glutkehlchen')));
      p.recordRun(difficulty: 1, wave: 3, won: false, burnKills: 250);
      expect(p.checkUnlocks(r, won: false).map((c) => c.id), contains('glutkehlchen'));
      expect(p.hasCharacter('glutkehlchen'), isTrue);
    });

    test('Frack: Welle 10 mit 3 Wasser-Waffen', () {
      final p = Progress();
      final r = RunState('water')
        ..addWeapon('bubbles', 0)
        ..wave = 10;
      expect(p.checkUnlocks(r, won: false).map((c) => c.id), isNot(contains('frack')));
      r.addWeapon('raincloud', 0);
      expect(p.checkUnlocks(r, won: false).map((c) => c.id), contains('frack'));
    });

    test('Henriette: Sieg mit dem Kampfspatz ab Falke', () {
      final p = Progress();
      final r = RunState(null, difficulty: 2);
      expect(p.checkUnlocks(r, won: true).map((c) => c.id), isNot(contains('henriette')));
      final r3 = RunState(null, difficulty: 3);
      expect(p.checkUnlocks(r3, won: true).map((c) => c.id), contains('henriette'));
    });

    test('Gesperrter Vogel ist nicht wählbar; Speichern und Laden', () async {
      SharedPreferences.setMockInitialValues({});
      final p = Progress()..selectedCharacter = 'russ';
      expect(p.selectedCharacter, 'spatz');
      p.characters.add('russ');
      p.selectedCharacter = 'russ';
      p.material = 42;
      await p.save();
      final q = Progress();
      await q.load();
      expect(q.selectedCharacter, 'russ');
      expect(q.material, 42);
    });
  });

  group('Im Spiel', () {
    testWidgets('Alle Waffen feuern und treffen ohne Fehler', (tester) async {
      final game = await _startGame(tester);
      game.startRun('pistol');
      await tester.pump(const Duration(milliseconds: 50));
      final r = game.run!;
      r.weapons.clear();
      for (final id in weaponDefs.keys.take(6)) {
        r.weapons.add(OwnedWeapon(id, 1));
      }
      game.startWave();
      for (final batch in [weaponDefs.keys.take(6), weaponDefs.keys.skip(6).take(6), weaponDefs.keys.skip(12)]) {
        r.weapons
          ..clear()
          ..addAll(batch.map((id) => OwnedWeapon(id, 1)));
        game.startWave();
        game.godMode = true;
        final p = game.player.position;
        for (var i = 0; i < 6; i++) {
          game.addEnemy(i.isEven ? EnemyType.crow : EnemyType.beetle, Vector2(p.x + 90 + i * 30, kGround - 40));
        }
        for (var i = 0; i < 60; i++) {
          await tester.pump(const Duration(milliseconds: 50));
        }
      }
      expect(r.kills, greaterThan(0));
    });

    testWidgets('Alle Aktionen lassen sich auslösen', (tester) async {
      final game = await _startGame(tester);
      game.startRun('pistol');
      game.godMode = true;
      await tester.pump(const Duration(milliseconds: 50));
      final p = game.player.position;
      for (final a in ActionId.values) {
        for (final level in [0, 1]) {
          game.waveTime = 999;
          game.player.position.x = 400; // Sturzflug & Co. nicht bis ins Ziel
          game.addEnemy(EnemyType.crow, Vector2(p.x + 60, p.y));
          game.run!.actions
            ..clear()
            ..add(OwnedAction(ActionId.dash))
            ..add(OwnedAction(a, level));
          game.actionCds[1] = 0;
          expect(game.phase, Phase.play, reason: '${a.label} $level');
          game.useAction(1);
          expect(game.actionCds[1], game.run!.actions[1].cooldown, reason: a.label);
          for (var i = 0; i < 20; i++) {
            await tester.pump(const Duration(milliseconds: 50));
          }
        }
      }
    });

    testWidgets('Status: Brand tickt, Einfangen lässt Gegner steigen, Fluch erhöht Schaden', (tester) async {
      final game = await _startGame(tester);
      game.startRun('pistol');
      game.godMode = true;
      await tester.pump(const Duration(milliseconds: 50));
      game.run!.weapons.clear();
      final p = game.player.position;
      game.addEnemy(EnemyType.beetle, Vector2(p.x + 500, kGround - 20));
      final e = game.enemies.last;
      final hp = e.hp;
      e.ignite(2, 4);
      for (var i = 0; i < 12; i++) {
        await tester.pump(const Duration(milliseconds: 50));
      }
      expect(e.hp, lessThan(hp));

      e.applyEffects(const WeaponStats(dmg: 0, cooldown: 1, range: 1, trap: 1.5));
      final y = e.y;
      for (var i = 0; i < 10; i++) {
        await tester.pump(const Duration(milliseconds: 50));
      }
      expect(e.y, lessThan(y - 10), reason: 'eingefangen treibt nach oben');

      e.hp = 1000;
      game.hurtEnemy(e, 10, false, 0);
      final plain = 1000 - e.hp;
      e.applyEffects(const WeaponStats(dmg: 0, cooldown: 1, range: 1, curse: 3));
      e.hp = 1000;
      game.hurtEnemy(e, 10, false, 0);
      expect(1000 - e.hp, closeTo(plain * (1 + game.run!.curseBonus), 0.001));
    });

    testWidgets('Lebensraub heilt höchstens 1 HP je 0,5 s, egal wie viele Treffer', (tester) async {
      final game = await _startGame(tester);
      game.startRun('pistol');
      game.godMode = true;
      await tester.pump(const Duration(milliseconds: 50));
      final r = game.run!..applyMods({Stat.lifesteal: 100, Stat.maxHp: 100});
      r.hp = 10;
      game.addEnemy(EnemyType.rock, Vector2(game.player.x + 500, 200));
      final e = game.enemies.last..hp = 1e9;
      for (var i = 0; i < 50; i++) {
        game.hurtEnemy(e, 1, false, 0);
      }
      expect(r.hp, 11, reason: 'viele Treffer im selben Moment: nur 1 HP');
      game.lifestealCd = 0;
      game.hurtEnemy(e, 1, false, 0);
      expect(r.hp, 12);
      game.toMenu();
      await tester.pump(const Duration(seconds: 1));
    });

    testWidgets('Phönixasche belebt einmal wieder, Seifenblasenschild schluckt Treffer', (tester) async {
      final game = await _startGame(tester);
      game.startRun('pistol');
      await tester.pump(const Duration(milliseconds: 50));
      final r = _withItem(game.run!, 'phoenix');
      game.shieldT = 1;
      r.hp = 5;
      game.player.iframe = 0;
      game.hurtPlayer(100);
      expect(r.hp, 5);
      game.shieldT = 0;
      game.hurtPlayer(100);
      expect(game.phase, Phase.play);
      expect(r.hp, (r.maxHp * 0.3).roundToDouble());
      game.player.iframe = 0;
      game.hurtPlayer(1000);
      expect(game.phase, Phase.over);
      await tester.pump(const Duration(seconds: 1)); // Game-Over-Einblendung
    });

    testWidgets('Kolibri fliegt frei und bleibt ohne Eingabe stehen; Sinkflug für andere Vögel', (tester) async {
      final game = await _startGame(tester);
      game.startRun(null, 1, 'schillerchen');
      game.godMode = true;
      await tester.pump(const Duration(milliseconds: 50));
      game.player.position.y = 250;
      for (var i = 0; i < 30; i++) {
        await tester.pump(const Duration(milliseconds: 50));
      }
      expect(game.player.y, closeTo(250, 2), reason: 'keine Schwerkraft');
      game.keyDown = true;
      for (var i = 0; i < 10; i++) {
        await tester.pump(const Duration(milliseconds: 50));
      }
      game.keyDown = false;
      expect(game.player.y, greaterThan(330), reason: 'runter');
      final low = game.player.y;
      game.keyFly = true;
      for (var i = 0; i < 20; i++) {
        await tester.pump(const Duration(milliseconds: 50));
      }
      game.keyFly = false;
      expect(game.player.y, lessThan(low - 80), reason: 'hoch');

      game.startRun(null, 1, 'spatz');
      game.godMode = true;
      await tester.pump(const Duration(milliseconds: 50));
      game.player.position.y = 150;
      game.player.vel.y = 0;
      game.keyDown = true;
      for (var i = 0; i < 10; i++) {
        await tester.pump(const Duration(milliseconds: 50));
      }
      game.keyDown = false;
      expect(game.player.y, greaterThan(250), reason: 'Sinkflug schneller als Gleiten (150/s)');
    });

    testWidgets('Jeder Vogel lässt sich spielen', (tester) async {
      final game = await _startGame(tester);
      for (final c in characterDefs) {
        game.startRun(null, 1, c.id);
        game.godMode = true;
        expect(game.player.character, c);
        game.keyFly = true;
        game.keyRight = true;
        for (var i = 0; i < 10; i++) {
          await tester.pump(const Duration(milliseconds: 50));
        }
        game.keyFly = false;
        for (var i = 0; i < 6; i++) {
          await tester.pump(const Duration(milliseconds: 50));
        }
        game.keyRight = false;
      }
      // Pinguin steigt kaum, Schwalbe ist schneller als der Spatz
      final frack = characterById['frack']!, boee = characterById['boee']!;
      expect(frack.thrustMul, lessThan(0.7));
      expect(boee.speedMul, greaterThan(1));
    });
  });
}
