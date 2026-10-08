import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:federfeuer/game/config.dart';
import 'package:federfeuer/game/progress.dart';
import 'package:federfeuer/game/run_state.dart';
import 'package:federfeuer/ui/workbench.dart';

import 'helpers/fonts.dart';

/// Werkbank im Kompendium: Kombinationen zusammenstellen und Reaktionen finden.
void main() {
  setUpAll(loadGameFonts);

  Future<void> pumpBench(WidgetTester t, Size size, Progress p) async {
    t.view.physicalSize = size;
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.reset);
    await t.pumpWidget(MaterialApp(
      home: Scaffold(
        body: SingleChildScrollView(
          child: SizedBox(width: size.width - 40, child: Workbench(progress: p, reference: RunState(null)..actions.clear())),
        ),
      ),
    ));
  }

  Future<void> tap(WidgetTester t, Finder f) async {
    await t.ensureVisible(f);
    await t.pump();
    await t.tap(f);
    await t.pump();
  }

  testWidgets('Grundwaffe + Gabe: Werte, Klassen und Reaktionen live', (t) async {
    final p = Progress();
    for (final id in ['smg', 'water', 'pistol']) {
      p.see('w:$id');
    }
    await pumpBench(t, const Size(1280, 900), p);
    expect(find.text('?'), findsWidgets, reason: 'unentdeckte Waffen als „?“');

    await tap(t, find.text(weaponDefs['smg']!.name));
    await tap(t, find.text(weaponGifts['water']!.name));
    // Böenschwarm mit Wasser-Gabe löst Frost allein aus
    expect(find.textContaining('Frost (löst sie selbst aus)'), findsOneWidget);
    expect(find.textContaining(RegExp('Gaben 1 / 1', caseSensitive: false)), findsWidgets);

    // Stufe I hat nur einen Gaben-Platz: die zweite Gabe ist nicht wählbar
    await tap(t, find.text(weaponGifts['pistol']!.name));
    expect(find.textContaining('Präzision'), findsOneWidget, reason: 'nur der Chip, keine zweite Gabe');
  });

  testWidgets('Reaktion suchen zeigt passende Kombinationen und lädt sie', (t) async {
    final p = Progress();
    for (final id in ['smg', 'water']) {
      p.see('w:$id');
    }
    await pumpBench(t, const Size(1280, 900), p);
    await tap(t, find.text(Reaction.frost.label));
    final combo = find.text('${weaponDefs['smg']!.name} + ${weaponGifts['water']!.name}');
    expect(combo, findsOneWidget);
    await tap(t, combo);
    expect(find.textContaining('Frost (löst sie selbst aus)'), findsOneWidget);
  });

  for (final size in const [Size(844, 600), Size(1280, 900)]) {
    testWidgets('Werkbank ohne Überlauf bei ${size.width.round()}', (t) async {
      final p = Progress()..debugUnlockAll = true;
      await pumpBench(t, size, p);
      await tap(t, find.text(weaponDefs['rocket']!.name));
      await tap(t, find.text('Stufe IV'));
      await tap(t, find.text(Reaction.steam.label));
      expect(t.takeException(), isNull);
    });
  }
}
