import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:federfeuer/game/config.dart';
import 'package:federfeuer/game/federfeuer_game.dart';
import 'package:federfeuer/game/gamepad_input.dart';
import 'package:federfeuer/game/run_state.dart';
import 'package:federfeuer/main.dart' show buildOverlayMap;
import 'package:federfeuer/ui/inspect.dart' show InfoCard;
import 'package:flutter/gestures.dart' show PointerDeviceKind;
import 'package:gamepads/gamepads.dart';
import 'package:federfeuer/ui/radial_menu.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'helpers/fonts.dart';

/// Kreismenü: Segmente je Option, Schließen per Esc/Klick daneben; im Shop für Waffen und „als Gabe kaufen“.
NormalizedGamepadEvent _button(GamepadButton b, double v) => NormalizedGamepadEvent(
      gamepadId: '1',
      timestamp: 0,
      button: b,
      value: v,
      rawEvent: GamepadEvent(gamepadId: '1', timestamp: 0, type: KeyType.button, key: b.name, value: v),
    );

void main() {
  setUpAll(loadGameFonts);

  Future<void> frames(WidgetTester t, [int n = 4]) async {
    for (var i = 0; i < n; i++) {
      await t.pump(const Duration(milliseconds: 60));
    }
  }

  testWidgets('Zwei Optionen oben und unten, drei als Drittel; Esc schließt, Wahl führt aus', (t) async {
    var open = true, picked = '';
    late StateSetter set;
    List<RadialOption> opts(int n) => [
          for (final l in ['eins', 'zwei', 'drei'].take(n))
            RadialOption(icon: '•', label: l, color: Colors.teal, onPressed: () => picked = l),
        ];
    var n = 2;
    await t.pumpWidget(MaterialApp(
      home: Scaffold(
        body: Center(
          child: StatefulBuilder(builder: (context, s) {
            set = s;
            return RadialMenu(
              open: open,
              options: opts(n),
              onClose: () => s(() => open = false),
              child: const SizedBox(width: 60, height: 60, key: ValueKey('anchor')),
            );
          }),
        ),
      ),
    ));
    await frames(t);
    final c = t.getCenter(find.byKey(const ValueKey('anchor')));
    expect(t.getCenter(find.text('eins')).dy, lessThan(c.dy - 30), reason: 'erste Option oben');
    expect(t.getCenter(find.text('zwei')).dy, greaterThan(c.dy + 30), reason: 'zweite unten');

    set(() => n = 3);
    await frames(t);
    final drei = t.getCenter(find.text('drei')), zwei = t.getCenter(find.text('zwei'));
    expect(zwei.dx, greaterThan(c.dx), reason: 'Drittel: rechts unten');
    expect(drei.dx, lessThan(c.dx), reason: 'Drittel: links unten');

    await t.sendKeyEvent(LogicalKeyboardKey.escape);
    await frames(t);
    expect(open, isFalse);
    expect(find.text('eins'), findsNothing);

    set(() => open = true);
    await frames(t);
    await t.tap(find.text('zwei'));
    await frames(t);
    expect(picked, 'zwei');
    expect(open, isFalse);
  });

  testWidgets('Richtungen wählen das Segment in dieser Richtung; schon dort bleibt die Auswahl', (t) async {
    var n = 3;
    late StateSetter set;
    await t.pumpWidget(MaterialApp(
      home: Scaffold(
        body: Center(
          child: StatefulBuilder(builder: (context, s) {
            set = s;
            return RadialMenu(
              open: true,
              options: [
                for (final l in ['oben', 'zwei', 'drei', 'vier'].take(n))
                  RadialOption(icon: '•', label: l, color: Colors.teal, onPressed: () {}),
              ],
              onClose: () {},
              child: const SizedBox(width: 60, height: 60),
            );
          }),
        ),
      ),
    ));
    await frames(t);
    String focused() {
      final ctx = FocusManager.instance.primaryFocus?.context;
      String? label;
      void visit(Element e) {
        final w = e.widget;
        if (w is Text && ['oben', 'zwei', 'drei', 'vier'].contains(w.data)) label = w.data;
        e.visitChildren(visit);
      }

      (ctx as Element?)?.visitChildren(visit);
      return label ?? '-';
    }

    Future<String> key(LogicalKeyboardKey k) async {
      await t.sendKeyEvent(k);
      await t.pump();
      return focused();
    }

    // Drei Segmente: oben, rechts unten, links unten
    expect(focused(), 'oben');
    expect(await key(LogicalKeyboardKey.arrowUp), 'oben', reason: 'schon oben');
    expect(await key(LogicalKeyboardKey.arrowRight), 'zwei');
    expect(await key(LogicalKeyboardKey.arrowRight), 'zwei');
    expect(await key(LogicalKeyboardKey.arrowLeft), 'drei');
    expect(await key(LogicalKeyboardKey.arrowDown), 'drei', reason: 'unten: beide gleich nah, Auswahl bleibt');
    expect(await key(LogicalKeyboardKey.arrowUp), 'oben');

    // Vier Segmente: oben, rechts, unten, links
    set(() => n = 4);
    await frames(t);
    expect(focused(), 'oben');
    expect(await key(LogicalKeyboardKey.arrowUp), 'oben');
    expect(await key(LogicalKeyboardKey.arrowRight), 'zwei');
    expect(await key(LogicalKeyboardKey.arrowDown), 'drei');
    expect(await key(LogicalKeyboardKey.arrowLeft), 'vier');
    expect(await key(LogicalKeyboardKey.arrowLeft), 'vier');
  });

  testWidgets('Shop: Waffe antippen öffnet das Kreismenü; Angebot nur als Gabe kaufen', (t) async {
    SharedPreferences.setMockInitialValues({});
    t.view.physicalSize = const Size(1280, 720);
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.reset);
    final game = FederfeuerGame();
    await t.pumpWidget(MaterialApp(
      home: GameWidget<FederfeuerGame>(game: game, focusNode: game.focusNode, overlayBuilderMap: buildOverlayMap()),
    ));
    await frames(t);
    game.startRun('pistol');
    final r = game.run!
      ..addWeapon('smg', 0)
      ..money = 100
      ..offers = [Offer.weapon('water', 0, 30), Offer.item('magnet', 10)];
    game.overlays.add('shop');
    await frames(t);

    // Menü mit Gabe, Reserve, Verkaufen (kein Partner zum Verschmelzen)
    await t.tap(find.byKey(const ValueKey('weapon-tile-1')));
    await frames(t);
    expect(find.text('Gabe'), findsOneWidget);
    // Der Ring sitzt genau um den Waffen-Kreis
    final circle = t.getCenter(
        find.descendant(of: find.byKey(const ValueKey('weapon-tile-1')), matching: find.byType(DecoratedBox)).first);
    final ring = t.getCenter(find.ancestor(of: find.text('verkaufen'), matching: find.byType(CustomPaint)).first);
    expect((ring - circle).distance, lessThan(0.5), reason: 'Ring $ring, Waffe $circle');
    expect(find.text('Reserve'), findsOneWidget);
    expect(find.text('verkaufen'), findsOneWidget);
    expect(find.text('verschmelzen'), findsNothing);
    await t.tap(find.text('Reserve'));
    await frames(t);
    expect(r.reserve.map((w) => w.id), ['smg']);

    // Wasserpistole nur als Gabe kaufen: Angebot antippen, im Kreismenü „als Gabe“, dann Ziel im Ring
    await t.tap(find.text('Wasserpistole'));
    await frames(t);
    expect(find.text('kaufen'), findsOneWidget);
    expect(find.text('zurückhalten'), findsOneWidget);
    await t.tap(find.text('als Gabe'));
    await frames(t);
    expect(find.textContaining('Gabe kaufen (30)'), findsOneWidget);
    await t.tap(find.byKey(const ValueKey('weapon-tile-0')));
    await frames(t);
    expect(r.weapons.single.gifts, ['water']);
    expect(r.money, 70);
    expect(r.offers.first.sold, isTrue);
    expect(r.allWeapons.length, 2, reason: 'die gekaufte Waffe belegt keinen Platz');
    expect(r.allWeapons.length, lessThanOrEqualTo(kMaxWeapons));

    game.overlays.remove('shop');
    game.toMenu();
    await t.pump(const Duration(seconds: 1));
  });

  testWidgets('Modal: dahinter nichts anwählbar oder überfahrbar; B schließt, Steuerkreuz wählt Segmente', (t) async {
    SharedPreferences.setMockInitialValues({});
    t.view.physicalSize = const Size(1280, 720);
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.reset);
    addTearDown(() => controllerActive.value = false);
    final game = FederfeuerGame();
    await t.pumpWidget(MaterialApp(
      home: GameWidget<FederfeuerGame>(game: game, focusNode: game.focusNode, overlayBuilderMap: buildOverlayMap()),
    ));
    await frames(t);
    game.startRun('pistol');
    final r = game.run!
      ..addWeapon('smg', 0)
      ..money = 100
      ..offers = [Offer.item('magnet', 10), Offer.item('helm', 14)];
    game.phase = Phase.shop;
    game.overlays.add('shop');
    await frames(t);
    final offer = t.getCenter(find.text('Magnet'));

    await t.tap(find.byKey(const ValueKey('weapon-tile-1')));
    await frames(t);
    expect(openModalMenu, isNotNull);

    // Bei offenem Menü kein Info-Panel – weder vom Angebot unter der Maus noch vom fokussierten Segment
    final mouse = await t.createGesture(kind: PointerDeviceKind.mouse);
    await mouse.addPointer(location: offer);
    await frames(t);
    expect(find.byType(InfoCard), findsNothing);
    await mouse.removePointer();

    // Tab bleibt im Ring
    for (var i = 0; i < 6; i++) {
      await t.sendKeyEvent(LogicalKeyboardKey.tab);
      await t.pump();
      final label = FocusManager.instance.primaryFocus?.debugLabel;
      expect(label, 'RadialOption', reason: 'Fokus darf den Ring nicht verlassen');
    }

    // Shop-Kurztasten ruhen (X würfelt sonst neu)
    game.pad.handle(_button(GamepadButton.x, 1));
    game.pad.handle(_button(GamepadButton.x, 0));
    await t.pump();
    expect(r.rerolls, 0);

    // Steuerkreuz nach unten: unteres Segment (bei 3 Optionen links oder rechts unten)
    game.pad.handle(_button(GamepadButton.dpadUp, 1));
    game.pad.handle(_button(GamepadButton.dpadUp, 0));
    await t.pump();
    final top = FocusManager.instance.primaryFocus;
    game.pad.handle(_button(GamepadButton.dpadDown, 1));
    game.pad.handle(_button(GamepadButton.dpadDown, 0));
    await t.pump();
    expect(FocusManager.instance.primaryFocus, isNot(top));
    expect(FocusManager.instance.primaryFocus?.debugLabel, 'RadialOption');

    // B schließt
    game.pad.handle(_button(GamepadButton.b, 1));
    game.pad.handle(_button(GamepadButton.b, 0));
    await frames(t);
    expect(openModalMenu, isNull);
    expect(find.text('verkaufen'), findsNothing);

    // Klick daneben schließt nur – das Angebot darunter wird nicht gekauft
    await t.tap(find.byKey(const ValueKey('weapon-tile-1')));
    await frames(t);
    await t.tapAt(offer);
    await frames(t);
    expect(openModalMenu, isNull);
    expect(r.offers.first.sold, isFalse);
    expect(r.money, 100);

    game.overlays.remove('shop');
    game.toMenu();
    await t.pump(const Duration(seconds: 1));
  });

  testWidgets('Gabe vergeben: nur gültige Ziele (aktiv und Reserve) und „abbrechen“ wählbar; B bricht ab', (t) async {
    SharedPreferences.setMockInitialValues({});
    t.view.physicalSize = const Size(1280, 720);
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.reset);
    addTearDown(() => controllerActive.value = false);
    final game = FederfeuerGame();
    await t.pumpWidget(MaterialApp(
      home: GameWidget<FederfeuerGame>(game: game, focusNode: game.focusNode, overlayBuilderMap: buildOverlayMap()),
    ));
    await frames(t);
    game.startRun('pistol');
    final r = game.run!
      ..slotsUnlocked = kMaxWeapons
      ..addWeapon('smg', 0)
      ..addWeapon('water', 0)
      ..money = 100
      ..offers = [Offer.item('magnet', 10)];
    r.weapons.first.gifts.add('bubbles'); // Lichtfeder: Gaben-Platz voll → kein Ziel
    r.addWeapon('rocket', 0);
    r.toReserve(r.weapons.last); // Rakete in die Reserve
    game.phase = Phase.shop;
    game.overlays.add('shop');
    await frames(t);
    expect(r.reserve.single.id, 'rocket');

    Future<void> chooseGift() async {
      final water = r.weapons.indexWhere((w) => w.id == 'water');
      await t.ensureVisible(find.byKey(ValueKey('weapon-tile-$water')));
      await t.pump();
      await t.tap(find.byKey(ValueKey('weapon-tile-$water')));
      await frames(t);
      await t.tap(find.text('Gabe'));
      await frames(t);
      expect(find.textContaining('Wähle die Waffe, die sie erhält'), findsOneWidget);
    }

    await chooseGift();
    // Fokus springt aufs erste Ziel; Tab erreicht nur Ziele und „abbrechen“
    final seen = <String>{};
    for (var i = 0; i < 8; i++) {
      final n = FocusManager.instance.primaryFocus;
      final label = n?.debugLabel ?? '';
      var text = '';
      void visit(Element e) {
        final w = e.widget;
        if (w is Text && w.data != null) text += '${w.data} ';
        e.visitChildren(visit);
      }

      (n?.context as Element?)?.visitChildren(visit);
      final ok = label == 'Waffe smg' || label == 'Waffe rocket' || text.contains('abbrechen');
      expect(ok, isTrue, reason: 'Fokus auf „$label“ ($text) – nur Ziele und abbrechen erlaubt');
      seen.add(label.startsWith('Waffe') ? label : 'abbrechen');
      await t.sendKeyEvent(LogicalKeyboardKey.tab);
      await t.pump();
    }
    expect(seen, containsAll(['Waffe smg', 'Waffe rocket', 'abbrechen']));

    // Angebote: weder anklickbar noch überfahrbar
    await t.ensureVisible(find.text('Magnet'));
    await t.pump();
    final offer = t.getCenter(find.text('Magnet'));
    final mouse = await t.createGesture(kind: PointerDeviceKind.mouse);
    await mouse.addPointer(location: offer);
    await frames(t);
    expect(find.descendant(of: find.byType(InfoCard), matching: find.textContaining('Magnet')), findsNothing);
    await mouse.removePointer();
    await t.tapAt(offer);
    await frames(t);
    expect(r.offers.first.sold, isFalse);

    // Controller-B bricht ab
    game.pad.handle(_button(GamepadButton.b, 1));
    game.pad.handle(_button(GamepadButton.b, 0));
    await frames(t);
    expect(find.textContaining('Wähle die Waffe, die sie erhält'), findsNothing);
    expect(openModalMenu, isNull);

    // Ziel in der Reserve
    await chooseGift();
    await t.ensureVisible(find.byKey(const ValueKey('reserve-tile-0')));
    await t.pump();
    await t.tap(find.byKey(const ValueKey('reserve-tile-0')));
    await frames(t);
    expect(r.reserve.single.gifts, ['water']);
    expect(r.allWeapons.any((w) => w.id == 'water'), isFalse);
    expect(openModalMenu, isNull);

    game.overlays.remove('shop');
    game.toMenu();
    await t.pump(const Duration(seconds: 1));
  });

  testWidgets('Angebote: Kreismenü zum Kaufen und Zurückhalten; zu teuer bleibt grau ohne Wirkung', (t) async {
    SharedPreferences.setMockInitialValues({});
    t.view.physicalSize = const Size(1280, 720);
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.reset);
    addTearDown(() => controllerActive.value = false);
    final game = FederfeuerGame();
    await t.pumpWidget(MaterialApp(
      home: GameWidget<FederfeuerGame>(game: game, focusNode: game.focusNode, overlayBuilderMap: buildOverlayMap()),
    ));
    await frames(t);
    game.startRun('pistol');
    final r = game.run!
      ..money = 20
      ..offers = [Offer.item('magnet', 10), Offer.item('helm', 50)];
    game.phase = Phase.shop;
    game.overlays.add('shop');
    await frames(t);

    // Kaufen
    await t.tap(find.text('Magnet'));
    await frames(t);
    expect(find.text('kaufen'), findsOneWidget);
    await t.tap(find.text('kaufen'));
    await frames(t);
    expect(r.offers[0].sold, isTrue);
    expect(r.money, 10);
    expect(openModalMenu, isNull);

    // Zu teuer: Segment grau mit Grund, Antippen bewirkt nichts; Zurückhalten geht
    await t.tap(find.text('Blechhelm'));
    await frames(t);
    expect(find.text('zu teuer'), findsOneWidget);
    // Fokus beginnt auf der ersten wählbaren Option, nicht auf der grauen
    final focusCtx = FocusManager.instance.primaryFocus!.context! as Element;
    var focusText = '';
    void visit(Element e) {
      final w = e.widget;
      if (w is Text && w.data != null) focusText += '${w.data} ';
      e.visitChildren(visit);
    }

    focusCtx.visitChildren(visit);
    expect(focusText, contains('zurückhalten'));
    await t.tap(find.text('zu teuer'));
    await frames(t);
    expect(r.offers[1].sold, isFalse);
    expect(openModalMenu, isNotNull, reason: 'graue Wahl schließt das Menü nicht');
    await t.tap(find.text('zurückhalten'));
    await frames(t);
    expect(r.offers[1].locked, isTrue);
    expect(find.byKey(const ValueKey('lock-badge-1')), findsOneWidget, reason: 'Schloss-Abzeichen an der Karte');

    // Controller: A auf der Karte öffnet das Menü, Wahl „freigeben“
    await t.runAsync(() => Future<void>.delayed(const Duration(milliseconds: kMenuConfirmGraceMs + 50)));
    Focus.of(t.element(find.text('Blechhelm'))).requestFocus();
    await t.pump();
    game.pad.handle(_button(GamepadButton.a, 1));
    game.pad.handle(_button(GamepadButton.a, 0));
    await frames(t);
    expect(find.text('freigeben'), findsOneWidget);
    expect(t.takeException(), isNull);

    game.overlays.remove('shop');
    game.toMenu();
    await t.pump(const Duration(seconds: 1));
  });
}
