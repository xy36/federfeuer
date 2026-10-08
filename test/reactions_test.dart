import 'dart:math';

import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:federfeuer/game/components/enemy.dart';
import 'package:federfeuer/game/config.dart';
import 'package:federfeuer/game/federfeuer_game.dart';
import 'package:federfeuer/game/run_state.dart';
import 'package:federfeuer/main.dart' show buildOverlayMap;
import 'package:shared_preferences/shared_preferences.dart';

/// Elementar-Reaktionen zwischen den Waffenklassen.
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
  game.godMode = true;
  game.player.position.setValues(200, 300);
  game.debugAlwaysReact = true;
  return game;
}

Enemy _rock(FederfeuerGame game, double x) {
  game.addEnemy(EnemyType.rock, Vector2(x, 200));
  return game.enemies.last;
}

void main() {
  testWidgets('Nass + Wind friert ein, Stein zerschmettert dreifach', (t) async {
    final game = await _game(t);
    final e = _rock(game, 900);
    game.hurtEnemy(e, 1, false, 0, classes: const [WeaponClass.water]);
    expect(e.wet, isTrue);
    game.hurtEnemy(e, 1, false, 0, classes: const [WeaponClass.wind]);
    expect(e.frozen, isTrue);
    expect(e.wet, isFalse, reason: 'Frost verbraucht die Nässe');
    expect(game.progress.hasSeen('k:frost'), isTrue);

    // Eingefroren: +25 % Schaden ohne Reaktion
    final hp0 = e.hp;
    game.hurtEnemy(e, 10, false, 0);
    expect(hp0 - e.hp, closeTo(10 * (1 + kFrostVuln), 1e-9));

    // Zerschmettern: genau dreifach, Frost endet
    e.reactCd = 0;
    final hp1 = e.hp;
    game.hurtEnemy(e, 10, false, 0, classes: const [WeaponClass.stone]);
    expect(hp1 - e.hp, closeTo(10 * kShatterMul, 1e-9));
    expect(e.frozen, isFalse);
  });

  testWidgets('Dampfstoß löscht Brand und trifft Nachbarn', (t) async {
    final game = await _game(t);
    final e = _rock(game, 900), near = _rock(game, 940);
    e.ignite(3, 1);
    final nearHp = near.hp;
    game.hurtEnemy(e, 5, false, 0, classes: const [WeaponClass.water]);
    expect(e.burning, isFalse);
    expect(e.wet, isFalse, reason: 'Dampf verbraucht beide Zustände');
    expect(nearHp - near.hp, closeTo(5 * kSteamMul, 1e-9));
  });

  testWidgets('Eine Reaktion je Gegner höchstens alle 0,8 s', (t) async {
    final game = await _game(t);
    final e = _rock(game, 900);
    e.wetT = 2;
    expect(game.reactionFor(e, const [WeaponClass.wind]), Reaction.frost);
    game.hurtEnemy(e, 1, false, 0, classes: const [WeaponClass.wind]);
    e.wetT = 2;
    expect(game.reactionFor(e, const [WeaponClass.wind]), isNull);
  });

  testWidgets('Feuersturm verbreitet den Brand', (t) async {
    final game = await _game(t);
    final e = _rock(game, 900), near = _rock(game, 950), far = _rock(game, 1200);
    e.ignite(3, 2);
    game.hurtEnemy(e, 1, false, 0, classes: const [WeaponClass.wind]);
    expect(near.burning, isTrue);
    expect(far.burning, isFalse);
  });

  testWidgets('Bannstrahl springt auf andere verfluchte Gegner', (t) async {
    final game = await _game(t);
    final e = _rock(game, 900), other = _rock(game, 1100), clean = _rock(game, 1000);
    e.curseT = 3;
    other.curseT = 3;
    final otherHp = other.hp, cleanHp = clean.hp;
    game.hurtEnemy(e, 10, false, 0, classes: const [WeaponClass.light]);
    expect(other.hp, lessThan(otherHp));
    expect(clean.hp, cleanHp, reason: 'nur verfluchte Gegner');
  });

  testWidgets('Höllenfeuer: verflucht und brennend gestorben steckt Nachbarn an', (t) async {
    final game = await _game(t);
    game.addEnemy(EnemyType.crow, Vector2(900, 200));
    final crow = game.enemies.last;
    final near = _rock(game, 960);
    crow
      ..curseT = 3
      ..ignite(3, 1);
    game.hurtEnemy(crow, 9999, false, 0);
    expect(crow.dead, isTrue);
    expect(near.burning, isTrue);
    expect(near.cursed, isTrue);
    expect(game.progress.hasSeen('k:hellfire'), isTrue);
  });

  testWidgets('Regenbogen: Licht auf nassen Gegner bricht sich in Splitter', (t) async {
    final game = await _game(t);
    final e = _rock(game, 900), near = _rock(game, 1000);
    e.wetT = 2;
    final hp = near.hp;
    game.hurtEnemy(e, 10, false, 0, classes: const [WeaponClass.light]);
    expect(near.hp, closeTo(hp - 10 * kRainbowMul, 1e-9));
    expect(e.wet, isFalse);
  });

  testWidgets('Gaben: Spender-Klasse löst Reaktionen aus, Zündfunke trifft Nachbarn', (t) async {
    final game = await _game(t);
    final e = _rock(game, 900), near = _rock(game, 920);
    // Glutwaffe mit Wasser-Gabe auf brennenden Gegner: Dampfstoß
    e.ignite(3, 1);
    expect(game.reactionFor(e, const [WeaponClass.ember, WeaponClass.water]), Reaction.steam);

    final w = OwnedWeapon('pistol', 0)..gifts.add('rocket');
    final s = game.run!.statsOf(w);
    e.burnT = 0;
    e.reactCd = 1;
    final hp = near.hp;
    game.hurtEnemy(e, 10, false, 0, fx: s, classes: s.classes);
    expect(near.hp, lessThan(hp), reason: 'kleine Explosion der Gabe');
  });

  testWidgets('Reaktionen lösen nur mit Wahrscheinlichkeit aus – schnelle Waffen seltener je Treffer', (t) async {
    final game = await _game(t);
    game.debugAlwaysReact = false;
    final r = game.run!;
    // Formel: Grundchance × min(1, Abklingzeit / 1 s) ÷ Projektile
    expect(game.reactionChance(Reaction.frost, null), kReactionChance[Reaction.frost]);
    final smg = r.weaponStats('smg', 0), shotgun = r.weaponStats('shotgun', 0);
    expect(game.reactionChance(Reaction.frost, smg), closeTo(0.15 * smg.cooldown, 1e-9));
    expect(game.reactionChance(Reaction.steam, shotgun),
        closeTo(0.25 * min(1.0, shotgun.cooldown) / shotgun.count, 1e-9));

    // Stichprobe: nasser Gegner, Wind-Treffer ohne Waffe → etwa 15 % Frost
    final e = _rock(game, 900);
    var frozen = 0;
    const n = 600;
    for (var i = 0; i < n; i++) {
      e
        ..wetT = 2
        ..frozenT = 0
        ..reactCd = 0
        ..hp = 1e9;
      game.hurtEnemy(e, 1, false, 0, classes: const [WeaponClass.wind]);
      if (e.frozen) frozen++;
    }
    expect(frozen / n, closeTo(kReactionChance[Reaction.frost]!, 0.05));
  });
}
