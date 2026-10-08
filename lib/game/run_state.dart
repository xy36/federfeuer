import 'dart:math';

import 'config.dart';

class OwnedWeapon {
  OwnedWeapon(this.id, this.tier);
  final String id;
  int tier;
  WeaponDef get def => weaponDefs[id]!;

  /// Gaben verschmolzener Spenderwaffen (deren IDs) und gewählte Eigenschaften.
  final gifts = <String>[];
  final traits = <WeaponTrait>[];

  /// Eigene Klasse plus die Klassen der Spender (Set-Boni, Reaktionen).
  List<WeaponClass> get classes => {def.cls, for (final g in gifts) weaponDefs[g]!.cls}.toList();
}

/// Ausstehende Wahl einer Eigenschaft nach dem Verschmelzen gleicher Waffen.
class TraitChoice {
  TraitChoice(this.weapon, this.options);
  final OwnedWeapon weapon;
  final List<WeaponTrait> options;
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
    this.classes = const [],
    this.count = 1,
    this.pierce = 0,
    this.spread = 0,
    this.radius = 0,
    this.critBonus = 0,
    this.stunChance = 0,
    this.stunTime = 0,
    this.trapChance = 0,
    this.trapTime = 0,
    this.blastChance = 0,
    this.blastRadius = 0,
    this.blastMul = 0,
  });
  final double dmg, cooldown, range, explosion;
  final double burnTime, burnDps, slow, slowTime, stun, trap, curse, knock, stickTime, stickDps, lifesteal;

  /// Klassen der Treffer (eigene plus Gaben), für Reaktionen.
  final List<WeaponClass> classes;

  /// Projektile/Klingen/Begleiter, Durchschlag, Streuung bzw. Hiebbogen, Wolkenbreite.
  final int count, pierce;
  final double spread, radius;

  /// Aus Gaben: Krit-Bonus, Chancen auf Betäuben/Einfangen, kleine Explosionen.
  final double critBonus, stunChance, stunTime, trapChance, trapTime, blastChance, blastRadius, blastMul;
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
    statBase.addAll(stats);
    hp = maxHp;
    // Torwächter und Endboss dieses Runs auslosen (Torwächter ohne Wiederholung)
    final pool = [...kGatekeepers]..shuffle(_rng);
    for (var i = 0; i < kGateWaves.length; i++) {
      gatekeepers[kGateWaves[i]] = pool[i % pool.length];
    }
    finalBoss = kFinalBosses[_rng.nextInt(kFinalBosses.length)];
  }

  final CharacterDef character;
  final Random _rng;

  /// Torwächter je Welle (4, 8, 12) und Endboss dieses Runs, beim Start ausgelost.
  final gatekeepers = <int, EnemyType>{};
  late EnemyType finalBoss;
  EnemyType? gatekeeperFor(int wave) => gatekeepers[wave];

  /// Schwierigkeitsstufe 1–[kDifficultyCount].
  final int difficulty;
  DifficultyDef get difficultyDef => difficultyDefs[difficulty - 1];

  /// Sinkgeschwindigkeit des Materials: Stufe, aber mindestens die des Vogels (Frack).
  double get dropFallSpeed => max(difficultyDef.dropFallSpeed, character.minDropFall);

  /// Aktuelle Welt (für Tag/Nacht-Boni), vom Spiel je Welle gesetzt.
  Biome biome = Biome.fields;

  /// Grundwerte ohne Set-Boni; wirksame Werte liefert [stat].
  final Map<Stat, double> stats = {
    for (final s in Stat.values) s: s == Stat.maxHp ? 20.0 : (s == Stat.crit ? 5.0 : 0.0),
  };
  /// Herkunft der Werte (Werte-Seite): Startwerte des Vogels und Summe der Level-ups;
  /// der Rest von [stats] stammt aus Items, [stat] − [stats] aus Set-Boni und Item-Effekten.
  final statBase = <Stat, double>{};
  final statFromLevels = {for (final s in Stat.values) s: 0.0};
  double statFromItems(Stat s) => stats[s]! - statBase[s]! - statFromLevels[s]!;
  double statFromSets(Stat s) => stat(s) - stats[s]!;

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

  int classCount(WeaponClass c) => weapons.where((w) => w.classes.contains(c)).length;
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

  /// Abklingzeit einer Aktion mit Aktionstempo (wie beim Angriffstempo höchstens × 1/0,3).
  double actionCooldown(OwnedAction a) => a.cooldown / max(0.3, 1 + stat(Stat.actionSpeed) / 100);

  /// Faktor für Herz- und Geschenk-Chancen aus Glück.
  double get luckDropMul => 1 + kLuckDrops * max(0.0, stat(Stat.luck));
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
      statFromLevels[Stat.maxHp] = statFromLevels[Stat.maxHp]! + 1;
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

  /// Werte einer eigenen Waffe inklusive Gaben und Eigenschaften.
  WeaponStats statsOf(OwnedWeapon w, {bool raining = false}) =>
      weaponStats(w.id, w.tier, raining: raining, gifts: w.gifts, traits: w.traits);

  WeaponStats weaponStats(String id, int tier,
      {bool raining = false, List<String> gifts = const [], List<WeaponTrait> traits = const []}) {
    final d = weaponDefs[id]!, t = tiers[tier];
    final gs = [for (final g in gifts) weaponGifts[g]!];
    int n(WeaponTrait x) => traits.where((y) => y == x).length;
    double sum(double Function(WeaponGift) f) => gs.fold(0.0, (a, g) => a + f(g));
    double prod(double Function(WeaponGift) f) => gs.fold(1.0, (a, g) => a * f(g));
    double most(double Function(WeaponGift) f) => gs.fold(0.0, (a, g) => max(a, f(g)));
    var mul = (1 + stat(Stat.dmg) / 100) * prod((g) => g.dmgMul) * (1 + kTraitDmg * n(WeaponTrait.sharp));
    final storm = has(ItemEffect.stormChild) && stormy;
    if (storm) mul *= 1 + kStormChildDmg;
    if (character.classBonus == d.cls) mul *= 1.25;
    if (d.heavy) mul *= 1 + kSetHeavy[setLevelOf(WeaponClass.stone)];
    if (has(ItemEffect.mirror) && _projectile(d.kind)) mul *= 0.7;
    mul *= worldDamageMul(raining: raining);
    final dmg = d.dmg * t.dmg * kWeaponDmgMul * mul;
    final ember = 1 + kSetEmber[setLevelOf(WeaponClass.ember)];
    final water = 1 + kSetSlow[setLevelOf(WeaponClass.water)];
    final burnFactor = character.burnBonus ? 1.25 : 1.0;
    final atk = (1 + stat(Stat.atk) / 100) * prod((g) => g.atkMul) * (1 + kTraitAtk * n(WeaponTrait.quick)) *
        (storm ? 1 + kStormChildAtk : 1);
    final rangeAdd = stat(Stat.range) + sum((g) => g.rangeAdd) + kTraitRange * n(WeaponTrait.reach);
    final stick = max(d.stick, sum((g) => g.stick));
    return WeaponStats(
      dmg: dmg,
      cooldown: d.cooldown * t.cooldown / max(0.3, atk),
      range: d.range + (d.kind == WeaponKind.orbit ? rangeAdd / 6 : rangeAdd),
      explosion: d.explosion * ember * (1 + kTraitBlast * n(WeaponTrait.blast)),
      burnTime: max(d.burn, sum((g) => g.burnTime)) * (character.burnBonus ? 1.5 : 1),
      burnDps: d.dmg * t.dmg * kWeaponDmgMul * kBurnDpsFactor * ember * burnFactor * (1 + stat(Stat.dmg) / 100),
      slow: min(0.85, max(d.slow, most((g) => g.slow)) * water),
      slowTime: max(d.slowTime, most((g) => g.slowTime)) * water,
      stun: d.stun,
      trap: d.trap * (0.85 + 0.15 * water),
      curse: max(d.curse, sum((g) => g.curse)),
      knock: d.knock + sum((g) => g.knockAdd),
      stickTime: stick,
      stickDps: stick > 0 ? dmg : 0,
      lifesteal: d.lifesteal + sum((g) => g.lifesteal),
      classes: {d.cls, for (final g in gifts) weaponDefs[g]!.cls}.toList(),
      count: d.count + n(WeaponTrait.multi) * (d.kind == WeaponKind.disco ? 2 : 1),
      pierce: d.pierce + kTraitPierce * n(WeaponTrait.pierce),
      spread: d.spread + kTraitArc * n(WeaponTrait.arc),
      radius: d.radius * (1 + kTraitWide * n(WeaponTrait.wide)),
      critBonus: sum((g) => g.critBonus) + kTraitCrit * n(WeaponTrait.keen),
      stunChance: sum((g) => g.stunChance),
      stunTime: most((g) => g.stunTime),
      trapChance: sum((g) => g.trapChance),
      trapTime: most((g) => g.trapTime),
      blastChance: min(1.0, sum((g) => g.blastChance)),
      blastRadius: most((g) => g.blastRadius),
      blastMul: most((g) => g.blastMul),
    );
  }

  static bool _projectile(WeaponKind k) => k == WeaponKind.shot || k == WeaponKind.lob || k == WeaponKind.disco;

  // ---------------- Shop ----------------

  int weaponPrice(String id, int tier) =>
      (weaponDefs[id]!.price * kWeaponPriceScale * tiers[tier].price * weaponPriceFactor(wave) * character.shopMul).round();
  int itemPrice(ItemDef it) {
    final base = it.effect == ItemEffect.weaponBelt ? kBeltPrice + kBeltPriceStep * (items[it.id] ?? 0) : it.price;
    return (base * itemPriceFactor(wave) * character.shopMul * (it.rarity == Rarity.cursed ? kCursedPriceMul : 1)).round();
  }
  int get rerollCost => (has(ItemEffect.freeReroll) && rerolls == 0) ? 0 : rerollBaseCost(wave) + rerolls * 2;
  int sellPrice(OwnedWeapon w) => (weaponPrice(w.id, w.tier) * 0.4).round();

  /// Reserve: feuert nicht, zählt nicht für Sets; zum Verschmelzen und als Gaben-Spender.
  final reserve = <OwnedWeapon>[];

  /// Freigeschaltete aktive Plätze (Waffengurt, Torwächter).
  late int slotsUnlocked = min(kStartWeaponSlots, character.maxWeapons);

  /// Höchstzahl aktiver Plätze dieses Vogels (Einsamer Wolf: weniger).
  int get weaponSlotCap => has(ItemEffect.loneWolf) ? min(kLoneWolfSlots, character.maxWeapons) : character.maxWeapons;

  /// Aktuell nutzbare aktive Plätze.
  int get maxWeapons => min(slotsUnlocked, weaponSlotCap);

  bool get reserveFull => reserve.length >= kReserveSlots;

  /// Einen aktiven Platz freischalten (Waffengurt, Torwächter); false, wenn schon alle offen sind.
  bool unlockSlot() {
    if (slotsUnlocked >= character.maxWeapons) return false;
    slotsUnlocked++;
    return true;
  }

  /// Alle eigenen Waffen (aktiv und Reserve).
  Iterable<OwnedWeapon> get allWeapons => [...weapons, ...reserve];

  /// Faktor kritischer Treffer (Adler ×2,5, Nachtschatten ×3).
  double get critMul => has(ItemEffect.nightShade) ? max(kNightCritMul, character.critMul) : character.critMul;

  /// Schlechtwetter in der laufenden Welle (vom Spiel gesetzt; für Sturmkind).
  bool stormy = false;

  /// Hat der Run ein verfluchtes Item? (dunkler Schimmer um den Vogel)
  bool get cursed => items.keys.any((id) => itemById[id]!.rarity == Rarity.cursed);

  bool get slotsFull => weapons.length >= maxWeapons;

  /// Gibt es schon eine gleiche Waffe gleicher Stufe (unter IV), mit der sie verschmelzen könnte?
  bool canMerge(String id, int tier) => tier < 3 && allWeapons.any((w) => w.id == id && w.tier == tier);

  /// Kauf verschmilzt nur, wenn alle Slots belegt sind – sonst kommt die Waffe in einen freien Slot.
  bool mergesOnBuy(String id, int tier) => slotsFull && canMerge(id, tier);
  bool canAddWeapon(String id, int tier) => !slotsFull || canMerge(id, tier) || !reserveFull;

  /// Fügt eine Waffe in einen freien Slot ein. Sind alle Slots belegt,
  /// verschmilzt sie mit einer gleichen Waffe gleicher Stufe (eine Stufe, keine Kette).
  void addWeapon(String id, int tier) {
    if (!slotsFull) {
      weapons.add(OwnedWeapon(id, tier));
      return;
    }
    final same = allWeapons.where((w) => w.id == id && w.tier == tier && tier < 3).firstOrNull;
    if (same != null) {
      _tierUp(same);
    } else if (!reserveFull) {
      reserve.add(OwnedWeapon(id, tier));
    }
  }

  /// Ausstehende Wahl einer Eigenschaft (nach dem Verschmelzen gleicher Waffen).
  TraitChoice? traitChoice;

  /// Stufe hoch und 1 aus 3 passenden Eigenschaften zur Wahl stellen.
  void _tierUp(OwnedWeapon w) {
    w.tier++;
    final pool = WeaponTrait.values.where((t) => t.appliesTo(w.def)).toList()..shuffle(_rng);
    if (pool.isNotEmpty) traitChoice = TraitChoice(w, pool.take(3).toList());
  }

  /// Gewählte Eigenschaft übernehmen.
  void chooseTrait(int k) {
    final c = traitChoice;
    if (c == null) return;
    c.weapon.traits.add(c.options[k]);
    traitChoice = null;
  }

  /// Kann [d] seine Gabe an [t] abgeben? (Verschiedene Waffen, freier Gaben-Platz, Gabe noch
  /// nicht vorhanden; die letzte aktive Waffe gibt nichts ab.)
  bool canGiftTo(OwnedWeapon d, OwnedWeapon t) =>
      !identical(d, t) &&
      d.id != t.id &&
      !t.gifts.contains(d.id) &&
      t.gifts.length < maxGifts(t.tier) &&
      !(weapons.contains(d) && weapons.length < 2);

  bool hasGiftTargetFor(OwnedWeapon d) => allWeapons.any((t) => canGiftTo(d, t));

  /// [d] gibt seine Gabe an [t] ab und verschwindet (aus Plätzen oder Reserve).
  bool giftTo(OwnedWeapon d, OwnedWeapon t) {
    if (!canGiftTo(d, t)) return false;
    t.gifts.add(d.id);
    if (!weapons.remove(d)) reserve.remove(d);
    return true;
  }

  /// Angebotene Waffe [i] direkt als Gabe an [t] kaufen – sie belegt weder Platz noch Reserve.
  bool canBuyAsGift(int i, OwnedWeapon t) {
    final o = offers[i];
    return o.isWeapon && !o.sold && money >= o.price && canGiftTo(OwnedWeapon(o.id, o.tier), t);
  }

  bool offerHasGiftTarget(int i) {
    final o = offers[i];
    return o.isWeapon && !o.sold && hasGiftTargetFor(OwnedWeapon(o.id, o.tier));
  }

  bool buyAsGift(int i, OwnedWeapon t) {
    if (!canBuyAsGift(i, t)) return false;
    final o = offers[i];
    t.gifts.add(o.id);
    money -= o.price;
    o.sold = true;
    return true;
  }

  // Index-Varianten für die aktiven Plätze
  bool canGift(int donor, int target) =>
      donor < weapons.length && target < weapons.length && canGiftTo(weapons[donor], weapons[target]);
  bool hasGiftTarget(int donor) => donor < weapons.length && hasGiftTargetFor(weapons[donor]);
  bool giveGift(int donor, int target) => canGift(donor, target) && giftTo(weapons[donor], weapons[target]);

  /// Gleiche Waffe gleicher Stufe (aktiv oder Reserve) zum Verschmelzen mit [w].
  OwnedWeapon? partnerFor(OwnedWeapon w) =>
      w.tier >= 3 ? null : allWeapons.where((o) => !identical(o, w) && o.id == w.id && o.tier == w.tier).firstOrNull;

  /// [w] steigt eine Stufe auf, der Partner verschwindet; seine Gaben gehen mit über, soweit Platz ist.
  bool mergeWeapon(OwnedWeapon w) {
    final p = partnerFor(w);
    if (p == null) return false;
    for (final g in p.gifts) {
      if (!w.gifts.contains(g) && w.gifts.length < maxGifts(w.tier + 1)) w.gifts.add(g);
    }
    _tierUp(w);
    if (!weapons.remove(p)) reserve.remove(p);
    return true;
  }

  /// Aktive Waffe in die Reserve (nicht die letzte aktive).
  bool toReserve(OwnedWeapon w) {
    if (!weapons.contains(w) || weapons.length < 2 || reserveFull) return false;
    weapons.remove(w);
    reserve.add(w);
    return true;
  }

  /// Reserve-Waffe einsetzen (freier aktiver Platz nötig).
  bool toActive(OwnedWeapon w) {
    if (!reserve.contains(w) || slotsFull) return false;
    reserve.remove(w);
    weapons.add(w);
    return true;
  }

  /// Reserve-Waffe [r] gegen aktive Waffe [a] tauschen.
  bool swapWeapons(OwnedWeapon r, OwnedWeapon a) {
    final i = weapons.indexOf(a), j = reserve.indexOf(r);
    if (i < 0 || j < 0) return false;
    weapons[i] = r;
    reserve[j] = a;
    return true;
  }

  /// Verkaufen aus Plätzen oder Reserve (die letzte aktive Waffe bleibt).
  bool sellWeapon(OwnedWeapon w) {
    if (weapons.contains(w)) {
      if (weapons.length < 2) return false;
      weapons.remove(w);
    } else if (!reserve.remove(w)) {
      return false;
    }
    money += sellPrice(w);
    return true;
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
  bool merge(int i) => i < weapons.length && mergeWeapon(weapons[i]);

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
    _guaranteeBelt(list, r);
    final act = kept[kShopOffers] ?? _actionOffer(r);
    offers = [...list, ?act];
  }

  /// Shops in Folge ohne Waffengurt-Angebot (nur neue Shops zählen, nicht Neu würfeln).
  int shopsWithoutBelt = 0;
  int _lastOfferWave = -1;

  void _guaranteeBelt(List<Offer> list, Random r) {
    final belt = itemById['waffengurt']!;
    final fresh = wave != _lastOfferWave;
    _lastOfferWave = wave;
    if (!itemAvailable(belt)) return;
    if (list.any((o) => o.id == belt.id)) {
      shopsWithoutBelt = 0;
      return;
    }
    if (!fresh) return;
    if (shopsWithoutBelt >= kBeltGuaranteeShops) {
      final free = [for (var i = 0; i < list.length; i++) if (!list[i].locked) i];
      if (free.isNotEmpty) {
        final i = free.lastWhere((i) => !list[i].isWeapon, orElse: () => free.last);
        list[i] = Offer.item(belt.id, itemPrice(belt));
        shopsWithoutBelt = 0;
        return;
      }
    }
    shopsWithoutBelt++;
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
    // Verflucht: unabhängig von Glück, ab Welle kCursedFromWave
    if (wave >= kCursedFromWave && r.nextDouble() < kCursedChance) return Rarity.cursed;
    final x = r.nextDouble();
    final luck = max(0.0, stat(Stat.luck));
    final legendary = wave >= 8 ? 0.04 + kLuckLegendary * luck : 0.0;
    final epic = (wave >= 4 ? 0.12 + 0.01 * (wave - 4) : 0.03) + kLuckEpic * luck;
    final rare = 0.3 + kLuckRare * luck;
    if (x < legendary) return Rarity.legendary;
    if (x < legendary + epic) return Rarity.epic;
    if (x < legendary + epic + rare) return Rarity.rare;
    return Rarity.common;
  }

  /// Darf dieses Item (noch) angeboten werden?
  bool itemAvailable(ItemDef it) {
    // Aktions-Items: solange sie noch etwas bewirken (neu, Stufe II oder Ersatz)
    if (it.action != null) return actionBuy(it.action!) != ActionBuy.none;
    if (it.unique && items.containsKey(it.id)) return false;
    if (it.effect == ItemEffect.weaponBelt) return slotsUnlocked < weaponSlotCap;
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
      // Keine verfluchten mehr übrig: normales seltenes Item statt eines legendären
      rarity = rarity == Rarity.cursed ? Rarity.rare : Rarity.values[rarity.index - 1];
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
      // Waffengurt: ein aktiver Platz mehr
      if (it.effect == ItemEffect.weaponBelt) unlockSlot();
      // Einsamer Wolf: überzählige Waffen in die Reserve, sonst verkaufen (die schwächsten zuerst)
      while (weapons.length > maxWeapons) {
        final low = weapons.reduce((a, b) => b.tier < a.tier ? b : a);
        weapons.remove(low);
        if (reserveFull) {
          money += sellPrice(low);
        } else {
          reserve.add(low);
        }
      }
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
    final rareChance = 0.2 + kLuckLevelRare * max(0.0, stat(Stat.luck));
    levelChoices = pool.take(4).map((o) => LevelChoice(o, r.nextDouble() < rareChance)).toList();
  }

  void chooseLevel(int i) {
    final c = levelChoices[i];
    applyMods({c.option.stat: c.value});
    statFromLevels[c.option.stat] = statFromLevels[c.option.stat]! + c.value;
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
      statFromLevels[Stat.maxHp] = statFromLevels[Stat.maxHp]! + 1;
      pendingLevels++;
      rollLevelChoices(rng);
      chooseLevel(rng.nextInt(levelChoices.length));
    }

    // Plätze: wie nach den Torwächtern der geschafften Welten
    for (final gate in [4, 8, 12]) {
      if (done >= gate) unlockSlot();
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
      // Verfluchte Items sind bewusste Tauschgeschäfte – nicht in der Debug-Ausrüstung
      if (rarity == Rarity.cursed) continue;
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
