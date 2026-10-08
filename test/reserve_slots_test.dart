import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:federfeuer/game/config.dart';
import 'package:federfeuer/game/run_state.dart';

/// Erspielte Waffenplätze, Reserve und Gaben direkt aus dem Shop.
void main() {
  test('Start mit 2 Plätzen; weitere Waffen in die Reserve, danach nur noch Verschmelzen', () {
    final r = RunState('pistol');
    expect(r.maxWeapons, kStartWeaponSlots);
    r.addWeapon('smg', 0);
    expect(r.slotsFull, isTrue);
    r
      ..addWeapon('rail', 0)
      ..addWeapon('rocket', 0);
    expect(r.weapons.length, kStartWeaponSlots);
    expect(r.reserve.map((w) => w.id), ['rail', 'rocket']);
    expect(r.canAddWeapon('water', 0), isFalse);
    expect(r.canAddWeapon('rail', 0), isTrue, reason: 'verschmilzt mit der Reserve-Waffe');
    expect(r.allWeapons.length, 4);
  });

  test('Reserve: ablegen, einsetzen, tauschen; die letzte aktive Waffe bleibt', () {
    final r = RunState('pistol')..addWeapon('smg', 0);
    final pistol = r.weapons.first, smg = r.weapons.last;
    expect(r.toReserve(smg), isTrue);
    expect(r.toReserve(pistol), isFalse, reason: 'letzte aktive Waffe');
    expect(r.toActive(smg), isTrue);
    r.addWeapon('rail', 0);
    final rail = r.reserve.single;
    expect(r.toActive(rail), isFalse, reason: 'aktive Plätze voll');
    r.swapWeapons(rail, smg);
    expect(r.weapons, containsAll([pistol, rail]));
    expect(r.reserve, [smg]);
  });

  test('Reserve-Waffen verschmelzen und spenden Gaben, zählen aber nicht für Sets', () {
    final r = RunState('pistol')..addWeapon('pistol', 0);
    final reservePistol = r.weapons.last;
    r
      ..toReserve(reservePistol)
      ..addWeapon('smg', 0)
      ..addWeapon('water', 0);
    expect(r.reserve.map((w) => w.id), ['pistol', 'water']);
    expect(identical(r.partnerFor(r.weapons.first), reservePistol), isTrue);
    final sets = r.classCount(weaponDefs['water']!.cls);
    expect(sets, 0, reason: 'Reserve zählt nicht');
    final water = r.reserve.firstWhere((w) => w.id == 'water');
    expect(r.giftTo(water, r.weapons.last), isTrue);
    expect(r.reserve.contains(water), isFalse);
    expect(r.mergeWeapon(r.weapons.first), isTrue);
    expect(r.weapons.first.tier, 1);
    expect(r.reserve, isEmpty);
  });

  test('Waffengurt: +1 Platz, teurer mit jedem Kauf, verschwindet wenn alle offen sind', () {
    final r = RunState('pistol')..money = 999;
    final belt = itemById['waffengurt']!;
    expect(r.itemPrice(belt), kBeltPrice);
    r.offers = [Offer.item(belt.id, r.itemPrice(belt))];
    r.buy(0);
    expect(r.maxWeapons, kStartWeaponSlots + 1);
    expect(r.itemPrice(belt), kBeltPrice + kBeltPriceStep);
    r.offers = [Offer.item(belt.id, r.itemPrice(belt))];
    r.buy(0);
    expect(r.maxWeapons, kMaxWeapons);
    expect(r.itemAvailable(belt), isFalse);
    expect(r.unlockSlot(), isFalse, reason: 'Torwächter gibt dann nichts mehr');
  });

  test('Waffengurt spätestens im dritten Shop, solange Plätze fehlen', () {
    for (var seed = 0; seed < 30; seed++) {
      final r = RunState('pistol'), rng = Random(seed);
      var seen = false;
      for (var w = 1; w <= kBeltGuaranteeShops + 1 && !seen; w++) {
        r
          ..wave = w
          ..rollOffers(rng);
        seen = r.offers.any((o) => o.id == 'waffengurt');
      }
      expect(seen, isTrue, reason: 'Seed $seed');
    }
  });

  test('Waffe nur als Gabe kaufen: kein Platz, Geld weg, Gabe beim Ziel', () {
    final r = RunState('pistol')
      ..addWeapon('smg', 0)
      ..addWeapon('rail', 0)
      ..addWeapon('rocket', 0)
      ..money = 100
      ..offers = [Offer.weapon('water', 0, 30), Offer.weapon('pistol', 0, 20)];
    expect(r.canAddWeapon('water', 0), isFalse, reason: 'alles voll');
    final smg = r.weapons.last;
    expect(r.offerHasGiftTarget(0), isTrue);
    expect(r.buyAsGift(0, smg), isTrue);
    expect(smg.gifts, ['water']);
    expect(r.money, 70);
    expect(r.offers[0].sold, isTrue);
    expect(r.allWeapons.length, 4);
    // Gleiche Waffe kann sich selbst keine Gabe geben
    expect(r.canBuyAsGift(1, r.weapons.first), isFalse);
    // Zu teuer
    r.money = 5;
    expect(r.canBuyAsGift(1, smg), isFalse);
  });
}
