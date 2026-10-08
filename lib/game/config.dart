import 'dart:math';
import 'dart:ui';

import 'package:flutter/foundation.dart' show ValueNotifier;

/// Virtuelle Höhe der Spielwelt. Die Breite ergibt sich aus dem Seitenverhältnis.
const double kVH = 540;
const double kGround = 468;
const double kCeil = 24;
const int kMaxWave = 15;

/// Breite der Arena in der Bosswelle und im Menü-Hintergrund.
const double kArenaW = 2400;

/// Grundtempo des Spielers (ohne Tempo-Bonus).
const double kPlayerSpeed = 230;

/// Sinkflug (nach unten halten): zusätzliche Beschleunigung nach unten und Höchsttempo.
const double kDiveAccel = 900, kDiveSpeed = 380;

/// Spinnennetz: Tempo und Schub des Spielers, solange er drin hängt.
const double kWebSlow = 0.55, kWebThrust = 0.75;

/// Freier Flug (Kolibri): senkrechtes Höchsttempo (× Schub %) und Beschleunigung.
const double kFreeFlightSpeed = 260, kFreeFlightAccel = 1500;

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

/// Schlussphase einer Timer-Welle (s Restzeit): Timer warnt ab [kWaveWarnTime], großer
/// Countdown ab [kWaveCountdown], keine neuen Gegner mehr ab [kWaveSpawnStop].
const double kWaveWarnTime = 10, kWaveCountdown = 5, kWaveSpawnStop = 3;

/// So lange nach dem Öffnen eines Menüs wird Controller-A ignoriert, damit
/// ein Tippen zum Fliegen nicht versehentlich etwas auswählt (Millisekunden).
const int kMenuConfirmGraceMs = 500;

bool isBossWave(int wave) => wave == kMaxWave;

// ---------------- Shop-Preise ----------------

/// Preisfaktor je Welle: 1 + lin·(w−1) + quad·(w−1)². Der quadratische Anteil
/// hält mit dem späten Einkommen mit (mehr und längere Wellen, größere Gruppen).
const double kWeaponPriceLin = 0.1, kWeaponPriceQuad = 0.009;

/// Waffen-Grundpreise × diesem Faktor (Waffen sollen erschwinglicher sein als Items).
const double kWeaponPriceScale = 0.85;
const double kItemPriceLin = 0.15, kItemPriceQuad = 0.015;

/// Neu würfeln: ⌊2 + lin·w + quad·w²⌋, jeder weitere Wurf in derselben Shopphase +2.
const double kRerollLin = 0.8, kRerollQuad = 0.04;

/// Material-Kristalle: Wert und Farbe. Größere Ausbeute fällt als wenige wertvolle Kristalle.
const kMaterialValues = [10, 5, 3, 1];

Color materialColor(int value) => switch (value) {
      >= 10 => const Color(0xFFFFC94A), // Gold
      >= 5 => const Color(0xFFC07BFF), // Violett
      >= 3 => const Color(0xFF6CC8FF), // Blau
      _ => Palette.mint,
    };

/// Zerlegt [total] Material in möglichst wenige Kristalle (z. B. 9 → 5 + 3 + 1).
List<int> splitMaterial(int total) {
  final out = <int>[];
  var left = total;
  for (final v in kMaterialValues) {
    while (left >= v) {
      out.add(v);
      left -= v;
    }
  }
  return out;
}

/// Startgeld jedes Runs, damit schon nach Welle 1 ein Kauf drin ist.
const int kStartMoney = 15;

/// Frühe Wellen (bis [kEarlySpawnWaves]): je Gegnergruppe [kEarlySpawnBonus] Gegner mehr.
const int kEarlySpawnWaves = 4, kEarlySpawnBonus = 1;

// Weniger, aber zähere Gegner: Spawn-Takt und Gruppengröße wachsen langsamer, dafür
// steigen HP und Material je Gegner mit der Zähigkeit – Einkommen und XP bleiben ähnlich.

/// Spawn-Intervall (s) vor Zufall und Schwierigkeit: max(Min; Basis − Schritt · Welle).
const double kSpawnIntervalBase = 3.0, kSpawnIntervalStep = 0.1, kSpawnIntervalMin = 1.6;
double spawnInterval(int wave) => max(kSpawnIntervalMin, kSpawnIntervalBase - kSpawnIntervalStep * wave);

/// Gruppengröße: 1 + ⌊Welle / [kGroupWaveStep]⌋, mit [kGroupExtraChance] einer mehr.
const double kGroupWaveStep = 5, kGroupExtraChance = 0.4;

/// Höchstens so viele lebende Gegner, darüber keine neuen Spawns.
const int kMaxAliveEnemies = 40;

/// Zähigkeit regulärer Gegner (nicht Boss, Torwächter, Spawner-Kinder): HP und Material × k(w).
const double kToughnessPerWave = 0.25;
double enemyToughness(int wave) => 1 + kToughnessPerWave * (wave - 1);

/// Material-Faktor regulärer Gegner je Welle (1–14; die Bosswelle nutzt den letzten Wert).
/// Abgeleitet aus dem Einkommen pro Welle: Wellen 1–6 wie vor „wenige, aber zähe Gegner“,
/// danach gleichmäßig weniger bis 80 % in Welle 14 (spät gab es zu viel Geld). Der Faktor
/// springt, weil die Gruppengröße in Stufen wächst; das Einkommen pro Welle steigt gleichmäßig.
const kMaterialByWave = [1.3, 1.35, 1.95, 1.45, 2.05, 2.15, 2.25, 3.0, 3.15, 2.95, 2.7, 2.5, 2.65, 2.45];
double enemyMaterialFactor(int wave) => kMaterialByWave[(wave - 1).clamp(0, kMaterialByWave.length - 1)];

/// Zusätzlicher Schaden regulärer Gegner je Welle (wenige Gegner sollen trotzdem wehtun).
const double kEnemyDmgPerWave = 0.04;
double enemyDmgBonus(int wave) => 1 + kEnemyDmgPerWave * (wave - 1);

/// Glück je Punkt: Seltenheit im Shop (Selten/Episch/Legendär), seltene Level-up-Option,
/// Herzen und Geschenke (relativ).
const double kLuckRare = 0.005, kLuckEpic = 0.003, kLuckLegendary = 0.001;
const double kLuckLevelRare = 0.01, kLuckDrops = 0.02;

/// Chance auf ein Herz beim Tod eines Gegners (vor Glück).
const double kHeartChance = 0.04;

/// Ausweichen: höchstens so viel Prozent der Treffer.
const double kDodgeMax = 60;

/// Shop: Chance, dass ein Angebot eine Waffe ist – früh hoch, später mehr Items.
const double kWeaponOfferStart = 0.8, kWeaponOfferStep = 0.04, kWeaponOfferMin = 0.55;
double weaponOfferChance(int wave) => max(kWeaponOfferMin, kWeaponOfferStart - kWeaponOfferStep * (wave - 1));

/// Shop: Anzahl normaler Angebote (dazu kommt immer ein Aktions-Angebot), Mindestzahl Waffen bis Welle 3.
const int kShopOffers = 4, kEarlyMinWeapons = 2, kEarlyWaves = 3;

/// Aktions-Angebot: Gewicht für Aktionen, die zur Stufe II führen oder in ein Rezept passen.
const double kActionMatchWeight = 3;

double weaponPriceFactor(int wave) => 1 + kWeaponPriceLin * (wave - 1) + kWeaponPriceQuad * (wave - 1) * (wave - 1);
double itemPriceFactor(int wave) => 1 + kItemPriceLin * (wave - 1) + kItemPriceQuad * (wave - 1) * (wave - 1);
int rerollBaseCost(int wave) => (2 + kRerollLin * wave + kRerollQuad * wave * wave).floor();

/// Bezugsgröße der Menüs und des HUD (logische Pixel).
const double kUiRefW = 1280, kUiRefH = 720, kUiMaxScale = 2.2;

/// Wählbare UI-Skalierung (Einstellungen → Skalierung); 1 = Standard.
/// Größer geht nicht: Der Standard füllt den Bildschirm bereits aus.
const List<double> kUiScaleOptions = [0.5, 0.6, 0.7, 0.8, 0.9, 1.0];

/// Gewählte UI-Skalierung (gespeichert in den Einstellungen).
final uiScaleSetting = ValueNotifier<double>(1.0);

/// Menüs und HUD wachsen auf großen Bildschirmen mit (z. B. PC im Vollbild);
/// auf kleineren Bildschirmen bleibt alles in Originalgröße. Die Einstellung
/// Skalierung verkleinert das Ergebnis.
double uiScaleFor(double w, double h) =>
    clampD(min(w / kUiRefW, h / kUiRefH), 1, kUiMaxScale) * uiScaleSetting.value;

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

enum Stat { maxHp, regen, dmg, atk, range, speed, armor, lifesteal, crit, luck, dodge, actionSpeed, pickup, thrust, glide }

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
        Stat.luck => 'Glück',
        Stat.dodge => 'Ausweichen',
        Stat.actionSpeed => 'Aktionstempo',
        Stat.pickup => 'Sammelradius',
        Stat.thrust => 'Schub',
        Stat.glide => 'Gleiten',
      };

  String get unit => switch (this) {
        Stat.dmg ||
        Stat.atk ||
        Stat.speed ||
        Stat.lifesteal ||
        Stat.crit ||
        Stat.dodge ||
        Stat.actionSpeed ||
        Stat.thrust ||
        Stat.glide =>
          '%',
        _ => '',
      };
}

// ---------------- Waffenklassen ----------------

/// Sechs Waffenklassen; mehrere Waffen einer Klasse geben Set-Boni (ab 2 / 4 / 6).
// ---------------- Verschmelzen: Gaben und Eigenschaften ----------------

/// Gabe, die eine Waffe weitergibt, wenn sie mit einer anderen Waffe verschmolzen wird
/// (die Spenderwaffe verschwindet). Der Empfänger zählt zusätzlich zur Klasse des Spenders.
class WeaponGift {
  const WeaponGift(
    this.name,
    this.desc, {
    this.dmgMul = 1,
    this.atkMul = 1,
    this.critBonus = 0,
    this.rangeAdd = 0,
    this.knockAdd = 0,
    this.burnTime = 0,
    this.slow = 0,
    this.slowTime = 0,
    this.stunChance = 0,
    this.stunTime = 0,
    this.trapChance = 0,
    this.trapTime = 0,
    this.curse = 0,
    this.stick = 0,
    this.lifesteal = 0,
    this.blastChance = 0,
    this.blastRadius = 0,
    this.blastMul = 0,
  });
  final String name, desc;
  final double dmgMul, atkMul, critBonus, rangeAdd, knockAdd, burnTime, slow, slowTime;
  final double stunChance, stunTime, trapChance, trapTime, curse, stick, lifesteal;

  /// Chance je Treffer auf eine kleine Explosion (Radius, Anteil des Treffers).
  final double blastChance, blastRadius, blastMul;
}

/// Gabe jeder Waffe (Schlüssel: Waffen-ID).
const weaponGifts = <String, WeaponGift>{
  'pistol': WeaponGift('Präzision', '+10 % Krit-Chance', critBonus: 10),
  'rail': WeaponGift('Fernlicht', '+80 Reichweite', rangeAdd: 80),
  'disco': WeaponGift('Blendung', '10 % Chance zu betäuben (0,5 s)', stunChance: 0.1, stunTime: 0.5),
  'rocket': WeaponGift('Zündfunke', 'jeder Treffer explodiert klein (Radius 30, 35 %)',
      blastChance: 1, blastRadius: 30, blastMul: 0.35),
  'shotgun': WeaponGift('Funkenflug', 'setzt 2 s in Brand', burnTime: 2),
  'popcorn': WeaponGift('Plopp', '20 % Chance auf eine Explosion (Radius 50, 80 %)',
      blastChance: 0.2, blastRadius: 50, blastMul: 0.8),
  'smg': WeaponGift('Rückenwind', '+15 % Angriffstempo', atkMul: 1.15),
  'feather': WeaponGift('Wirbel', '+25 Rückstoß', knockAdd: 25),
  'dandelion': WeaponGift('Flugsamen', 'Treffer kleben 2 s', stick: 2),
  'vine': WeaponGift('Dornen', '+10 % Lebensraub', lifesteal: 10),
  'crowcall': WeaponGift('Krähenfluch', 'verflucht 2 s', curse: 2),
  'lantern': WeaponGift('Pakt', '+20 % Schaden', dmgMul: 1.2),
  'water': WeaponGift('Spritzer', 'verlangsamt um 30 % für 1 s', slow: 0.3, slowTime: 1),
  'bubbles': WeaponGift('Blase', '8 % Chance einzufangen (1,5 s)', trapChance: 0.08, trapTime: 1.5),
  'raincloud': WeaponGift('Nieselregen', 'verlangsamt um 20 % für 2 s', slow: 0.2, slowTime: 2),
  'pebble': WeaponGift('Wucht', '+12 % Schaden, +25 Rückstoß', dmgMul: 1.12, knockAdd: 25),
  'gnome': WeaponGift('Zwergenmütze', '15 % Chance zu betäuben (0,8 s)', stunChance: 0.15, stunTime: 0.8),
  'bowling': WeaponGift('Strike', '+10 % Schaden, +40 Rückstoß', dmgMul: 1.1, knockAdd: 40),
};

/// Höchstens so viele Gaben trägt eine Waffe der Stufe [tier] (0 = I).
int maxGifts(int tier) => tier + 1;

/// Eigenschaft, die beim Verschmelzen zweier gleicher Waffen gewählt wird (1 aus 3).
enum WeaponTrait {
  sharp('Geschliffen', '+20 % Schaden'),
  quick('Flink', '+20 % Angriffstempo'),
  reach('Weitblick', '+60 Reichweite'),
  keen('Scharfsinn', '+10 % Krit-Chance'),
  multi('Mehrfach', '+1 Projektil'),
  pierce('Durchschlag', 'durchschlägt 2 Gegner mehr'),
  blast('Wucht', '+40 % Explosionsradius'),
  arc('Weiter Bogen', 'Hieb +0,5 rad breiter'),
  wide('Breite Wolke', 'Wolke 40 % breiter');

  const WeaponTrait(this.label, this.desc);
  final String label, desc;

  /// Beschreibung passend zur Waffe (z. B. „+1 Klinge“ beim Federwirbel).
  String descFor(WeaponDef d) => this == multi
      ? switch (d.kind) {
          WeaponKind.orbit => '+1 Klinge',
          WeaponKind.summon => '+1 Begleiter',
          WeaponKind.disco => '+2 Strahlen',
          _ => desc,
        }
      : desc;

  /// Passt die Eigenschaft zu dieser Waffe?
  bool appliesTo(WeaponDef d) => switch (this) {
        sharp || quick || keen => true,
        reach => d.kind != WeaponKind.summon,
        multi => d.kind == WeaponKind.shot ||
            d.kind == WeaponKind.lob ||
            d.kind == WeaponKind.disco ||
            d.kind == WeaponKind.orbit ||
            d.kind == WeaponKind.summon,
        pierce => d.kind == WeaponKind.shot && d.pierce < 50 && d.explosion == 0,
        blast => d.explosion > 0,
        arc => d.kind == WeaponKind.whip,
        wide => d.kind == WeaponKind.cloud,
      };
}

const double kTraitDmg = 0.2, kTraitAtk = 0.2, kTraitRange = 60, kTraitCrit = 10;
const int kTraitPierce = 2;
const double kTraitBlast = 0.4, kTraitArc = 0.5, kTraitWide = 0.4;

// ---------------- Automatische Aktionen ----------------

/// Aktionen lösen selbst aus, sobald sie bereit sind und es sich lohnt (Q/E bzw. X/Y lösen
/// sofort aus). Schwellen: Gefahr (Abstand einer Kugel bzw. eines Gegners zum Vogel),
/// Gegner in der Nähe, Gegner im Bild, wenig HP, herumliegendes Material.
const double kAutoThreat = 60, kAutoShieldThreat = 70, kAutoLowHp = 0.35;
const double kAutoPullRadius = 260, kAutoEggRadius = 260;
const int kAutoNearCount = 2, kAutoViewCount = 5, kAutoPullCount = 3, kAutoMaterial = 12;

/// Glutbombe und Platzregen: Radius der Explosion, Gegner in einer Gruppe bzw. im Bild.
const double kFireBombRadius = 110, kQuakeRadius = 220;
const int kAutoClusterCount = 3, kAutoRainCount = 4;

/// Ankündigung: so lange lädt eine automatisch ausgelöste Aktion sichtbar auf, danach
/// bleibt ihr Name noch so lange eingeblendet.
const double kActionWindup = 0.6, kActionShoutTime = 1.0;

/// Die Seifenblase schützt vor Treffern – ihre Ankündigung muss kurz sein.
const double kShieldWindup = 0.15;

/// Spätestens so lange nach dem Bereitwerden lösen Kampf-Aktionen aus, sobald irgendein
/// Gegner im Bild ist (damit nichts ungenutzt herumliegt).
const double kAutoFallback = 6;

// ---------------- Chaos ----------------

/// Verrückte Zustände des Spielers (aus den Wolken des Wirrlings). Jeder ist kurz, gut
/// sichtbar angezeigt und danach [kChaosImmunity] s lang nicht erneut möglich.
enum ChaosEffect {
  confused('Verwirrt', 'links und rechts vertauscht', 3, Color(0xFFC77DFF)),
  upsideDown('Kopfüber', 'Schwerkraft umgekehrt', 2.5, Color(0xFF6CE0FF)),
  mirror('Spiegelwelt', 'das Bild ist gespiegelt', 4, Color(0xFFFFE08A)),
  sticky('Verklebt', 'halber Schub, schnelleres Sinken', 3, Color(0xFFFFB347));

  const ChaosEffect(this.label, this.desc, this.duration, this.color);
  final String label, desc;
  final double duration;
  final Color color;
}

const double kChaosImmunity = 6;

/// Verklebte Flügel: Schub- und Sinkfaktor.
const double kStickyThrust = 0.5, kStickyFall = 1.7;

/// Chaos-Wolke des Wirrlings: Radius, Dauer; Ausstoß alle 3,5–4,5 s nach 0,6 s Warnung.
const double kChaosCloudRadius = 55, kChaosCloudTime = 3.5, kWirrlingWarn = 0.6;

/// Items: Wirrkraut, Hühnerzauber, Gummiflügel.
const double kConfuseChance = 0.08, kConfuseTime = 3, kConfuseHitMul = 2;
const double kChickenChance = 0.05, kChickenTime = 3, kChickenVuln = 0.5;
const double kRubberRadius = 90, kRubberCd = 1, kRubberMinSpeed = 150;

// ---------------- Elementar-Reaktionen ----------------

/// Nässe durch Wasser-Treffer (s); bei Regen × [kWetRainMul].
const double kWetTime = 3, kWetRainMul = 2;

/// Eine Reaktion je Gegner höchstens alle [kReactionCd] s; Einblendung je Typ höchstens alle [kReactionTextCd] s.
const double kReactionCd = 0.8, kReactionTextCd = 0.5;

const double kSteamRadius = 60, kSteamMul = 2;
const double kFrostTime = 1.2, kFrostVuln = 0.25, kShatterMul = 3;
const double kFirestormRadius = 70;
const double kHellfireRadius = 120, kHellfireCurse = 2;
const int kHellfireTargets = 2;
const double kBanishMul = 0.6, kBanishRange = 400;
const int kBanishTargets = 2;
const double kRainbowMul = 0.4, kRainbowRadius = 200;
const int kRainbowShards = 3;

/// Reaktionen, wenn ein Treffer auf einen Gegner mit passendem Zustand trifft
/// (Höllenfeuer: beim Tod). Belohnt Waffen verschiedener Klassen.
enum Reaction {
  steam('Dampfstoß', 'DAMPF!', WeaponClass.ember, WeaponClass.water, Color(0xFFE8F4FF),
      'Nasser Gegner + Glut-Treffer oder brennender Gegner + Wasser-Treffer: Explosion (Radius 60, doppelter Trefferschaden); löscht Brand und Nässe.',
      short: 'Explosion, löscht Brand und Nässe'),
  frost('Frost', 'FROST!', WeaponClass.water, WeaponClass.wind, Color(0xFFBFE8FF),
      'Nasser Gegner + Wind-Treffer: eingefroren für 1,2 s (Boss 30 %), nimmt dabei 25 % mehr Schaden.',
      short: 'friert 1,2 s ein (nasse Gegner)'),
  shatter('Zerschmettern', 'ZERSCHMETTERT!', WeaponClass.stone, WeaponClass.water, Color(0xFF9FE6FF),
      'Eingefrorener Gegner + Stein-Treffer: dreifacher Schaden, der Frost zerspringt.',
      short: 'eingefrorene Gegner: Treffer × 3'),
  firestorm('Feuersturm', 'FEUERSTURM!', WeaponClass.ember, WeaponClass.wind, Color(0xFFFF8A3D),
      'Brennender Gegner + Wind-Treffer: Der Brand springt auf alle Gegner im Umkreis 70 über.',
      short: 'Brand springt auf Nachbarn über'),
  hellfire('Höllenfeuer', 'HÖLLENFEUER!', WeaponClass.dark, WeaponClass.ember, Color(0xFFFF4AB4),
      'Verfluchter Gegner stirbt brennend: Brand und Fluch springen auf die 2 nächsten Gegner (Umkreis 120).',
      short: 'verflucht und brennend gestorben: Brand und Fluch springen über'),
  banish('Bannstrahl', 'BANNSTRAHL!', WeaponClass.light, WeaponClass.dark, Color(0xFFE6B8FF),
      'Verfluchter Gegner + Licht-Treffer: Ein Lichtstrahl springt auf bis zu 2 weitere verfluchte Gegner (je 60 % Schaden).',
      short: 'Lichtbogen auf weitere verfluchte Gegner'),
  rainbow('Regenbogen', 'REGENBOGEN!', WeaponClass.light, WeaponClass.water, Color(0xFFFFF0A0),
      'Nasser Gegner + Licht-Treffer: Das Licht bricht sich in 3 Splitter auf Gegner in der Nähe (je 40 % Schaden); verbraucht die Nässe.',
      short: '3 Lichtsplitter auf nasse Gegner');

  const Reaction(this.label, this.shout, this.a, this.b, this.color, this.desc, {required this.short});
  final String label, shout, desc;

  /// Kurzfassung für Waffen-Info-Panels.
  final String short;
  final WeaponClass a, b;
  final Color color;
}

enum WeaponClass {
  light('Licht', Color(0xFFFFE6A0)),
  ember('Glut', Color(0xFFFF8A3D)),
  wind('Wind', Color(0xFFBFF8E6)),
  dark('Böse', Color(0xFFB44CFF)),
  water('Wasser', Color(0xFF6CC8FF)),
  stone('Stein', Color(0xFFC9B8A0));

  const WeaponClass(this.label, this.color);
  final String label;
  final Color color;

  /// Set-Bonus je Stufe (2 / 4 / 6 Waffen), als lesbarer Text.
  List<String> get bonusTexts => switch (this) {
        light => const ['+5 % Krit', '+10 % Krit', '+20 % Krit'],
        ember => const ['Brand/Explosion +15 %', 'Brand/Explosion +30 %', 'Brand/Explosion +50 %'],
        wind => const ['+8 % Angriffstempo', '+16 % Angriffstempo', '+30 % Angriffstempo'],
        dark => const ['+2 % Lebensraub, Fluch +15 %', '+4 % Lebensraub, Fluch +30 %', '+8 % Lebensraub, Fluch +50 %'],
        water => const ['Verlangsamung +20 %, +1 Regen.', 'Verlangsamung +40 %, +2 Regen.', 'Verlangsamung +70 %, +4 Regen.'],
        stone => const ['+2 Rüstung, schwere Waffen +10 %', '+4 Rüstung, schwere Waffen +20 %', '+8 Rüstung, schwere Waffen +35 %'],
      };
}

/// Set-Bonus-Stufe (0–3) bei [count] Waffen einer Klasse.
int setLevel(int count) => count >= 6 ? 3 : (count >= 4 ? 2 : (count >= 2 ? 1 : 0));

/// Werte der Set-Boni je Stufe (Index 0 = keine).
const kSetCrit = [0.0, 5, 10, 20];
const kSetEmber = [0.0, 0.15, 0.3, 0.5]; // Brandschaden und Explosionsradius
const kSetAtk = [0.0, 8, 16, 30];
const kSetLifesteal = [0.0, 2, 4, 8];

/// Lebensraub heilt höchstens 1 HP je so viele Sekunden (sonst heilen schnelle Waffen fast dauerhaft).
const double kLifestealInterval = 0.5;
const kSetCurse = [0.0, 0.15, 0.3, 0.5]; // Zusatzschaden auf verfluchte Gegner
const kSetSlow = [0.0, 0.2, 0.4, 0.7]; // stärkere/längere Verlangsamung
const kSetRegen = [0.0, 1, 2, 4];
const kSetArmor = [0.0, 2, 4, 8];
const kSetHeavy = [0.0, 0.1, 0.2, 0.35]; // Schaden für Waffen mit Abklingzeit ≥ 1 s

/// Verfluchte Gegner nehmen grundsätzlich so viel mehr Schaden (plus Set-Bonus „Böse“).
const double kCurseBase = 0.25;

/// Brand: Schaden pro Sekunde = Waffenschaden × dieser Faktor.
const double kBurnDpsFactor = 0.45;

// ---------------- Waffen ----------------

/// Verhalten einer Waffe.
enum WeaponKind {
  shot, // Projektil(e) aufs Ziel
  lob, // im Bogen geworfen (Schwerkraft), mit Zünder bzw. beim Aufprall
  orbit, // Klingen kreisen um den Vogel
  whip, // Hieb im Bogen, trifft sofort alles in Reichweite
  summon, // ruft selbstständige Begleiter
  cloud, // Wolke über dem Ziel, regnet Schaden
  roll, // rollt über den Boden
  disco, // schießt rundherum, zielt nicht
}

class WeaponDef {
  const WeaponDef({
    required this.id,
    required this.name,
    required this.icon,
    required this.desc,
    required this.cls,
    required this.dmg,
    required this.cooldown,
    required this.range,
    required this.speed,
    required this.price,
    required this.color,
    required this.radius,
    required this.length,
    this.kind = WeaponKind.shot,
    this.count = 1,
    this.spread = 0,
    this.pierce = 0,
    this.explosion = 0,
    this.burn = 0,
    this.slow = 0,
    this.slowTime = 0,
    this.stun = 0,
    this.trap = 0,
    this.curse = 0,
    this.knock = 5,
    this.stick = 0,
    this.fuse = 0,
    this.hpCost = 0,
    this.lifesteal = 0,
  });

  final String id, name, icon, desc;
  final WeaponClass cls;
  final WeaponKind kind;
  final double dmg, cooldown, range, speed, spread, radius, length, explosion;
  final int count, pierce, price;
  final Color color;

  /// Brand (s), Verlangsamung (Anteil) und Dauer (s), Betäubung (s), Einfangen (s), Fluch (s).
  final double burn, slow, slowTime, stun, trap, curse;

  /// Rückstoß, Kleben (s Schaden über Zeit), Zünder (s), HP-Kosten je Schuss, Lebensraub-Chance (%).
  final double knock, stick, fuse, lifesteal;
  final int hpCost;

  /// Schwere Waffe (Set-Bonus Stein).
  bool get heavy => cooldown >= 1;
}

const Map<String, WeaponDef> weaponDefs = {
  // ---- Licht
  'pistol': WeaponDef(
      id: 'pistol', name: 'Lichtfeder', icon: '🪶', desc: 'Zuverlässiger Lichtschuss.', cls: WeaponClass.light,
      dmg: 8, cooldown: 0.75, range: 330, speed: 720, spread: 0.04, price: 15,
      color: Color(0xFFFFF3B0), radius: 4, length: 12),
  'rail': WeaponDef(
      id: 'rail', name: 'Sonnenstrahl', icon: '☀️', desc: 'Langsamer Strahl, durchschlägt alles.', cls: WeaponClass.light,
      dmg: 22, cooldown: 1.7, range: 470, speed: 1500, pierce: 99, price: 28,
      color: Color(0xFFFFF0B8), radius: 4, length: 20),
  'disco': WeaponDef(
      id: 'disco', name: 'Diskokugel', icon: '🪩', desc: 'Strahlen in alle Richtungen – zielt nie, trifft trotzdem.',
      cls: WeaponClass.light, kind: WeaponKind.disco,
      dmg: 5, cooldown: 0.9, range: 300, speed: 680, count: 6, price: 24,
      color: Color(0xFFF2D6FF), radius: 3.5, length: 10),
  // ---- Glut
  'rocket': WeaponDef(
      id: 'rocket', name: 'Glutkern', icon: '☄️', desc: 'Explodiert und trifft alles im Umkreis.', cls: WeaponClass.ember,
      dmg: 15, cooldown: 1.6, range: 390, speed: 420, spread: 0.05, explosion: 75, price: 30,
      color: Color(0xFFFF9F1C), radius: 6, length: 18),
  'shotgun': WeaponDef(
      id: 'shotgun', name: 'Funkenfächer', icon: '🎇', desc: 'Fünf Funken im Fächer, setzen in Brand.', cls: WeaponClass.ember,
      dmg: 5, cooldown: 1.15, range: 210, speed: 640, count: 5, spread: 0.6, burn: 2, price: 20,
      color: Color(0xFFFFB37A), radius: 3.5, length: 17),
  'popcorn': WeaponDef(
      id: 'popcorn', name: 'Popcornmaschine', icon: '🍿', desc: 'Maiskörner ploppen nach 1 s laut auf und explodieren.',
      cls: WeaponClass.ember, kind: WeaponKind.lob,
      dmg: 9, cooldown: 1.0, range: 320, speed: 380, count: 2, spread: 0.35, explosion: 50, fuse: 1.0, price: 24,
      color: Color(0xFFFFF4C2), radius: 4.5, length: 12),
  // ---- Wind
  'smg': WeaponDef(
      id: 'smg', name: 'Böenschwarm', icon: '🌬️', desc: 'Sehr schnell, wenig Schaden.', cls: WeaponClass.wind,
      dmg: 3, cooldown: 0.18, range: 270, speed: 760, spread: 0.22, price: 18,
      color: Color(0xFFD9FFF2), radius: 3, length: 15),
  'feather': WeaponDef(
      id: 'feather', name: 'Federwirbel', icon: '🌀', desc: 'Federklingen kreisen um dich (Nahkampf).',
      cls: WeaponClass.wind, kind: WeaponKind.orbit,
      dmg: 6, cooldown: 0.4, range: 58, speed: 4.2, count: 3, price: 22,
      color: Color(0xFFCFFFF0), radius: 9, length: 14),
  'dandelion': WeaponDef(
      id: 'dandelion', name: 'Pusteblume', icon: '🌼', desc: 'Schirmchen schweben davon und kleben an Gegnern.',
      cls: WeaponClass.wind,
      dmg: 2, cooldown: 0.6, range: 260, speed: 150, count: 3, spread: 0.5, stick: 3, knock: 0, price: 20,
      color: Color(0xFFFFFFF2), radius: 4, length: 10),
  // ---- Böse
  'vine': WeaponDef(
      id: 'vine', name: 'Dornenranke', icon: '🥀', desc: 'Peitschenhieb im Bogen, stiehlt Leben (Nahkampf).',
      cls: WeaponClass.dark, kind: WeaponKind.whip,
      dmg: 12, cooldown: 0.9, range: 125, speed: 0, spread: 1.7, lifesteal: 15, curse: 2, knock: 18, price: 22,
      color: Color(0xFFD08CFF), radius: 4, length: 14),
  'crowcall': WeaponDef(
      id: 'crowcall', name: 'Krähenruf', icon: '🐦‍⬛', desc: 'Ruft Geisterkrähen, die selbst Gegner jagen.',
      cls: WeaponClass.dark, kind: WeaponKind.summon,
      dmg: 6, cooldown: 2.5, range: 420, speed: 260, count: 3, curse: 2, price: 26,
      color: Color(0xFFC07BFF), radius: 8, length: 12),
  'lantern': WeaponDef(
      id: 'lantern', name: 'Paktlaterne', icon: '🏮', desc: 'Sehr stark – kostet aber 1 HP pro Schuss.', cls: WeaponClass.dark,
      dmg: 26, cooldown: 1.0, range: 360, speed: 900, hpCost: 1, curse: 3, price: 26,
      color: Color(0xFFFF6AD5), radius: 5, length: 14),
  // ---- Wasser
  'water': WeaponDef(
      id: 'water', name: 'Wasserpistole', icon: '🔫', desc: 'Strahl, der verlangsamt und zurückschiebt.', cls: WeaponClass.water,
      dmg: 2, cooldown: 0.12, range: 230, speed: 650, spread: 0.06, slow: 0.35, slowTime: 1.2, knock: 7, price: 16,
      color: Color(0xFFA8E6FF), radius: 3, length: 14),
  'bubbles': WeaponDef(
      id: 'bubbles', name: 'Seifenblasen', icon: '🫧', desc: 'Fangen Gegner ein – sie treiben hilflos nach oben.',
      cls: WeaponClass.water,
      dmg: 3, cooldown: 1.4, range: 300, speed: 220, count: 2, spread: 0.3, trap: 1.8, knock: 0, price: 22,
      color: Color(0xFFE6F8FF), radius: 7, length: 10),
  'raincloud': WeaponDef(
      id: 'raincloud', name: 'Regenwolke', icon: '🌧️', desc: 'Setzt sich über Gegner und regnet verlangsamenden Schaden.',
      cls: WeaponClass.water, kind: WeaponKind.cloud,
      dmg: 3, cooldown: 3.0, range: 380, speed: 0, slow: 0.4, slowTime: 0.6, price: 26,
      color: Color(0xFF9FD4FF), radius: 46, length: 12),
  // ---- Stein
  'pebble': WeaponDef(
      id: 'pebble', name: 'Kieselschleuder', icon: '🪨', desc: 'Schwere Kiesel mit starkem Rückstoß.', cls: WeaponClass.stone,
      dmg: 11, cooldown: 1.0, range: 320, speed: 620, knock: 40, price: 18,
      color: Color(0xFFD8C8B0), radius: 5, length: 13),
  'gnome': WeaponDef(
      id: 'gnome', name: 'Gartenzwergwerfer', icon: '🧙', desc: 'Gartenzwerge zerplatzen beim Aufprall und betäuben kurz.',
      cls: WeaponClass.stone, kind: WeaponKind.lob,
      dmg: 14, cooldown: 1.5, range: 340, speed: 430, explosion: 45, stun: 1.0, price: 26,
      color: Color(0xFFFF7A6B), radius: 6, length: 14),
  'bowling': WeaponDef(
      id: 'bowling', name: 'Bowlingkugel', icon: '🎳', desc: 'Rollt über den Boden und durchschlägt alles.',
      cls: WeaponClass.stone, kind: WeaponKind.roll,
      dmg: 20, cooldown: 2.2, range: 620, speed: 430, pierce: 99, knock: 25, price: 28,
      color: Color(0xFF8F86B8), radius: 9, length: 12),
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

// ---------------- Aktionen (Aktionstaste) ----------------

enum ActionId {
  fireBomb('Glutbombe', 12, '💣', 'Große Explosion auf der dichtesten Gegnergruppe (Radius 110), setzt alle in Brand.',
      cls: WeaponClass.ember),
  downpour('Platzregen', 14, '🌧️', 'Wolkenbruch über dem ganzen Bild: alle Gegner 4 s nass und 30 % langsamer.',
      cls: WeaponClass.water),
  whirlwind('Wirbelsturm', 14, '🌪️', 'Ein Tornado zieht 4 s durchs Bild, saugt Gegner und Material ein und schadet ihnen.',
      cls: WeaponClass.wind),
  flash('Lichtblitz', 12, '⚡', 'Blendet alle Gegner im Bild 1,5 s.', cls: WeaponClass.light),
  screech('Fluchschrei', 10, '🦅', 'Alle Gegner im Bild sind 5 s verflucht und weichen kurz zurück.', cls: WeaponClass.dark),
  quake('Felsbeben', 9, '🪨', 'Schockwelle am Boden: Bodengegner betäubt, Flieger werden zu Boden geschleudert.',
      cls: WeaponClass.stone),
  bubbleShield('Seifenblase', 14, '🫧', 'Blase schluckt 1,5 s lang jeden Treffer.'),
  egg('Ei legen', 2.5, '🥚', 'Ei rollt zum nächsten Gegner und explodiert.'),
  // ---- Evolutionen (aus zwei Aktionen verschmolzen)
  glacier('Gletscher', 18, '🧊', 'Alles im Bild friert 2 s ein – Gegner und Gegnerkugeln.', evolved: true),
  hellmaw('Höllenschlund', 16, '🌋', 'Riesige Glutbombe, danach sind alle Gegner im Bild verflucht – Brand und Fluch springen weiter.',
      evolved: true),
  thunderstorm('Gewittersturm', 18, '⛈️', 'Ein Tornado zieht durchs Bild und schleudert Blitze in Gegner.', evolved: true);

  const ActionId(this.label, this.cooldown, this.icon, this.desc, {this.evolved = false, this.cls});
  final String label, icon, desc;

  /// Klasse der Kraft: ihre Treffer lösen Reaktionen wie Waffen dieser Klasse aus.
  final WeaponClass? cls;

  /// Abklingzeit in Sekunden (Stufe I).
  final double cooldown;

  /// Entsteht nur durch Verschmelzen zweier Aktionen.
  final bool evolved;
}

/// Aktionen in Stufe II: kürzere Abklingzeit, stärkere bzw. längere Wirkung.
const double kActionLv2Cooldown = 0.7, kActionLv2Power = 1.5;

/// Höchstzahl gleichzeitiger Aktionen (Aktionstaste 1 und 2).
const int kActionSlots = 2;

/// Rezept: [a] und [b] (Reihenfolge egal) verschmelzen zu [result].
class ActionRecipe {
  const ActionRecipe(this.a, this.b, this.result);
  final ActionId a, b, result;
  bool matches(ActionId x, ActionId y) => (x == a && y == b) || (x == b && y == a);
}

const actionRecipes = [
  ActionRecipe(ActionId.downpour, ActionId.whirlwind, ActionId.glacier),
  ActionRecipe(ActionId.fireBomb, ActionId.screech, ActionId.hellmaw),
  ActionRecipe(ActionId.whirlwind, ActionId.flash, ActionId.thunderstorm),
];

ActionRecipe? recipeFor(ActionId x, ActionId y) {
  for (final r in actionRecipes) {
    if (r.matches(x, y)) return r;
  }
  return null;
}

/// Rezepte, in denen [x] vorkommt.
Iterable<ActionRecipe> recipesWith(ActionId x) => actionRecipes.where((r) => r.a == x || r.b == x);

// ---------------- Items ----------------

enum Rarity {
  common('Gewöhnlich', Color(0xFFCFCFD6)),
  rare('Selten', Color(0xFF4FB3FF)),
  epic('Episch', Color(0xFFB36BFF)),
  legendary('Legendär', Color(0xFFFF5D73));

  const Rarity(this.label, this.color);
  final String label;
  final Color color;
}

/// Besondere Wirkungen von Items (über Werte hinaus).
enum ItemEffect {
  none,
  windVane, // Wind schiebt nur in Flugrichtung
  raincoat, // keine Regen-Nachteile
  duck, // 10 % der Treffer ignorieren
  interest, // 10 % Zinsen am Wellenende
  freeReroll, // erstes Neu würfeln je Shop gratis
  burningGlass, // Licht-Krits setzen in Brand
  wateringCan, // bei Regen +20 % Schaden statt Nachteile
  pebbles, // +1 Rüstung je Stein-Waffe
  mirror, // doppelte Projektile, −30 % Schaden
  thorns, // Berührungsschaden zurück
  stardust, // Krits lösen kleine Explosionen aus
  lightShield, // blockt alle 8 s einen Treffer
  compass, // doppelter Zeitbonus am Ziel
  greed, // 15 % doppelte Drops
  phoenix, // einmal pro Run Wiederbeleben mit 30 % HP
  confuseHerb, // Treffer verwirren Gegner manchmal (sie greifen sich gegenseitig an)
  chickenSpell, // Treffer verwandeln Gegner manchmal kurz in ein Huhn
  rubberWings, // gegen die Decke: abprallen und Schockwelle
  action, // setzt die Aktion [ItemDef.action]
}

class ItemDef {
  const ItemDef(this.id, this.name, this.icon, this.price, this.mods,
      {this.rarity = Rarity.common, this.effect = ItemEffect.none, this.desc = '', this.action, this.unique = false});
  final String id, name, icon, desc;
  final int price;
  final Map<Stat, double> mods;
  final Rarity rarity;
  final ItemEffect effect;
  final ActionId? action;

  /// Nur einmal kaufbar (Wirkung stapelt nicht).
  final bool unique;
}

const itemDefs = [
  // ---- Werte-Items
  ItemDef('helm', 'Blechhelm', '⛑️', 14, {Stat.armor: 2}),
  ItemDef('apfel', 'Riesenapfel', '🍎', 12, {Stat.maxHp: 5}),
  ItemDef('pflaster', 'Pflasterrolle', '🩹', 15, {Stat.regen: 2}),
  ItemDef('fernglas', 'Fernglas', '🔭', 16, {Stat.range: 60}),
  ItemDef('feder', 'Goldfeder', '🪶', 14, {Stat.speed: 12}),
  ItemDef('magnet', 'Magnet', '🧲', 10, {Stat.pickup: 70}),
  ItemDef('hantel', 'Hantel', '🏋️', 18, {Stat.dmg: 12, Stat.speed: -3}, rarity: Rarity.rare),
  ItemDef('kaffee', 'Doppelter Espresso', '☕', 18, {Stat.atk: 15}, rarity: Rarity.rare),
  ItemDef('zahn', 'Vampirzahn', '🦷', 22, {Stat.lifesteal: 3}, rarity: Rarity.rare),
  ItemDef('klee', 'Kleeblatt', '🍀', 16, {Stat.luck: 8, Stat.crit: 3}, rarity: Rarity.rare),
  ItemDef('hufeisen', 'Hufeisen', '🐴', 18, {Stat.luck: 12}, rarity: Rarity.rare),
  ItemDef('muenze', 'Glücksmünze', '🪙', 26, {Stat.luck: 22, Stat.dmg: -5}, rarity: Rarity.epic),
  ItemDef('glas', 'Glaskanone', '🔮', 25, {Stat.dmg: 30, Stat.maxHp: -6}, rarity: Rarity.rare),
  ItemDef('panzer', 'Schildkrötenpanzer', '🐢', 20, {Stat.armor: 5, Stat.speed: -8}, rarity: Rarity.rare),
  ItemDef('dose', 'Energiedose', '🥤', 22, {Stat.atk: 25, Stat.armor: -2}, rarity: Rarity.rare),
  ItemDef('wurm', 'Fetter Wurm', '🪱', 20, {Stat.maxHp: 8, Stat.regen: 1}, rarity: Rarity.rare),
  // ---- Flug-Items
  ItemDef('knochen', 'Leichte Knochen', '🦴', 16, {Stat.thrust: 15}, rarity: Rarity.rare),
  ItemDef('segelfeder', 'Segelfeder', '🪁', 16, {Stat.glide: 30}, rarity: Rarity.rare),
  ItemDef('windfahne', 'Windfahne', '🚩', 22, {}, rarity: Rarity.epic, effect: ItemEffect.windVane,
      desc: 'Wind schiebt nur in deine Flugrichtung', unique: true),
  ItemDef('regenmantel', 'Regenmantel', '🧥', 18, {}, rarity: Rarity.rare, effect: ItemEffect.raincoat,
      desc: 'Keine Regen-Nachteile', unique: true),
  // ---- Spezial-Items
  ItemDef('wirrkraut', 'Wirrkraut', '🌿', 22, {}, rarity: Rarity.rare, effect: ItemEffect.confuseHerb,
      desc: '8 % der Treffer verwirren Gegner 3 s – sie greifen andere Gegner an', unique: true),
  ItemDef('huehnerzauber', 'Hühnerzauber', '🐔', 26, {}, rarity: Rarity.epic, effect: ItemEffect.chickenSpell,
      desc: '5 % der Treffer verwandeln Gegner 3 s in ein harmloses Huhn (+50 % Schaden)', unique: true),
  ItemDef('gummifluegel', 'Gummiflügel', '🪀', 20, {}, rarity: Rarity.rare, effect: ItemEffect.rubberWings,
      desc: 'Prallst du gegen die Decke, federst du zurück und löst eine Schockwelle aus', unique: true),
  ItemDef('gummiente', 'Gummiente', '🦆', 26, {Stat.armor: 2}, rarity: Rarity.epic, effect: ItemEffect.duck,
      desc: '10 % der Treffer werden ignoriert – quietsch!', unique: true),
  ItemDef('socke', 'Socke mit Loch', '🧦', 18, {Stat.speed: 20, Stat.armor: -2}, rarity: Rarity.rare),
  ItemDef('sparschwein', 'Sparschwein', '🐷', 28, {}, rarity: Rarity.epic, effect: ItemEffect.interest,
      desc: 'Am Wellenende 10 % Zinsen (höchstens 25)', unique: true),
  ItemDef('glueckskeks', 'Glückskeks', '🥠', 16, {}, rarity: Rarity.rare, effect: ItemEffect.freeReroll,
      desc: 'Erstes Neu würfeln je Shop gratis', unique: true),
  ItemDef('brennglas', 'Brennglas', '🔍', 26, {}, rarity: Rarity.epic, effect: ItemEffect.burningGlass,
      desc: 'Krits von Licht-Waffen setzen in Brand', unique: true),
  ItemDef('giesskanne', 'Gießkanne', '🪣', 18, {}, rarity: Rarity.rare, effect: ItemEffect.wateringCan,
      desc: 'Bei Regen +20 % Schaden statt Nachteile', unique: true),
  ItemDef('kiesel', 'Kieselsammlung', '🫙', 18, {}, rarity: Rarity.rare, effect: ItemEffect.pebbles,
      desc: '+1 Rüstung je Stein-Waffe', unique: true),
  ItemDef('spiegel', 'Spiegelscherbe', '🪞', 40, {}, rarity: Rarity.legendary, effect: ItemEffect.mirror,
      desc: 'Jedes Projektil doppelt, dafür −30 % Schaden', unique: true),
  ItemDef('dornenkleid', 'Dornenkleid', '🌵', 26, {Stat.armor: 1}, rarity: Rarity.epic, effect: ItemEffect.thorns,
      desc: 'Berührungsschaden geht ×3 zurück an den Gegner', unique: true),
  ItemDef('sternenstaub', 'Sternenstaub', '✨', 30, {Stat.crit: 3}, rarity: Rarity.epic, effect: ItemEffect.stardust,
      desc: 'Krits lösen kleine Explosionen aus', unique: true),
  ItemDef('lichtschild', 'Lichtschild', '🛡️', 30, {}, rarity: Rarity.epic, effect: ItemEffect.lightShield,
      desc: 'Blockt alle 8 s einen Treffer', unique: true),
  ItemDef('kompass', 'Rückenwind-Kompass', '🧭', 18, {}, rarity: Rarity.rare, effect: ItemEffect.compass,
      desc: 'Doppelter Zeitbonus am Ziel', unique: true),
  ItemDef('goldgier', 'Goldgier', '💰', 22, {Stat.maxHp: -5}, rarity: Rarity.rare, effect: ItemEffect.greed,
      desc: '15 % Chance auf doppelte Drops', unique: true),
  ItemDef('phoenix', 'Phönixasche', '🔥', 45, {}, rarity: Rarity.legendary, effect: ItemEffect.phoenix,
      desc: 'Einmal pro Run: bei 0 HP mit 30 % HP weiter', unique: true),
  // ---- Aktions-Items (ersetzen die aktuelle Aktion)
  ItemDef('a_firebomb', 'Glutbombe', '💣', 24, {}, rarity: Rarity.epic, effect: ItemEffect.action,
      action: ActionId.fireBomb, desc: 'Explosion auf der dichtesten Gegnergruppe, setzt in Brand', unique: true),
  ItemDef('a_downpour', 'Platzregen', '🌧️', 24, {}, rarity: Rarity.epic, effect: ItemEffect.action,
      action: ActionId.downpour, desc: 'Alle Gegner im Bild 4 s nass und langsamer', unique: true),
  ItemDef('a_whirlwind', 'Wirbelsturm', '🌪️', 26, {}, rarity: Rarity.epic, effect: ItemEffect.action,
      action: ActionId.whirlwind, desc: 'Tornado saugt Gegner und Material ein', unique: true),
  ItemDef('a_flash', 'Lichtblitz', '⚡', 22, {}, rarity: Rarity.epic, effect: ItemEffect.action,
      action: ActionId.flash, desc: 'Blendet alle Gegner im Bild für 1,5 s', unique: true),
  ItemDef('a_screech', 'Fluchschrei', '🦅', 22, {}, rarity: Rarity.epic, effect: ItemEffect.action,
      action: ActionId.screech, desc: 'Alle Gegner im Bild 5 s verflucht', unique: true),
  ItemDef('a_quake', 'Felsbeben', '🪨', 20, {}, rarity: Rarity.rare, effect: ItemEffect.action,
      action: ActionId.quake, desc: 'Schockwelle: Bodengegner betäubt, Flieger zu Boden', unique: true),
  ItemDef('a_shield', 'Seifenblase', '🫧', 20, {}, rarity: Rarity.rare, effect: ItemEffect.action,
      action: ActionId.bubbleShield, desc: 'Blase schluckt 1,5 s lang jeden Treffer', unique: true),
];

final Map<String, ItemDef> itemById = {for (final i in itemDefs) i.id: i};

// ---------------- Charaktere ----------------

/// Aussehen-Variante des Geistvogels.
enum BirdLook { sparrow, robin, swallow, hummingbird, raven, penguin, woodpecker, owl, magpie, hen, ostrich, eagle }

/// Freischalt-Aufgabe eines Charakters.
enum UnlockKind { start, burnKills, reachWave, winAny, totalKills, classWave, runLevel, totalMaterial, winWith, waveWith }

class UnlockDef {
  const UnlockDef(this.kind, this.text, {this.amount = 0, this.cls, this.wave = 0, this.character, this.difficulty = 1});
  final UnlockKind kind;
  final String text;
  final int amount, wave, difficulty;
  final WeaponClass? cls;
  final String? character;
}

/// Spielbarer Vogel: Werte, Besonderheiten, Flugverhalten, Aussehen, Start und Freischalten.
class CharacterDef {
  const CharacterDef({
    required this.id,
    required this.name,
    required this.species,
    required this.icon,
    required this.role,
    required this.strength,
    required this.weakness,
    required this.flight,
    required this.look,
    required this.glow,
    required this.body,
    required this.belly,
    required this.unlock,
    this.startWeapons = const [],
    this.startAction,
    this.mods = const {},
    this.classBonus,
    this.burnBonus = false,
    this.heartMul = 1,
    this.xpMul = 1,
    this.materialChance = 0,
    this.shopMul = 1,
    this.giftChance = 0,
    this.maxWeapons = 6,
    this.nightBonus = 0,
    this.dayMalus = 0,
    this.maxHpMul = 1,
    this.speedMul = 1,
    this.accelMul = 1,
    this.thrustMul = 1,
    this.glideMul = 1,
    this.groundMul = 1,
    this.stamina = 0,
    this.wallCling = false,
    this.freeFlight = false,
    this.minDropFall = 0,
    this.critMul = 2,
    this.radius = 16,
    this.scale = 1,
  });

  final String id, name, species, icon, role, strength, weakness, flight;
  final BirdLook look;
  final Color glow, body, belly;
  final UnlockDef unlock;
  /// Wählbare Startwaffen (die erste ist voreingestellt); leer = ohne Waffe (Henriette).
  final List<String> startWeapons;
  String? get startWeapon => startWeapons.isEmpty ? null : startWeapons.first;
  final ActionId? startAction;

  /// Werte-Änderungen zu Beginn eines Runs.
  final Map<Stat, double> mods;

  /// +25 % Schaden für Waffen dieser Klasse.
  final WeaponClass? classBonus;

  /// Glutkehlchen: Brand hält 50 % länger und schadet 25 % mehr.
  final bool burnBonus;
  final double heartMul, xpMul, materialChance, shopMul, giftChance;
  final int maxWeapons;

  /// Schaden in Nacht-Welten (Wald, Gebirge, Gipfel) bzw. Malus am Tag (Felder, Dorf).
  final double nightBonus, dayMalus;
  final double maxHpMul;

  /// Flugprofil: Höchsttempo, Beschleunigung, Schub, Sinkgeschwindigkeit beim Gleiten, Tempo am Boden.
  final double speedMul, accelMul, thrustMul, glideMul, groundMul;

  /// > 0: Schub nur so viele Sekunden am Stück, lädt am Boden auf (Huhn).
  final double stamina;

  /// Hält sich am Weltrand fest, statt abzurutschen (Specht).
  final bool wallCling;

  /// Schadensfaktor kritischer Treffer (Adler: 2,5).
  final double critMul;

  /// Material fällt mindestens so schnell zu Boden (Frack kommt kaum hoch, schwebendes Material wäre unerreichbar).
  final double minDropFall;

  /// Freier Flug ohne Schwerkraft: hoch und runter per Stick bzw. Tasten, bleibt beim Loslassen stehen (Kolibri).
  final bool freeFlight;
  final double radius, scale;
}

const characterDefs = [
  CharacterDef(
    id: 'spatz', name: 'Kampfspatz', species: 'Spatz', icon: '🐦', role: 'Allround',
    strength: '+10 % Material', weakness: 'keine Spezialität', flight: 'normal – das Maß aller Dinge',
    look: BirdLook.sparrow, glow: Color(0xFFFFC86E), body: Color(0xFFFFD23F), belly: Color(0xFFFFF3C4),
    startWeapons: ['pistol', 'smg', 'shotgun'], materialChance: 0.1,
    unlock: UnlockDef(UnlockKind.start, 'Von Anfang an verfügbar'),
  ),
  CharacterDef(
    id: 'glutkehlchen', name: 'Glutkehlchen', species: 'Rotkehlchen', icon: '🐦', role: 'Glut',
    strength: 'Brand hält länger, +25 % Brandschaden', weakness: '−30 Reichweite', flight: 'normal, mit Funkenspur',
    look: BirdLook.robin, glow: Color(0xFFFF7A3D), body: Color(0xFFB0643A), belly: Color(0xFFFF6A3D),
    startWeapons: ['shotgun', 'rocket', 'popcorn'], burnBonus: true, mods: {Stat.range: -30},
    unlock: UnlockDef(UnlockKind.burnKills, '500 Gegner durch Brand besiegen', amount: 500),
  ),
  CharacterDef(
    id: 'boee', name: 'Böe', species: 'Schwalbe', icon: '🐦', role: 'Wind',
    strength: '+20 % Angriffstempo, schnellster Flieger', weakness: '−5 Max-HP', flight: 'sehr schnell, enge Kurven',
    look: BirdLook.swallow, glow: Color(0xFFBFF8E6), body: Color(0xFF3D5A9E), belly: Color(0xFFF2F2E8),
    startWeapons: ['smg', 'feather', 'dandelion'], mods: {Stat.atk: 20, Stat.maxHp: -5}, speedMul: 1.3, accelMul: 1.5,
    unlock: UnlockDef(UnlockKind.reachWave, 'Welle 8 erreichen', wave: 8),
  ),
  CharacterDef(
    id: 'schillerchen', name: 'Schillerchen', species: 'Kolibri', icon: '🐦', role: 'Licht',
    strength: '+15 % Krit, winzige Trefferfläche', weakness: '−40 % Max-HP', flight: 'fliegt frei in alle Richtungen, steht in der Luft',
    look: BirdLook.hummingbird, glow: Color(0xFF8CFFC8), body: Color(0xFF3FD6A0), belly: Color(0xFFE6FFF4),
    startWeapons: ['disco', 'pistol', 'rail'], mods: {Stat.crit: 15}, maxHpMul: 0.6, freeFlight: true, radius: 11, scale: 0.75,
    unlock: UnlockDef(UnlockKind.winAny, 'Einen Run gewinnen'),
  ),
  CharacterDef(
    id: 'russ', name: 'Ruß', species: 'Rabe', icon: '🐦‍⬛', role: 'Böse',
    strength: 'Böse-Waffen +25 %, +3 % Lebensraub', weakness: 'Herzen heilen nur halb', flight: 'schwer, gleitet lange',
    look: BirdLook.raven, glow: Color(0xFFB44CFF), body: Color(0xFF2A2140), belly: Color(0xFF4A3A66),
    startWeapons: ['vine', 'crowcall', 'lantern'], classBonus: WeaponClass.dark, mods: {Stat.lifesteal: 3}, heartMul: 0.5,
    glideMul: 0.6, accelMul: 0.8,
    unlock: UnlockDef(UnlockKind.totalKills, '2000 Gegner besiegen', amount: 2000),
  ),
  CharacterDef(
    id: 'frack', name: 'Frack', species: 'Pinguin', icon: '🐧', role: 'Wasser',
    strength: '+50 % Max-HP, +3 Rüstung; Material fällt immer zu Boden', weakness: 'kann kaum fliegen', flight: 'mühsam in der Luft, am Boden rasend schnell',
    look: BirdLook.penguin, glow: Color(0xFF9FE4FF), body: Color(0xFF26304A), belly: Color(0xFFF4FAFF),
    startWeapons: ['water', 'bubbles', 'raincloud'], startAction: ActionId.downpour, mods: {Stat.armor: 3}, maxHpMul: 1.5,
    thrustMul: 0.62, glideMul: 1.4, groundMul: 1.7, minDropFall: 70, scale: 1.1, radius: 17,
    unlock: UnlockDef(UnlockKind.classWave, 'Welle 10 mit mindestens 3 Wasser-Waffen erreichen',
        cls: WeaponClass.water, amount: 3, wave: 10),
  ),
  CharacterDef(
    id: 'hacki', name: 'Hacki', species: 'Specht', icon: '🐦', role: 'Stein',
    strength: 'Stein-Waffen +25 %, +3 Rüstung', weakness: '−15 % Angriffstempo', flight: 'ruckartig, klammert sich an den Weltrand',
    look: BirdLook.woodpecker, glow: Color(0xFFFFB37A), body: Color(0xFF3A3A3A), belly: Color(0xFFF2EEE6),
    startWeapons: ['pebble', 'gnome', 'bowling'], startAction: ActionId.quake, classBonus: WeaponClass.stone,
    mods: {Stat.armor: 3, Stat.atk: -15}, accelMul: 1.3, wallCling: true,
    unlock: UnlockDef(UnlockKind.classWave, 'Welle 10 mit mindestens 3 Stein-Waffen erreichen',
        cls: WeaponClass.stone, amount: 3, wave: 10),
  ),
  CharacterDef(
    id: 'uhu', name: 'Professor Uhu', species: 'Eule', icon: '🦉', role: 'Licht/Böse',
    strength: '+25 % Erfahrung, nachts +20 % Schaden', weakness: 'tagsüber −10 % Schaden', flight: 'lautlos, sinkt sehr langsam',
    look: BirdLook.owl, glow: Color(0xFFE6D6FF), body: Color(0xFF8A6A4A), belly: Color(0xFFE8D8C0),
    startWeapons: ['pistol', 'rail', 'crowcall'], startAction: ActionId.flash, xpMul: 1.25, nightBonus: 0.2, dayMalus: 0.1, glideMul: 0.35,
    scale: 1.1, radius: 17,
    unlock: UnlockDef(UnlockKind.runLevel, 'In einem Run Level 15 erreichen', amount: 15),
  ),
  CharacterDef(
    id: 'glitzer', name: 'Glitzer', species: 'Elster', icon: '🐦', role: 'Wirtschaft',
    strength: 'Shop −15 %, manchmal Geschenk beim Kill', weakness: 'nur 4 Waffenslots', flight: 'normal',
    look: BirdLook.magpie, glow: Color(0xFF9FD4FF), body: Color(0xFF20242E), belly: Color(0xFFF6F6F6),
    startWeapons: ['water', 'disco', 'pebble'], startAction: ActionId.whirlwind, shopMul: 0.85, giftChance: 0.01, maxWeapons: 4,
    unlock: UnlockDef(UnlockKind.totalMaterial, '3000 Material sammeln', amount: 3000),
  ),
  CharacterDef(
    id: 'henriette', name: 'Henriette', species: 'Huhn', icon: '🐔', role: 'Glut/Stein',
    strength: 'sehr zäh (+40 % Max-HP, +2 Rüstung), Eier als Bomben', weakness: 'keine Startwaffe, fliegt nur kurze Hüpfer',
    flight: 'flattert in Hüpfern, viel Bodenzeit',
    look: BirdLook.hen, glow: Color(0xFFFFE08A), body: Color(0xFFF6EEDC), belly: Color(0xFFFFFFFF),
    startAction: ActionId.egg, mods: {Stat.armor: 2}, maxHpMul: 1.4, stamina: 0.55, groundMul: 1.1, scale: 1.1, radius: 17,
    unlock: UnlockDef(UnlockKind.winWith, 'Mit dem Kampfspatz auf Falke gewinnen', character: 'spatz', difficulty: 3),
  ),
  CharacterDef(
    id: 'strauss', name: 'Rudi Rennfeder', species: 'Strauß', icon: '🦤', role: 'Boden/Stein',
    strength: 'schnellster Läufer (+100 % am Boden), +60 % Max-HP, +2 Rüstung; Material fällt immer zu Boden',
    weakness: 'kann nicht fliegen – nur hohe Sprünge, sinkt schnell', flight: 'rennt und springt, keine Flügel zum Fliegen',
    look: BirdLook.ostrich, glow: Color(0xFFFFC2D6), body: Color(0xFF2A2430), belly: Color(0xFFF4EEF4),
    startWeapons: ['pebble', 'bowling', 'feather'], startAction: ActionId.fireBomb,
    mods: {Stat.armor: 2}, maxHpMul: 1.6, groundMul: 2.0, thrustMul: 1.25, glideMul: 2.6, stamina: 0.4,
    minDropFall: 70, scale: 1.2, radius: 18,
    unlock: UnlockDef(UnlockKind.waveWith, 'Mit Frack Welle 10 erreichen', character: 'frack', wave: 10),
  ),
  CharacterDef(
    id: 'adler', name: 'Seine Hoheit Aurelius', species: 'Steinadler', icon: '🦅', role: 'Licht/Stein',
    strength: '+20 % Schaden, Krits ×2,5 statt ×2, Adleraugen +80 Reichweite',
    weakness: 'groß und leicht zu treffen, träge in Kurven', flight: 'majestätischer Gleiter, sinkt sehr langsam',
    look: BirdLook.eagle, glow: Color(0xFFFFD27A), body: Color(0xFF5A3A22), belly: Color(0xFF8A6A4A),
    startWeapons: ['rail', 'rocket', 'pebble'], startAction: ActionId.screech,
    mods: {Stat.dmg: 20, Stat.range: 80}, critMul: 2.5, speedMul: 1.1, accelMul: 0.7, thrustMul: 1.1, glideMul: 0.4,
    scale: 1.25, radius: 20,
    unlock: UnlockDef(UnlockKind.winWith, 'Auf Stufe Adler gewinnen', difficulty: 4),
  ),
];

final Map<String, CharacterDef> characterById = {for (final c in characterDefs) c.id: c};

/// Nacht-Welten für Professor Uhu.
bool isNightBiome(Biome b) => b == Biome.forest || b == Biome.mountains || b == Biome.summit;

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
  LevelOption(Stat.lifesteal, 1, '🦷'),
  LevelOption(Stat.crit, 4, '✨'),
  LevelOption(Stat.luck, 5, '🍀'),
  LevelOption(Stat.dodge, 3, '💨'),
  LevelOption(Stat.actionSpeed, 8, '⏳'),
];

// ---------------- Gegner ----------------

enum EnemyType {
  crow,
  beetle,
  spitter,
  rock,
  // Welt-Gegner
  puffball,
  scarecrow,
  bat,
  weathercock,
  spider,
  wisp,
  eagle,
  avalanche,
  wirrling,
  // Spawner und ihre Kinder
  crowNest,
  waspNest,
  wasp,
  sporeShroom,
  spore,
  beetleQueen,
  beetleEgg,
  rift,
  // Torwächter am Ende der Welten
  strawKing,
  bell,
  spiderMother,
  boss,
}

class EnemyDef {
  const EnemyDef({
    required this.hp,
    required this.speed,
    required this.dmg,
    required this.radius,
    required this.flying,
    required this.drop,
    this.wind = WeatherConfig.windFactorLight,
    this.stationary = false,
    this.spawner = false,
  });
  final double hp, speed, dmg, radius;
  final bool flying;
  final int drop;

  /// Windanfälligkeit (1 = voller Drift).
  final double wind;

  /// Bewegt sich nicht vom Fleck (Vogelscheuche, Wetterhahn).
  final bool stationary;

  /// Erzeugt weitere Gegner (Nester, Pilz, Königin, Riss); höchstens [kMaxSpawners] gleichzeitig.
  final bool spawner;
}

extension EnemyInfo on EnemyType {
  String get label => switch (this) {
        EnemyType.crow => 'Fäulniskrähe',
        EnemyType.beetle => 'Glutkäfer',
        EnemyType.spitter => 'Spucker',
        EnemyType.rock => 'Brocken',
        EnemyType.puffball => 'Pusteling',
        EnemyType.scarecrow => 'Vogelscheuche',
        EnemyType.bat => 'Fledermaus',
        EnemyType.weathercock => 'Wetterhahn',
        EnemyType.spider => 'Spinne',
        EnemyType.wisp => 'Irrlicht',
        EnemyType.eagle => 'Felsadler',
        EnemyType.avalanche => 'Lawinenkäfer',
        EnemyType.wirrling => 'Wirrling',
        EnemyType.crowNest => 'Krähennest',
        EnemyType.waspNest => 'Wespennest',
        EnemyType.wasp => 'Fäulniswespe',
        EnemyType.sporeShroom => 'Sporenpilz',
        EnemyType.spore => 'Spore',
        EnemyType.beetleQueen => 'Käferkönigin',
        EnemyType.beetleEgg => 'Käferei',
        EnemyType.rift => 'Fäulnisriss',
        EnemyType.strawKing => 'Der Strohkönig',
        EnemyType.bell => 'Die Glocke',
        EnemyType.spiderMother => 'Die Spinnenmutter',
        EnemyType.boss => 'Der Geierkönig',
      };

  String get icon => switch (this) {
        EnemyType.crow => '🐦‍⬛',
        EnemyType.beetle => '🪲',
        EnemyType.spitter => '🦠',
        EnemyType.rock => '🪨',
        EnemyType.puffball => '🎈',
        EnemyType.scarecrow => '🌾',
        EnemyType.bat => '🦇',
        EnemyType.weathercock => '🐓',
        EnemyType.spider => '🕷️',
        EnemyType.wisp => '👻',
        EnemyType.eagle => '🦅',
        EnemyType.avalanche => '🐚',
        EnemyType.wirrling => '🍄',
        EnemyType.crowNest => '🪹',
        EnemyType.waspNest => '🐝',
        EnemyType.wasp => '🐝',
        EnemyType.sporeShroom => '🍄',
        EnemyType.spore => '🟢',
        EnemyType.beetleQueen => '🪲',
        EnemyType.beetleEgg => '🥚',
        EnemyType.rift => '🌀',
        EnemyType.strawKing => '🎃',
        EnemyType.bell => '🔔',
        EnemyType.spiderMother => '🕸️',
        EnemyType.boss => '👑',
      };

  String get desc => switch (this) {
        EnemyType.crow => 'Fliegt direkt auf dich zu. Schwach, aber zahlreich.',
        EnemyType.beetle => 'Krabbelt am Boden entlang – wer tief fliegt, trifft auf ihn.',
        EnemyType.spitter => 'Hält Abstand und spuckt Giftkugeln.',
        EnemyType.rock => 'Langsam und zäh; lässt drei Material fallen.',
        EnemyType.puffball => 'Aufgeblähte Pollenkugel. Platzt in eine Giftwolke – nicht hindurchfliegen.',
        EnemyType.scarecrow => 'Steht im Feld und wirft brennendes Stroh im Bogen.',
        EnemyType.bat => 'Flattert im Zickzack – schwer zu treffen.',
        EnemyType.weathercock => 'Dreht sich auf seiner Stange und schießt dorthin, wohin er gerade zeigt.',
        EnemyType.spider => 'Seilt sich von oben ab; ihre Netze verlangsamen dich.',
        EnemyType.wisp => 'Springt von Ort zu Ort und explodiert in deiner Nähe.',
        EnemyType.eagle => 'Kreist oben und stürzt sich nach kurzer Warnung auf dich.',
        EnemyType.avalanche => 'Rollt sich ein und rast über den Boden.',
        EnemyType.wirrling => 'Schwebender Sporenquall. Stößt Chaos-Wolken aus – wer hineinfliegt, wird verwirrt, steht kopf, sieht alles gespiegelt oder hat verklebte Flügel.',
        EnemyType.crowNest => 'Steht auf einem Pfahl; alle 4 s schlüpft eine Krähe (höchstens drei). Zuerst zerstören!',
        EnemyType.waspNest => 'Hängt an der Decke und tut nichts – bis man es trifft. Dann schwärmt pro Treffer eine Wespe aus.',
        EnemyType.wasp => 'Flink und klein, kommt aus dem Wespennest. Lässt kein Material fallen.',
        EnemyType.sporeShroom => 'Pulsiert am Boden und stößt alle 5 s drei Sporen aus.',
        EnemyType.spore => 'Kleine Spore, treibt langsam auf dich zu. Lässt kein Material fallen.',
        EnemyType.beetleQueen => 'Langsam und groß; legt alle 4 s ein Ei, aus dem ein Lawinenkäfer schlüpft.',
        EnemyType.beetleEgg => 'Schlüpft nach 2,5 s – vorher zerstören!',
        EnemyType.rift => 'Ein Fäulnisriss, der offen bleibt: 12 s lang alle 3 s ein Gegner. Beschießen schließt ihn früher.',
        EnemyType.strawKing =>
          'Torwächter der Felder (Welle 4). Riesige Vogelscheuche: wirft Strohbündel im Fächer und ruft Krähen.',
        EnemyType.bell => 'Torwächter des Dorfs (Welle 8). Schießt Kugelringe; vor dem Glockenschlag rechtzeitig raus aus dem Kreis!',
        EnemyType.spiderMother =>
          'Torwächterin des Waldes (Welle 12). Schießt Netzfächer, ruft Spinnen und lässt sich blitzschnell fallen.',
        EnemyType.boss => 'Herrscher der Fäulnis auf dem Gipfel. Erscheint in Welle 15.',
      };
}

const Map<EnemyType, EnemyDef> enemyDefs = {
  EnemyType.crow: EnemyDef(hp: 6, speed: 95, dmg: 2, radius: 13, flying: true, drop: 1),
  EnemyType.beetle: EnemyDef(
      hp: 12, speed: 75, dmg: 3, radius: 15, flying: false, drop: 1, wind: WeatherConfig.windFactorGround),
  EnemyType.spitter: EnemyDef(
      hp: 9, speed: 70, dmg: 2, radius: 14, flying: true, drop: 1, wind: WeatherConfig.windFactorMedium),
  EnemyType.rock: EnemyDef(
      hp: 45, speed: 42, dmg: 5, radius: 27, flying: true, drop: 3, wind: WeatherConfig.windFactorHeavy),
  // Felder
  EnemyType.puffball: EnemyDef(hp: 10, speed: 35, dmg: 2, radius: 15, flying: true, drop: 1),
  EnemyType.scarecrow: EnemyDef(
      hp: 26, speed: 0, dmg: 3, radius: 18, flying: false, drop: 2, wind: 0, stationary: true),
  // Dorf
  EnemyType.bat: EnemyDef(hp: 7, speed: 150, dmg: 2, radius: 11, flying: true, drop: 1),
  EnemyType.weathercock: EnemyDef(
      hp: 22, speed: 0, dmg: 3, radius: 16, flying: false, drop: 2, wind: 0, stationary: true),
  // Wald
  EnemyType.spider: EnemyDef(
      hp: 16, speed: 60, dmg: 3, radius: 15, flying: true, drop: 1, wind: WeatherConfig.windFactorMedium),
  EnemyType.wisp: EnemyDef(hp: 9, speed: 0, dmg: 5, radius: 12, flying: true, drop: 1, wind: 0),
  // Gebirge
  EnemyType.eagle: EnemyDef(
      hp: 30, speed: 120, dmg: 5, radius: 20, flying: true, drop: 2, wind: WeatherConfig.windFactorMedium),
  EnemyType.wirrling: EnemyDef(hp: 14, speed: 55, dmg: 2, radius: 14, flying: true, drop: 1),
  EnemyType.avalanche: EnemyDef(
      hp: 40, speed: 70, dmg: 6, radius: 18, flying: false, drop: 2, wind: WeatherConfig.windFactorGround),
  // Spawner (geben mehr Material) und ihre Kinder (geben keins)
  EnemyType.crowNest: EnemyDef(
      hp: 30, speed: 0, dmg: 2, radius: 20, flying: false, drop: 3, wind: 0, stationary: true, spawner: true),
  EnemyType.waspNest: EnemyDef(
      hp: 34, speed: 0, dmg: 3, radius: 18, flying: true, drop: 3, wind: 0, stationary: true, spawner: true),
  EnemyType.wasp: EnemyDef(hp: 4, speed: 190, dmg: 1, radius: 8, flying: true, drop: 0),
  EnemyType.sporeShroom: EnemyDef(
      hp: 40, speed: 0, dmg: 3, radius: 20, flying: false, drop: 3, wind: 0, stationary: true, spawner: true),
  EnemyType.spore: EnemyDef(hp: 4, speed: 45, dmg: 2, radius: 8, flying: true, drop: 0),
  EnemyType.beetleQueen: EnemyDef(
      hp: 90, speed: 30, dmg: 6, radius: 26, flying: false, drop: 4, wind: WeatherConfig.windFactorHeavy, spawner: true),
  EnemyType.beetleEgg: EnemyDef(hp: 8, speed: 0, dmg: 0, radius: 9, flying: false, drop: 0, wind: 0, stationary: true),
  EnemyType.rift: EnemyDef(
      hp: 50, speed: 0, dmg: 0, radius: 22, flying: true, drop: 3, wind: 0, stationary: true, spawner: true),
  // Torwächter
  EnemyType.strawKing: EnemyDef(
      hp: 220, speed: 25, dmg: 5, radius: 40, flying: false, drop: 0, wind: 0),
  EnemyType.bell: EnemyDef(hp: 260, speed: 40, dmg: 5, radius: 36, flying: true, drop: 0, wind: 0),
  EnemyType.spiderMother: EnemyDef(hp: 300, speed: 70, dmg: 6, radius: 40, flying: true, drop: 0, wind: 0),
  EnemyType.boss: EnemyDef(
      hp: 4500, speed: 55, dmg: 6, radius: 52, flying: true, drop: 0, wind: WeatherConfig.windFactorBoss),
};

/// Elitegegner: Modifikator mit Farbe und Zeichen über dem Kopf.
enum EliteMod {
  swift('Flink', '»', Color(0xFF7FE8FF), 'bewegt und greift 35 % schneller an'),
  armored('Gepanzert', '◆', Color(0xFFBFC8D8), 'nimmt nur halben Schaden, kein Rückstoß'),
  volatile('Explosiv', '✸', Color(0xFFFF8A3D), 'explodiert kurz nach dem Tod'),
  splitting('Teilend', '✂', Color(0xFFC6FF6A), 'zerfällt beim Tod in zwei kleine Kopien'),
  healer('Heiler', '✚', Color(0xFF8CF5B0), 'heilt Gegner in der Nähe');

  const EliteMod(this.label, this.mark, this.color, this.desc);
  final String label, mark, desc;
  final Color color;
}

/// Elite ab Welle [kEliteStartWave]: Chance je Gegner, HP-Faktor, Größe, Material-Faktor, Geschenk-Chance.
const int kEliteStartWave = 5;
const double kEliteHp = 2.5, kEliteScale = 1.18, kEliteGiftChance = 0.25;
const int kEliteDrops = 3;
const double kEliteChanceMax = 0.25, kEliteChanceBase = 0.06, kEliteChanceStep = 0.015;
double eliteChance(int wave) =>
    wave < kEliteStartWave ? 0 : min(kEliteChanceMax, kEliteChanceBase + kEliteChanceStep * (wave - kEliteStartWave));

/// Kopien eines teilenden Elitegegners: HP-Anteil und Größe.
const double kSplitHp = 0.35, kSplitScale = 0.7;

/// Gegner-Pool einer Welle (Typ, Gewicht). Jede Welt bringt zwei eigene Gegner mit,
/// die früheren bleiben dabei.
List<(EnemyType, double)> spawnPool(int wave) {
  final w = wave.toDouble();
  final biome = biomeForWave(wave);
  final pool = <(EnemyType, double)>[(EnemyType.crow, 10)];
  if (w >= 2) pool.add((EnemyType.beetle, 7));
  if (w >= 3) pool.add((EnemyType.spitter, 4 + w * 0.3));
  if (w >= 5) pool.add((EnemyType.rock, 2 + w * 0.3));
  if (w >= 2) pool.add((EnemyType.puffball, biome == Biome.fields ? 4 : 2));
  if (w >= 3) pool.add((EnemyType.scarecrow, biome == Biome.fields ? 2 : 1));
  if (w >= 5) pool.add((EnemyType.bat, biome == Biome.village ? 6 : 3));
  if (w >= 6) pool.add((EnemyType.weathercock, biome == Biome.village ? 2.5 : 1));
  if (w >= 5) pool.add((EnemyType.wirrling, biome == Biome.village ? 2.5 : 1.5));
  if (w >= 9) pool.add((EnemyType.spider, biome == Biome.forest ? 4 : 2));
  if (w >= 10) pool.add((EnemyType.wisp, biome == Biome.forest ? 3 : 1.5));
  if (w >= 13) pool.add((EnemyType.eagle, 4));
  if (w >= 13) pool.add((EnemyType.avalanche, 3));
  // Spawner: in ihrer Welt häufiger
  if (w >= 3) pool.add((EnemyType.crowNest, biome == Biome.fields ? 1.5 : 0.6));
  if (w >= 6) pool.add((EnemyType.waspNest, biome == Biome.village ? 1.5 : 0.6));
  if (w >= 9) pool.add((EnemyType.sporeShroom, biome == Biome.forest ? 1.5 : 0.6));
  if (w >= 13) pool.add((EnemyType.beetleQueen, 1.5));
  if (w >= 6) pool.add((EnemyType.rift, 1));
  return pool;
}

/// Höchstzahl gleichzeitig lebender Spawner; darüber kommt stattdessen eine Krähe.
const int kMaxSpawners = 3;

/// Torwächter einer Welle (Ende der Felder, des Dorfs, des Waldes), sonst null.
EnemyType? gatekeeperForWave(int wave) => switch (wave) {
      4 => EnemyType.strawKing,
      8 => EnemyType.bell,
      12 => EnemyType.spiderMother,
      _ => null,
    };

/// Torwächter erscheint, sobald der Spieler so nah am Ziel ist; er steht so weit davor.
const double kGateTriggerDist = 1000, kGateOffset = 260;

/// Belohnung für einen Torwächter: Material plus ein Geschenk.
const int kGateDrops = 15;

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
