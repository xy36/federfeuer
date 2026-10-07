import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:federfeuer/game/config.dart';
import 'package:federfeuer/game/run_state.dart';

/// Verschmelzen mit Gaben (verschiedene Waffen) und Eigenschaften (gleiche Waffen).
void main() {
  RunState run(List<(String, int)> weapons) {
    final r = RunState(null, rng: Random(1))..weapons.clear();
    for (final (id, tier) in weapons) {
      r.weapons.add(OwnedWeapon(id, tier));
    }
    return r;
  }

  test('Jede Waffe hat eine Gabe', () {
    expect(weaponGifts.keys.toSet(), weaponDefs.keys.toSet());
  });

  test('Gabe abgeben: Ziel erbt Gabe und Klasse, Spender verschwindet', () {
    final r = run([('smg', 0), ('water', 0)]);
    expect(r.canGift(1, 0), isTrue);
    expect(r.giveGift(1, 0), isTrue);
    expect(r.weapons, hasLength(1));
    final w = r.weapons.single;
    expect(w.gifts, ['water']);
    expect(w.classes, containsAll([WeaponClass.wind, WeaponClass.water]));
    expect(r.classCount(WeaponClass.water), 1, reason: 'zählt für das Wasser-Set');
    final s = r.statsOf(w);
    expect(s.classes, contains(WeaponClass.water));
    expect(s.slow, greaterThan(0));
  });

  test('Grenzen: keine gleiche Waffe, keine doppelte Gabe, höchstens Stufe + 1 Gaben', () {
    final r = run([('smg', 0), ('smg', 0), ('water', 0), ('pistol', 0)]);
    expect(r.canGift(0, 1), isFalse, reason: 'gleiche Waffen verschmelzen normal');
    expect(r.giveGift(2, 0), isTrue); // Stufe I: 1 Gabe
    expect(r.canGift(2, 0), isFalse, reason: 'Platz voll (Pistole ist jetzt Index 2)');
    r.weapons[0].tier = 1;
    expect(r.canGift(2, 0), isTrue);
    r.weapons.add(OwnedWeapon('water', 0));
    expect(r.canGift(r.weapons.length - 1, 0), isFalse, reason: 'Gabe schon vorhanden');
  });

  test('Gaben verändern die Werte', () {
    final plain = run([('pistol', 0)]).statsOf(OwnedWeapon('pistol', 0));
    final w = OwnedWeapon('pistol', 2)..gifts.addAll(['lantern', 'rocket', 'pistol']);
    final r = run([]);
    final s = r.statsOf(w), base = r.weaponStats('pistol', 2);
    expect(s.dmg, closeTo(base.dmg * 1.2, 1e-9));
    expect(s.blastChance, 1);
    expect(s.critBonus, 10);
    expect(plain.blastChance, 0);
  });

  test('Gleiche Waffen verschmelzen: Stufe hoch und 1 aus 3 passenden Eigenschaften', () {
    final r = run([('pistol', 0), ('pistol', 0)]);
    r.weapons[1].gifts.add('water');
    expect(r.merge(0), isTrue);
    final w = r.weapons.single;
    expect(w.tier, 1);
    expect(w.gifts, ['water'], reason: 'Gaben des Partners gehen mit über');
    final c = r.traitChoice!;
    expect(c.options, hasLength(3));
    expect(c.options.every((t) => t.appliesTo(w.def)), isTrue);
    final countBefore = r.statsOf(w).count;
    final k = c.options.indexOf(WeaponTrait.multi);
    r.chooseTrait(k < 0 ? 0 : k);
    expect(r.traitChoice, isNull);
    expect(w.traits, hasLength(1));
    if (k >= 0) expect(r.statsOf(w).count, countBefore + 1);
  });

  test('Eigenschaften passen zur Waffenart', () {
    expect(WeaponTrait.arc.appliesTo(weaponDefs['vine']!), isTrue);
    expect(WeaponTrait.arc.appliesTo(weaponDefs['pistol']!), isFalse);
    expect(WeaponTrait.pierce.appliesTo(weaponDefs['rail']!), isFalse, reason: 'durchschlägt schon alles');
    expect(WeaponTrait.blast.appliesTo(weaponDefs['rocket']!), isTrue);
    expect(WeaponTrait.wide.appliesTo(weaponDefs['raincloud']!), isTrue);
    for (final d in weaponDefs.values) {
      expect(WeaponTrait.values.where((t) => t.appliesTo(d)).length, greaterThanOrEqualTo(3), reason: d.id);
    }
  });

  test('Kauf verschmilzt bei vollen Slots ebenfalls mit Eigenschafts-Wahl', () {
    final r = run([for (var i = 0; i < 6; i++) ('pistol', min(i, 1))]);
    r.addWeapon('pistol', 0);
    expect(r.traitChoice, isNotNull);
  });
}
