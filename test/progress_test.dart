import 'package:flutter_test/flutter_test.dart';
import 'package:federfeuer/game/config.dart';
import 'package:federfeuer/game/progress.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  group('Progress', () {
    test('Sieg schaltet genau die nächste Stufe frei', () {
      final p = Progress();
      expect(p.isUnlocked(2), isFalse);
      expect(p.recordRun(difficulty: 1, wave: 7, won: false), isNull);
      expect(p.recordRun(difficulty: 1, wave: kMaxWave, won: true), 2);
      expect(p.isUnlocked(2), isTrue);
      expect(p.isUnlocked(3), isFalse);
      // Erneuter Sieg auf Stufe 1 schaltet nichts weiter frei.
      expect(p.recordRun(difficulty: 1, wave: kMaxWave, won: true), isNull);
    });

    test('Höchste Stufe bleibt bei 5', () {
      final p = Progress()..unlocked = kDifficultyCount;
      expect(p.recordRun(difficulty: kDifficultyCount, wave: kMaxWave, won: true), isNull);
      expect(p.unlocked, kDifficultyCount);
    });

    test('Bestleistung pro Stufe, Sieg = kMaxWave + 1', () {
      final p = Progress();
      p.recordRun(difficulty: 1, wave: 9, won: false);
      p.recordRun(difficulty: 1, wave: 4, won: false);
      expect(p.bestFor(1), 9);
      p.recordRun(difficulty: 1, wave: kMaxWave, won: true);
      expect(p.bestFor(1), kMaxWave + 1);
      expect(p.bestFor(2), 0);
    });

    test('Gesperrte Stufe lässt sich nicht wählen, Debug-Modus öffnet alles', () {
      final p = Progress()..selected = 4;
      expect(p.selected, 1);
      p.debugUnlockAll = true;
      p.selected = 4;
      expect(p.selected, 4);
      p.debugUnlockAll = false;
      expect(p.selected, 1, reason: 'ohne Debug fällt die Wahl auf eine freie Stufe zurück');
    });

    test('Speichern/Laden inkl. alter Bestleistung', () async {
      SharedPreferences.setMockInitialValues({'bestWave': 8});
      final a = Progress();
      await a.load();
      expect(a.bestFor(1), 8);
      a.recordRun(difficulty: 1, wave: kMaxWave, won: true);
      a.selected = 2;
      await a.save();

      final b = Progress();
      await b.load();
      expect(b.unlocked, 2);
      expect(b.selected, 2);
      expect(b.bestFor(1), kMaxWave + 1);
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getInt('bestWave'), isNull);
    });
  });

  test('fmtFactor', () {
    expect(fmtFactor(1.0), '1');
    expect(fmtFactor(1.1), '1,1');
    expect(fmtFactor(1.25), '1,25');
    expect(fmtFactor(10), '10');
  });
}
