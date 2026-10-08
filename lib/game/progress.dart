import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'config.dart';
import 'run_state.dart';

/// Debug-Werkzeuge (Wetter-Tasten, Debug-Modus im Menü): in Debug-Builds
/// oder mit `--dart-define=FEDERFEUER_DEBUG=true`.
const bool kDebugTools = kDebugMode || bool.fromEnvironment('FEDERFEUER_DEBUG');

/// Dauerhafter Fortschritt über Runs hinweg: freigeschaltete Stufen,
/// Bestleistung pro Stufe und die zuletzt gewählte Stufe.
class Progress {
  static const _unlockedKey = 'unlockedDifficulty';
  static const _selectedKey = 'selectedDifficulty';
  static const _legacyBestKey = 'bestWave';
  static String _bestKey(int difficulty) => 'bestWave_$difficulty';

  /// Höchste regulär freigeschaltete Stufe (1–[kDifficultyCount]).
  int unlocked = 1;
  int _selected = 1;

  /// Bestleistung pro Stufe: erreichte Welle, [kMaxWave] + 1 = gewonnen.
  final Map<int, int> best = {};

  /// Statistik über alle Runs.
  int runs = 0, wins = 0, kills = 0, bestLevel = 0;
  static const _runsKey = 'statRuns', _winsKey = 'statWins', _killsKey = 'statKills', _levelKey = 'statBestLevel';

  /// Über alle Runs: Kills durch Brand, gesammeltes Material.
  int burnKills = 0, material = 0;
  static const _burnKey = 'statBurnKills', _materialKey = 'statMaterial';

  /// Freigeschaltete Vögel (Kampfspatz immer) und der zuletzt gewählte.
  final Set<String> characters = {'spatz'};
  String _character = 'spatz';
  static const _charactersKey = 'unlockedCharacters', _characterKey = 'selectedCharacter';

  /// Kompendium: gesehene Einträge ('w:'/'i:'/'a:'/'e:'/'r:' + ID) und selbst verschmolzene Evolutionen.
  final Set<String> seen = {};
  final Set<String> evolved = {};
  static const _seenKey = 'compendiumSeen', _evolvedKey = 'compendiumEvolved';
  bool _seenDirty = false;

  /// Neue Einträge seit dem letzten Speichern.
  bool get seenDirty => _seenDirty;

  bool hasSeen(String key) => debugUnlockAll || seen.contains(key);
  bool hasEvolved(ActionId a) => debugUnlockAll || evolved.contains(a.name);

  void see(String key) {
    if (seen.add(key)) _seenDirty = true;
  }

  void seeEnemy(EnemyType t) => see('e:${t.name}');

  /// Alles, was ein Run gerade zeigt: Angebote, Inventar, Aktionen samt Rezepten, Evolutionen.
  void noteRun(RunState r) {
    for (final w in r.allWeapons) {
      see('w:${w.id}');
    }
    for (final id in r.items.keys) {
      see('i:$id');
    }
    for (final o in r.offers) {
      see(o.isWeapon ? 'w:${o.id}' : 'i:${o.id}');
      final act = o.isWeapon ? null : itemById[o.id]?.action;
      if (act != null) see('a:${act.name}');
    }
    for (final a in r.actions) {
      see('a:${a.id.name}');
      // Rezepte mit eigenen Aktionen zeigt der Shop – damit gelten sie als gesehen
      for (final rec in recipesWith(a.id)) {
        see('r:${rec.result.name}');
      }
    }
    for (final e in r.evolutions) {
      see('a:${e.name}');
      see('r:${e.name}');
      if (evolved.add(e.name)) _seenDirty = true;
    }
  }

  /// Debug-Modus: alle Stufen und Vögel wählbar. Wird nicht gespeichert.
  bool debugUnlockAll = false;

  bool isUnlocked(int difficulty) => debugUnlockAll || difficulty <= unlocked;

  bool hasCharacter(String id) =>
      debugUnlockAll || characters.contains(id) || characterById[id]?.unlock.kind == UnlockKind.start;

  String get selectedCharacter => hasCharacter(_character) ? _character : 'spatz';

  /// Gewählte Startwaffe je Vogel (sonst die erste seiner Auswahl).
  final Map<String, String> _startWeapons = {};
  static const _startWeaponsKey = 'startWeapons';

  String? startWeaponFor(CharacterDef c) {
    final w = _startWeapons[c.id];
    return w != null && c.startWeapons.contains(w) ? w : c.startWeapon;
  }

  void setStartWeapon(CharacterDef c, String id) {
    if (c.startWeapons.contains(id)) _startWeapons[c.id] = id;
  }
  set selectedCharacter(String id) {
    if (hasCharacter(id) && characterById.containsKey(id)) _character = id;
  }

  /// Fortschritt einer Freischalt-Aufgabe über alle Runs (Zähler-Aufgaben), sonst null.
  (int, int)? unlockProgress(UnlockDef u) => switch (u.kind) {
        UnlockKind.burnKills => (min(burnKills, u.amount), u.amount),
        UnlockKind.totalKills => (min(kills, u.amount), u.amount),
        UnlockKind.totalMaterial => (min(material, u.amount), u.amount),
        UnlockKind.runLevel => (min(bestLevel, u.amount), u.amount),
        _ => null,
      };

  /// Prüft nach einem Run alle Freischalt-Aufgaben. Gibt neu freigeschaltete Vögel zurück.
  List<CharacterDef> checkUnlocks(RunState r, {required bool won}) {
    final fresh = <CharacterDef>[];
    for (final c in characterDefs) {
      if (characters.contains(c.id)) continue;
      final u = c.unlock;
      final ok = switch (u.kind) {
        UnlockKind.start => true,
        UnlockKind.burnKills => burnKills >= u.amount,
        UnlockKind.reachWave => r.wave >= u.wave,
        UnlockKind.winAny => won || wins > 0,
        UnlockKind.totalKills => kills >= u.amount,
        UnlockKind.classWave => r.wave >= u.wave && r.classCount(u.cls!) >= u.amount,
        UnlockKind.runLevel => bestLevel >= u.amount,
        UnlockKind.totalMaterial => material >= u.amount,
        UnlockKind.winWith => won && (u.character == null || r.character.id == u.character) && r.difficulty >= u.difficulty,
        UnlockKind.waveWith => r.character.id == u.character && (won || r.wave >= u.wave),
      };
      if (ok) {
        characters.add(c.id);
        fresh.add(c);
      }
    }
    return fresh;
  }

  int get selected => isUnlocked(_selected) ? _selected : 1;
  set selected(int difficulty) {
    if (isUnlocked(difficulty)) _selected = difficulty;
  }

  int bestFor(int difficulty) => best[difficulty] ?? 0;

  /// Trägt einen beendeten Run ein. Gibt die dabei neu freigeschaltete Stufe
  /// zurück (oder null).
  int? recordRun({
    required int difficulty,
    required int wave,
    required bool won,
    int kills = 0,
    int level = 0,
    String character = 'spatz',
    int burnKills = 0,
    int material = 0,
  }) {
    runs++;
    this.burnKills += burnKills;
    this.material += material;
    if (won) wins++;
    this.kills += kills;
    bestLevel = max(bestLevel, level);
    final reached = won ? kMaxWave + 1 : wave;
    best[difficulty] = max(bestFor(difficulty), reached);
    if (won && difficulty == unlocked && unlocked < kDifficultyCount) {
      unlocked++;
      return unlocked;
    }
    return null;
  }

  Future<void> load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      unlocked = (prefs.getInt(_unlockedKey) ?? 1).clamp(1, kDifficultyCount);
      _selected = (prefs.getInt(_selectedKey) ?? 1).clamp(1, kDifficultyCount);
      for (var d = 1; d <= kDifficultyCount; d++) {
        final v = prefs.getInt(_bestKey(d));
        if (v != null) best[d] = v;
      }
      runs = prefs.getInt(_runsKey) ?? 0;
      wins = prefs.getInt(_winsKey) ?? 0;
      kills = prefs.getInt(_killsKey) ?? 0;
      bestLevel = prefs.getInt(_levelKey) ?? 0;
      burnKills = prefs.getInt(_burnKey) ?? 0;
      material = prefs.getInt(_materialKey) ?? 0;
      characters.addAll(prefs.getStringList(_charactersKey) ?? const []);
      _character = prefs.getString(_characterKey) ?? 'spatz';
      for (final e in prefs.getStringList(_startWeaponsKey) ?? const <String>[]) {
        final i = e.indexOf('=');
        if (i > 0) _startWeapons[e.substring(0, i)] = e.substring(i + 1);
      }
      seen.addAll(prefs.getStringList(_seenKey) ?? const []);
      evolved.addAll(prefs.getStringList(_evolvedKey) ?? const []);
      // Bestleistung aus der Zeit vor den Schwierigkeitsstufen gilt für Stufe 1.
      final legacy = prefs.getInt(_legacyBestKey);
      if (legacy != null) best[1] = max(bestFor(1), legacy);
    } catch (e) {
      debugPrint('Fortschritt konnte nicht geladen werden: $e');
    }
  }

  Future<void> save() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt(_unlockedKey, unlocked);
      await prefs.setInt(_selectedKey, _selected);
      for (final e in best.entries) {
        await prefs.setInt(_bestKey(e.key), e.value);
      }
      await prefs.setInt(_runsKey, runs);
      await prefs.setInt(_winsKey, wins);
      await prefs.setInt(_killsKey, kills);
      await prefs.setInt(_levelKey, bestLevel);
      await prefs.setInt(_burnKey, burnKills);
      await prefs.setInt(_materialKey, material);
      await prefs.setStringList(_charactersKey, characters.toList());
      await prefs.setString(_characterKey, _character);
      await prefs.setStringList(_startWeaponsKey, [for (final e in _startWeapons.entries) '${e.key}=${e.value}']);
      await prefs.setStringList(_seenKey, seen.toList());
      await prefs.setStringList(_evolvedKey, evolved.toList());
      _seenDirty = false;
      await prefs.remove(_legacyBestKey);
    } catch (e) {
      debugPrint('Fortschritt konnte nicht gespeichert werden: $e');
    }
  }
}
