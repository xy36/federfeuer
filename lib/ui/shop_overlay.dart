import 'dart:math';

import 'package:flutter/material.dart';
import 'package:gamepads/gamepads.dart';

import '../game/config.dart';
import '../game/federfeuer_game.dart';
import '../game/gamepad_input.dart' show controllerActive;
import '../game/run_state.dart';
import 'bird_preview.dart';
import 'controls_editor.dart' show ShortcutHint;
import 'fusion.dart';
import 'inspect.dart';
import 'inspect_info.dart';
import 'widgets.dart';

class ShopOverlay extends StatefulWidget {
  const ShopOverlay({super.key, required this.game});
  final FederfeuerGame game;

  @override
  State<ShopOverlay> createState() => _ShopOverlayState();
}

class _ShopOverlayState extends State<ShopOverlay> {
  FederfeuerGame get game => widget.game;

  static const _cardW = 166.0, _cardH = 236.0;

  /// Bereiche für den Sprung mit Bild ↑/↓ bzw. LB/RB: Angebote, Waffen & Items, Aktionen & Werte.
  final _sections = List.generate(3, (i) => FocusNode(debugLabel: 'Shop-Bereich $i', skipTraversal: true));
  int _section = 0;

  /// Zuletzt fokussiertes Angebot (für „Zurückhalten“ per Taste).
  int? _focusedOffer;

  @override
  void initState() {
    super.initState();
    game.onShopHotkey = _hotkey;
  }

  @override
  void dispose() {
    if (game.onShopHotkey == _hotkey) game.onShopHotkey = null;
    for (final n in _sections) {
      n.dispose();
    }
    super.dispose();
  }

  void _hotkey(ShopHotkey key) {
    final r = game.run!;
    if (_fusion != null || r.traitChoice != null) return; // Animation bzw. Eigenschafts-Wahl läuft
    switch (key) {
      case ShopHotkey.reroll:
        if (r.money >= r.rerollCost) setState(() => r.reroll(game.rng));
      case ShopHotkey.start:
        game.nextWave();
      case ShopHotkey.lock:
        final i = _focusedOffer;
        if (i != null && i < r.offers.length) setState(() => r.toggleLock(i));
      case ShopHotkey.nextSection || ShopHotkey.prevSection:
        _section = (_section + (key == ShopHotkey.nextSection ? 1 : _sections.length - 1)) % _sections.length;
        final first = _sections[_section].traversalDescendants.where((n) => n.canRequestFocus).firstOrNull;
        first?.requestFocus();
        if (first?.context != null) Scrollable.ensureVisible(first!.context!, alignment: 0.3);
    }
  }

  /// Bereich, der beim Sprung angesteuert wird.
  Widget _sectionArea(int i, Widget child) => Focus(
    focusNode: _sections[i],
    canRequestFocus: false,
    onFocusChange: (v) {
      if (v) _section = i;
    },
    child: child,
  );
  static const _itemAccent = Color(0xFFFFB86B);

  @override
  Widget build(BuildContext context) {
    final r = game.run!;
    game.progress.noteRun(r); // Kompendium: alles hier Gezeigte gilt als gesehen
    final next = biomeForWave(r.wave + 1);
    final panel = Panel(
      maxWidth: 960,
      hints: const [
        (GamepadButton.a, 'Kaufen'),
        (GamepadButton.x, 'Neu würfeln'),
        (GamepadButton.y, 'Zurückhalten'),
        (GamepadButton.leftBumper, '/ RB Bereich'),
        (GamepadButton.start, 'Welle starten'),
      ],
      footer: Row(
        children: [
          MoneyPill(r.money),
          const SizedBox(width: 12),
          // Tastatur: Kurztasten auf einen Blick (Controller zeigt sie in der Hinweiszeile)
          Expanded(
            child: ValueListenableBuilder<bool>(
              valueListenable: controllerActive,
              builder: (context, pad, _) => pad || isTouchPlatform
                  ? const SizedBox.shrink()
                  : GlyphText('R würfeln · L zurückhalten · Bild ↑↓ Bereich',
                      maxLines: 1, overflow: TextOverflow.ellipsis, style: bodyText(11.5, color: Ui.muted)),
            ),
          ),
          const ShortcutHint(keyLabel: 'N', pad: GamepadButton.start),
          GameButton(
            label: isBossWave(r.wave + 1) ? 'Zum Gipfel: Boss' : 'Welle ${r.wave + 1} starten',
            icon: '▶',
            size: 18,
            color: Palette.mint,
            onPressed: game.nextWave,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          PanelHeader(
            title: 'WELLE ${r.wave} GESCHAFFT',
            subtitle: Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                if (r.goalBonus != null)
                  Pill('Ziel erreicht: +${r.goalBonus} Zeitbonus', icon: '🏁', color: const Color(0x407CF29C)),
                if (next != biomeForWave(r.wave))
                  Pill('Nächste Welt: ${biomeDefs[next]!.name}', icon: '🗺', color: const Color(0x40B36BFF)),
              ],
            ),
          ),
          Row(
            children: [
              Expanded(child: sectionTitle('Angebote')),
              const SizedBox(width: 12),
              const ShortcutHint(keyLabel: 'R', pad: GamepadButton.x),
              GameButton(
                label: 'Neu würfeln · ${r.rerollCost}',
                icon: '🎲',
                size: 14,
                color: Ui.card,
                onPressed: r.money >= r.rerollCost ? () => setState(() => r.reroll(game.rng)) : null,
              ),
            ],
          ),
          _sectionArea(
            0,
            Wrap(spacing: 12, runSpacing: 4, children: [for (var i = 0; i < r.offers.length; i++) _offer(r, i)]),
          ),
          LayoutBuilder(
            builder: (context, box) {
              final left = _sectionArea(1, _inventory(r)), right = _sectionArea(2, _stats(r));
              if (box.maxWidth > 680) {
                return Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(flex: 14, child: left),
                    const SizedBox(width: 24),
                    Expanded(flex: 10, child: right),
                  ],
                );
              }
              return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [left, right]);
            },
          ),
        ],
      ),
    );
    final f = _fusion, choice = r.traitChoice;
    return Stack(
      fit: StackFit.expand,
      children: [
        // Während der Eigenschafts-Wahl ist der Shop dahinter nicht ansteuerbar
        ExcludeFocus(excluding: choice != null, child: panel),
        if (choice != null) _traitChooser(r, choice),
        if (f != null) FusionAnimation(a: f.$1, b: f.$2, result: f.$3, onDone: () => setState(() => _fusion = null)),
      ],
    );
  }

  /// Nach dem Verschmelzen gleicher Waffen: 1 aus 3 Eigenschaften wählen.
  Widget _traitChooser(RunState r, TraitChoice choice) {
    final w = choice.weapon, d = w.def, t = tiers[w.tier];
    return ColoredBox(
      color: const Color(0xB3050814),
      child: Center(
        child: SingleChildScrollView(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Text('EIGENSCHAFT WÄHLEN', style: displayStyle(24, Palette.sun).copyWith(shadows: glowShadows(Palette.sun))),
            const SizedBox(height: 4),
            Text('${d.name} ist jetzt Stufe ${t.label}', style: bodyText(14, color: Ui.muted)),
            const SizedBox(height: 14),
            Wrap(spacing: 12, runSpacing: 12, alignment: WrapAlignment.center, children: [
              for (var k = 0; k < choice.options.length; k++)
                ChoiceCard(
                  accent: t.color,
                  icon: '⤴',
                  glyph: WeaponGlyph(w.id, tier: w.tier),
                  title: choice.options[k].label,
                  width: 176,
                  height: 176,
                  body: Center(
                    child: Text(choice.options[k].descFor(d),
                        textAlign: TextAlign.center, style: bodyText(15, color: const Color(0xFFB5FFD0), weight: 900)),
                  ),
                  footer: CardFooter(const Text('Wählen'), color: Palette.sun),
                  onPressed: () => setState(() => r.chooseTrait(k)),
                ),
            ]),
          ]),
        ),
      ),
    );
  }

  /// Slot, der gerade seine Gabe abgibt (Ziel wird gewählt), sonst null.
  int? _donor;

  /// Laufende Verschmelz-Animation (Zutaten, Ergebnis).
  (ActionId, ActionId, ActionId)? _fusion;

  /// Angebot eines Aktions-Items, für das gerade der zu ersetzende Platz gewählt wird.
  int? _replaceOffer;

  void _buy(int i) {
    final r = game.run!, it = r.offers[i].isWeapon ? null : itemById[r.offers[i].id];
    if (it?.action != null && r.actionBuy(it!.action!) == ActionBuy.replace) {
      setState(() => _replaceOffer = i);
      return;
    }
    setState(() => r.buy(i));
  }

  void _replace(int slot) => setState(() {
    game.run!.buy(_replaceOffer!, replaceSlot: slot);
    _replaceOffer = null;
  });

  // ---------------- Angebote ----------------

  /// Angebotskarte mit Schloss-Knopf darunter.
  Widget _offer(RunState r, int i) {
    final o = r.offers[i];
    return Focus(
      canRequestFocus: false,
      skipTraversal: true,
      onFocusChange: (v) {
        if (v) _focusedOffer = i;
      },
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (o.sold)
            _offerCard(r, i)
          else
            Inspectable(
              radius: 16,
              info: (_) => o.isWeapon ? weaponInfo(r, o.id, o.tier, price: o.price) : itemInfo(r, o.id, price: o.price),
              child: _offerCard(r, i),
            ),
          SizedBox(width: _cardW, height: _lockH, child: o.sold ? null : _lockButton(r, i)),
        ],
      ),
    );
  }

  static const _lockH = 30.0;

  Widget _lockButton(RunState r, int i) {
    final locked = r.offers[i].locked;
    return Pressable(
      onPressed: () => setState(() => r.toggleLock(i)),
      builder: (context, s) => Sticker(
        state: s,
        color: locked ? Palette.sun : Ui.card,
        radius: 10,
        depth: 2,
        child: Center(
          child: GlyphText(
            locked ? '🔒 Zurückgehalten' : '🔓 Zurückhalten',
            style: bodyText(11.5, color: locked ? Palette.sun : Ui.muted, weight: 900),
          ),
        ),
      ),
    );
  }

  Widget _offerCard(RunState r, int i) {
    final o = r.offers[i];
    if (o.sold) return _soldCard();
    final poor = r.money < o.price;

    if (o.isWeapon) {
      final d = weaponDefs[o.id]!, t = tiers[o.tier], s = r.weaponStats(o.id, o.tier);
      final ok = r.canAddWeapon(o.id, o.tier);
      final mergeNow = r.mergesOnBuy(o.id, o.tier), pair = !mergeNow && r.canMerge(o.id, o.tier);
      return ChoiceCard(
        accent: t.color,
        // Bei vollen Slots verschmilzt der Kauf sofort; sonst Hinweis auf ein mögliches Paar.
        badge: mergeNow
            ? '⤴ STUFE ${tiers[o.tier + 1].label}'
            : (pair ? 'STUFE ${t.label} · PAAR' : 'STUFE ${t.label}'),
        badgeColor: mergeNow || pair ? const Color(0xCC1F9D55) : Ui.badge,
        icon: d.icon,
        glyph: WeaponGlyph(o.id, tier: o.tier),
        title: d.name,
        width: _cardW,
        height: _cardH,
        body: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _classTag(d.cls, r),
            Text(
              d.desc,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: bodyText(12, color: Ui.cardMuted),
            ),
            const Spacer(),
            _line('Schaden', '${fmtNum(s.dmg)}${d.count > 1 ? ' ×${d.count}' : ''}'),
            _line('Tempo', '${s.cooldown.toStringAsFixed(2)} s'),
            _line('Reichweite', '${s.range.round()}'),
            const SizedBox(height: 8),
          ],
        ),
        footer: CardFooter(
          ok ? PriceTag(o.price) : const Text('Slots voll'),
          color: ok && !poor ? Palette.sun : const Color(0xFF6C7590),
        ),
        onPressed: poor || !ok ? null : () => _buy(i),
        // Zu teuer oder kein Platz: nicht kaufbar, aber ansteuerbar, um es anzusehen
        focusableWhenDisabled: !o.sold,
      );
    }

    final it = itemById[o.id]!;
    final act = it.action;
    final buyKind = act == null ? null : r.actionBuy(act);
    // Hinweise für Aktions-Items: Stufe II, passendes Rezept, Platz ersetzen
    final hints = <(String, Color)>[];
    if (buyKind == ActionBuy.upgrade) hints.add(('⤴ Stufe II: −30 % Abklingzeit, stärkere Wirkung', _green));
    if (act != null && buyKind != ActionBuy.upgrade) {
      // Höchstens eine Rezeptzeile, sonst läuft die Karte über; Details zeigt das Info-Panel
      final recs = [
        for (final owned in r.actions)
          if (recipeFor(owned.id, act) case final rec?) (owned.id, rec.result),
      ];
      if (recs.isNotEmpty) {
        final (with_, result) = recs.first;
        final more = recs.length > 1 ? ' (+${recs.length - 1})' : '';
        hints.add(('passt zu ${with_.label} → ${result.label}$more', _green));
      }
      if (buyKind == ActionBuy.replace) hints.add(('Plätze voll – ersetzt eine Aktion', Ui.cardMuted));
    }
    final picking = _replaceOffer == i;
    return ChoiceCard(
      accent: it.rarity == Rarity.common ? _itemAccent : it.rarity.color,
      badge: buyKind == ActionBuy.upgrade ? '⤴ STUFE II' : (act != null ? 'AKTION' : it.rarity.label.toUpperCase()),
      badgeColor: buyKind == ActionBuy.upgrade
          ? const Color(0xCC1F9D55)
          : (it.rarity == Rarity.common ? Ui.badge : it.rarity.color.withAlpha(210)),
      icon: it.icon,
      glyph: ItemGlyph(it.id),
      title: it.name,
      width: _cardW,
      height: _cardH,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (it.desc.isNotEmpty)
            Text(
              it.desc,
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
              style: bodyText(12, color: Ui.cardMuted),
            ),
          if (it.mods.isNotEmpty) ModsText(it.mods),
          if (hints.isNotEmpty) ...[
            const Spacer(),
            for (final (text, col) in hints)
              GlyphText(
                text,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: bodyText(11, color: col, weight: 900),
              ),
            const SizedBox(height: 6),
          ],
        ],
      ),
      footer: CardFooter(
        picking ? const GlyphText('Platz wählen ↘') : PriceTag(o.price),
        color: poor ? const Color(0xFF6C7590) : Palette.sun,
      ),
      onPressed: poor ? null : () => _buy(i),
    );
  }

  static const _green = Color(0xFF1F9D55);

  /// Aktionsplätze: Stufe, Abklingzeit, Rezepte, Verschmelzen bzw. Platz zum Ersetzen wählen.
  List<Widget> _actions(RunState r) {
    final pending = _replaceOffer == null ? null : itemById[r.offers[_replaceOffer!].id]!.action;
    final evo = r.evolution;
    // Rezepte mit eigenen Aktionen; Zutaten, die es nur als Startaktion gibt, nur wenn vorhanden
    final buyable = {
      for (final it in itemDefs)
        if (it.action != null) it.action!,
    };
    final owned = {for (final a in r.actions) a.id};
    final recipes = <String>{
      for (final a in r.actions)
        for (final rec in recipesWith(a.id))
          if ((buyable.contains(rec.a) || owned.contains(rec.a)) && (buyable.contains(rec.b) || owned.contains(rec.b)))
            '${a.id.label} + ${rec.a == a.id ? rec.b.label : rec.a.label} → ${rec.result.label}',
    };
    return [
      sectionTitle('Aktionen ${r.actions.length}/$kActionSlots'),
      if (pending != null) ...[
        Text('${pending.label} ersetzt:', style: bodyText(12.5, color: Ui.muted)),
        const SizedBox(height: 6),
        Wrap(
          spacing: 8,
          runSpacing: 6,
          children: [
            for (var k = 0; k < r.actions.length; k++)
              GameButton(
                label: r.actions[k].label,
                glyph: ActionGlyph(r.actions[k].id),
                size: 13,
                color: Ui.card,
                onPressed: () => _replace(k),
              ),
            GameButton(
              label: 'Abbrechen',
              size: 13,
              color: Ui.card,
              onPressed: () => setState(() => _replaceOffer = null),
            ),
          ],
        ),
      ] else
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: [
            for (var k = 0; k < r.actions.length; k++)
              Inspectable(
                focusable: true,
                radius: 999,
                info: (_) => actionInfo(r, r.actions[k], k),
                child: Pill(
                  '${r.actions[k].label} · ${fmtNum(r.actionCooldown(r.actions[k]))} s',
                  glyph: ActionGlyph(r.actions[k].id),
                  color: r.actions[k].id.evolved ? const Color(0x55FFC94A) : const Color(0x33FFD23F),
                ),
              ),
            if (r.actions.isEmpty) Text('Noch keine – Aktions-Items gibt es im Shop', style: mutedStyle),
          ],
        ),
      if (evo != null && pending == null) ...[
        const SizedBox(height: 8),
        Inspectable(
          radius: 20,
          info: (_) => evolutionPreview(r, evo),
          child: GameButton(
            label: 'Verschmelzen → ${evo.result.label}',
            icon: '⤴',
            size: 13,
            color: Palette.mint,
            onPressed: () {
              final a = r.actions[0].id, b = r.actions[1].id, res = evo.result;
              setState(() {
                r.evolve();
                _fusion = (a, b, res);
              });
            },
          ),
        ),
        const SizedBox(height: 2),
        Text(evo.result.desc, style: bodyText(11.5, color: Ui.muted)),
      ] else if (recipes.isNotEmpty && pending == null) ...[
        const SizedBox(height: 6),
        for (final t in recipes) GlyphText('⤴ $t', style: bodyText(11.5, color: Ui.muted)),
      ],
    ];
  }

  /// Klasse der Waffe; mit Hinweis, wenn der Kauf den nächsten Set-Bonus erreicht.
  Widget _classTag(WeaponClass cls, RunState r) {
    final have = r.classCount(cls), lvl = setLevel(have), next = setLevel(have + 1);
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
            decoration: BoxDecoration(color: cls.color.withAlpha(70), borderRadius: BorderRadius.circular(6)),
            child: Text(cls.label, style: bodyText(11, color: Color.lerp(cls.color, Colors.white, 0.35)!, weight: 900)),
          ),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              next > lvl ? 'Set ${have + 1}!' : (have > 0 ? '$have im Besitz' : ''),
              maxLines: 1,
              style: bodyText(11, color: next > lvl ? const Color(0xFF1F9D55) : Ui.cardMuted, weight: 900),
            ),
          ),
        ],
      ),
    );
  }

  Widget _soldCard() => Padding(
    padding: const EdgeInsets.only(top: 4, bottom: 10),
    child: Container(
      width: _cardW,
      height: _cardH,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: Ui.slot,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Ui.panelLine, width: 2),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          GlyphText('✓', style: displayStyle(34, Palette.mint)),
          Text('Gekauft', style: displayStyle(16, Ui.muted)),
        ],
      ),
    ),
  );

  Widget _line(String label, String value) => Row(
    children: [
      Expanded(
        child: Text(label, style: bodyText(12, color: Ui.cardMuted)),
      ),
      Text(value, style: bodyText(12.5, color: Ui.cardText, weight: 900)),
    ],
  );

  // ---------------- Inventar ----------------

  Widget _inventory(RunState r) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        sectionTitle('Waffen ${r.weapons.length}/${r.maxWeapons}'),
        _weaponRing(r),
        _weaponBar(r),

        sectionTitle('Items'),
        if (r.items.isEmpty)
          Text('Noch keine', style: mutedStyle)
        else
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              for (final e in r.items.entries)
                Inspectable(
                  focusable: true,
                  radius: 999,
                  info: (_) => itemInfo(r, e.key),
                  child: Pill(
                    e.value > 1 ? '${itemById[e.key]!.name} ×${e.value}' : itemById[e.key]!.name,
                    glyph: ItemGlyph(e.key),
                  ),
                ),
            ],
          ),
      ],
    );
  }

  /// Aktive und fast erreichte Set-Boni.
  List<Widget> _sets(RunState r) {
    final rows = <Widget>[];
    for (final cls in WeaponClass.values) {
      final n = r.classCount(cls);
      if (n == 0) continue;
      final lvl = setLevel(n);
      final nextAt = n < 2 ? 2 : (n < 4 ? 4 : (n < 6 ? 6 : 0));
      rows.add(
        Inspectable(
          focusable: true,
          radius: 999,
          info: (_) => setInfo(r, cls),
          child: Pill(
            lvl > 0 ? '${cls.label} $n: ${cls.bonusTexts[lvl - 1]}' : '${cls.label} $n/$nextAt',
            color: cls.color.withAlpha(lvl > 0 ? 80 : 30),
          ),
        ),
      );
    }
    return [
      ..._actions(r),
      if (rows.isNotEmpty) ...[sectionTitle('Set-Boni'), Wrap(spacing: 6, runSpacing: 6, children: rows)],
    ];
  }

  // ---------------- Waffenring ----------------

  /// Gewählte Waffe (Index), für die die Aktionsleiste gilt.
  int? _selected;

  static const _ringH = 270.0, _tile = 62.0;

  /// Eigene Waffen schweben wie im Spiel im Kreis um den Vogel; freie Plätze gestrichelt.
  Widget _weaponRing(RunState r) {
    if (_selected != null && _selected! >= r.weapons.length) _selected = null;
    return LayoutBuilder(builder: (context, box) {
      final w = box.maxWidth, cx = w / 2, cy = _ringH / 2 - 6;
      final rx = min(w / 2 - 44, 200.0), ry = 92.0, n = r.maxWeapons;
      Offset at(int k) {
        final a = -pi / 2 + k / n * pi * 2;
        return Offset(cx + cos(a) * rx, cy + sin(a) * ry);
      }

      return SizedBox(
        height: _ringH,
        child: Stack(clipBehavior: Clip.none, children: [
          Positioned.fill(child: CustomPaint(painter: _OrbitPainter(Offset(cx, cy), rx, ry))),
          Positioned(
            left: cx - 40,
            top: cy - 40,
            child: BirdPreview(character: r.character, size: 80, animate: true),
          ),
          for (var k = 0; k < n; k++)
            Positioned(
              left: at(k).dx - 40,
              top: at(k).dy - _tile / 2,
              width: 80,
              child: k < r.weapons.length ? _ringTile(r, k) : _ringEmpty(),
            ),
        ]),
      );
    });
  }

  Widget _ringEmpty() => Column(mainAxisSize: MainAxisSize.min, children: [
        Container(
          width: _tile,
          height: _tile,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: Ui.slot,
            border: Border.all(color: Ui.panelLine, width: 1.5),
          ),
          child: Text('frei', style: bodyText(11, color: Ui.muted)),
        ),
      ]);

  void _tapTile(RunState r, int i) => setState(() {
        final donor = _donor;
        if (donor != null) {
          if (i == donor) {
            _donor = null;
          } else if (r.canGift(donor, i)) {
            final target = r.weapons[i];
            r.giveGift(donor, i);
            _donor = null;
            _selected = r.weapons.indexOf(target);
          }
          return;
        }
        _selected = _selected == i ? null : i;
      });

  Widget _ringTile(RunState r, int i) {
    final w = r.weapons[i], t = tiers[w.tier];
    final selected = _selected == i;
    final partner = _donor == null && _selected != null && _selected! < r.weapons.length && r.mergePartner(_selected!) == i;
    final target = _donor != null && r.canGift(_donor!, i);
    final donor = _donor == i;
    final accent = target ? Palette.purple : (partner ? Palette.mint : (selected || donor ? Palette.sun : t.color));
    final marked = selected || partner || target || donor;
    return Inspectable(
      key: ValueKey('weapon-tile-$i'),
      radius: 40,
      info: (_) => target ? weaponGiftPreview(r, r.weapons[_donor!], w) : weaponInfo(r, w.id, w.tier, owned: w),
      child: Pressable(
        onPressed: () => _tapTile(r, i),
        builder: (context, s) => Column(mainAxisSize: MainAxisSize.min, children: [
          AnimatedContainer(
            duration: const Duration(milliseconds: 120),
            width: _tile,
            height: _tile,
            transform: Matrix4.translationValues(0, s.highlighted || marked ? -3 : 0, 0),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(colors: [
                Color.alphaBlend(accent.withAlpha(marked ? 70 : 40), Ui.glass),
                Color.alphaBlend(accent.withAlpha(12), Ui.glass),
              ]),
              border: Border.all(
                color: s.focused ? Colors.white : accent.withAlpha(marked ? 255 : 170),
                width: s.focused || marked ? 2.5 : 1.5,
              ),
              boxShadow: [BoxShadow(color: accent.withAlpha(s.highlighted || marked ? 130 : 50), blurRadius: marked ? 22 : 12)],
            ),
            child: Stack(clipBehavior: Clip.none, children: [
              Center(child: Glyph(WeaponGlyph(w.id, tier: w.tier), size: 40)),
              // Stufe als kleines Abzeichen oben rechts
              Positioned(
                right: -4,
                top: -4,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                  decoration: BoxDecoration(
                    color: t.color,
                    borderRadius: BorderRadius.circular(8),
                    boxShadow: [BoxShadow(color: t.color.withAlpha(120), blurRadius: 8)],
                  ),
                  child: Text(t.label, style: numberStyle(10, const Color(0xFF0A0F24))),
                ),
              ),
            ]),
          ),
          const SizedBox(height: 4),
          // Klassen als Punkte, Gaben-Plätze als Rauten (gefüllt = belegt)
          Row(mainAxisSize: MainAxisSize.min, children: [
            for (final c in w.classes) _dot(c.color),
            const SizedBox(width: 4),
            for (var g = 0; g < maxGifts(w.tier); g++) _diamond(g < w.gifts.length),
          ]),
        ]),
      ),
    );
  }

  Widget _dot(Color c) => Container(
        width: 7,
        height: 7,
        margin: const EdgeInsets.symmetric(horizontal: 1.5),
        decoration: BoxDecoration(shape: BoxShape.circle, color: c, boxShadow: [BoxShadow(color: c.withAlpha(150), blurRadius: 5)]),
      );

  Widget _diamond(bool filled) => Transform.rotate(
        angle: pi / 4,
        child: Container(
          width: 6,
          height: 6,
          margin: const EdgeInsets.symmetric(horizontal: 2),
          decoration: BoxDecoration(
            color: filled ? Palette.purple : Colors.transparent,
            border: Border.all(color: Palette.purple.withAlpha(filled ? 255 : 150), width: 1),
          ),
        ),
      );

  /// Aktionsleiste für die gewählte Waffe (bzw. Hinweis beim Abgeben einer Gabe).
  Widget _weaponBar(RunState r) {
    final donor = _donor, sel = _selected;
    if (donor != null && donor < r.weapons.length) {
      final d = r.weapons[donor];
      return Padding(
        padding: const EdgeInsets.only(top: 4),
        child: Row(children: [
          Expanded(
            child: classText('Gabe „${weaponGifts[d.id]!.name}“ (${d.def.cls.label}): Wähle die Waffe, die sie erhält.',
                bodyText(12.5, color: Palette.purple)),
          ),
          Inspectable(
            radius: 8,
            info: (_) => _giftHint(d),
            child: _slotButton('↺', 'abbrechen', base: Ui.slot, active: Palette.coral.withAlpha(90),
                onPressed: () => setState(() => _donor = null)),
          ),
        ]),
      );
    }
    if (sel == null) {
      return Padding(
        padding: const EdgeInsets.only(top: 4),
        child: Text('Waffe antippen: verschmelzen, Gabe abgeben oder verkaufen.', style: mutedStyle),
      );
    }
    final w = r.weapons[sel], t = tiers[w.tier];
    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: Row(children: [
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
            Text('${w.def.name} ${t.label}', maxLines: 1, overflow: TextOverflow.ellipsis, style: displayStyle(14, Ui.cardText)),
            classText(w.classes.map((c) => c.label).join(' + '), bodyText(11.5, color: Ui.cardMuted), maxLines: 1),
          ]),
        ),
        if (r.mergePartner(sel) >= 0)
          Inspectable(
            radius: 8,
            info: (_) => weaponMergePreview(r, w),
            child: _slotButton(
              '⤴ ${tiers[w.tier + 1].label}',
              'verschmelzen',
              base: Palette.mint.withAlpha(40),
              active: Palette.mint.withAlpha(110),
              onPressed: () => setState(() {
                r.merge(sel);
                _selected = r.weapons.indexOf(w);
              }),
            ),
          ),
        if (r.hasGiftTarget(sel))
          Inspectable(
            radius: 8,
            info: (_) => _giftHint(w),
            child: _slotButton('✦', 'Gabe', base: Palette.purple.withAlpha(30), active: Palette.purple.withAlpha(110),
                onPressed: () => setState(() => _donor = sel)),
          ),
        if (r.weapons.length > 1)
          Inspectable(
            radius: 8,
            info: (_) => weaponInfo(r, w.id, w.tier, owned: w),
            child: _slotButton(
              '+${r.sellPrice(w)}',
              'verkaufen',
              base: Ui.slot,
              active: Palette.sun.withAlpha(90),
              onPressed: () => setState(() {
                r.sell(sel);
                _selected = null;
              }),
            ),
          ),
      ]),
    );
  }

  /// Info zum Gabe-Knopf: was diese Waffe weitergibt.
  Widget _giftHint(OwnedWeapon w) {
    final g = weaponGifts[w.id]!;
    return Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
      Text('Gabe „${g.name}“ abgeben', style: displayStyle(15, Palette.purple)),
      const SizedBox(height: 4),
      classText('${g.desc}, dazu Klasse ${w.def.cls.label}.', bodyText(12.5, color: Ui.text)),
      Text('Danach die Waffe wählen, die sie erhält. ${w.def.name} verschwindet.', style: bodyText(12, color: Ui.muted)),
    ]);
  }

  /// Kleiner Knopf im Waffenslot (Verschmelzen, Gabe, Verkaufen).
  Widget _slotButton(
    String label,
    String sub, {
    required Color base,
    required Color active,
    required VoidCallback onPressed,
  }) {
    return Pressable(
      onPressed: onPressed,
      builder: (context, s) => Container(
        margin: const EdgeInsets.only(right: 6),
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
        decoration: BoxDecoration(
          color: s.highlighted ? active : base,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: s.focused ? Colors.white : Ui.edge, width: s.focused ? 2 : 1),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            GlyphText(label, style: numberStyle(12, Ui.cardText)),
            Text(sub, style: bodyText(8.5, color: Ui.cardMuted)),
          ],
        ),
      ),
    );
  }

  // ---------------- Werte ----------------

  Widget _statRow(RunState r, String label, String value, Stat? stat) {
    final row = Padding(
      padding: const EdgeInsets.symmetric(vertical: 2.5, horizontal: 4),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: bodyText(12.5, color: Ui.muted),
            ),
          ),
          Text(value, style: numberStyle(14)),
        ],
      ),
    );
    if (stat == null) return row;
    return Inspectable(focusable: true, radius: 8, info: (_) => statInfo(r, stat), child: row);
  }

  Widget _stats(RunState r) {
    String v(Stat s) => '${fmtNum(r.stat(s))}${s.unit.isEmpty ? '' : ' ${s.unit}'}';
    final rows = <(String, String, Stat?)>[
      for (final s in Stat.values) (s == Stat.regen ? 'Regen. / 5 s' : s.label, v(s), s),
      ('Level', '${r.level}', null),
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ..._sets(r),
        sectionTitle('Werte'),
        Container(
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
          decoration: BoxDecoration(
            color: Ui.slot,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: Ui.panelLine, width: 2),
          ),
          child: LayoutBuilder(
            builder: (context, box) {
              final colW = (box.maxWidth - 16) / 2;
              return Wrap(
                spacing: 16,
                children: [
                  for (final (label, value, stat) in rows)
                    SizedBox(width: colW, child: _statRow(r, label, value, stat)),
                ],
              );
            },
          ),
        ),
      ],
    );
  }
}

/// Feine Umlaufbahn der Waffen um den Vogel.
class _OrbitPainter extends CustomPainter {
  _OrbitPainter(this.center, this.rx, this.ry);
  final Offset center;
  final double rx, ry;

  @override
  void paint(Canvas c, Size size) {
    final rect = Rect.fromCenter(center: center, width: rx * 2, height: ry * 2);
    c.drawOval(rect, Paint()..color = const Color(0x10CFE3FF));
    c.drawOval(
        rect,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.2
          ..color = Ui.panelLine);
  }

  @override
  bool shouldRepaint(_OrbitPainter old) => old.center != center || old.rx != rx || old.ry != ry;
}
