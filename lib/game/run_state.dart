import 'dart:math';

import 'config.dart';

class OwnedWeapon {
  OwnedWeapon(this.id, this.tier);
  final String id;
  int tier;
  WeaponDef get def => weaponDefs[id]!;
}

/// Aktion in einem der beiden Aktionsplätze; [level] 0 = Stufe I, 1 = Stufe II.
enum ActionBuy { add, upgrade, replace, none }

class OwnedAction {
  OwnedAction(this.id, [this.level = 0]);
  final ActionId id;
  int level;

  double get cooldown => id.cooldown * (level > 0 ? kActionLv2Cooldown : 1);

  /// Wirkungsfaktor (Dauer, Radius, Schaden).
  double get power => level > 0 ? kActionLv2Power : 1;
  String get label => level > 0 ? '${id.label} II' : id.label;
}

class Offer {
  Offer.weapon(this.id, this.tier, this.price) : isWeapon = true;
  Offer.item(this.id, this.price)
      : isWeapon = false,
        tier = 0;

  final bool isWeapon;
  final String id;
  final int tier;
  int price;
  bool sold = false;

  /// Zurückgehalten: bleibt beim Neu würfeln und im nächsten Shop liegen.
  bool locked = false;
}

class LevelChoice {
  LevelChoice(this.option, this.rare);
  final LevelOption option;
  final bool rare;
  double get value => option.value * (rare ? 2 : 1);
}

/// Wirksame Werte einer Waffe inklusive Stufe, Werten, Set-Boni, Charakter und Items.
class WeaponStats {
  const WeaponStats({
    required this.dmg,
    required this.cooldown,
    required this.range,
    this.explosion = 0,
    this.burnTime = 0,
    this.burnDps = 0,
    this.slow = 0,
    this.slowTime = 0,
    this.stun = 0,
    this.trap = 0,
    this.curse = 0,
    this.knock = 5,
    this.stickTime = 0,
    this.stickDps = 0,
    this.lifesteal = 0,
  });
  final double dmg, cooldown, range, explosion;
  final double burnTime, burnDps, slow, slowTime, stun, trap, curse, knock, stickTime, stickDps, lifesteal;
}

/// Alles, was zu einem Durchlauf gehört (Charakter, Werte, Inventar, Fortschritt).
class RunState {
  /// [startWeapon] null: Startwaffe des Charakters (Henriette hat keine).
  RunState(String? startWeapon, {this.difficulty = 1, String characterId = 'spatz', Random? rng})
      : character = characterById[characterId] ?? characterDefs.first,
        _rng = rng ?? Random() {
    final c = character;
    final w = startWeapon ?? c.startWeapon;
    if (w != null) weapons.add(OwnedWeapon(w, 0));
    if (c.startAction != null) actions.add(OwnedAction(c.startAction!));
    c.mods.forEach((s, v) => stats[s] = stats[s]! + v);
    stats[Stat.maxHp] = max(1.0, (stats[Stat.maxHp]! * c.maxHpMul).roundToDouble());
    hp = maxHp;
  }

  final CharacterDef character;
  final Random _rng;

  /// Schwierigkeitsstufe 1–[kDifficultyCount].
  final int difficulty;
  DifficultyDef get difficultyDef => difficultyDefs[difficulty - 1];

  /// Aktuelle Welt (für Tag/Nacht-Boni), vom Spiel je Welle gesetzt.
  Biome biome = Biome.fields;

  /// Grundwerte ohne Set-Boni; wirksame Werte liefert [stat].
  final Map<Stat, double> stats = {
    for (final s in Stat.values) s: s == Stat.maxHp ? 20.0 : (s == Stat.crit ? 5.0 : 0.0),
  };
  final weapons = <OwnedWeapon>[];
  final items = <String, int>{};

  /// Aktionsplätze (höchstens [kActionSlots]): Startfähigkeit des Charakters und gekaufte Aktions-Items.
  final actions = <OwnedAction>[];

  int actionIndex(ActionId id) => actions.indexWhere((a) => a.id == id);

  /// Was ein Aktions-Item beim Kauf bewirkt.
  ActionBuy actionBuy(ActionId id) {
    final i = actionIndex(id);
    if (i >= 0) return actions[i].level == 0 ? ActionBuy.upgrade : ActionBuy.none;
    return actions.length < kActionSlots ? ActionBuy.add : ActionBuy.replace;
  }

  /// Fügt ein Aktions-Item hinzu: gleiche Aktion → Stufe II, sonst freier Platz oder [replaceSlot].
  void addAction(ActionId id, {int? replaceSlot}) {
    switch (actionBuy(id)) {
      case ActionBuy.upgrade:
        actions[actionIndex(id)].level = 1;
      case ActionBuy.add:
        actions.add(OwnedAction(id));
      case ActionBuy.replace:
        actions[replaceSlot ?? 0] = OwnedAction(id);
      case ActionBuy.none:
    }
  }

  /// Rezept der beiden aktuellen Aktionen, falls sie verschmelzen können.
  ActionRecipe? get evolution => actions.length == 2 ? recipeFor(actions[0].id, actions[1].id) : null;

  /// Verschmilzt beide Aktionen zur Evolution; sie liegt dann in Platz 1, Platz 2 wird frei.
  /// In diesem Run verschmolzene Evolutionen (Kompendium).
  final evolutions = <ActionId>{};

  bool evolve() {
    final r = evolution;
    if (r == null) return false;
    evolutions.add(r.result);
    actions
      ..clear()
      ..add(OwnedAction(r.result));
    return true;
  }

  /// Phönixasche schon verbraucht?
  bool phoenixUsed = false;

  int wave = 1, money = kStartMoney, xp = 0, level = 0, pendingLevels = 0, kills = 0, rerolls = 0;

  /// In diesem Run gesammeltes Material und durch Brand besiegte Gegner (Freischalten).
  int materialCollected = 0, burnKills = 0;
  double _xpAcc = 0;
  double hp = 20;

  /// Bonus-Material der letzten Welle fürs Erreichen des Ziels; null = per Timer beendet.
  int? goalBonus;
  List<Offer> offers = [];
  List<LevelChoice> levelChoices = [];

  // ---------------- Werte ----------------

  int classCount(WeaponClass c) => weapons.where((w) => w.def.cls == c).length;
  int setLevelOf(WeaponClass c) => setLevel(classCount(c));
  bool has(ItemEffect e) => items.keys.any((id) => itemById[id]!.effect == e);

  /// Wirksamer Wert inklusive Set-Boni und Item-Effekten.
  double stat(Stat s) {
    final base = stats[s]!;
    return switch (s) {
      Stat.crit => base + kSetCrit[setLevelOf(WeaponClass.light)],
      Stat.atk => base + kSetAtk[setLevelOf(WeaponClass.wind)],
      Stat.lifesteal => base + kSetLifesteal[setLevelOf(WeaponClass.dark)],
      Stat.regen => base + kSetRegen[setLevelOf(WeaponClass.water)],
      Stat.armor => base +
          kSetArmor[setLevelOf(WeaponClass.stone)] +
          (has(ItemEffect.pebbles) ? classCount(WeaponClass.stone) : 0),
      _ => base,
    };
  }

  double get maxHp => stats[Stat.maxHp]!;
  int get xpNeeded => (level + 3) * (level + 3);

  /// Zusatzschaden auf verfluchte Gegner.
  double get curseBonus => kCurseBase + kSetCurse[setLevelOf(WeaponClass.dark)];

  /// Schadensfaktor aus Welt (Eule), Gießkanne bei Regen usw.; [raining] vom Spiel.
  double worldDamageMul({bool raining = false}) {
    var m = 1.0;
    if (character.nightBonus > 0 && isNightBiome(biome)) m += character.nightBonus;
    if (character.dayMalus > 0 && !isNightBiome(biome)) m -= character.dayMalus;
    if (raining && has(ItemEffect.wateringCan)) m += 0.2;
    return m;
  }

  /// Gibt true zurück, wenn dabei ein Level-up passiert ist. Erfahrung mit Charakter-Faktor.
  bool gain(int v) {
    var money = v;
    if (character.materialChance > 0) {
      for (var i = 0; i < v; i++) {
        if (_rng.nextDouble() < character.materialChance) money++;
      }
    }
    this.money += money;
    materialCollected += money;
    _xpAcc += v * character.xpMul;
    final add = _xpAcc.floor();
    _xpAcc -= add;
    xp += add;
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
      stats[s] = stats[s]! + v;
      if (s == Stat.maxHp) {
        stats[s] = max(1.0, stats[s]!);
        hp = clampD(hp + max(0.0, v), 1, maxHp);
      }
    });
  }

  WeaponStats weaponStats(String id, int tier, {bool raining = false}) {
    final d = weaponDefs[id]!, t = tiers[tier];
    var mul = 1 + stat(Stat.dmg) / 100;
    if (character.classBonus == d.cls) mul *= 1.25;
    if (d.heavy) mul *= 1 + kSetHeavy[setLevelOf(WeaponClass.stone)];
    if (has(ItemEffect.mirror) && _projectile(d.kind)) mul *= 0.7;
    mul *= worldDamageMul(raining: raining);
    final dmg = d.dmg * t.dmg * mul;
    final ember = 1 + kSetEmber[setLevelOf(WeaponClass.ember)];
    final water = 1 + kSetSlow[setLevelOf(WeaponClass.water)];
    final burnFactor = character.burnBonus ? 1.25 : 1.0;
    return WeaponStats(
      dmg: dmg,
      cooldown: d.cooldown * t.cooldown / max(0.3, 1 + stat(Stat.atk) / 100),
      range: d.range + (d.kind == WeaponKind.orbit ? stat(Stat.range) / 6 : stat(Stat.range)),
      explosion: d.explosion * ember,
      burnTime: d.burn * (character.burnBonus ? 1.5 : 1),
      burnDps: d.dmg * t.dmg * kBurnDpsFactor * ember * burnFactor * (1 + stat(Stat.dmg) / 100),
      slow: min(0.85, d.slow * water),
      slowTime: d.slowTime * water,
      stun: d.stun,
      trap: d.trap * (0.85 + 0.15 * water),
      curse: d.curse,
      knock: d.knock,
      stickTime: d.stick,
      stickDps: d.stick > 0 ? dmg : 0,
      lifesteal: d.lifesteal,
    );
  }

  static bool _projectile(WeaponKind k) => k == WeaponKind.shot || k == WeaponKind.lob || k == WeaponKind.disco;

  // ---------------- Shop ----------------

  int weaponPrice(String id, int tier) =>
      (weaponDefs[id]!.price * tiers[tier].price * weaponPriceFactor(wave) * character.shopMul).round();
  int itemPrice(ItemDef it) => (it.price * itemPriceFactor(wave) * character.shopMul).round();
  int get rerollCost => (has(ItemEffect.freeReroll) && rerolls == 0) ? 0 : rerollBaseCost(wave) + rerolls * 2;
  int sellPrice(OwnedWeapon w) => (weaponPrice(w.id, w.tier) * 0.4).round();

  int get maxWeapons => character.maxWeapons;

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

  /// [kShopOffers] normale Angebote (bis Welle [kEarlyWaves] mindestens [kEarlyMinWeapons] Waffen)
  /// plus immer ein Aktions-Angebot am Ende.
  void rollOffers(Random r) {
    // Zurückgehaltene, nicht gekaufte Angebote bleiben am selben Platz (Preis der aktuellen Welle)
    Offer? keep(int i) {
      if (i >= offers.length) return null;
      final o = offers[i];
      if (!o.locked || o.sold) return null;
      if (!o.isWeapon && !itemAvailable(itemById[o.id]!)) return null;
      o.price = o.isWeapon ? weaponPrice(o.id, o.tier) : itemPrice(itemById[o.id]!);
      return o;
    }

    final kept = [for (var i = 0; i <= kShopOffers; i++) keep(i)];
    final list = [for (var i = 0; i < kShopOffers; i++) kept[i] ?? _randomOffer(r)];
    if (wave <= kEarlyWaves) {
      var i = 0;
      while (list.where((o) => o.isWeapon).length < kEarlyMinWeapons && i < list.length) {
        if (!list[i].isWeapon && !list[i].locked) list[i] = _weaponOffer(r);
        i++;
      }
    }
    final act = kept[kShopOffers] ?? _actionOffer(r);
    offers = [...list, ?act];
  }

  void toggleLock(int i) {
    final o = offers[i];
    if (!o.sold) o.locked = !o.locked;
  }

  /// Aktions-Item, bevorzugt eines, das zu Stufe II führt oder in ein Rezept passt.
  Offer? _actionOffer(Random r) {
    final pool = itemDefs.where((it) => it.action != null && itemAvailable(it)).toList();
    if (pool.isEmpty) return null;
    double weight(ItemDef it) {
      final a = it.action!;
      final match = actionBuy(a) == ActionBuy.upgrade || actions.any((o) => recipeFor(o.id, a) != null);
      return match ? kActionMatchWeight : 1;
    }

    final total = pool.fold(0.0, (t, it) => t + weight(it));
    var x = r.nextDouble() * total;
    for (final it in pool) {
      x -= weight(it);
      if (x <= 0) return Offer.item(it.id, itemPrice(it));
    }
    return Offer.item(pool.last.id, itemPrice(pool.last));
  }

  Offer _weaponOffer(Random r) {
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

  /// Seltenheit eines Item-Angebots je Welle.
  Rarity rollRarity(Random r) {
    final x = r.nextDouble();
    final legendary = wave >= 8 ? 0.04 : 0.0;
    final epic = wave >= 4 ? 0.12 + 0.01 * (wave - 4) : 0.03;
    if (x < legendary) return Rarity.legendary;
    if (x < legendary + epic) return Rarity.epic;
    if (x < legendary + epic + 0.3) return Rarity.rare;
    return Rarity.common;
  }

  /// Darf dieses Item (noch) angeboten werden?
  bool itemAvailable(ItemDef it) {
    // Aktions-Items: solange sie noch etwas bewirken (neu, Stufe II oder Ersatz)
    if (it.action != null) return actionBuy(it.action!) != ActionBuy.none;
    if (it.unique && items.containsKey(it.id)) return false;
    return true;
  }

  Offer _randomOffer(Random r) {
    if (r.nextDouble() < weaponOfferChance(wave)) return _weaponOffer(r);
    // Item: Seltenheit würfeln, dann ein verfügbares Item dieser (oder notfalls einer niedrigeren) Stufe
    var rarity = rollRarity(r);
    while (true) {
      // Aktions-Items kommen nur über das eigene Aktions-Angebot
      final pool = itemDefs.where((it) => it.rarity == rarity && it.action == null && itemAvailable(it)).toList();
      if (pool.isNotEmpty) {
        final it = pool[r.nextInt(pool.length)];
        return Offer.item(it.id, itemPrice(it));
      }
      if (rarity == Rarity.common) break;
      rarity = Rarity.values[rarity.index - 1];
    }
    final it = itemDefs.first;
    return Offer.item(it.id, itemPrice(it));
  }

  bool buy(int i, {int? replaceSlot}) {
    final o = offers[i];
    if (o.sold || money < o.price) return false;
    if (o.isWeapon) {
      if (!canAddWeapon(o.id, o.tier)) return false;
      addWeapon(o.id, o.tier);
    } else {
      final it = itemById[o.id]!;
      applyMods(it.mods);
      items[o.id] = (items[o.id] ?? 0) + 1;
      if (it.action != null) addAction(it.action!, replaceSlot: replaceSlot);
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

  /// Verkaufen: Charaktere mit Startwaffe behalten mindestens eine Waffe.
  void sell(int i) {
    if (weapons.length < 2) return;
    money += sellPrice(weapons[i]);
    weapons.removeAt(i);
  }

  /// Zinsen des Sparschweins am Wellenende (10 %, höchstens 25).
  int interest() => has(ItemEffect.interest) ? min(25, (money * 0.1).floor()) : 0;

  void rollLevelChoices(Random r) {
    final pool = [...levelOptions]..shuffle(r);
    levelChoices = pool.take(4).map((o) => LevelChoice(o, r.nextDouble() < 0.2)).toList();
  }

  void chooseLevel(int i) {
    final c = levelChoices[i];
    applyMods({c.option.stat: c.value});
    pendingLevels--;
  }

  // ---------------- Debug ----------------

  /// Debug: Ausrüstung, wie sie ein typischer Run bis vor Welle [wave] ungefähr hätte –
  /// Level-ups, Waffen aus zwei Klassen mit passender Stufe, Items und Aktionen.
  void debugEquip(int wave, Random rng) {
    if (wave <= 1) return;
    final done = wave - 1;

    // Level: etwa 1,2 je geschaffter Welle, Verbesserungen zufällig wie im Spiel
    final levels = (done * 1.2).round();
    for (var i = 0; i < levels; i++) {
      level++;
      stats[Stat.maxHp] = maxHp + 1;
      pendingLevels++;
      rollLevelChoices(rng);
      chooseLevel(rng.nextInt(levelChoices.length));
    }

    // Waffen: zwei Klassen (die der Startwaffe und eine zweite), Anzahl und Stufe wachsen mit der Welle
    final count = min(maxWeapons, (1 + done / 2.6).round());
    final firstCls = weapons.isNotEmpty ? weapons.first.def.cls : WeaponClass.values[rng.nextInt(WeaponClass.values.length)];
    final others = WeaponClass.values.where((c) => c != firstCls).toList();
    final classes = [firstCls, others[rng.nextInt(others.length)]];
    int tier() {
      final base = done >= 12 ? 2 : (done >= 7 ? 1 + (rng.nextDouble() < 0.5 ? 1 : 0) : (done >= 3 ? rng.nextInt(2) : 0));
      return min(3, base + (done >= 10 && rng.nextDouble() < 0.25 ? 1 : 0));
    }

    for (final w in weapons) {
      w.tier = max(w.tier, tier());
    }
    var k = 0;
    while (weapons.length < count) {
      final pool = weaponDefs.values.where((d) => d.cls == classes[k % 2]).toList();
      weapons.add(OwnedWeapon(pool[rng.nextInt(pool.length)].id, tier()));
      k++;
    }

    // Items: etwa 0,8 je Welle mit der Seltenheit dieser Welle
    final saved = this.wave;
    for (var i = 0; i < (done * 0.8).round(); i++) {
      this.wave = 1 + rng.nextInt(done);
      final rarity = rollRarity(rng);
      final pool = itemDefs.where((it) => it.action == null && it.rarity == rarity && itemAvailable(it)).toList();
      if (pool.isEmpty) continue;
      final it = pool[rng.nextInt(pool.length)];
      applyMods(it.mods);
      items[it.id] = (items[it.id] ?? 0) + 1;
    }
    this.wave = saved;

    // Aktionen: ab Welle 5 eine zweite, später Stufe II oder Verschmelzen
    final buyable = itemDefs.where((it) => it.action != null).map((it) => it.action!).toList();
    if (done >= 4) {
      final options = buyable.where((a) => actionBuy(a) == ActionBuy.add).toList();
      if (options.isNotEmpty) addAction(options[rng.nextInt(options.length)]);
    }
    if (done >= 8 && actions.isNotEmpty && rng.nextBool()) {
      final a = actions[rng.nextInt(actions.length)];
      if (!a.id.evolved) a.level = 1;
    }
    if (done >= 10 && evolution != null) evolve();
    hp = maxHp;
  }
}
