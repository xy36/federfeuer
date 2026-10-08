import 'dart:collection';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:gamepads/gamepads.dart';

import '../game/config.dart';
import '../game/federfeuer_game.dart';
import '../game/gamepad_input.dart' show ModalMenu, controllerActive, openModalMenu;
import '../game/run_state.dart';
import 'bird_preview.dart';
import 'controls_editor.dart' show ShortcutHint;
import 'fusion.dart';
import 'inspect.dart';
import 'inspect_info.dart';
import 'radial_menu.dart';
import 'stats_page.dart';
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
    if (identical(openModalMenu, _picker)) openModalMenu = null;
    for (final n in _tileNodes.values) {
      n.dispose();
    }
    for (final n in _sections) {
      n.dispose();
    }
    super.dispose();
  }

  /// Eigene Seite mit allen Werten offen?
  bool _statsOpen = false;

  void _hotkey(ShopHotkey key) {
    final r = game.run!;
    if (_fusion != null || r.traitChoice != null) return; // Animation bzw. Eigenschafts-Wahl läuft
    switch (key) {
      case ShopHotkey.stats:
        setState(() => _statsOpen = true);
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
    _syncPicking(r);
    final next = biomeForWave(r.wave + 1);
    final panel = Panel(
      maxWidth: 960,
      hints: const [
        (GamepadButton.a, 'Kaufen'),
        (GamepadButton.x, 'Neu würfeln'),
        (GamepadButton.y, 'Zurückhalten'),
        (GamepadButton.b, 'Info schließen'),
        (GamepadButton.leftBumper, '/ RB Bereich'),
        (GamepadButton.start, 'Welle starten'),
      ],
      footer: _blockWhenPicking(Row(
        children: [
          MoneyPill(r.money),
          const SizedBox(width: 12),
          // Tastatur: Kurztasten auf einen Blick (Controller zeigt sie in der Hinweiszeile)
          Expanded(
            child: ValueListenableBuilder<bool>(
              valueListenable: controllerActive,
              builder: (context, pad, _) => pad || isTouchPlatform
                  ? const SizedBox.shrink()
                  : GlyphText('R würfeln · L zurückhalten · C Werte · Bild ↑↓ Bereich',
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
      )),
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
          _blockWhenPicking(Row(
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
          )),
          _blockWhenPicking(_sectionArea(
            0,
            Wrap(spacing: 12, runSpacing: 4, children: [for (var i = 0; i < r.offers.length; i++) _offer(r, i)]),
          )),
          LayoutBuilder(
            builder: (context, box) {
              final left = _sectionArea(1, _inventory(r)), right = _blockWhenPicking(_sectionArea(2, _stats(r)));
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
    return CallbackShortcuts(
      bindings: {
        const SingleActivator(LogicalKeyboardKey.escape): () {
          if (_picking) _picker.close();
        },
      },
      child: Stack(
      fit: StackFit.expand,
      children: [
        // Während der Eigenschafts-Wahl bzw. auf der Werte-Seite ist der Shop dahinter nicht ansteuerbar
        ExcludeFocus(excluding: choice != null || _statsOpen, child: panel),
        if (choice != null) _traitChooser(r, choice),
        if (_statsOpen && choice == null) StatsPage(run: r, onClose: () => setState(() => _statsOpen = false)),
        if (f != null) FusionAnimation(a: f.$1, b: f.$2, result: f.$3, onDone: () => setState(() => _fusion = null)),
      ],
    ),
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

  /// Waffe, die gerade ihre Gabe abgibt bzw. aus der Reserve getauscht wird (Ziel wird gewählt).
  OwnedWeapon? _donor, _swap;

  /// Waffen-Angebot, das gerade direkt als Gabe gekauft wird ([_donor] ist dann eine Vorschau-Waffe).
  int? _giftOffer;

  void _cancelGift() {
    _donor = null;
    _giftOffer = null;
  }

  /// Ziel wählen (Gabe abgeben/kaufen, aus der Reserve tauschen): nur gültige Ziele und
  /// „abbrechen“ sind ansteuerbar, der Rest ist gedimmt und gesperrt; Esc/B brechen ab.
  bool get _picking => _donor != null || _swap != null;
  late final _picker = _Picker(() => setState(() {
        _cancelGift();
        _swap = null;
      }));
  bool _wasPicking = false;

  /// Fokusknoten der Waffenkacheln (Controller springt beim Zielwählen aufs erste Ziel).
  final _tileNodes = HashMap<OwnedWeapon, FocusNode>.identity();

  FocusNode _tileNode(OwnedWeapon w) => _tileNodes.putIfAbsent(w, () => FocusNode(debugLabel: 'Waffe ${w.id}'));

  void _syncPicking(RunState r) {
    final picking = _picking;
    // Kacheln verkaufter/verschmolzener Waffen aufräumen
    final gone = _tileNodes.keys.where((w) => !r.allWeapons.any((o) => identical(o, w))).toList();
    if (picking == _wasPicking && gone.isEmpty) return;
    final entering = picking && !_wasPicking;
    _wasPicking = picking;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      for (final w in gone) {
        _tileNodes.remove(w)?.dispose();
      }
      if (!mounted) return;
      // Übernimmt den Platz auch vom gerade schließenden Kreismenü (dieses gibt nur sich selbst frei)
      if (picking) openModalMenu = _picker;
      if (!picking && identical(openModalMenu, _picker)) openModalMenu = null;
      if (entering) {
        final first = r.allWeapons.where(_isTarget).map((w) => _tileNodes[w]).nonNulls.firstOrNull;
        first?.requestFocus();
      }
    });
  }

  bool _isTarget(OwnedWeapon w) {
    final r = game.run!, donor = _donor, swap = _swap;
    if (donor != null) return r.canGiftTo(donor, w);
    if (swap != null) return r.weapons.contains(w);
    return false;
  }

  /// Beim Zielwählen gesperrt und gedimmt.
  Widget _blockWhenPicking(Widget child, {bool block = true}) {
    final b = block && _picking;
    return ExcludeFocus(
      excluding: b,
      child: IgnorePointer(
        ignoring: b,
        child: AnimatedOpacity(opacity: b ? 0.35 : 1, duration: const Duration(milliseconds: 150), child: child),
      ),
    );
  }

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
  /// Angebot, dessen Kreismenü offen ist.
  int? _offerMenu;

  /// Angebotskarte; Antippen öffnet das Kreismenü (kaufen, als Gabe, zurückhalten).
  Widget _offer(RunState r, int i) {
    final o = r.offers[i];
    if (_offerMenu == i && (o.sold || _picking)) _offerMenu = null;
    return Focus(
      canRequestFocus: false,
      skipTraversal: true,
      onFocusChange: (v) {
        if (v) _focusedOffer = i;
      },
      child: o.sold
          ? _offerCard(r, i)
          : RadialMenu(
              open: _offerMenu == i,
              options: _offerMenu == i ? _offerOptions(r, i) : const [],
              onClose: () => setState(() {
                if (_offerMenu == i) _offerMenu = null;
              }),
              innerRadius: 34,
              thickness: 56,
              child: Stack(clipBehavior: Clip.none, children: [
                Inspectable(
                  radius: 16,
                  info: (_) => o.isWeapon
                      ? weaponInfo(r, o.id, o.tier, price: o.price, loadout: true)
                      : itemInfo(r, o.id, price: o.price),
                  child: _offerCard(r, i),
                ),
                // Zurückgehalten: Schloss-Abzeichen an der Karte
                if (o.locked)
                  Positioned(
                    key: ValueKey('lock-badge-$i'),
                    left: -6,
                    top: -2,
                    child: IgnorePointer(
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                        decoration: BoxDecoration(
                          color: Palette.sun,
                          borderRadius: BorderRadius.circular(10),
                          boxShadow: [BoxShadow(color: Palette.sun.withAlpha(120), blurRadius: 10)],
                        ),
                        child: GlyphText('🔒', style: bodyText(11, color: const Color(0xFF0A0F24), weight: 900)),
                      ),
                    ),
                  ),
              ]),
            ),
    );
  }

  /// Wahlmöglichkeiten im Kreismenü eines Angebots; nicht mögliche bleiben grau mit Grund.
  List<RadialOption> _offerOptions(RunState r, int i) {
    final o = r.offers[i], poor = r.money < o.price;
    final opts = <RadialOption>[];
    if (o.isWeapon) {
      final ok = r.canAddWeapon(o.id, o.tier), mergeNow = r.mergesOnBuy(o.id, o.tier);
      opts.add(RadialOption(
        price: o.price,
        label: !ok ? 'Slots voll' : (poor ? 'zu teuer' : (mergeNow ? 'kaufen ⤴ ${tiers[o.tier + 1].label}' : 'kaufen')),
        color: Palette.mint,
        onPressed: ok && !poor ? () => _buy(i) : null,
      ));
      if (r.offerHasGiftTarget(i)) {
        opts.add(RadialOption(
          icon: '✦',
          label: poor ? 'zu teuer' : 'als Gabe',
          color: Palette.purple,
          onPressed: poor
              ? null
              : () => setState(() {
                    _swap = null;
                    _sel = null;
                    _giftOffer = i;
                    _donor = OwnedWeapon(o.id, o.tier);
                  }),
        ));
      }
    } else {
      opts.add(RadialOption(
        price: o.price,
        label: poor ? 'zu teuer' : 'kaufen',
        color: Palette.mint,
        onPressed: poor ? null : () => _buy(i),
      ));
    }
    opts.add(RadialOption(
      icon: o.locked ? '🔓' : '🔒',
      label: o.locked ? 'freigeben' : 'zurückhalten',
      color: Palette.sun,
      onPressed: () => setState(() => r.toggleLock(i)),
    ));
    return opts;
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
        onPressed: () => setState(() => _offerMenu = i),
        // Zu teuer oder kein Platz: grau, öffnet aber das Kreismenü (Grund, Zurückhalten, als Gabe)
        dimmed: poor || !ok,
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
      onPressed: () => setState(() => _offerMenu = i),
      dimmed: poor,
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
        sectionTitle('Waffen ${r.weapons.length}/${r.maxWeapons}'
            '${r.weaponSlotCap > r.maxWeapons ? ' · ${r.weaponSlotCap - r.maxWeapons} gesperrt' : ''}'),
        _weaponRing(r),
        _reserveRow(r),
        _weaponBar(r),

        sectionTitle('Items'),
        if (r.items.isEmpty)
          Text('Noch keine', style: mutedStyle)
        else
          _blockWhenPicking(Wrap(
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
          )),
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
      final nextAt = nextSetAt(n);
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

  // ---------------- Waffenring und Reserve ----------------

  /// Gewählte Waffe (aktiv oder Reserve), für die die Aktionsleiste gilt.
  OwnedWeapon? _sel;

  static const _ringH = 270.0, _tile = 62.0;

  bool _owned(RunState r, OwnedWeapon? w) => w != null && r.allWeapons.any((o) => identical(o, w));

  /// Eigene Waffen schweben wie im Spiel im Kreis um den Vogel; freie Plätze leer,
  /// noch gesperrte mit Schloss (Waffengurt oder Torwächter).
  Widget _weaponRing(RunState r) {
    if (!_owned(r, _sel)) _sel = null;
    final gi = _giftOffer, donor = _donor;
    if (gi != null) {
      // Angebot inzwischen verkauft, neu gewürfelt oder zu teuer: Auswahl verwerfen
      if (gi >= r.offers.length ||
          donor == null ||
          r.offers[gi].id != donor.id ||
          !r.offerHasGiftTarget(gi) ||
          r.money < r.offers[gi].price) {
        _cancelGift();
      }
    } else if (!_owned(r, donor)) {
      _donor = null;
    }
    if (!_owned(r, _swap)) _swap = null;
    return LayoutBuilder(builder: (context, box) {
      final w = box.maxWidth, cx = w / 2, cy = _ringH / 2 - 6;
      final rx = min(w / 2 - 44, 200.0), ry = 92.0, n = r.weaponSlotCap;
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
              child: k < r.weapons.length
                  ? _weaponTile(r, r.weapons[k], key: ValueKey('weapon-tile-$k'))
                  : _blockWhenPicking(k < r.maxWeapons ? _emptyTile('frei') : _lockedTile()),
            ),
        ]),
      );
    });
  }

  Widget _emptyTile(String label, {double size = _tile}) => Column(mainAxisSize: MainAxisSize.min, children: [
        Container(
          width: size,
          height: size,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: Ui.slot,
            border: Border.all(color: Ui.panelLine, width: 1.5),
          ),
          child: Text(label, style: bodyText(11, color: Ui.muted)),
        ),
      ]);

  /// Noch gesperrter Platz: Schloss, Hinweis im Info-Panel.
  Widget _lockedTile() => Inspectable(
        focusable: true,
        radius: 40,
        info: (_) => Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
          Text('Gesperrter Waffenplatz', style: displayStyle(15, Ui.text)),
          const SizedBox(height: 4),
          Text('Freischalten mit einem Waffengurt aus dem Shop oder durch einen besiegten Torwächter.',
              style: bodyText(12.5, color: Ui.muted)),
        ]),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Container(
            width: _tile,
            height: _tile,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: const Color(0x14050814),
              border: Border.all(color: Ui.panelLine.withAlpha(90), width: 1.2),
            ),
            child: GlyphText('🔒', style: bodyText(18, color: Ui.muted)),
          ),
        ]),
      );

  /// Reserve: zwei kleine Plätze unter dem Ring.
  Widget _reserveRow(RunState r) => Padding(
        padding: const EdgeInsets.only(top: 2, bottom: 2),
        child: Row(children: [
          Text('RESERVE', style: displayStyle(11, Ui.muted).copyWith(letterSpacing: 1.5)),
          const SizedBox(width: 10),
          for (var k = 0; k < kReserveSlots; k++)
            Padding(
              padding: const EdgeInsets.only(right: 10),
              child: SizedBox(
                width: 64,
                child: k < r.reserve.length
                    ? _weaponTile(r, r.reserve[k], key: ValueKey('reserve-tile-$k'), size: 48)
                    : _emptyTile('frei', size: 48),
              ),
            ),
          Expanded(
            child: Text('feuert nicht, kein Set-Bonus – Partner und Gaben-Spender',
                style: bodyText(11, color: Ui.muted), maxLines: 2),
          ),
        ]),
      );

  void _tap(RunState r, OwnedWeapon w) => setState(() {
        final donor = _donor, swap = _swap;
        if (donor != null) {
          final gi = _giftOffer;
          if (identical(w, donor)) {
            _donor = null;
          } else if (gi != null) {
            if (r.buyAsGift(gi, w)) {
              _cancelGift();
              _sel = null; // kein Kreismenü direkt danach
            }
          } else if (r.canGiftTo(donor, w)) {
            r.giftTo(donor, w);
            _donor = null;
            _sel = null;
          }
          return;
        }
        if (swap != null) {
          if (identical(w, swap)) {
            _swap = null;
          } else if (r.weapons.contains(w)) {
            r.swapWeapons(swap, w);
            _swap = null;
            _sel = null;
          }
          return;
        }
        _sel = identical(_sel, w) ? null : w;
      });

  Widget _weaponTile(RunState r, OwnedWeapon w, {Key? key, double size = _tile}) {
    final t = tiers[w.tier];
    final sel = _sel, donor = _donor, swap = _swap;
    final selected = identical(sel, w);
    final partner = donor == null && swap == null && sel != null && identical(r.partnerFor(sel), w);
    final target = donor != null && r.canGiftTo(donor, w);
    final swapTarget = swap != null && r.weapons.contains(w);
    final picking = identical(donor, w) || identical(swap, w);
    final accent = target
        ? Palette.purple
        : (swapTarget ? Palette.cyan : (partner ? Palette.mint : (selected || picking ? Palette.sun : t.color)));
    final marked = selected || partner || target || swapTarget || picking;
    // Beim Zielwählen nur die Ziele ansteuerbar; die abgebende Waffe bleibt hell, ist aber gesperrt
    final blocked = _picking && !target && !swapTarget;
    final menuOpen = selected && donor == null && swap == null;
    return ExcludeFocus(
      excluding: blocked,
      child: IgnorePointer(
        ignoring: blocked,
        child: AnimatedOpacity(
          opacity: blocked && !picking ? 0.35 : 1,
          duration: const Duration(milliseconds: 150),
          child: Inspectable(
      key: key,
      radius: 40,
      info: (_) => target
          ? weaponGiftPreview(r, donor, w, price: _giftOffer == null ? null : r.offers[_giftOffer!].price)
          : weaponInfo(r, w.id, w.tier, owned: w, loadout: true),
      child: Pressable(
        focusNode: _tileNode(w),
        onPressed: () => _tap(r, w),
        builder: (context, s) => Column(mainAxisSize: MainAxisSize.min, children: [
          RadialMenu(
            open: menuOpen,
            options: selected ? _weaponOptions(r, w) : const [],
            onClose: () => setState(() {
              if (identical(_sel, w)) _sel = null;
            }),
            innerRadius: size / 2 + 10,
            thickness: size < _tile ? 48 : 52,
            child: AnimatedContainer(
            duration: const Duration(milliseconds: 120),
            width: size,
            height: size,
            // Mit offenem Kreismenü nicht anheben, sonst sitzt der Ring versetzt
            transform: Matrix4.translationValues(0, !menuOpen && (s.highlighted || marked) ? -3 : 0, 0),
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
              Center(child: Glyph(WeaponGlyph(w.id, tier: w.tier), size: size * 0.65)),
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
          )),
          const SizedBox(height: 4),
          // Klassen als Punkte, Gaben-Plätze als Rauten (gefüllt = belegt)
          Row(mainAxisSize: MainAxisSize.min, children: [
            for (final c in w.classes) _dot(c.color),
            const SizedBox(width: 4),
            for (var g = 0; g < maxGifts(w.tier); g++) _diamond(g < w.gifts.length),
          ]),
        ]),
      ),
    ),
        ),
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

  Widget _hintRow(String text, Color color, VoidCallback cancel, Widget info) => Padding(
        padding: const EdgeInsets.only(top: 4),
        child: Row(children: [
          Expanded(child: classText(text, bodyText(12.5, color: color))),
          Inspectable(
            radius: 8,
            info: (_) => info,
            child: _slotButton('↺', 'abbrechen', base: Ui.slot, active: Palette.coral.withAlpha(90), onPressed: () => setState(cancel)),
          ),
        ]),
      );

  /// Hinweiszeile unter Ring und Reserve (bzw. Hinweis beim Abgeben einer Gabe oder Tauschen).
  Widget _weaponBar(RunState r) {
    final donor = _donor, swap = _swap, w = _sel;
    if (donor != null) {
      final price = _giftOffer == null ? null : r.offers[_giftOffer!].price;
      return _hintRow(
          '${price == null ? 'Gabe' : 'Gabe kaufen ($price)'} „${weaponGifts[donor.id]!.name}“ (${donor.def.cls.label}): '
          'Wähle die Waffe, die sie erhält.',
          Palette.purple,
          _cancelGift,
          _giftHint(donor, price: price));
    }
    if (swap != null) {
      return _hintRow('${swap.def.name} einsetzen: Wähle die aktive Waffe, die dafür in die Reserve geht.', Palette.cyan,
          () => _swap = null, weaponInfo(r, swap.id, swap.tier, owned: swap, loadout: true));
    }
    if (w == null) {
      return Padding(
        padding: const EdgeInsets.only(top: 4),
        child: Text('Waffe antippen: verschmelzen, Gabe abgeben, Reserve oder verkaufen.', style: mutedStyle),
      );
    }
    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: Row(children: [
        Text('${w.def.name} ${tiers[w.tier].label}${r.reserve.contains(w) ? ' · Reserve' : ''}  ',
            maxLines: 1, style: displayStyle(14, Ui.cardText)),
        Expanded(
          child: classText(w.classes.map((c) => c.label).join(' + '), bodyText(11.5, color: Ui.cardMuted), maxLines: 1),
        ),
      ]),
    );
  }

  /// Wahlmöglichkeiten im Kreismenü einer eigenen Waffe.
  List<RadialOption> _weaponOptions(RunState r, OwnedWeapon w) {
    final inReserve = r.reserve.contains(w);
    return [
      if (r.partnerFor(w) != null)
        RadialOption(
          icon: '⤴ ${tiers[w.tier + 1].label}',
          label: 'verschmelzen',
          color: Palette.mint,
          onPressed: () => setState(() => r.mergeWeapon(w)),
        ),
      if (r.hasGiftTargetFor(w))
        RadialOption(
          icon: '✦',
          label: 'Gabe',
          color: Palette.purple,
          onPressed: () => setState(() => _donor = w),
        ),
      if (inReserve && !r.slotsFull)
        RadialOption(icon: '↑', label: 'einsetzen', color: Palette.cyan, onPressed: () => setState(() => r.toActive(w)))
      else if (inReserve && r.weapons.isNotEmpty)
        RadialOption(icon: '↻', label: 'tauschen', color: Palette.cyan, onPressed: () => setState(() => _swap = w))
      else if (!inReserve && !r.reserveFull && r.weapons.length > 1)
        RadialOption(icon: '↓', label: 'Reserve', color: Palette.cyan, onPressed: () => setState(() => r.toReserve(w))),
      if (inReserve || r.weapons.length > 1)
        RadialOption(
          price: r.sellPrice(w),
          gain: true,
          label: 'verkaufen',
          color: Palette.sun,
          onPressed: () => setState(() => r.sellWeapon(w)),
        ),
    ];
  }

  /// Info zum Gabe-Knopf: was diese Waffe weitergibt.
  Widget _giftHint(OwnedWeapon w, {int? price}) {
    final g = weaponGifts[w.id]!;
    return Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
      Text(price == null ? 'Gabe „${g.name}“ abgeben' : 'Nur die Gabe „${g.name}“ kaufen',
          style: displayStyle(15, Palette.purple)),
      const SizedBox(height: 4),
      classText('${g.desc}, dazu Klasse ${w.def.cls.label}.', bodyText(12.5, color: Ui.text)),
      Text(
          price == null
              ? 'Danach die Waffe wählen, die sie erhält. ${w.def.name} verschwindet.'
              : 'Danach die Waffe wählen, die sie erhält. Kostet $price, ${w.def.name} belegt keinen Platz.',
          style: bodyText(12, color: Ui.muted)),
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

  /// Die wichtigsten Werte im Shop; alle mit Herkunft und Wirkung auf der Werte-Seite.
  static const _keyStats = [Stat.maxHp, Stat.dmg, Stat.atk, Stat.crit, Stat.armor, Stat.luck];

  Widget _stats(RunState r) {
    String v(Stat s) => '${fmtNum(r.stat(s))}${s.unit.isEmpty ? '' : ' ${s.unit}'}';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ..._sets(r),
        Row(children: [
          Expanded(child: sectionTitle('Werte')),
          const ShortcutHint(keyLabel: 'C', pad: GamepadButton.back),
          GameButton(
            label: 'Alle Werte',
            icon: '▸',
            size: 13,
            color: Ui.card,
            onPressed: () => setState(() => _statsOpen = true),
          ),
        ]),
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
                  for (final s in _keyStats) SizedBox(width: colW, child: _statRow(r, s.label, v(s), s)),
                  SizedBox(width: colW, child: _statRow(r, 'Level', '${r.level}', null)),
                ],
              );
            },
          ),
        ),
      ],
    );
  }
}

/// Zielwählen im Shop als modales Menü: B/Esc brechen ab, Kurztasten ruhen, Info-Panels bleiben.
class _Picker implements ModalMenu {
  _Picker(this.onCancel);
  final VoidCallback onCancel;

  @override
  void close() => onCancel();

  @override
  void navigate(TraversalDirection dir) => FocusManager.instance.primaryFocus?.focusInDirection(dir);

  @override
  bool get hidesInfo => false;
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
