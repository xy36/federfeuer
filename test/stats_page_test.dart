import 'dart:math';

import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:federfeuer/game/config.dart';
import 'package:federfeuer/game/federfeuer_game.dart';
import 'package:federfeuer/game/gamepad_input.dart';
import 'package:federfeuer/game/run_state.dart';
import 'package:federfeuer/main.dart' show buildOverlayMap;
import 'package:federfeuer/ui/stats_page.dart';
import 'package:gamepads/gamepads.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'helpers/fonts.dart';

NormalizedGamepadEvent _button(GamepadButton b, double v) => NormalizedGamepadEvent(
      gamepadId: '1',
      timestamp: 0,
      button: b,
      value: v,
      rawEvent: GamepadEvent(gamepadId: '1', timestamp: 0, type: KeyType.button, key: b.name, value: v),
    );

/// Werte-Seite: Herkunft der Werte, Öffnen/Schließen per Taste und Controller, kein Überlauf.
void main() {
  setUpAll(loadGameFonts);

  test('Herkunft: Vogel + Level + Items + Sets ergibt den wirksamen Wert', () {
    final r = RunState('pistol', characterId: 'adler')
      ..slotsUnlocked = kMaxWeapons
      ..addWeapon('rail', 0) // Licht-Set: Krit
      ..money = 999
      ..offers = [Offer.item('klee', 16), Offer.item('hantel', 18)];
    r
      ..buy(0)
      ..buy(1);
    r.gain(200); // Level-ups (Max-HP +1 je Level)
    while (r.pendingLevels > 0) {
      r
        ..rollLevelChoices(Random(1))
        ..chooseLevel(0);
    }
    for (final s in Stat.values) {
      final sum = r.statBase[s]! + r.statFromLevels[s]! + r.statFromItems(s) + r.statFromSets(s);
      expect(sum, closeTo(r.stat(s), 1e-9), reason: s.label);
    }
    expect(r.statFromItems(Stat.luck), 8, reason: 'Kleeblatt');
    expect(r.statFromItems(Stat.dmg), 12, reason: 'Hantel');
    expect(r.statFromSets(Stat.crit), kSetCrit[1]);
    expect(r.statFromLevels[Stat.maxHp], greaterThanOrEqualTo(r.level));
    for (final s in Stat.values) {
      expect(statEffect(r, s), isNotEmpty);
    }
  });

  for (final size in const [Size(1280, 720), Size(844, 390)]) {
    testWidgets('C öffnet, Esc schließt; View öffnet, B schließt; kein Überlauf bei ${size.width.round()}×${size.height.round()}',
        (t) async {
      SharedPreferences.setMockInitialValues({});
      t.view.physicalSize = size;
      t.view.devicePixelRatio = 1;
      addTearDown(t.view.reset);
      addTearDown(() => controllerActive.value = false);
      final game = FederfeuerGame();
      await t.pumpWidget(MaterialApp(
        home: GameWidget<FederfeuerGame>(game: game, focusNode: game.focusNode, overlayBuilderMap: buildOverlayMap()),
      ));
      for (var i = 0; i < 4; i++) {
        await t.pump(const Duration(milliseconds: 50));
      }
      game.debugStartAtWave(6, shopFirst: true);
      for (var i = 0; i < 4; i++) {
        await t.pump(const Duration(milliseconds: 50));
      }
      await t.runAsync(() => Future<void>.delayed(const Duration(milliseconds: kMenuConfirmGraceMs + 50)));
      await t.pump();

      await t.sendKeyEvent(LogicalKeyboardKey.keyC);
      await t.pump();
      await t.pump();
      expect(find.byType(StatsPage), findsOneWidget);
      expect(find.descendant(of: find.byType(StatsPage), matching: find.text('WERTE')), findsOneWidget);
      for (final (title, _, _) in statGroups) {
        expect(find.text(title.toUpperCase()), findsOneWidget);
      }
      expect(t.takeException(), isNull, reason: 'kein Überlauf');
      // Fokus liegt in der Seite, nicht im Shop dahinter
      expect(FocusManager.instance.primaryFocus?.context?.findAncestorWidgetOfExactType<StatsPage>(), isNotNull);
      // Kurztasten des Shops ruhen
      final rerolls = game.run!.rerolls;
      await t.sendKeyEvent(LogicalKeyboardKey.keyR);
      await t.pump();
      expect(game.run!.rerolls, rerolls);

      await t.sendKeyEvent(LogicalKeyboardKey.escape);
      await t.pump();
      await t.pump();
      expect(find.byType(StatsPage), findsNothing);

      game.pad.handle(_button(GamepadButton.back, 1));
      game.pad.handle(_button(GamepadButton.back, 0));
      await t.pump();
      await t.pump();
      expect(find.byType(StatsPage), findsOneWidget);
      game.pad.handle(_button(GamepadButton.b, 1));
      game.pad.handle(_button(GamepadButton.b, 0));
      await t.pump();
      await t.pump();
      expect(find.byType(StatsPage), findsNothing);
      expect(openModalMenu, isNull);

      game.toMenu();
      await t.pump(const Duration(seconds: 1));
    });
  }
}
