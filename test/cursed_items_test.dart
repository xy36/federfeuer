import 'dart:math';

import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:federfeuer/game/config.dart';
import 'package:federfeuer/game/federfeuer_game.dart';
import 'package:federfeuer/game/run_state.dart';
import 'package:federfeuer/main.dart' show buildOverlayMap;
import 'package:shared_preferences/shared_preferences.dart';

/// Verfluchte Items: starker Vorteil, spürbarer Nachteil.
RunState _with(RunState r, String id) {
  r
    ..money = 999
    ..offers = [Offer.item(id, 1)];
  r.buy(0);
  return r;
}

Future<FederfeuerGame> _game(WidgetTester t, List<String> items) async {
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
  for (final id in items) {
    game.run!.items[id] = 1;
  }
  game.run!.weapons.clear();
  game.player.position.setValues(600, 300);
  return game;
}

Future<void> _run(WidgetTester t, FederfeuerGame game, double seconds) async {
  for (var i = 0; i < seconds * 20; i++) {
    game.waveTime = 99;
    await t.pump(const Duration(milliseconds: 50));
  }
}

void main() {
  test('Verflucht erst ab Welle 3, dann rund 12 % und 30 % günstiger', () {
    int cursed(int wave) {
      final r = RunState('pistol')..wave = wave;
      final rng = Random(5);
      var n = 0;
      for (var i = 0; i < 4000; i++) {
        if (r.rollRarity(rng) == Rarity.cursed) n++;
      }
      return n;
    }

    expect(cursed(2), 0);
    expect(cursed(6) / 4000, closeTo(kCursedChance, 0.02));
    final r = RunState('pistol');
    final lead = itemById['bleifeder']!;
    expect(r.itemPrice(lead), (lead.price * kCursedPriceMul).round());
  });

  test('Einsamer Wolf: höchstens 2 Waffen, die schwächsten gehen in die Reserve, sonst verkauft', () {
    final r = RunState('pistol')
      ..slotsUnlocked = kMaxWeapons
      ..addWeapon('smg', 2)
      ..addWeapon('rail', 0)
      ..addWeapon('rocket', 1);
    _with(r, 'einsamerwolf');
    expect(r.maxWeapons, kLoneWolfSlots);
    expect(r.weapons.map((w) => w.id), unorderedEquals(['smg', 'rocket']));
    expect(r.reserve.map((w) => w.id), unorderedEquals(['pistol', 'rail']));

    // Reserve schon voll: Überzählige werden verkauft
    final s = RunState('pistol')
      ..slotsUnlocked = kMaxWeapons
      ..addWeapon('smg', 2)
      ..addWeapon('rail', 0)
      ..addWeapon('rocket', 1)
      ..addWeapon('water', 0)
      ..addWeapon('gnome', 0);
    expect(s.reserveFull, isTrue);
    final money = s.money;
    final paid = s.itemPrice(itemById['einsamerwolf']!);
    _with(s, 'einsamerwolf');
    expect(s.weapons.length, kLoneWolfSlots);
    expect(s.money, greaterThan(money + 999 - money - paid), reason: 'Verkaufserlös gutgeschrieben');
  });

  test('Nachtschatten: Krits ×3; Sturmkind nur bei Schlechtwetter', () {
    final night = _with(RunState('pistol'), 'nachtschatten');
    expect(night.critMul, kNightCritMul);
    final storm = _with(RunState('pistol'), 'sturmkind');
    final calm = storm.weaponStats('pistol', 0).dmg;
    storm.stormy = true;
    expect(storm.weaponStats('pistol', 0).dmg, closeTo(calm * (1 + kStormChildDmg), 1e-9));
  });

  testWidgets('Glaskörper: jeder Treffer mindestens 5; Gierschlund: Herzen heilen nicht, Material doppelt', (t) async {
    final game = await _game(t, ['glaskoerper', 'gierschlund']);
    final r = game.run!;
    final hp = r.hp;
    game.player.iframe = 0; // keine Schonfrist vom Wellenstart
    game.hurtPlayer(1);
    expect(hp - r.hp, kGlassMinDmg);
    final hurt = r.hp;
    game.healHeart();
    expect(r.hp, hurt);
    final money = r.money;
    game.gain(3);
    expect(r.money, greaterThanOrEqualTo(money + 6));
  });

  testWidgets('Bleifeder: nur bis zur halben Höhe', (t) async {
    final game = await _game(t, ['bleifeder']);
    game.debugInvincible = true;
    await t.sendKeyDownEvent(LogicalKeyboardKey.space);
    await _run(t, game, 1.5);
    await t.sendKeyUpEvent(LogicalKeyboardKey.space);
    final top = kCeil + (kGround - kCeil) * kLeadCeiling;
    expect(game.player.y, greaterThanOrEqualTo(top + game.player.r - 0.5));
  });

  testWidgets('Dicker Bauch: größer; Brennende Federn: setzen in Brand, kosten selbst HP', (t) async {
    final game = await _game(t, ['dickbauch', 'brennfedern']);
    expect(game.player.r, closeTo(game.player.character.radius * kBigBellyScale, 1e-9));
    game.addEnemy(EnemyType.rock, Vector2(900, 200));
    final e = game.enemies.last;
    final s = game.run!.weaponStats('pistol', 0);
    game.hurtEnemy(e, 10, false, 0, fx: s, classes: s.classes);
    expect(e.burning, isTrue);
    final hp = game.run!.hp;
    await _run(t, game, kSelfBurnEvery + 0.2);
    expect(game.run!.hp, lessThan(hp));
  });

  testWidgets('Wirrkopf: regelmäßig verwirrt', (t) async {
    final game = await _game(t, ['wirrkopf']);
    game.debugInvincible = true;
    await _run(t, game, kDizzyEvery + 0.3);
    expect(game.chaos(ChaosEffect.confused), isTrue);
  });
}
