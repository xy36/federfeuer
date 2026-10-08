import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:federfeuer/game/config.dart';
import 'package:federfeuer/game/run_state.dart';
import 'package:federfeuer/ui/inspect_info.dart';

/// Waffen-Panels im Run: nur Reaktionen, die mit der aktuellen Ausrüstung möglich sind.
void main() {
  Future<String> panel(WidgetTester t, Widget info) async {
    await t.pumpWidget(MaterialApp(home: Scaffold(body: SingleChildScrollView(child: info))));
    final out = StringBuffer();
    for (final e in find.byType(RichText).evaluate()) {
      out.writeln((e.widget as RichText).text.toPlainText());
    }
    return out.toString();
  }

  testWidgets('Eigene Waffe: nur erreichbare Reaktionen mit Partner; sonst ein kurzer Hinweis', (t) async {
    final r = RunState('pistol')..addWeapon('smg', 0); // Licht + Wind
    final light = r.weapons.first;
    var text = await panel(t, weaponInfo(r, light.id, 0, owned: light, loadout: true));
    expect(text, isNot(contains(Reaction.rainbow.label)));
    expect(text, isNot(contains(Reaction.banish.label)));
    expect(text, contains('Keine mit deiner Ausrüstung'));

    // Wasserwaffe dazu: Regenbogen mit ihr, Bannstrahl weiterhin nicht
    r
      ..slotsUnlocked = kMaxWeapons
      ..addWeapon('water', 0);
    text = await panel(t, weaponInfo(r, light.id, 0, owned: light, loadout: true));
    expect(text, contains('${Reaction.rainbow.label} (mit ${weaponDefs['water']!.name})'));
    expect(text, isNot(contains(Reaction.banish.label)));
    expect(text, isNot(contains('NEU')), reason: 'nur Angebote markieren Neues');
  });

  testWidgets('Aktionen zählen als Partner', (t) async {
    final r = RunState('pistol')..addAction(ActionId.downpour); // Wasser
    final light = r.weapons.first;
    final text = await panel(t, weaponInfo(r, light.id, 0, owned: light, loadout: true));
    expect(text, contains('${Reaction.rainbow.label} (mit ${ActionId.downpour.label} (Aktion))'));
  });

  testWidgets('Shop-Angebot: was die Waffe mit der Ausrüstung erreichen könnte, Neues markiert', (t) async {
    final r = RunState('pistol')..addWeapon('smg', 0); // Licht + Wind
    final text = await panel(t, weaponInfo(r, 'water', 0, price: 20, loadout: true));
    expect(text, contains('NEU ${Reaction.frost.label} (mit ${weaponDefs['smg']!.name})'));
    expect(text, contains('NEU ${Reaction.rainbow.label} (mit ${weaponDefs['pistol']!.name})'));
    expect(text, isNot(contains(Reaction.steam.label)), reason: 'kein Glut in der Ausrüstung');
    expect(text, isNot(contains(Reaction.shatter.label)), reason: 'kein Stein in der Ausrüstung');

    // Schon vorhandene Reaktion: nicht als neu markiert
    r
      ..slotsUnlocked = kMaxWeapons
      ..addWeapon('bubbles', 0); // weitere Wasserwaffe
    final again = await panel(t, weaponInfo(r, 'water', 0, price: 20, loadout: true));
    expect(again, contains('• ${Reaction.frost.label} ('));
    expect(again, isNot(contains('NEU ${Reaction.frost.label}')));
  });

  testWidgets('Ohne Run-Bezug (Kompendium, Werkbank): alle Reaktionen der Klasse', (t) async {
    final r = RunState('pistol')..weapons.clear();
    final text = await panel(t, weaponInfo(r, 'pistol', 0));
    expect(text, contains(Reaction.rainbow.label));
    expect(text, contains(Reaction.banish.label));
  });
}
