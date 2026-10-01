import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:federfeuer/game/config.dart';
import 'package:federfeuer/game/run_state.dart';

void main() {
  group('Waffen kaufen & verschmelzen', () {
    test('Gleiche Waffe landet bei freiem Slot in einem eigenen Slot', () {
      final r = RunState('pistol');
      r.addWeapon('pistol', 0);
      expect(r.weapons.map((w) => (w.id, w.tier)), [('pistol', 0), ('pistol', 0)]);
    });

    test('Kauf über das Angebot verschmilzt nicht automatisch', () {
      final r = RunState('pistol')
        ..money = 100
        ..offers = [Offer.weapon('pistol', 0, 15)];
      expect(r.mergesOnBuy('pistol', 0), isFalse);
      expect(r.buy(0), isTrue);
      expect(r.weapons.length, 2);
      expect(r.weapons.every((w) => w.tier == 0), isTrue);
    });

    test('Manuelles Verschmelzen: Slot steigt auf, Partner wird frei', () {
      final r = RunState('pistol')
        ..addWeapon('smg', 0)
        ..addWeapon('pistol', 0);
      expect(r.mergePartner(0), 2);
      expect(r.mergePartner(1), -1);
      expect(r.merge(2), isTrue);
      expect(r.weapons.map((w) => (w.id, w.tier)), [('smg', 0), ('pistol', 1)]);
      expect(r.mergePartner(1), -1);
    });

    test('Keine Kette: zwei Stufe-II nach Verschmelzen erst per zweitem Klick', () {
      final r = RunState('pistol')
        ..addWeapon('pistol', 0)
        ..addWeapon('pistol', 1);
      r.merge(0); // pistol I + I → II
      expect(r.weapons.map((w) => w.tier), [1, 1]);
      expect(r.mergePartner(0), 1);
      r.merge(0); // II + II → III
      expect(r.weapons.map((w) => w.tier), [2]);
    });

    test('Stufe IV verschmilzt nicht weiter', () {
      final r = RunState('pistol')..addWeapon('pistol', 3);
      r.weapons.first.tier = 3;
      expect(r.mergePartner(0), -1);
      expect(r.merge(0), isFalse);
      expect(r.canMerge('pistol', 3), isFalse);
    });

    test('Volle Slots: Kauf nur, wenn er verschmilzt – dann eine Stufe', () {
      final r = RunState('pistol');
      for (final id in ['smg', 'shotgun', 'rail', 'rocket', 'smg']) {
        r.addWeapon(id, 0);
      }
      expect(r.slotsFull, isTrue);
      expect(r.canAddWeapon('shotgun', 1), isFalse);
      expect(r.mergesOnBuy('rail', 0), isTrue);
      r
        ..money = 100
        ..offers = [Offer.weapon('rail', 0, 28)];
      expect(r.buy(0), isTrue);
      expect(r.weapons.length, 6);
      expect(r.weapons.where((w) => w.id == 'rail').single.tier, 1);
    });

    test('Angebote bleiben gültig', () {
      final r = RunState('pistol')..rollOffers(Random(1));
      expect(r.offers.length, 4);
    });
  });

  group('Shop-Preise', () {
    test('steigen jede Welle, spät deutlich stärker', () {
      final r = RunState('pistol');
      var lastW = 0, lastI = 0, lastR = 0;
      final item = itemById['magnet']!;
      for (var w = 1; w <= 14; w++) {
        r.wave = w;
        final pw = r.weaponPrice('rail', 0), pi = r.itemPrice(item), pr = r.rerollCost;
        expect(pw, greaterThan(lastW), reason: 'Waffe Welle $w');
        expect(pi, greaterThanOrEqualTo(lastI), reason: 'Item Welle $w');
        expect(pr, greaterThanOrEqualTo(lastR), reason: 'Neu würfeln Welle $w');
        lastW = pw;
        lastI = pi;
        lastR = pr;
      }
      expect(weaponPriceFactor(14), closeTo(4.588, 1e-3));
      expect(itemPriceFactor(14), closeTo(5.485, 1e-3));
      expect(rerollBaseCost(1), 2);
      expect(rerollBaseCost(9), 12);
      expect(rerollBaseCost(14), 21);
    });
  });
}
