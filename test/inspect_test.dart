import 'dart:math';

import 'package:flame/game.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
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
    await mouse.moveTo(t.getCenter(find.text('Funkenfächer')));
    await t.pump(const Duration(milliseconds: 100));
    await mouse.moveTo(t.getCenter(find.text('Rüstung').last));
    await t.pump(const Duration(milliseconds: 100));
    await mouse.moveTo(const Offset(5, 5));
    await t.pump(const Duration(milliseconds: 100));
    expect(find.byType(InfoCard), findsNothing);
    // Tastatur: Fokus auf Aktion
    await mouse.removePointer();
    Focus.of(t.element(find.text('Sturzflug · 3 s'))).requestFocus();
    await t.pump(const Duration(milliseconds: 100));
    expect(find.byType(InfoCard), findsOneWidget);
    await t.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    await t.pump(const Duration(milliseconds: 100));
    expect(find.byType(InfoCard), findsOneWidget, reason: 'Pfeiltaste wechselt zum nächsten Element');
    game.overlays.remove('shop');
    game.toMenu();
    await t.pump(const Duration(seconds: 1));
  });
}
