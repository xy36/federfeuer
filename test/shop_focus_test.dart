import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:federfeuer/game/config.dart';
import 'package:federfeuer/game/federfeuer_game.dart';
import 'package:federfeuer/game/run_state.dart';
import 'package:federfeuer/main.dart' show buildOverlayMap;
import 'package:federfeuer/ui/widgets.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'helpers/fonts.dart';

/// Knöpfe in den Waffenslots müssen per Pfeiltasten (und damit Controller) erreichbar sein.
void main() {
  setUpAll(loadGameFonts);

  /// Texte unterhalb eines Fokusknotens (zum Erkennen der Knöpfe).
  String texts(FocusNode? n) {
    final out = StringBuffer();
    void visit(Element e) {
      final w = e.widget;
      if (w is Text && w.data != null) out.write('${w.data} ');
      e.visitChildren(visit);
    }

    (n?.context as Element?)?.visitChildren(visit);
    return out.toString();
  }

  testWidgets('Waffenring: auswählen, verschmelzen und Gabe abgeben', (tester) async {
    SharedPreferences.setMockInitialValues({});
    tester.view.physicalSize = const Size(1280, 720);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final game = FederfeuerGame();
    await tester.pumpWidget(MaterialApp(
      home: GameWidget<FederfeuerGame>(game: game, focusNode: game.focusNode, overlayBuilderMap: buildOverlayMap()),
    ));
    Future<void> frames() async {
      for (var i = 0; i < 4; i++) {
        await tester.pump(const Duration(milliseconds: 50));
      }
    }

    await frames();
    game.startRun('pistol');
    final r = game.run!
      ..weapons.clear()
      ..slotsUnlocked = kMaxWeapons
      ..addWeapon('pistol', 0)
      ..addWeapon('pistol', 0)
      ..addWeapon('smg', 0)
      ..addWeapon('water', 0)
      ..offers = [Offer.item('magnet', 10)];
    game.overlays.add('shop');
    await frames();
    Finder tile(int i) => find.byKey(ValueKey('weapon-tile-$i'));
    Future<void> tap(Finder f) async {
      await tester.ensureVisible(f);
      await tester.pump();
      await tester.tap(f);
      await frames();
    }

    // Ohne Auswahl nur ein Hinweis, nach Antippen die Aktionsleiste
    expect(find.text('verschmelzen'), findsNothing);
    await tap(tile(0));
    expect(find.text('verschmelzen'), findsOneWidget);
    expect(find.text('Gabe'), findsOneWidget);

    // Die Knöpfe der Leiste sind per Tastatur erreichbar
    final buttons = FocusManager.instance.rootScope.traversalDescendants
        .where((n) => n.canRequestFocus && n.context != null && texts(n).contains('verschmelzen'));
    expect(buttons, isNotEmpty);

    await tap(find.text('verschmelzen'));
    expect(r.weapons.where((w) => w.id == 'pistol').single.tier, 1);
    // Eigenschaft über die Karte wählen (schließt das Auswahlfenster)
    expect(find.text('EIGENSCHAFT WÄHLEN'), findsOneWidget);
    await tap(find.text('Wählen').first);
    expect(r.traitChoice, isNull);
    expect(find.text('EIGENSCHAFT WÄHLEN'), findsNothing);

    // Gabe: Wasserpistole wählen, „Gabe“, dann Böenschwarm antippen
    final water = r.weapons.indexWhere((w) => w.id == 'water');
    await tap(tile(water));
    await tap(find.text('Gabe'));
    final smg = r.weapons.indexWhere((w) => w.id == 'smg');
    await tap(tile(smg));
    expect(r.weapons.any((w) => w.id == 'water'), isFalse);
    expect(r.weapons.firstWhere((w) => w.id == 'smg').gifts, ['water']);
  });

  testWidgets('Zu teure Angebote sind ansteuerbar und zeigen ihr Info-Panel', (tester) async {
    SharedPreferences.setMockInitialValues({});
    tester.view.physicalSize = const Size(1280, 720);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final game = FederfeuerGame();
    await tester.pumpWidget(MaterialApp(
      home: GameWidget<FederfeuerGame>(game: game, focusNode: game.focusNode, overlayBuilderMap: buildOverlayMap()),
    ));
    Future<void> frames() async {
      for (var i = 0; i < 4; i++) {
        await tester.pump(const Duration(milliseconds: 50));
      }
    }

    await frames();
    game.startRun('pistol');
    game.run!
      ..money = 0
      ..offers = [Offer.item('glas', 25)];
    game.overlays.add('shop');
    await frames();

    final card = FocusManager.instance.rootScope.traversalDescendants
        .firstWhere((n) => n.canRequestFocus && n.context != null && texts(n).contains('Glaskanone'));
    card.requestFocus();
    await frames();
    // Panel zeigt den Effekt des Items, gekauft wird nichts
    expect(find.textContaining('Schaden'), findsWidgets);
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pump();
    expect(game.run!.items, isNot(contains('glas')));
    expect(game.run!.offers.single.sold, isFalse);
  });

  testWidgets('Klassennamen erscheinen in ihrer Klassenfarbe', (tester) async {
    await tester.pumpWidget(MaterialApp(home: classText('Stufe I · Licht + Wind, Schaden', const TextStyle())));
    final rich = tester.widget<Text>(find.byType(Text)).textSpan! as TextSpan;
    final colored = {
      for (final s in rich.children!.whereType<TextSpan>())
        if (s.style?.color != null) s.text: s.style!.color,
    };
    expect(colored, {'Licht': WeaponClass.light.color, 'Wind': WeaponClass.wind.color});
  });
}
