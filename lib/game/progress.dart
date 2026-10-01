import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'config.dart';

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

  /// Debug-Modus: alle Stufen wählbar. Wird nicht gespeichert.
  bool debugUnlockAll = false;

  bool isUnlocked(int difficulty) => debugUnlockAll || difficulty <= unlocked;

  int get selected => isUnlocked(_selected) ? _selected : 1;
  set selected(int difficulty) {
    if (isUnlocked(difficulty)) _selected = difficulty;
  }

  int bestFor(int difficulty) => best[difficulty] ?? 0;

  /// Trägt einen beendeten Run ein. Gibt die dabei neu freigeschaltete Stufe
  /// zurück (oder null).
  int? recordRun({required int difficulty, required int wave, required bool won, int kills = 0, int level = 0}) {
    runs++;
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
      await prefs.remove(_legacyBestKey);
    } catch (e) {
      debugPrint('Fortschritt konnte nicht gespeichert werden: $e');
    }
  }
}
