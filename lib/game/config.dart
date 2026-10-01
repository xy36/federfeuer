import 'dart:math';
import 'dart:ui';

/// Virtuelle Höhe der Spielwelt. Die Breite ergibt sich aus dem Seitenverhältnis.
const double kVH = 540;
const double kGround = 468;
const double kCeil = 24;
const int kMaxWave = 15;

/// Breite der Arena in der Bosswelle und im Menü-Hintergrund.
const double kArenaW = 2400;

/// Grundtempo des Spielers (ohne Tempo-Bonus).
const double kPlayerSpeed = 230;

/// Anteil der Wellenzeit, in dem die Strecke mit Grundtempo durchflogen ist.
const double kCrossTimeShare = 0.6;

/// Startposition links und Abstand des Ziels vom rechten Weltende.
const double kStartX = 120;
const double kGoalInset = 90;

/// Beim Erreichen des Ziels: 1 Material pro so vielen Sekunden Restzeit.
const double kGoalBonusSeconds = 2;

/// Gegner, die so weit hinter dem Spieler zurückliegen, verschwinden.
const double kDespawnBehind = 1400;

/// Spawn-Abstand zum Spieler und Chance, dass die Gruppe vor ihm erscheint.
const double kSpawnMinDist = 280;
const double kSpawnMaxDist = 700;
const double kSpawnAheadChance = 0.65;

/// Timer-Wellen spawnen im Bild: Abstand der Gruppe zum Bildrand.
const double kSpawnScreenMargin = 40;

/// Einblendung „Welle geschafft“, bevor Level-up/Shop erscheinen (Sekunden).
const double kWaveClearDelay = 1.2;

/// So lange nach dem Öffnen eines Menüs wird Controller-A ignoriert, damit
/// ein Tippen zum Fliegen nicht versehentlich etwas auswählt (Millisekunden).
const int kMenuConfirmGraceMs = 500;

bool isBossWave(int wave) => wave == kMaxWave;

// ---------------- Shop-Preise ----------------

/// Preisfaktor je Welle: 1 + lin·(w−1) + quad·(w−1)². Der quadratische Anteil
/// hält mit dem späten Einkommen mit (mehr und längere Wellen, größere Gruppen).
const double kWeaponPriceLin = 0.12, kWeaponPriceQuad = 0.012;
const double kItemPriceLin = 0.15, kItemPriceQuad = 0.015;

/// Neu würfeln: ⌊2 + lin·w + quad·w²⌋, jeder weitere Wurf in derselben Shopphase +2.
const double kRerollLin = 0.8, kRerollQuad = 0.04;

double weaponPriceFactor(int wave) => 1 + kWeaponPriceLin * (wave - 1) + kWeaponPriceQuad * (wave - 1) * (wave - 1);
double itemPriceFactor(int wave) => 1 + kItemPriceLin * (wave - 1) + kItemPriceQuad * (wave - 1) * (wave - 1);
int rerollBaseCost(int wave) => (2 + kRerollLin * wave + kRerollQuad * wave * wave).floor();

/// Bezugsgröße der Menüs und des HUD (logische Pixel).
const double kUiRefW = 1280, kUiRefH = 720, kUiMaxScale = 2.2;

/// Menüs und HUD wachsen auf großen Bildschirmen mit (z. B. PC im Vollbild);
/// auf kleineren Bildschirmen bleibt alles in Originalgröße.
double uiScaleFor(double w, double h) => clampD(min(w / kUiRefW, h / kUiRefH), 1, kUiMaxScale);

/// Dauer einer Timer-Welle in Sekunden.
double waveDuration(int wave) => 20.0 + (wave - 1) * 4;

/// Weltbreite: mit Grundtempo in [kCrossTimeShare] der Wellenzeit durchfliegbar.
double worldWidth(int wave) =>
    isBossWave(wave) ? kArenaW : kPlayerSpeed * kCrossTimeShare * waveDuration(wave);

double clampD(double v, double lo, double hi) => v < lo ? lo : (v > hi ? hi : v);

String fmtNum(double v) {
  if (v.abs() >= 10 || v == v.roundToDouble()) return v.round().toString();
  return v.toStringAsFixed(1);
}

/// Faktor mit deutschem Komma und ohne überflüssige Nullen (1,25 / 1,1 / 1).
String fmtFactor(double v) =>
    v.toStringAsFixed(2).replaceFirst(RegExp(r'\.?0+$'), '').replaceAll('.', ',');

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
  EnemyType.boss: EnemyDef(hp: 4500, speed: 55, dmg: 6, radius: 52, flying: true, drop: 0),
};

// ---------------- Schwierigkeitsstufen ----------------

class DifficultyDef {
  const DifficultyDef(this.level, this.name, this.hp, this.dmg, this.spawn, {this.dropFallSpeed = 0});

  /// 1–[kDifficultyCount]; steuert auch die Schlechtwetter-Chance (+15 % pro Stufe).
  final int level;
  final String name;

  /// Faktoren auf Gegner-HP und -Schaden (auch Boss) und auf die Spawnrate.
  final double hp, dmg, spawn;

  /// Wie schnell Material und Herzen zu Boden sinken (Welteinheiten/s);
  /// 0 = sie schweben dort, wo der Gegner starb.
  final double dropFallSpeed;

  bool get dropsFall => dropFallSpeed > 0;
}

const difficultyDefs = [
  DifficultyDef(1, 'Küken', 1.0, 1.0, 1.0),
  DifficultyDef(2, 'Spatz', 1.15, 1.1, 1.1),
  DifficultyDef(3, 'Falke', 1.3, 1.25, 1.2, dropFallSpeed: 12),
  DifficultyDef(4, 'Adler', 1.5, 1.4, 1.3, dropFallSpeed: 35),
  DifficultyDef(5, 'Phönix', 1.75, 1.6, 1.4, dropFallSpeed: 70),
];

const int kDifficultyCount = 5;

DifficultyDef difficultyDef(int level) => difficultyDefs[level.clamp(1, kDifficultyCount) - 1];

// ---------------- Welten ----------------

enum Biome { fields, village, forest, mountains, summit }

/// Form der Parallax-Ebenen einer Welt.
enum LayerStyle { hills, ruins, forest, peaks }

/// Kulisse einer Welt im leuchtenden, geschichteten Stil: Himmel mit Lichtquelle,
/// vier Silhouetten-Ebenen mit Dunst, dunkler Boden mit Lichtkante, Lichtpartikel.
/// Spielwerte hängen nur an der Welle; die Welt bestimmt zusätzlich das Wetter.
class BiomeDef {
  const BiomeDef({
    required this.name,
    required this.sky,
    required this.light,
    required this.layers,
    required this.fog,
    required this.ground,
    required this.rim,
    required this.glow,
    required this.style,
    this.lightX = 0.7,
    this.lightY = 200,
    this.lightSize = 60,
    this.moon = false,
    this.shafts = false,
    this.stars = false,
    this.aurora = false,
    this.river = false,
    this.snow = false,
    this.layerDrop = 0,
    this.layerAmp = 1,
    this.motes = 40,
    this.shaftStrength = 1,
    this.weatherPool = WeatherConfig.defaultPool,
    this.badWeatherBonus = 0,
  });

  final String name;

  /// Himmelsverlauf von oben nach unten (4 Stufen).
  final List<Color> sky;

  /// Farbe der Lichtquelle (Sonne/Mond), ihrer Strahlen und des Lichthofs.
  final Color light;

  /// Position (Anteil der Bildbreite, Welt-y) und Größe der Lichtquelle.
  final double lightX, lightY, lightSize;
  final bool moon;

  /// Vier Silhouetten-Ebenen von hinten (hell, dunstig) nach vorn (dunkel).
  final List<Color> layers;

  /// Dunst zwischen den Ebenen.
  final Color fog;

  /// Boden und Vordergrund (fast schwarz) und die leuchtende Kante darauf.
  final Color ground, rim;

  /// Leuchtfarbe für Pflanzen, Laternen und schwebende Lichtpartikel.
  final Color glow;
  final LayerStyle style;

  final bool shafts, stars, aurora, river, snow;

  /// Verschiebung der Ebenen nach unten und Höhenfaktor (Gipfel: Berge tief unten).
  final double layerDrop, layerAmp;

  /// Anzahl der schwebenden Lichtpartikel.
  final int motes;

  /// Helligkeit der Lichtstrahlen (1 = normal).
  final double shaftStrength;

  /// Mögliche Schlechtwetter dieser Welt und Zuschlag auf die Chance dafür.
  final List<WeatherType> weatherPool;
  final double badWeatherBonus;
}

const Map<Biome, BiomeDef> biomeDefs = {
  // Goldene Stunde: warmes Gegenlicht, Pollen und Glühwürmchen
  Biome.fields: BiomeDef(
    name: 'Felder',
    sky: [Color(0xFF1B2748), Color(0xFF4B5588), Color(0xFFE39A6E), Color(0xFFFFD9A0)],
    light: Color(0xFFFFE2A6),
    lightX: 0.72,
    lightY: 215,
    lightSize: 62,
    shafts: true,
    shaftStrength: 0.55,
    layers: [Color(0xFF9C86A6), Color(0xFF675C88), Color(0xFF34365C), Color(0xFF15162D)],
    fog: Color(0xFFF6C99C),
    ground: Color(0xFF0B0D1C),
    rim: Color(0xFFFFD27A),
    glow: Color(0xFFFFE6A0),
    style: LayerStyle.hills,
    layerAmp: 0.7,
    motes: 34,
    weatherPool: [WeatherType.wind, WeatherType.rain],
  ),
  // Dämmerung über verlassenen Ruinen, glimmende Laternen
  Biome.village: BiomeDef(
    name: 'Dorf',
    sky: [Color(0xFF111431), Color(0xFF3A2C5E), Color(0xFFB0587A), Color(0xFFF29C7C)],
    light: Color(0xFFFFB892),
    lightX: 0.3,
    lightY: 300,
    lightSize: 56,
    layers: [Color(0xFF8C6E98), Color(0xFF5A4778), Color(0xFF2E2552), Color(0xFF130E27)],
    fog: Color(0xFFE48C98),
    ground: Color(0xFF0A0717),
    rim: Color(0xFFFFA86B),
    glow: Color(0xFFFFB86B),
    style: LayerStyle.ruins,
    motes: 30,
    weatherPool: [WeatherType.rain],
  ),
  // Nachtblauer Wald mit leuchtenden Pflanzen und Mondstrahlen
  Biome.forest: BiomeDef(
    name: 'Wald mit Fluss',
    sky: [Color(0xFF030A1C), Color(0xFF0A2544), Color(0xFF1A5470), Color(0xFF3FA3B5)],
    light: Color(0xFFBFF6FF),
    lightX: 0.62,
    lightY: 150,
    lightSize: 46,
    moon: true,
    shafts: true,
    layers: [Color(0xFF2E7088), Color(0xFF1B4A64), Color(0xFF0E2B41), Color(0xFF05101D)],
    fog: Color(0xFF5CC6D6),
    ground: Color(0xFF020912),
    rim: Color(0xFF7FF3FF),
    glow: Color(0xFF8CFAFF),
    style: LayerStyle.forest,
    layerAmp: 0.8,
    river: true,
    motes: 70,
    weatherPool: [WeatherType.rain],
    badWeatherBonus: 0.15,
  ),
  // Blaue Stunde, Nebel zwischen spitzen Gipfeln
  Biome.mountains: BiomeDef(
    name: 'Gebirge',
    sky: [Color(0xFF0A1028), Color(0xFF28325F), Color(0xFF6E76A8), Color(0xFFCBC8E2)],
    light: Color(0xFFEAF0FF),
    lightX: 0.78,
    lightY: 170,
    lightSize: 40,
    moon: true,
    shafts: true,
    layers: [Color(0xFFA9ADD0), Color(0xFF7276A0), Color(0xFF3E426C), Color(0xFF151834)],
    fog: Color(0xFFD6DAF2),
    ground: Color(0xFF0B0D1D),
    rim: Color(0xFFCADAFF),
    glow: Color(0xFFE2EAFF),
    style: LayerStyle.peaks,
    layerAmp: 1.7,
    snow: true,
    motes: 35,
    shaftStrength: 0.45,
    weatherPool: [WeatherType.wind],
    badWeatherBonus: 0.25,
  ),
  // Nacht über den Wolken: Polarlicht, Sterne, verschneiter Grat
  Biome.summit: BiomeDef(
    name: 'Gipfel',
    sky: [Color(0xFF02040E), Color(0xFF091431), Color(0xFF1A2A5A), Color(0xFF3C4C84)],
    light: Color(0xFFF2F6FF),
    lightX: 0.2,
    lightY: 120,
    lightSize: 34,
    moon: true,
    stars: true,
    aurora: true,
    layers: [Color(0xFF6474AC), Color(0xFF3E4A7E), Color(0xFF20284E), Color(0xFF0A0D20)],
    fog: Color(0xFF8FA6E0),
    ground: Color(0xFF0A0E22),
    rim: Color(0xFFE8F4FF),
    glow: Color(0xFFBFF8E6),
    style: LayerStyle.peaks,
    layerAmp: 1.4,
    layerDrop: 80,
    snow: true,
    motes: 50,
    weatherPool: [WeatherType.wind],
    badWeatherBonus: 0.4,
  ),
};

/// Welle 1–4 Felder, 5–8 Dorf, 9–12 Wald mit Fluss, 13–14 Gebirge, 15 Gipfel.
Biome biomeForWave(int wave) {
  if (wave >= 15) return Biome.summit;
  if (wave >= 13) return Biome.mountains;
  if (wave >= 9) return Biome.forest;
  if (wave >= 5) return Biome.village;
  return Biome.fields;
}

// ---------------- Wetter ----------------

/// Wetterarten. Umgesetzt sind bisher Klar, Wind und Regen;
/// Nebel, Gewitter, Hitze und Schnee folgen laut GDD.
enum WeatherType {
  clear('Klar'),
  wind('Wind'),
  rain('Regen');

  const WeatherType(this.label);
  final String label;
}

/// Alle Wetterwerte an einer Stelle.
class WeatherConfig {
  WeatherConfig._();

  // Wind
  /// Seitlicher Drift in Welteinheiten pro Sekunde.
  static const double windStrength = 80;
  static const double windSwitchMin = 8;
  static const double windSwitchMax = 12;

  /// Dauer eines kompletten Richtungswechsels (+80 → −80) in Sekunden.
  static const double windTurnTime = 1.5;

  /// Böen: ±15 % Schwankung um den Grundwind.
  static const double windGust = 0.15;
  static const double windGustSpeed = 1.7;

  /// Windanfälligkeit nach Gegnerklasse (1 = voller Drift).
  static const double windFactorLight = 1.0; // Krähe
  static const double windFactorMedium = 0.8; // Spucker
  static const double windFactorGround = 0.5; // Käfer
  static const double windFactorHeavy = 0.35; // Brocken
  static const double windFactorBoss = 0.2; // Geierkönig

  // Regen
  static const double rainThrustFactor = 0.9; // Schub −10 %
  static const double rainGlideFallFactor = 1.3; // Gleiten +30 % Fall
  static const double rainDropFallFactor = 1.5; // Material sinkt schneller

  // Häufigkeit
  static const double badWeatherBase = 0.20; // Stufe 1 (Küken)
  static const double badWeatherPerLevel = 0.15; // +15 % pro Stufe
  static const List<WeatherType> defaultPool = [
    WeatherType.wind,
    WeatherType.rain,
  ];
}
