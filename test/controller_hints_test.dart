import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:federfeuer/game/federfeuer_game.dart';
import 'package:federfeuer/game/gamepad_input.dart';
import 'package:federfeuer/main.dart' show buildOverlayMap;
import 'package:federfeuer/ui/widgets.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'helpers/fonts.dart';

void main() {
  testWidgets('Mit Controller zeigen Menüs Knopf-Hinweise, Tastatur blendet sie aus', (t) async {
    await t.runAsync(loadGameFonts);
    SharedPreferences.setMockInitialValues({});
    t.view.physicalSize = const Size(1280, 720);
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
    expect(find.text('Bestätigen'), findsNothing);
    game.pad.used = true;
    await t.pump(const Duration(milliseconds: 50));
    expect(find.text('Bestätigen'), findsOneWidget, reason: 'Titel');
    await t.tap(find.text('EINSTELLUNGEN'));
    await t.pump(const Duration(milliseconds: 50));
    expect(find.text('Zurück'), findsWidgets);
    expect(find.byType(PadGlyph), findsWidgets);
    game.focusNode.requestFocus();
    await t.pump();
    await t.sendKeyEvent(LogicalKeyboardKey.keyX);
    await t.pump(const Duration(milliseconds: 50));
    expect(game.pad.used, isFalse);
    expect(find.text('Auswählen'), findsNothing);
  });
}
