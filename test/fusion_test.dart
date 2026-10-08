import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:federfeuer/game/config.dart';
import 'package:federfeuer/game/federfeuer_game.dart';
import 'package:federfeuer/main.dart' show buildOverlayMap;
import 'package:federfeuer/ui/constellation.dart';
import 'package:federfeuer/ui/fusion.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'helpers/fonts.dart';

Future<FederfeuerGame> _game(WidgetTester t) async {
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
  return game;
}

void main() {
  testWidgets('Verschmelzen zeigt die Animation; sie endet von selbst oder per Klick', (t) async {
    final game = await _game(t);
    game.startRun('pistol');
    final r = game.run!
      ..addAction(ActionId.downpour)
      ..addAction(ActionId.whirlwind);
    r.offers = [];
    game.phase = Phase.shop;
    game.overlays.add('shop');
    await t.pump(const Duration(milliseconds: 50));
    await t.tap(find.textContaining('Verschmelzen'));
    await t.pump(const Duration(milliseconds: 50));
    expect(find.byType(FusionAnimation), findsOneWidget);
    expect(r.actions.single.id, ActionId.glacier, reason: 'Verschmelzen passiert sofort');
    await t.pump(FusionAnimation.duration + const Duration(milliseconds: 100));
    await t.pump(const Duration(milliseconds: 50));
    expect(find.byType(FusionAnimation), findsNothing);

    // Erneut, diesmal per Klick überspringen
    r
      ..actions.clear()
      ..addAction(ActionId.flash)
      ..addAction(ActionId.whirlwind);
    game.overlays.remove('shop');
    await t.pump();
    game.overlays.add('shop');
    await t.pump(const Duration(milliseconds: 50));
    await t.tap(find.textContaining('Verschmelzen'));
    await t.pump(const Duration(milliseconds: 300));
    await t.tapAt(const Offset(640, 360));
    await t.pump(const Duration(milliseconds: 50));
    expect(find.byType(FusionAnimation), findsNothing);
    expect(r.actions.single.id, ActionId.thunderstorm);
    expect(game.progress.hasEvolved(ActionId.thunderstorm), isTrue, reason: 'Kompendium vermerkt die Evolution');
    game.overlays.remove('shop');
    game.toMenu();
    await t.pump(const Duration(seconds: 1));
  });

  testWidgets('Sternbild zeigt alle Aktionen und Rezepte als Sterne', (t) async {
    final game = await _game(t);
    game.progress.debugUnlockAll = true;
    await t.tap(find.text('KOMPENDIUM'));
    await t.pump(const Duration(milliseconds: 50));
    await t.tap(find.textContaining('Kombinationen'));
    await t.pump(const Duration(milliseconds: 50));
    expect(find.byType(ActionConstellation), findsOneWidget);
    for (final a in ActionConstellation.order) {
      expect(find.text(a.label), findsWidgets, reason: a.label);
    }
    // Alle Grund-Aktionen sind Sterne, darunter alle Rezept-Zutaten
    expect(ActionConstellation.order.toSet(), ActionId.values.where((a) => !a.evolved).toSet());
    expect(ActionConstellation.order.toSet(), containsAll({for (final r in actionRecipes) ...[r.a, r.b]}));
  });
}
