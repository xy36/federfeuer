import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:federfeuer/game/federfeuer_game.dart';
import 'package:federfeuer/game/progress.dart';
import 'package:federfeuer/game/settings.dart';
import 'package:federfeuer/main.dart' show buildOverlayMap;
import 'package:shared_preferences/shared_preferences.dart';

import 'helpers/fonts.dart';

Future<FederfeuerGame> _pumpGame(WidgetTester tester) async {
  SharedPreferences.setMockInitialValues({});
  tester.view.physicalSize = const Size(1280, 720);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final game = FederfeuerGame();
  await tester.pumpWidget(MaterialApp(
    home: GameWidget<FederfeuerGame>(game: game, focusNode: game.focusNode, autofocus: true, overlayBuilderMap: buildOverlayMap()),
  ));
  for (var i = 0; i < 4; i++) {
    await tester.pump(const Duration(milliseconds: 50));
  }
  return game;
}

void main() {
  setUpAll(loadGameFonts);

  testWidgets('Einstellungen: Bildschirmwackeln umschalten wird gespeichert', (tester) async {
    final game = await _pumpGame(tester);
    await tester.tap(find.text('EINSTELLUNGEN'));
    await tester.pump(const Duration(milliseconds: 50));
    expect(game.settings.screenShake, isTrue);
    // Erster An/Aus-Knopf = Bildschirmwackeln (Vollbild gibt es im Test nicht)
    await tester.tap(find.text('An').first);
    await tester.pump(const Duration(milliseconds: 50));
    expect(game.settings.screenShake, isFalse);
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 50)));
    final loaded = Settings();
    await tester.runAsync(loaded.load);
    expect(loaded.screenShake, isFalse);
  });

  testWidgets('Esc führt von einer Unterseite zurück zum Titel', (tester) async {
    await _pumpGame(tester);
    await tester.tap(find.text('REKORDE'));
    await tester.pump(const Duration(milliseconds: 50));
    expect(find.text('FEDERFEUER'), findsNothing);
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pump(const Duration(milliseconds: 50));
    expect(find.text('FEDERFEUER'), findsOneWidget);
  });

  testWidgets('„Neue Runde“ öffnet direkt „Run vorbereiten“', (tester) async {
    final game = await _pumpGame(tester);
    game.startRun('pistol');
    await tester.pump(const Duration(milliseconds: 50));
    game.toMenu(play: true);
    await tester.pump(const Duration(milliseconds: 50));
    expect(find.text('RUN VORBEREITEN'), findsOneWidget);
    game.toMenu();
    await tester.pump(const Duration(milliseconds: 50));
    expect(find.text('FEDERFEUER'), findsOneWidget);
  });

  test('Statistik zählt Runs, Siege, Gegner und höchstes Level', () async {
    SharedPreferences.setMockInitialValues({});
    final p = Progress()
      ..recordRun(difficulty: 1, wave: 4, won: false, kills: 30, level: 3)
      ..recordRun(difficulty: 1, wave: 15, won: true, kills: 200, level: 9);
    expect(p.runs, 2);
    expect(p.wins, 1);
    expect(p.kills, 230);
    expect(p.bestLevel, 9);
    await p.save();
    final q = Progress();
    await q.load();
    expect((q.runs, q.wins, q.kills, q.bestLevel), (2, 1, 230, 9));
  });
}
