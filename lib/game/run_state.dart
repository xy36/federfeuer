import 'dart:math';

import 'config.dart';

class OwnedWeapon {
  OwnedWeapon(this.id, this.tier);
  final String id;
  int tier;
  WeaponDef get def => weaponDefs[id]!;
}

class Offer {
  Offer.weapon(this.id, this.tier, this.price) : isWeapon = true;
  Offer.item(this.id, this.price)
      : isWeapon = false,
        tier = 0;

  final bool isWeapon;
  final String id;
  final int tier;
  final int price;
  bool sold = false;
}

class LevelChoice {
  LevelChoice(this.option, this.rare);
  final LevelOption option;
  final bool rare;
  double get value => option.value * (rare ? 2 : 1);
}

class WeaponStats {
  const WeaponStats(this.dmg, this.cooldown, this.range);
  final double dmg, cooldown, range;
}

/// Alles, was zu einem Durchlauf gehört (Werte, Inventar, Fortschritt).
class RunState {
  RunState(String startWeapon, {this.difficulty = 1}) {
    weapons.add(OwnedWeapon(startWeapon, 0));
    hp = maxHp;
  }

  /// Schwierigkeitsstufe 1–[kDifficultyCount].
  final int difficulty;
  DifficultyDef get difficultyDef => difficultyDefs[difficulty - 1];

  final Map<Stat, double> stats = {
    for (final s in Stat.values) s: s == Stat.maxHp ? 20.0 : (s == Stat.crit ? 5.0 : 0.0),
  };
  final weapons = <OwnedWeapon>[];
  final items = <String, int>{};

  int wave = 1, money = 0, xp = 0, level = 0, pendingLevels = 0, kills = 0, rerolls = 0;
  double hp = 20;
  /// Bonus-Material der letzten Welle fürs Erreichen des Ziels; null = per Timer beendet.
  int? goalBonus;
  List<Offer> offers = [];
  List<LevelChoice> levelChoices = [];

  double stat(Stat s) => stats[s]!;
  double get maxHp => stat(Stat.maxHp);
  int get xpNeeded => (level + 3) * (level + 3);

  /// Gibt true zurück, wenn dabei ein Level-up passiert ist.
  bool gain(int v) {
    money += v;
    xp += v;
    var up = false;
    while (xp >= xpNeeded) {
      xp -= xpNeeded;
      level++;
      pendingLevels++;
      stats[Stat.maxHp] = maxHp + 1;
      hp += 1;
      up = true;
    }
    return up;
  }

  void applyMods(Map<Stat, double> mods) {
    mods.forEach((s, v) {
      stats[s] = stat(s) + v;
      if (s == Stat.maxHp) {
        stats[s] = max(1.0, stat(s));
        hp = clampD(hp + max(0.0, v), 1, maxHp);
      }
    });
  }

  WeaponStats weaponStats(String id, int tier) {
    final d = weaponDefs[id]!, t = tiers[tier];
    return WeaponStats(
      d.dmg * t.dmg * (1 + stat(Stat.dmg) / 100),
      d.cooldown * t.cooldown / max(0.3, 1 + stat(Stat.atk) / 100),
      d.range + stat(Stat.range),
    );
  }

  int weaponPrice(String id, int tier) => (weaponDefs[id]!.price * tiers[tier].price * weaponPriceFactor(wave)).round();
  int itemPrice(ItemDef it) => (it.price * itemPriceFactor(wave)).round();
  int get rerollCost => rerollBaseCost(wave) + rerolls * 2;
  int sellPrice(OwnedWeapon w) => (weaponPrice(w.id, w.tier) * 0.4).round();

  static const maxWeapons = 6;

  bool get slotsFull => weapons.length >= maxWeapons;

  /// Gibt es schon eine gleiche Waffe gleicher Stufe (unter IV), mit der sie verschmelzen könnte?
  bool canMerge(String id, int tier) => tier < 3 && weapons.any((w) => w.id == id && w.tier == tier);

  /// Kauf verschmilzt nur, wenn alle Slots belegt sind – sonst kommt die Waffe in einen freien Slot.
  bool mergesOnBuy(String id, int tier) => slotsFull && canMerge(id, tier);
  bool canAddWeapon(String id, int tier) => !slotsFull || canMerge(id, tier);

  /// Fügt eine Waffe in einen freien Slot ein. Sind alle Slots belegt,
  /// verschmilzt sie mit einer gleichen Waffe gleicher Stufe (eine Stufe, keine Kette).
  void addWeapon(String id, int tier) {
    if (!slotsFull) {
      weapons.add(OwnedWeapon(id, tier));
      return;
    }
    final i = weapons.indexWhere((w) => w.id == id && w.tier == tier);
    if (i >= 0 && tier < 3) weapons[i].tier++;
  }

  /// Index einer zweiten, gleichen Waffe gleicher Stufe für Slot [i], sonst -1.
  int mergePartner(int i) {
    final w = weapons[i];
    if (w.tier >= 3) return -1;
    for (var j = 0; j < weapons.length; j++) {
      if (j != i && weapons[j].id == w.id && weapons[j].tier == w.tier) return j;
    }
    return -1;
  }

  /// Verschmilzt Slot [i] mit seinem Partner: [i] steigt eine Stufe auf, der Partner wird frei.
  bool merge(int i) {
    final j = mergePartner(i);
    if (j < 0) return false;
    final w = weapons[i];
    w.tier++;
    weapons.removeAt(j);
    return true;
  }

  void rollOffers(Random r) => offers = List.generate(4, (_) => _randomOffer(r));

  Offer _randomOffer(Random r) {
    if (r.nextDouble() < 0.45) {
      final ids = weaponDefs.keys.toList();
      final id = ids[r.nextInt(ids.length)];
      final roll = r.nextDouble();
      var tier = 0;
      if (wave >= 11 && roll < 0.03) {
        tier = 3;
      } else if (wave >= 7 && roll < 0.08) {
        tier = 2;
      } else if (wave >= 3 && roll < 0.25) {
        tier = 1;
      }
      return Offer.weapon(id, tier, weaponPrice(id, tier));
    }
    final it = itemDefs[r.nextInt(itemDefs.length)];
    return Offer.item(it.id, itemPrice(it));
  }

  bool buy(int i) {
    final o = offers[i];
    if (o.sold || money < o.price) return false;
    if (o.isWeapon) {
      if (!canAddWeapon(o.id, o.tier)) return false;
      addWeapon(o.id, o.tier);
    } else {
      applyMods(itemById[o.id]!.mods);
      items[o.id] = (items[o.id] ?? 0) + 1;
    }
    money -= o.price;
    o.sold = true;
    return true;
  }

  bool reroll(Random r) {
    final c = rerollCost;
    if (money < c) return false;
    money -= c;
    rerolls++;
    rollOffers(r);
    return true;
  }

  void sell(int i) {
    if (weapons.length < 2) return;
    money += sellPrice(weapons[i]);
    weapons.removeAt(i);
  }

  void rollLevelChoices(Random r) {
    final pool = [...levelOptions]..shuffle(r);
    levelChoices = pool.take(4).map((o) => LevelChoice(o, r.nextDouble() < 0.2)).toList();
  }

  void chooseLevel(int i) {
    final c = levelChoices[i];
    applyMods({c.option.stat: c.value});
    pendingLevels--;
  }
}
