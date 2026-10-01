import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:federfeuer/game/federfeuer_game.dart';
import 'package:federfeuer/game/perf.dart';
import 'package:federfeuer/main.dart' show buildOverlayMap;
import 'package:shared_preferences/shared_preferences.dart';

import 'helpers/fonts.dart';

void main() {
  setUpAll(loadGameFonts);

  test('Auswertung: Durchschnitt, 1%-Low, schlechtester Frame', () {
    final m = PerfMonitor()..recording = true;
    for (var i = 0; i < 99; i++) {
      m.frame(1 / 60);
    }
    m.frame(0.1); // ein Ruckler
    final r = m.endRecording();
    expect(r.frames, 100);
    expect(r.worstMs, closeTo(100, 1e-6));
    expect(r.low1Fps, closeTo(10, 1e-6));
    expect(r.avgFps, closeTo(100 / (99 / 60 + 0.1), 1e-6));
    expect(m.recording, isFalse);
  });

  testWidgets('Lastszene: 110 Gegner, Held unverwundbar, Anzeige ohne Fehler', (tester) async {
    SharedPreferences.setMockInitialValues({});
    tester.view.physicalSize = const Size(1280, 720);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final game = FederfeuerGame();
    await tester.pumpWidget(MaterialApp(
      home: GameWidget<FederfeuerGame>(game: game, focusNode: game.focusNode, overlayBuilderMap: buildOverlayMap()),
    ));
    for (var i = 0; i < 4; i++) {
      await tester.pump(const Duration(milliseconds: 50));
    }
    game.startBenchmark();
    final hp = game.run!.hp;
    for (var i = 0; i < 40; i++) {
      await tester.pump(const Duration(milliseconds: 50));
    }
    expect(game.benchmarkRunning, isTrue);
    expect(game.enemies.length, greaterThanOrEqualTo(FederfeuerGame.benchmarkEnemies - 10));
    expect(game.run!.weapons.length, 6);
    expect(game.run!.hp, greaterThanOrEqualTo(hp), reason: 'unverwundbar; Level-ups dürfen HP erhöhen');
    expect(game.phase, Phase.play);
    expect(game.biome.name, 'forest');
    // Obergrenze für schwebende Schadenszahlen hält, Zähler stimmt
    final floats = game.world.children.where((c) => c.runtimeType.toString() == 'FloatText').length;
    expect(floats, lessThanOrEqualTo(FederfeuerGame.maxFloatTexts));
    expect(game.floatTextCount, floats);
  });

  testWidgets('Render-Analyse misst jeden Bildteil einzeln und räumt danach auf', (tester) async {
    SharedPreferences.setMockInitialValues({});
    tester.view.physicalSize = const Size(1280, 720);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final game = FederfeuerGame();
    await tester.pumpWidget(MaterialApp(
      home: GameWidget<FederfeuerGame>(game: game, focusNode: game.focusNode, overlayBuilderMap: buildOverlayMap()),
    ));
    for (var i = 0; i < 4; i++) {
      await tester.pump(const Duration(milliseconds: 50));
    }
    game.startRenderAnalysis();
    final seen = <RenderPart>{};
    var guard = 0;
    while (game.analysisRunning && guard++ < 2000) {
      await tester.pump(const Duration(milliseconds: 50));
      if (perfSkip.isNotEmpty) {
        expect(perfSkip.length, 1, reason: 'immer genau ein Bildteil aus');
        seen.add(perfSkip.single);
      }
    }
    expect(game.analysisRunning, isFalse);
    expect(seen, RenderPart.values.toSet());
    expect(game.analysis.length, RenderPart.values.length + 1);
    expect(perfSkip, isEmpty, reason: 'nach der Analyse ist alles wieder an');
    expect(game.analysisLines().length, RenderPart.values.length + 1);
    expect(game.phase, Phase.paused);
  });
}
