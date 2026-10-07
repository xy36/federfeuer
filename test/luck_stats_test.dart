import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:federfeuer/game/config.dart';
import 'package:federfeuer/game/run_state.dart';

/// Glück, Ausweichen und Aktionstempo.
void main() {
  Map<Rarity, int> rolls(RunState r, int n) {
    final rng = Random(7);
    final out = {for (final x in Rarity.values) x: 0};
    for (var i = 0; i < n; i++) {
      final x = r.rollRarity(rng);
      out[x] = out[x]! + 1;
    }
    return out;
  }

  test('Glück verbessert die Seltenheit im Shop', () {
    final plain = RunState('pistol')..wave = 10;
    final lucky = RunState('pistol')..wave = 10;
    lucky.stats[Stat.luck] = 40;
    final a = rolls(plain, 20000), b = rolls(lucky, 20000);
    expect(b[Rarity.common]!, lessThan(a[Rarity.common]! * 0.85));
    expect(b[Rarity.legendary]!, greaterThan(a[Rarity.legendary]!));
    expect(b[Rarity.epic]!, greaterThan(a[Rarity.epic]!));
  });

  test('Glück macht seltene Level-up-Optionen häufiger', () {
    int rare(double luck) {
      final r = RunState('pistol');
      r.stats[Stat.luck] = luck;
      final rng = Random(3);
      var n = 0;
      for (var i = 0; i < 2000; i++) {
        r.rollLevelChoices(rng);
        n += r.levelChoices.where((c) => c.rare).length;
      }
      return n;
    }

    expect(rare(30), greaterThan(rare(0) * 1.8));
  });

  test('Aktionstempo verkürzt die Abklingzeit, höchstens auf 30 %', () {
    final r = RunState('pistol');
    final a = OwnedAction(ActionId.values.first);
    expect(r.actionCooldown(a), a.cooldown);
    r.stats[Stat.actionSpeed] = 100;
    expect(r.actionCooldown(a), closeTo(a.cooldown / 2, 1e-9));
    r.stats[Stat.actionSpeed] = -500;
    expect(r.actionCooldown(a), closeTo(a.cooldown / 0.3, 1e-9));
  });

  test('Level-up bietet Glück, Ausweichen und Aktionstempo statt Schub und Gleiten', () {
    final stats = levelOptions.map((o) => o.stat).toSet();
    expect(stats, containsAll([Stat.luck, Stat.dodge, Stat.actionSpeed]));
    expect(stats.intersection({Stat.thrust, Stat.glide}), isEmpty);
    // Flug-Werte gibt es weiter über Items
    expect(itemDefs.any((i) => i.mods.containsKey(Stat.glide)), isTrue);
  });

  test('Material: Tabelle je Welle, spät unter der Zähigkeit', () {
    expect(kMaterialByWave, hasLength(14));
    expect(enemyMaterialFactor(1), kMaterialByWave.first);
    expect(enemyMaterialFactor(15), kMaterialByWave.last, reason: 'Bosswelle');
    expect(enemyMaterialFactor(14), lessThan(enemyToughness(14)));
  });
}
