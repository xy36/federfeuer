import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:federfeuer/game/federfeuer_game.dart';
import 'package:federfeuer/game/run_state.dart';
import 'package:federfeuer/main.dart' show buildOverlayMap;
import 'package:federfeuer/ui/widgets.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'helpers/fonts.dart';

/// Rendert alle Menüs mit den echten Schriften in Desktop- und Handy-Größe.
/// Schlägt fehl, sobald ein Layout überläuft (RenderFlex overflow).
void main() {
  setUpAll(loadGameFonts);

  for (final size in const [Size(1280, 720), Size(844, 390), Size(1920, 1080), Size(2560, 1440)]) {
    testWidgets('Menüs ohne Überlauf bei ${size.width.round()}×${size.height.round()}', (tester) async {
      SharedPreferences.setMockInitialValues({'unlockedDifficulty': 3, 'selectedDifficulty': 2, 'bestWave_2': 9});
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);

      final game = FederfeuerGame();
      await tester.pumpWidget(MaterialApp(
        home: GameWidget<FederfeuerGame>(game: game, focusNode: game.focusNode, overlayBuilderMap: buildOverlayMap()),
      ));
      Future<void> frames([int n = 4]) async {
        for (var i = 0; i < n; i++) {
          await tester.pump(const Duration(milliseconds: 50));
        }
      }

      await frames();
      expect(game.overlays.isActive('menu'), isTrue);
      // Menü füllt den ganzen Bildschirm (auch hochskaliert) – nicht nur eine Ecke.
      final ui = find.byType(UiScale);
      expect(tester.getSize(ui.first), size);
      expect(tester.getTopLeft(ui.first), Offset.zero);
      expect(find.text('FEDERFEUER'), findsOneWidget);

      // Jede Unterseite öffnen, füllt den Bildschirm, Zurück führt zum Titel
      for (final item in ['SPIELEN', 'EINSTELLUNGEN', 'REKORDE', 'CREDITS']) {
        await tester.tap(find.text(item));
        await frames();
        final panel = tester.getRect(find.byType(Panel).first);
        expect(panel.width, closeTo(size.width, 1), reason: item);
        expect(panel.height, closeTo(size.height, 1), reason: item);
        game.menuBack!();
        await frames();
        expect(find.text('FEDERFEUER'), findsOneWidget, reason: 'zurück von $item');
      }

      game.startRun('pistol');
      await frames();
      game.run!.gain(40);
      game.endWave();
      expect(game.phase, Phase.cleared);
      await frames(30); // 1,5 s in 50-ms-Schritten (Spiel-dt ist auf 0,05 s begrenzt)
      expect(game.overlays.isActive('levelUp'), isTrue);

      while (game.phase == Phase.levelUp) {
        game.chooseLevel(0);
        await frames(1);
      }
      game.run!
        ..money = 57
        ..goalBonus = 6
        ..addWeapon('smg', 1)
        ..addWeapon('rocket', 0)
        ..addWeapon('pistol', 0) // Paar → Verschmelzen-Knopf im Slot
        ..items['klee'] = 2
        ..offers = [
          Offer.weapon('pistol', 0, 15), // verschmilzt
          Offer.weapon('rail', 1, 53),
          Offer.item('glas', 25),
          Offer.item('magnet', 10)..sold = true,
        ];
      game.overlays.remove('shop');
      await frames(1);
      game.overlays.add('shop');
      await frames();

      // Verschmelzen gleicher Waffen: Auswahl einer Eigenschaft (1 aus 3)
      final pair = game.run!.weapons.indexWhere((w) => w.id == 'pistol' && game.run!.mergePartner(game.run!.weapons.indexOf(w)) >= 0);
      expect(game.run!.merge(pair), isTrue);
      game.overlays.remove('shop');
      await frames(1);
      game.overlays.add('shop');
      await frames();
      expect(find.text('EIGENSCHAFT WÄHLEN'), findsOneWidget);
      game.run!.chooseTrait(0);

      game.nextWave();
      await frames();
      game.togglePause();
      await frames();
      expect(game.overlays.isActive('pause'), isTrue);
      game.togglePause();
      await frames();

      game.endRun(false);
      await tester.pump(const Duration(milliseconds: 800));
      await frames();
      expect(game.overlays.isActive('gameOver'), isTrue);
    });
  }
}
