import 'dart:math';

import 'package:flame/game.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:federfeuer/game/config.dart';
import 'package:federfeuer/game/federfeuer_game.dart';
import 'package:federfeuer/game/progress.dart';
import 'package:federfeuer/game/run_state.dart';
import 'package:federfeuer/main.dart' show buildOverlayMap;
import 'package:federfeuer/ui/inspect.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'helpers/fonts.dart';

void main() {
  test('Gesehen wird, was im Shop liegt oder besessen wird; Rezepte über eigene Aktionen', () {
    final p = Progress();
    final r = RunState(null)
      ..addAction(ActionId.downpour)
      ..rollOffers(Random(1));
    p.noteRun(r);
    expect(p.hasSeen('w:pistol'), isTrue, reason: 'Startwaffe');
    for (final o in r.offers) {
      expect(p.hasSeen(o.isWeapon ? 'w:${o.id}' : 'i:${o.id}'), isTrue);
    }
    expect(p.hasSeen('a:downpour'), isTrue);
    expect(p.hasSeen('r:${ActionId.glacier.name}'), isTrue, reason: 'Platzregen steckt im Rezept');
    expect(p.hasSeen('r:${ActionId.hellmaw.name}'), isFalse);
    expect(p.hasEvolved(ActionId.glacier), isFalse);
    r.addAction(ActionId.whirlwind);
    r.evolve();
    p.noteRun(r);
    expect(p.hasEvolved(ActionId.glacier), isTrue);
    expect(p.hasSeen('a:glacier'), isTrue);
    p.seeEnemy(EnemyType.rock);
    expect(p.hasSeen('e:rock'), isTrue);
  });

  test('Kompendium wird gespeichert', () async {
    SharedPreferences.setMockInitialValues({});
    final a = Progress()
      ..see('w:rail')
      ..evolved.add('glacier');
    await a.save();
    final b = Progress();
    await b.load();
    expect(b.hasSeen('w:rail'), isTrue);
    expect(b.hasEvolved(ActionId.glacier), isTrue);
    expect(b.hasSeen('w:bowling'), isFalse);
  });

  testWidgets('Kompendium zeigt Bekanntes, Unbekanntes als ???', (t) async {
    await t.runAsync(loadGameFonts);
    SharedPreferences.setMockInitialValues({});
    t.view.physicalSize = const Size(1280, 720);
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.reset);
    final game = FederfeuerGame();
    await t.pumpWidget(MaterialApp(
      home: GameWidget<FederfeuerGame>(game: game, focusNode: game.focusNode, overlayBuilderMap: buildOverlayMap()),
    ));
    for (var i = 0; i < 4; i++) {
      await t.pump(const Duration(milliseconds: 50));
    }
    game.progress.see('w:rail');
    await t.tap(find.text('KOMPENDIUM'));
    await t.pump(const Duration(milliseconds: 50));
    await t.tap(find.textContaining('Waffen 1/18'));
    await t.pump(const Duration(milliseconds: 50));
    expect(find.text('Sonnenstrahl'), findsOneWidget);
    expect(find.text('???'), findsNWidgets(17));
    final mouse = await t.createGesture(kind: PointerDeviceKind.mouse);
    await mouse.addPointer(location: Offset.zero);
    await mouse.moveTo(t.getCenter(find.text('Sonnenstrahl')));
    await t.pump(const Duration(milliseconds: 100));
    expect(find.byType(InfoCard), findsOneWidget);
    await mouse.removePointer();
    await t.tap(find.textContaining('Kombinationen'));
    await t.pump(const Duration(milliseconds: 50));
    expect(find.text('Überschallknall'), findsNothing);
    game.progress.debugUnlockAll = true;
    await t.tap(find.textContaining('Gegner'));
    await t.pump(const Duration(milliseconds: 50));
    expect(find.text('Der Geierkönig'), findsOneWidget);
  });
}
