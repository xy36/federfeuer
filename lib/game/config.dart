import 'dart:ui';

/// Virtuelle Höhe der Spielwelt. Die Breite ergibt sich aus dem Seitenverhältnis.
const double kVH = 540;
const double kWorldW = 2400;
const double kGround = 468;
const double kCeil = 24;
const int kMaxWave = 10;

double clampD(double v, double lo, double hi) => v < lo ? lo : (v > hi ? hi : v);

String fmtNum(double v) {
  if (v.abs() >= 10 || v == v.roundToDouble()) return v.round().toString();
  return v.toStringAsFixed(1);
}

class Palette {
  static const ink = Color(0xFF2A1D3A);
  static const sun = Color(0xFFFFD23F);
  static const mint = Color(0xFF7CF29C);
  static const coral = Color(0xFFFF5D73);
  static const cyan = Color(0xFF9BF6FF);
  static const teal = Color(0xFF2EC4B6);
  static const purple = Color(0xFFB36BFF);
  static const panel = Color(0xFFF3ECFF);
  static const card = Color(0xFFFFFFFF);
  static const line = Color(0xFFD9CDEF);
  static const muted = Color(0xFF6D5F7E);
  static const good = Color(0xFF1F9D55);
  static const bad = Color(0xFFD8425A);
}

enum Stat { maxHp, regen, dmg, atk, range, speed, armor, lifesteal, crit, pickup }

extension StatInfo on Stat {
  String get label => switch (this) {
        Stat.maxHp => 'Max-HP',
        Stat.regen => 'Regeneration',
        Stat.dmg => 'Schaden',
        Stat.atk => 'Angriffstempo',
        Stat.range => 'Reichweite',
        Stat.speed => 'Tempo',
        Stat.armor => 'Rüstung',
        Stat.lifesteal => 'Lebensraub',
        Stat.crit => 'Krit-Chance',
        Stat.pickup => 'Sammelradius',
      };

  String get unit => switch (this) {
        Stat.dmg || Stat.atk || Stat.speed || Stat.lifesteal || Stat.crit => '%',
        _ => '',
      };
}

// ---------------- Waffen ----------------

class WeaponDef {
  const WeaponDef({
    required this.id,
    required this.name,
    required this.icon,
    required this.desc,
    required this.dmg,
    required this.cooldown,
    required this.range,
    required this.speed,
    required this.price,
    required this.color,
    required this.radius,
    required this.length,
    this.count = 1,
    this.spread = 0,
    this.pierce = 0,
    this.explosion = 0,
  });

  final String id, name, icon, desc;
  final double dmg, cooldown, range, speed, spread, radius, length, explosion;
  final int count, pierce, price;
  final Color color;
}

const Map<String, WeaponDef> weaponDefs = {
  'pistol': WeaponDef(
      id: 'pistol', name: 'Pistole', icon: '🔫', desc: 'Solide Allround-Waffe.',
      dmg: 8, cooldown: 0.75, range: 330, speed: 720, spread: 0.04, price: 15,
      color: Color(0xFFFFF3B0), radius: 4, length: 12),
  'smg': WeaponDef(
      id: 'smg', name: 'Maschinenpistole', icon: '💨', desc: 'Sehr schnell, wenig Schaden.',
      dmg: 3, cooldown: 0.18, range: 270, speed: 760, spread: 0.22, price: 18,
      color: Color(0xFFFFD6A5), radius: 3, length: 15),
  'shotgun': WeaponDef(
      id: 'shotgun', name: 'Schrotflinte', icon: '💥', desc: 'Fünf Kugeln auf kurze Distanz.',
      dmg: 5, cooldown: 1.15, range: 210, speed: 640, count: 5, spread: 0.6, price: 20,
      color: Color(0xFFFFADAD), radius: 3.5, length: 17),
  'rail': WeaponDef(
      id: 'rail', name: 'Railgun', icon: '⚡', desc: 'Durchschlägt alle Gegner in der Linie.',
      dmg: 22, cooldown: 1.7, range: 470, speed: 1500, pierce: 99, price: 28,
      color: Color(0xFF9BF6FF), radius: 4, length: 20),
  'rocket': WeaponDef(
      id: 'rocket', name: 'Raketenwerfer', icon: '🚀', desc: 'Explodiert und trifft alles im Umkreis.',
      dmg: 15, cooldown: 1.6, range: 390, speed: 420, spread: 0.05, explosion: 75, price: 30,
      color: Color(0xFFFF9F1C), radius: 6, length: 18),
};

class TierDef {
  const TierDef(this.dmg, this.cooldown, this.price, this.label, this.color);
  final double dmg, cooldown, price;
  final String label;
  final Color color;
}

const tiers = [
  TierDef(1, 1, 1, 'I', Color(0xFFCFCFD6)),
  TierDef(1.7, 0.9, 1.9, 'II', Color(0xFF4FB3FF)),
  TierDef(2.7, 0.8, 3.3, 'III', Color(0xFFB36BFF)),
  TierDef(4.2, 0.7, 5.5, 'IV', Color(0xFFFF5D73)),
];

// ---------------- Items & Level-ups ----------------

class ItemDef {
  const ItemDef(this.id, this.name, this.icon, this.price, this.mods);
  final String id, name, icon;
  final int price;
  final Map<Stat, double> mods;
}

const itemDefs = [
  ItemDef('helm', 'Blechhelm', '⛑️', 14, {Stat.armor: 2}),
  ItemDef('apfel', 'Riesenapfel', '🍎', 12, {Stat.maxHp: 5}),
  ItemDef('pflaster', 'Pflasterrolle', '🩹', 15, {Stat.regen: 2}),
  ItemDef('hantel', 'Hantel', '🏋️', 18, {Stat.dmg: 12, Stat.speed: -3}),
  ItemDef('kaffee', 'Doppelter Espresso', '☕', 18, {Stat.atk: 15}),
  ItemDef('fernglas', 'Fernglas', '🔭', 16, {Stat.range: 60}),
  ItemDef('feder', 'Goldfeder', '🪶', 14, {Stat.speed: 12}),
  ItemDef('zahn', 'Vampirzahn', '🦷', 22, {Stat.lifesteal: 4}),
  ItemDef('klee', 'Kleeblatt', '🍀', 16, {Stat.crit: 8}),
  ItemDef('magnet', 'Magnet', '🧲', 10, {Stat.pickup: 70}),
  ItemDef('glas', 'Glaskanone', '🔮', 25, {Stat.dmg: 30, Stat.maxHp: -6}),
  ItemDef('panzer', 'Schildkrötenpanzer', '🐢', 20, {Stat.armor: 5, Stat.speed: -8}),
  ItemDef('dose', 'Energiedose', '🥤', 22, {Stat.atk: 25, Stat.armor: -2}),
  ItemDef('wurm', 'Fetter Wurm', '🪱', 20, {Stat.maxHp: 8, Stat.regen: 1}),
];

final Map<String, ItemDef> itemById = {for (final i in itemDefs) i.id: i};

class LevelOption {
  const LevelOption(this.stat, this.value, this.icon);
  final Stat stat;
  final double value;
  final String icon;
}

const levelOptions = [
  LevelOption(Stat.maxHp, 3, '❤️'),
  LevelOption(Stat.regen, 1, '💚'),
  LevelOption(Stat.dmg, 6, '💥'),
  LevelOption(Stat.atk, 6, '⚡'),
  LevelOption(Stat.armor, 1, '🛡️'),
  LevelOption(Stat.range, 25, '🎯'),
  LevelOption(Stat.speed, 5, '🪶'),
  LevelOption(Stat.lifesteal, 2, '🦷'),
  LevelOption(Stat.crit, 4, '🍀'),
];

// ---------------- Gegner ----------------

enum EnemyType { crow, beetle, spitter, rock, boss }

class EnemyDef {
  const EnemyDef({
    required this.hp,
    required this.speed,
    required this.dmg,
    required this.radius,
    required this.flying,
    required this.drop,
  });
  final double hp, speed, dmg, radius;
  final bool flying;
  final int drop;
}

const Map<EnemyType, EnemyDef> enemyDefs = {
  EnemyType.crow: EnemyDef(hp: 6, speed: 95, dmg: 2, radius: 13, flying: true, drop: 1),
  EnemyType.beetle: EnemyDef(hp: 12, speed: 75, dmg: 3, radius: 15, flying: false, drop: 1),
  EnemyType.spitter: EnemyDef(hp: 9, speed: 70, dmg: 2, radius: 14, flying: true, drop: 1),
  EnemyType.rock: EnemyDef(hp: 45, speed: 42, dmg: 5, radius: 27, flying: true, drop: 3),
  EnemyType.boss: EnemyDef(hp: 3000, speed: 55, dmg: 6, radius: 52, flying: true, drop: 0),
};
