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

    test('Vier Angebote plus immer ein Aktions-Angebot', () {
      for (var seed = 0; seed < 50; seed++) {
        final r = RunState('pistol')..rollOffers(Random(seed));
        expect(r.offers.length, kShopOffers + 1);
        expect(itemById[r.offers.last.id]?.action, isNotNull, reason: 'letztes Feld ist eine Aktion');
        expect(r.offers.take(kShopOffers).where((o) => !o.isWeapon && itemById[o.id]!.action != null), isEmpty);
        expect(r.offers.where((o) => o.isWeapon).length, greaterThanOrEqualTo(kEarlyMinWeapons), reason: 'früh viele Waffen');
      }
    });

    test('Zurückgehaltene Angebote bleiben beim Neu würfeln und im nächsten Shop', () {
      final r = RunState('pistol')..rollOffers(Random(1));
      final weapon = r.offers[0], action = r.offers.last;
      r.toggleLock(0);
      r.toggleLock(r.offers.length - 1);
      r.money = 999;
      r.reroll(Random(2));
      expect(r.offers[0], same(weapon));
      expect(r.offers.last, same(action));
      // Nächste Welle: noch da, Preis der neuen Welle
      r.wave = 6;
      r.rollOffers(Random(3));
      expect(r.offers[0], same(weapon));
      expect(weapon.price, r.weaponPrice(weapon.id, weapon.tier));
      // Gekauft: verschwindet beim nächsten Wurf
      r.buy(0);
      r.rollOffers(Random(4));
      expect(r.offers[0], isNot(same(weapon)));
      // Entsperrt: wird neu gewürfelt
      r.toggleLock(r.offers.length - 1);
      final act = r.offers.last;
      r.rollOffers(Random(5));
      expect(r.offers.last, isNot(same(act)));
    });

    test('Früh mehr Waffen, später mehr Items', () {
      double share(int wave) {
        var w = 0;
        for (var seed = 0; seed < 400; seed++) {
          final r = RunState('pistol')..wave = wave;
          r.rollOffers(Random(seed));
          w += r.offers.take(kShopOffers).where((o) => o.isWeapon).length;
        }
        return w / (400 * kShopOffers);
      }

      expect(weaponOfferChance(1), 0.8);
      expect(weaponOfferChance(5), closeTo(0.64, 1e-9));
      expect(weaponOfferChance(14), 0.55);
      expect(share(1), greaterThan(0.75));
      expect(share(12), closeTo(0.55, 0.06));
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
      expect(weaponPriceFactor(14), closeTo(3.821, 1e-3));
      expect(RunState('pistol').weaponPrice('rail', 0), (28 * kWeaponPriceScale).round());
      expect(itemPriceFactor(14), closeTo(5.485, 1e-3));
      expect(rerollBaseCost(1), 2);
      expect(rerollBaseCost(9), 12);
      expect(rerollBaseCost(14), 21);
    });
  });
}
