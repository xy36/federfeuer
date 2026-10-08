import 'dart:math';

import 'package:flame/game.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:federfeuer/game/config.dart' show ActionId;
import 'package:federfeuer/game/federfeuer_game.dart';
import 'package:federfeuer/main.dart' show buildOverlayMap;
import 'package:federfeuer/ui/inspect.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'helpers/fonts.dart';



void main() {
  testWidgets('Shop: Maus und Tastatur zeigen Details zum gewählten Element', (t) async {
    await t.runAsync(loadGameFonts);
    SharedPreferences.setMockInitialValues({});
    t.view.physicalSize = const Size(1280, 720);
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.reset);
    final game = FederfeuerGame();
    await t.pumpWidget(RepaintBoundary(
      child: MaterialApp(
        home: GameWidget<FederfeuerGame>(game: game, focusNode: game.focusNode, overlayBuilderMap: buildOverlayMap()),
      ),
    ));
    for (var i = 0; i < 4; i++) {
      await t.pump(const Duration(milliseconds: 50));
    }
    game.startRun('pistol');
    final r = game.run!;
    r.money = 200;
    r.addAction(ActionId.quake);
    r.addWeapon('shotgun', 1);
    r.items['gummiente'] = 1;
    r.items['helm'] = 2;
    r.rollOffers(Random(4));
    game.phase = Phase.shop;
    game.overlays.add('shop');
    await t.pump(const Duration(milliseconds: 50));
    final mouse = await t.createGesture(kind: PointerDeviceKind.mouse);
    await mouse.addPointer(location: Offset.zero);
    await mouse.moveTo(t.getCenter(find.text('Krähenruf')));
    await t.pump(const Duration(milliseconds: 100));
    expect(find.byType(InfoCard), findsOneWidget);
    // Eigene Waffe im Waffenring (Funkenfächer)
    await mouse.moveTo(t.getCenter(find.byKey(const ValueKey('weapon-tile-1'))));
    await t.pump(const Duration(milliseconds: 100));
    await mouse.moveTo(t.getCenter(find.text('Rüstung').last));
    await t.pump(const Duration(milliseconds: 100));
    await mouse.moveTo(const Offset(5, 5));
    await t.pump(const Duration(milliseconds: 100));
    expect(find.byType(InfoCard), findsNothing);
    // Angeklickt (fokussiert) und Maus weg: Panel zu, kein Rückfall auf das fokussierte Element
    await t.ensureVisible(find.text('Rüstung').last);
    await t.pump(const Duration(milliseconds: 100));
    final armor = t.getCenter(find.text('Rüstung').last);
    await mouse.moveTo(armor);
    await t.pump(const Duration(milliseconds: 100));
    await mouse.down(armor);
    await mouse.up();
    await t.pump(const Duration(milliseconds: 100));
    expect(find.byType(InfoCard), findsOneWidget);
    await mouse.moveTo(const Offset(5, 5));
    await t.pump(const Duration(milliseconds: 100));
    expect(find.byType(InfoCard), findsNothing, reason: 'Maus verlässt das Element');
    // Fokus aus dem Programm nach Mausbenutzung: kein Panel
    await mouse.removePointer();
    Focus.of(t.element(find.textContaining('Felsbeben ·'))).requestFocus();
    await t.pump(const Duration(milliseconds: 100));
    expect(find.byType(InfoCard), findsNothing);
    // Tastatur: Pfeiltaste zeigt das Panel des angesteuerten Elements
    await t.sendKeyEvent(LogicalKeyboardKey.arrowUp);
    await t.pump(const Duration(milliseconds: 100));
    expect(find.byType(InfoCard), findsOneWidget);
    await t.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    await t.pump(const Duration(milliseconds: 100));
    expect(find.byType(InfoCard), findsOneWidget, reason: 'Pfeiltaste wechselt zum nächsten Element');
    game.overlays.remove('shop');
    game.toMenu();
    await t.pump(const Duration(seconds: 1));
  });

  testWidgets('Pause zeigt die Übersicht des Runs mit Info-Panels', (t) async {
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
    game.debugStartAtWave(8);
    await t.pump(const Duration(milliseconds: 100));
    game.togglePause();
    await t.pump(const Duration(milliseconds: 100));
    final r = game.run!;
    expect(find.text('PAUSE'), findsOneWidget);
    expect(find.text('Level ${r.level}'), findsOneWidget);
    final mouse = await t.createGesture(kind: PointerDeviceKind.mouse);
    await mouse.addPointer(location: Offset.zero);
    await mouse.moveTo(t.getCenter(find.text(r.weapons.first.def.name).first));
    await t.pump(const Duration(milliseconds: 100));
    expect(find.byType(InfoCard), findsOneWidget);
    expect(find.text('Verkaufen'), findsNothing);
    await mouse.removePointer();
    await t.tap(find.text('Weiterspielen'));
    await t.pump(const Duration(milliseconds: 50));
    expect(game.phase, Phase.play);
    game.toMenu();
    await t.pump(const Duration(seconds: 1));
  });
}
