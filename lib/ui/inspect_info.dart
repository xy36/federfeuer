import 'package:flutter/material.dart';

import '../game/config.dart';
import '../game/progress.dart';
import '../game/run_state.dart';
import 'widgets.dart';

/// Inhalte der Info-Panels im Shop: Waffen, Items, Aktionen, Set-Boni, Werte.

Widget _head(Object icon, String title, String sub, Color color) => Row(children: [
      Container(
        width: 38,
        height: 38,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: color.withAlpha(30),
          border: Border.all(color: color.withAlpha(140), width: 1.2),
        ),
        child: icon is Widget ? icon : (icon is GlyphRef ? Glyph(icon, size: 30) : iconWidget('$icon', 17, color: color)),
      ),
      const SizedBox(width: 10),
      Expanded(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(title, style: displayStyle(16, Color.lerp(color, Colors.white, 0.45)!)),
          classText(sub, bodyText(11.5, color: Ui.muted)),
        ]),
      ),
    ]);

Widget _line(String label, String value, {Color color = Ui.text}) => Padding(
      padding: const EdgeInsets.symmetric(vertical: 1),
      child: Row(children: [
        Expanded(child: Text(label, style: bodyText(12, color: Ui.muted))),
        GlyphText(value, style: bodyText(12.5, color: color, weight: 900)),
      ]),
    );

Widget _section(String t, {Color color = Ui.muted}) => Padding(
      padding: const EdgeInsets.only(top: 8, bottom: 3),
      child: Text(t.toUpperCase(), style: displayStyle(10.5, color).copyWith(letterSpacing: 1.5)),
    );

/// Wie [_text], Klassennamen in Klassenfarbe.
Widget _classText(String t, {Color color = Ui.text}) => Padding(
      padding: const EdgeInsets.only(top: 2),
      child: classText(t, bodyText(12.5, color: color)),
    );

Widget _text(String t, {Color color = Ui.text}) => Padding(
      padding: const EdgeInsets.only(top: 2),
      child: GlyphText(t, style: bodyText(12.5, color: color)),
    );

const _good = Color(0xFF8CF5B0), _bad = Color(0xFFFF8A9A);

String _s(double v) => '${fmtNum(v)} s';
String _pct(double v) => '${(v * 100).round()} %';

/// Waffe in Stufe [tier]; [owned] = Slot im Inventar (zeigt Verkaufspreis).
/// [loadout]: Reaktionen nur mit der aktuellen Ausrüstung des Runs (Shop, Pause) statt aller möglichen.
Widget weaponInfo(RunState r, String id, int tier,
    {OwnedWeapon? owned, int? price, bool showSell = true, bool loadout = false}) {
  final d = weaponDefs[id]!, t = tiers[tier], s = owned != null ? r.statsOf(owned) : r.weaponStats(id, tier);
  final classes = owned?.classes ?? [d.cls];
  final gift = weaponGifts[id]!;
  final kind = switch (d.kind) {
    WeaponKind.shot => 'Schuss',
    WeaponKind.lob => 'Wurf im Bogen',
    WeaponKind.orbit => 'Nahkampf, kreist um dich',
    WeaponKind.whip => 'Nahkampf, Hieb im Bogen',
    WeaponKind.summon => 'Begleiter',
    WeaponKind.cloud => 'Wolke über dem Ziel',
    WeaponKind.roll => 'rollt über den Boden',
    WeaponKind.disco => 'rundum, zielt nicht',
  };
  final have = r.classCount(d.cls), lvl = setLevel(have), next = owned == null ? setLevel(have + 1) : lvl;
  final fx = <String>[
    if (s.count > 1) '${s.count} Projektile${d.kind == WeaponKind.orbit ? ' (Klingen)' : ''}',
    if (s.pierce >= 50) 'durchschlägt alles' else if (s.pierce > 0) 'durchschlägt ${s.pierce} Gegner',
    if (s.explosion > 0) 'Explosion, Radius ${s.explosion.round()}${d.fuse > 0 ? ' nach ${_s(d.fuse)}' : ''}',
    if (s.burnTime > 0) 'Brand ${_s(s.burnTime)}, ${fmtNum(s.burnDps)} Schaden/s',
    if (s.slow > 0) 'verlangsamt um ${_pct(s.slow)} für ${_s(s.slowTime)}',
    if (s.stun > 0) 'betäubt ${_s(s.stun)}',
    if (s.trap > 0) 'fängt ${_s(s.trap)} in einer Blase ein',
    if (s.curse > 0) 'verflucht ${_s(s.curse)} (+${_pct(r.curseBonus)} Schaden)',
    if (s.stickTime > 0) 'klebt ${_s(s.stickTime)}, ${fmtNum(s.stickDps)} Schaden/s',
    if (s.lifesteal > 0) '${s.lifesteal.round()} % Chance je Treffer auf +1 HP',
    if (s.critBonus > 0) '+${s.critBonus.round()} % Krit-Chance',
    if (s.stunChance > 0) '${_pct(s.stunChance)} Chance, ${_s(s.stunTime)} zu betäuben',
    if (s.trapChance > 0) '${_pct(s.trapChance)} Chance, ${_s(s.trapTime)} einzufangen',
    if (s.blastChance > 0)
      '${s.blastChance >= 1 ? 'jeder Treffer' : '${_pct(s.blastChance)} der Treffer'} explodiert (Radius ${s.blastRadius.round()}, ${_pct(s.blastMul)})',
    if (d.hpCost > 0) 'kostet ${d.hpCost} HP pro Schuss',
    if (s.knock >= 15) 'starker Rückstoß (${s.knock.round()})',
    if (d.heavy) 'langsam und schwer: profitiert vom Stein-Set',
  ];
  return Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
    _head(WeaponGlyph(id, tier: tier), d.name, 'Stufe ${t.label} · ${classes.map((c) => c.label).join(' + ')} · $kind',
        t.color),
    _text(d.desc),
    _section('Werte'),
    _line('Schaden', '${fmtNum(s.dmg)}${s.count > 1 ? ' ×${s.count}' : ''}'),
    _line(d.kind == WeaponKind.orbit ? 'Treffer je Gegner alle' : 'Abklingzeit', '${s.cooldown.toStringAsFixed(2)} s'),
    _line(d.kind == WeaponKind.orbit ? 'Kreisradius' : 'Reichweite', '${s.range.round()}'),
    if (fx.isNotEmpty) ...[
      _section('Effekte'),
      for (final f in fx) _text('• $f'),
    ],
    if (owned != null && owned.traits.isNotEmpty) ...[
      _section('Eigenschaften'),
      for (final tr in owned.traits) _text('• ${tr.label}: ${tr.descFor(d)}', color: _good),
    ],
    if (owned != null && owned.gifts.isNotEmpty) ...[
      _section('Gaben ${owned.gifts.length} / ${maxGifts(owned.tier)}'),
      for (final g in owned.gifts)
        _text('• ${weaponGifts[g]!.name} (${weaponDefs[g]!.name}): ${weaponGifts[g]!.desc}', color: _good),
    ],
    ...(loadout ? _loadoutReactionLines(r, classes, owned: owned) : _reactionLines(classes)),
    _section('Gabe beim Verschmelzen'),
    _classText('${gift.name}: ${gift.desc}, dazu Klasse ${d.cls.label} – geht an eine andere Waffe, wenn du diese mit ihr verschmilzt.',
        color: Ui.muted),
    _section('Klasse ${d.cls.label}', color: d.cls.color),
    for (var i = 0; i < 3; i++)
      _text('${kSetThresholds[i]} Waffen: ${d.cls.bonusTexts[i]}',
          color: lvl > i ? _good : (next > i ? Palette.sun : Ui.muted)),
    _classText(owned == null ? 'Du hast $have ${d.cls.label}-Waffen${next > lvl ? ' – Kauf erreicht den nächsten Bonus!' : ''}' : 'Du hast $have ${d.cls.label}-Waffen',
        color: Ui.muted),
    if (r.character.classBonus == d.cls) _text('${r.character.name}: +25 % Schaden mit dieser Klasse', color: _good),
    if (tier < 3) ...[
      _section('Nächste Stufe ${tiers[tier + 1].label}'),
      _line('Schaden', fmtNum(r.weaponStats(id, tier + 1).dmg)),
      _text('Zwei gleiche Waffen gleicher Stufe verschmelzen im Shop.', color: Ui.muted),
    ],
    if (owned != null && showSell) ...[
      _section('Verkaufen'),
      _line('Erlös', '${r.sellPrice(owned)}', color: Palette.mint),
    ],
    if (price != null) _line('Preis', '$price', color: Palette.sun),
  ]);
}

Widget itemInfo(RunState r, String id, {int? price}) {
  final it = itemById[id]!, owned = r.items[id] ?? 0;
  final act = it.action;
  return Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
    _head(ItemGlyph(it.id), it.name, act != null ? 'Aktions-Item · ${it.rarity.label}' : it.rarity.label, it.rarity.color),
    if (it.desc.isNotEmpty) _text(it.desc),
    if (it.mods.isNotEmpty) ...[
      _section('Werte'),
      for (final e in it.mods.entries)
        _line(e.key.label, '${e.value > 0 ? '+' : ''}${fmtNum(e.value)}${e.key.unit}', color: e.value < 0 ? _bad : _good),
    ],
    if (act != null) ...actionDetails(r, OwnedAction(act), buying: true),
    if (act == null) ...[
      _section('Besitz'),
      _text(owned > 0 ? 'Schon $owned× im Besitz.' : 'Noch nicht im Besitz.', color: Ui.muted),
      _text(it.unique ? 'Nur einmal pro Run.' : 'Stapelt sich unbegrenzt.', color: Ui.muted),
    ],
    if (price != null) _line('Preis', '$price', color: Palette.sun),
  ]);
}

/// Aktion: Wirkung, Abklingzeit, Stufe II, Rezepte; [buying]: aus Sicht eines Kaufs.
List<Widget> actionDetails(RunState r, OwnedAction a, {bool buying = false}) {
  final id = a.id;
  final buy = buying ? r.actionBuy(id) : null;
  final recipes = recipesWith(id).toList();
  return [
    _section('Aktion'),
    _text(id.desc),
    _line('Abklingzeit', _s(a.cooldown)),
    if (!id.evolved) _line('Stufe II', '${_s(id.cooldown * kActionLv2Cooldown)}, Wirkung ×${fmtNum(kActionLv2Power)}'),
    if (buy == ActionBuy.upgrade) _text('Kauf hebt deine ${id.label} auf Stufe II.', color: _good),
    if (buy == ActionBuy.add) _text('Kommt in den freien Aktionsplatz.', color: Ui.muted),
    if (buy == ActionBuy.replace) _text('Beide Plätze belegt – beim Kauf wählst du, welche Aktion ersetzt wird.', color: Palette.sun),
    if (id.evolved) _text('Evolution – entsteht nur durch Verschmelzen.', color: const Color(0xFFFFC94A)),
    if (recipes.isNotEmpty) ...[
      _section('Rezepte'),
      for (final rec in recipes)
        _text(
          '${rec.a.label} + ${rec.b.label} → ${rec.result.label}: ${rec.result.desc}',
          color: r.actions.any((o) => o.id != id && (o.id == rec.a || o.id == rec.b)) ? _good : Ui.text,
        ),
    ],
  ];
}

Widget actionInfo(RunState r, OwnedAction a, int slot) => Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        _head(ActionGlyph(a.id), a.label, 'Aktionsplatz ${slot + 1}', a.id.evolved ? const Color(0xFFFFC94A) : Palette.sun),
        ...actionDetails(r, a),
      ],
    );

Widget setInfo(RunState r, WeaponClass cls) {
  final n = r.classCount(cls), lvl = setLevel(n);
  return Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
    _head('◆', 'Set ${cls.label}', '$n ${cls.label}-Waffen', cls.color),
    _section('Boni'),
    for (var i = 0; i < 3; i++) _text('${kSetThresholds[i]} Waffen: ${cls.bonusTexts[i]}', color: lvl > i ? _good : Ui.muted),
    _section('Waffen dieser Klasse'),
    _text(weaponDefs.values.where((w) => w.cls == cls).map((w) => w.name).join(', '), color: Ui.muted),
  ]);
}

Widget statInfo(RunState r, Stat s) {
  final base = r.stats[s]!, total = r.stat(s);
  final desc = switch (s) {
    Stat.maxHp => 'Höchste Lebenspunkte. Jedes Level gibt +1.',
    Stat.regen => 'Heilt (Wert ÷ 5) HP pro Sekunde.',
    Stat.dmg => 'Multipliziert den Schaden aller Waffen und Aktionen.',
    Stat.atk => 'Verkürzt die Abklingzeit aller Waffen (höchstens auf 30 %).',
    Stat.range => 'Addiert sich auf die Reichweite aller Waffen.',
    Stat.speed => 'Bewegungstempo.',
    Stat.armor => 'Erlittener Schaden × 15 / (15 + Rüstung); negativ erhöht ihn.',
    Stat.lifesteal => 'Chance pro Treffer auf +1 HP – höchstens 1 HP alle 0,5 s.',
    Stat.crit => 'Chance auf doppelten Schaden pro Treffer.',
    Stat.pickup => 'Material in diesem Radius fliegt zu dir (Grundradius 70).',
    Stat.thrust => 'Stärkerer Schub beim Fliegen (Kolibri: schneller hoch und runter).',
    Stat.glide => 'Langsameres Sinken beim Gleiten.',
    Stat.luck => 'Bessere Seltenheit im Shop, öfter seltene Level-ups, mehr Herzen und Geschenke.',
    Stat.dodge => 'Chance, einem Treffer ganz auszuweichen (höchstens ${kDodgeMax.round()} %).',
    Stat.actionSpeed => 'Kürzere Abklingzeit der Aktionstasten.',
  };
  final bonus = total - base;
  return Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
    _head('◆', s.label, '${fmtNum(total)}${s.unit.isEmpty ? '' : ' ${s.unit}'}', Palette.cyan),
    _text(desc),
    if (bonus != 0) ...[
      _section('Zusammensetzung'),
      _line('Grundwert', fmtNum(base)),
      _line('Set-Boni und Items', '${bonus > 0 ? '+' : ''}${fmtNum(bonus)}', color: bonus > 0 ? _good : _bad),
    ],
  ]);
}

Widget characterInfo(Progress p, CharacterDef c) {
  final has = p.hasCharacter(c.id);
  final prog = p.unlockProgress(c.unlock);
  return Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
    _head(BirdGlyph(c), c.name, '${c.species} · ${c.role}', c.glow),
    _section('Stärke'),
    _text(c.strength, color: _good),
    _section('Nachteil'),
    _text(c.weakness, color: _bad),
    _section('Fliegt'),
    _text(c.flight),
    _section('Start'),
    _text([
      c.startWeapons.isEmpty ? 'keine Waffe' : c.startWeapons.map((id) => weaponDefs[id]!.name).join(' / '),
      if (c.startAction != null) c.startAction!.label,
      if (c.maxWeapons != kMaxWeapons) '${c.maxWeapons} Waffenslots',
    ].join(' · ')),
    _section(has ? 'Freigeschaltet' : 'Gesperrt'),
    _text(has ? 'Wählbar unter „Spielen“.' : '${c.unlock.text}${prog == null ? '' : ' (${prog.$1} / ${prog.$2})'}',
        color: has ? _good : Palette.sun),
  ]);
}

Widget enemyInfo(EnemyType t) {
  final d = enemyDefs[t]!;
  return Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
    _head(EnemyGlyph(t), t.label, d.flying ? 'fliegt' : 'am Boden', const Color(0xFFC77DFF)),
    _text(t.desc),
    _section('Grundwerte (Welle 1, Stufe Küken)'),
    _line('Lebenspunkte', fmtNum(d.hp)),
    _line('Berührungsschaden', fmtNum(d.dmg)),
    _line('Tempo', fmtNum(d.speed)),
    if (d.drop > 0) _line('Material', '${d.drop}', color: Palette.mint),
  ]);
}

/// Platzhalter für noch nicht Entdecktes.
Widget unknownInfo(String hint) => Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
      _head('?', '???', 'Noch nicht entdeckt', Ui.muted),
      _classText(hint, color: Ui.muted),
    ]);

Widget recipeInfo(RunState r, ActionRecipe rec, {required bool evolved}) => Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        _head(ActionGlyph(rec.result), rec.result.label, '${rec.a.label} + ${rec.b.label}', const Color(0xFFFFC94A)),
        ...actionDetails(r, OwnedAction(rec.result)),
        _section('Status'),
        _text(evolved ? 'Schon selbst verschmolzen ✓' : 'Noch nie verschmolzen', color: evolved ? _good : Ui.muted),
      ],
    );

/// Vorschau beim Verschmelzen zweier Aktionen.
Widget evolutionPreview(RunState r, ActionRecipe rec) {
  final lost = r.actions.where((a) => a.level > 0).map((a) => a.id.label).toList();
  return Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
    _head(ActionGlyph(rec.result), rec.result.label, 'Evolution aus ${rec.a.label} + ${rec.b.label}', const Color(0xFFFFC94A)),
    ...actionDetails(r, OwnedAction(rec.result)),
    _section('Beim Verschmelzen'),
    _text('• ${rec.a.label} und ${rec.b.label} werden zu ${rec.result.label} (Aktionsplatz 1).'),
    _text('• Aktionsplatz 2 wird frei.', color: _good),
    if (lost.isNotEmpty) _text('• Stufe II von ${lost.join(' und ')} geht verloren.', color: _bad),
    _text('• Evolutionen haben keine Stufe II.', color: Ui.muted),
  ]);
}

/// Vorschau beim Verschmelzen zweier gleicher Waffen: Werte vorher → nachher.
Widget weaponMergePreview(RunState r, OwnedWeapon w) {
  final d = w.def, a = r.statsOf(w), b = r.weaponStats(w.id, w.tier + 1, gifts: w.gifts, traits: w.traits);
  final ta = tiers[w.tier], tb = tiers[w.tier + 1];
  Widget cmp(String label, String from, String to) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 1),
        child: Row(children: [
          Expanded(child: Text(label, style: bodyText(12, color: Ui.muted))),
          Text(from, style: bodyText(12.5, color: Ui.muted, weight: 900)),
          GlyphText('  →  ', style: bodyText(12, color: Ui.muted)),
          Text(to, style: bodyText(12.5, color: _good, weight: 900)),
        ]),
      );
  return Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
    _head(WeaponGlyph(w.id, tier: w.tier + 1), d.name, 'Verschmelzen: Stufe ${ta.label} + ${ta.label} → ${tb.label}', tb.color),
    _section('Werte'),
    cmp('Schaden', fmtNum(a.dmg), fmtNum(b.dmg)),
    cmp(d.kind == WeaponKind.orbit ? 'Treffer je Gegner alle' : 'Abklingzeit', '${a.cooldown.toStringAsFixed(2)} s',
        '${b.cooldown.toStringAsFixed(2)} s'),
    if (a.burnDps > 0 && a.burnTime > 0) cmp('Brand / s', fmtNum(a.burnDps), fmtNum(b.burnDps)),
    if (a.stickDps > 0) cmp('Kleben / s', fmtNum(a.stickDps), fmtNum(b.stickDps)),
    _line('Verkaufswert', '${r.sellPrice(w)} → ${(r.weaponPrice(w.id, w.tier + 1) * 0.4).round()}', color: Palette.mint),
    _section('Beim Verschmelzen'),
    _text('• Dieser Slot steigt auf Stufe ${tb.label}.'),
    _text('• Die zweite ${d.name} (Stufe ${ta.label}) verschwindet, ihr Slot wird frei.', color: _good),
    _text('• Du wählst eine von 3 Eigenschaften (z. B. ${WeaponTrait.values.where((x) => x.appliesTo(d)).take(2).map((x) => x.descFor(d)).join(', ')}).',
        color: _good),
    _text('• Platz für Gaben: ${maxGifts(w.tier)} → ${maxGifts(w.tier + 1)}; Gaben der zweiten Waffe gehen mit über.'),
  ]);
}

/// Reaktionen, an denen die Klassen einer Waffe beteiligt sind, mit der Partnerklasse.
List<Widget> _reactionLines(List<WeaponClass> classes) {
  final lines = <Widget>[];
  for (final re in Reaction.values) {
    if (!classes.contains(re.a) && !classes.contains(re.b)) continue;
    final partner = [re.a, re.b].where((c) => !classes.contains(c)).map((c) => c.label).join(' + ');
    final who = partner.isEmpty ? 'löst sie selbst aus' : 'mit $partner';
    lines.add(_classText('• ${re.label} ($who): ${re.short}', color: Color.lerp(re.color, Colors.white, 0.3)!));
  }
  return lines.isEmpty ? const [] : [_section('Reaktionen'), ...lines];
}

/// Quellen der aktuellen Ausrüstung für Reaktionen: aktive Waffen (ohne [except]) und Aktionen mit Klasse.
List<(String, List<WeaponClass>)> _loadoutSources(RunState r, {OwnedWeapon? except}) => [
      for (final w in r.weapons)
        if (!identical(w, except)) (w.def.name, w.classes),
      for (final a in r.actions)
        if (a.id.cls != null) ('${a.id.label} (Aktion)', [a.id.cls!]),
    ];

/// Nur Reaktionen, die diese Waffe mit der aktuellen Ausrüstung auslösen kann – mit dem Partner,
/// der die zweite Klasse liefert. Bei Shop-Angeboten ([owned] null) sind neue Reaktionen markiert.
List<Widget> _loadoutReactionLines(RunState r, List<WeaponClass> classes, {OwnedWeapon? owned}) {
  final sources = _loadoutSources(r, except: owned);
  bool provided(WeaponClass c) => sources.any((s) => s.$2.contains(c));
  final lines = <Widget>[];
  final missing = <WeaponClass>{};
  for (final re in Reaction.values) {
    if (!classes.contains(re.a) && !classes.contains(re.b)) continue;
    final need = [re.a, re.b].where((c) => !classes.contains(c)).toList();
    String who;
    if (need.isEmpty) {
      who = 'löst sie selbst aus';
    } else {
      final names = [for (final s in sources) if (s.$2.contains(need.first)) s.$1];
      if (names.isEmpty) {
        missing.add(need.first);
        continue;
      }
      who = 'mit ${names.take(2).join(', ')}${names.length > 2 ? ' …' : ''}';
    }
    // Angebot: schafft der Kauf eine Reaktion, die die Ausrüstung noch nicht hat?
    final isNew = owned == null && !(provided(re.a) && provided(re.b));
    lines.add(_classText('• ${isNew ? 'NEU ' : ''}${re.label} ($who): ${re.short}',
        color: isNew ? _good : Color.lerp(re.color, Colors.white, 0.3)!));
  }
  if (lines.isEmpty && missing.isEmpty) return const [];
  return [
    _section('Reaktionen'),
    ...lines,
    if (lines.isEmpty)
      _classText('Keine mit deiner Ausrüstung – Partner wären: ${missing.map((c) => c.label).join(', ')}', color: Ui.muted),
  ];
}

/// Vorschau: [donor] gibt seine Gabe an [target] ab und verschwindet.
/// [price] gesetzt: die Spenderwaffe ist ein Shop-Angebot, das nur für die Gabe gekauft wird.
Widget weaponGiftPreview(RunState r, OwnedWeapon donor, OwnedWeapon target, {int? price}) {
  final g = weaponGifts[donor.id]!, d = target.def, t = tiers[target.tier];
  final classes = {...target.classes, donor.def.cls};
  return Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
    _head(WeaponGlyph(target.id, tier: target.tier), d.name, 'erhält die Gabe „${g.name}“', t.color),
    _text(g.desc, color: _good),
    _section('Danach'),
    Row(children: [
      Expanded(child: Text('Klassen', style: bodyText(12, color: Ui.muted))),
      classText(classes.map((c) => c.label).join(' + '), bodyText(12.5, color: Ui.text, weight: 900)),
    ]),
    _line('Gaben', '${target.gifts.length + 1} / ${maxGifts(target.tier)}'),
    if (price == null)
      _text('• ${donor.def.name} (Stufe ${tiers[donor.tier].label}) verschwindet, ihr Slot wird frei.')
    else
      _text('• Kostet $price – ${donor.def.name} belegt keinen Platz.'),
    if (donor.gifts.isNotEmpty) _text('• Ihre eigenen Gaben gehen verloren.', color: _bad),
  ]);
}

Widget reactionInfo(Reaction re) => Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
      _head(ReactionBadge(re, size: 30), re.label, '${re.a.label} + ${re.b.label}', re.color),
      _text(re.desc),
      _section('Regeln'),
      _line('Höchstens je Gegner alle', _s(kReactionCd)),
      if (re == Reaction.steam || re == Reaction.frost || re == Reaction.rainbow)
        _line('Nässe hält', '${_s(kWetTime)} (Regen ×${fmtNum(kWetRainMul)})', color: _good),
    ]);

Widget eliteInfo(EliteMod m) => Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
      _head('★', 'Elite: ${m.label}', 'ab Welle $kEliteStartWave', const Color(0xFFFFC94A)),
      _text('Ein normaler Gegner mit goldenem Schein, der ${m.desc}.'),
      _section('Alle Elitegegner'),
      _line('Lebenspunkte', '×${fmtNum(kEliteHp)}'),
      _line('Material', '×$kEliteDrops', color: Palette.mint),
      _line('Chance auf ein Geschenk', '${(kEliteGiftChance * 100).round()} %', color: Palette.mint),
    ]);
