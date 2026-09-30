import 'package:flutter/material.dart';

import '../game/config.dart';
import '../game/federfeuer_game.dart';
import '../game/run_state.dart';
import 'widgets.dart';

class ShopOverlay extends StatefulWidget {
  const ShopOverlay({super.key, required this.game});
  final FederfeuerGame game;

  @override
  State<ShopOverlay> createState() => _ShopOverlayState();
}

class _ShopOverlayState extends State<ShopOverlay> {
  FederfeuerGame get game => widget.game;

  static const _cardW = 176.0, _cardH = 222.0;
  static const _itemAccent = Color(0xFFFFB86B);

  @override
  Widget build(BuildContext context) {
    final r = game.run!;
    final next = biomeForWave(r.wave + 1);
    return Panel(
      maxWidth: 960,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          PanelHeader(
            title: 'WELLE ${r.wave} GESCHAFFT',
            subtitle: Wrap(spacing: 6, runSpacing: 6, children: [
              if (r.goalBonus != null)
                Pill('Ziel erreicht: +${r.goalBonus} Zeitbonus', icon: '🏁', color: const Color(0x407CF29C)),
              if (next != biomeForWave(r.wave))
                Pill('Nächste Welt: ${biomeDefs[next]!.name}', icon: '🗺', color: const Color(0x40B36BFF)),
            ]),
            trailing: MoneyPill(r.money),
          ),
          Row(children: [
            sectionTitle('Angebote'),
            const Spacer(),
            GameButton(
              label: 'Neu würfeln · ${r.rerollCost}',
              icon: '🎲',
              size: 14,
              color: Ui.card,
              onPressed: r.money >= r.rerollCost ? () => setState(() => r.reroll(game.rng)) : null,
            ),
          ]),
          Wrap(spacing: 12, runSpacing: 4, children: [
            for (var i = 0; i < r.offers.length; i++) _offer(r, i),
          ]),
          LayoutBuilder(builder: (context, box) {
            final left = _inventory(r), right = _stats(r);
            if (box.maxWidth > 680) {
              return Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Expanded(flex: 14, child: left),
                const SizedBox(width: 24),
                Expanded(flex: 10, child: right),
              ]);
            }
            return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [left, right]);
          }),
          const SizedBox(height: 10),
          Align(
            alignment: Alignment.centerRight,
            child: GameButton(
              label: isBossWave(r.wave + 1) ? 'Zum Gipfel: Boss' : 'Welle ${r.wave + 1} starten',
              icon: '▶',
              size: 20,
              color: Palette.mint,
              onPressed: game.nextWave,
            ),
          ),
        ],
      ),
    );
  }

  void _buy(int i) => setState(() => game.run!.buy(i));

  // ---------------- Angebote ----------------

  Widget _offer(RunState r, int i) {
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
        badgeColor: mergeNow || pair ? Palette.good : Palette.ink,
        icon: d.icon,
        title: d.name,
        width: _cardW,
        height: _cardH,
        body: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(d.desc, maxLines: 2, overflow: TextOverflow.ellipsis, style: bodyText(12, color: Ui.cardMuted)),
          const Spacer(),
          _line('Schaden', '${fmtNum(s.dmg)}${d.count > 1 ? ' ×${d.count}' : ''}'),
          _line('Tempo', '${s.cooldown.toStringAsFixed(2)} s'),
          _line('Reichweite', '${s.range.round()}'),
          const SizedBox(height: 8),
        ]),
        footer: CardFooter(
          ok ? PriceTag(o.price) : const Text('Slots voll'),
          color: ok && !poor ? Palette.sun : const Color(0xFFD9D2E3),
        ),
        onPressed: poor || !ok ? null : () => _buy(i),
      );
    }

    final it = itemById[o.id]!;
    return ChoiceCard(
      accent: _itemAccent,
      badge: 'ITEM',
      icon: it.icon,
      title: it.name,
      width: _cardW,
      height: _cardH,
      body: ModsText(it.mods),
      footer: CardFooter(PriceTag(o.price), color: poor ? const Color(0xFFD9D2E3) : Palette.sun),
      onPressed: poor ? null : () => _buy(i),
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
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Text('✓', style: displayStyle(34, Palette.mint)),
            Text('Gekauft', style: displayStyle(16, Ui.muted)),
          ]),
        ),
      );

  Widget _line(String label, String value) => Row(children: [
        Expanded(child: Text(label, style: bodyText(12, color: Ui.cardMuted))),
        Text(value, style: bodyText(12.5, color: Palette.ink, weight: 900)),
      ]);

  // ---------------- Inventar ----------------

  Widget _inventory(RunState r) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      sectionTitle('Waffen ${r.weapons.length}/6'),
      Wrap(spacing: 8, runSpacing: 6, children: [
        for (var i = 0; i < 6; i++) i < r.weapons.length ? _weaponSlot(r, i) : _emptySlot(),
      ]),
      sectionTitle('Items'),
      if (r.items.isEmpty)
        Text('Noch keine', style: mutedStyle)
      else
        Wrap(spacing: 6, runSpacing: 6, children: [
          for (final e in r.items.entries)
            Tooltip(
              message: itemById[e.key]!.name,
              child: Pill(e.value > 1 ? '${itemById[e.key]!.name} ×${e.value}' : itemById[e.key]!.name,
                  icon: itemById[e.key]!.icon),
            ),
        ]),
    ]);
  }

  static const _slotW = 232.0, _slotH = 46.0;

  Widget _emptySlot() => Container(
        width: _slotW,
        height: _slotH,
        decoration: BoxDecoration(
          color: Ui.slot,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Ui.panelLine, width: 2),
        ),
      );

  Widget _weaponSlot(RunState r, int i) {
    final w = r.weapons[i], t = tiers[w.tier];
    return Container(
      width: _slotW,
      height: _slotH,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: Ui.card,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Palette.ink, width: 2.5),
      ),
      child: Row(children: [
        Container(width: 8, color: t.color),
        const SizedBox(width: 7),
        Text(w.def.icon, style: const TextStyle(fontSize: 20)),
        const SizedBox(width: 6),
        Expanded(
          child: Column(mainAxisAlignment: MainAxisAlignment.center, crossAxisAlignment: CrossAxisAlignment.start, children: [
            FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(w.def.name, maxLines: 1, style: displayStyle(13, Palette.ink)),
            ),
            Text('Stufe ${t.label}', style: bodyText(11, color: Ui.cardMuted)),
          ]),
        ),
        if (r.mergePartner(i) >= 0)
          _slotButton(
            '⤴ ${tiers[w.tier + 1].label}',
            'verschmelzen',
            base: const Color(0xFFC4F5D2),
            active: Palette.mint,
            onPressed: () => setState(() => r.merge(i)),
          ),
        if (r.weapons.length > 1)
          _slotButton(
            '+${r.sellPrice(w)}',
            'verkaufen',
            base: const Color(0xFFEDE3F7),
            active: Palette.sun,
            onPressed: () => setState(() => r.sell(i)),
          ),
      ]),
    );
  }

  /// Kleiner Knopf im Waffenslot (Verschmelzen, Verkaufen).
  Widget _slotButton(String label, String sub,
      {required Color base, required Color active, required VoidCallback onPressed}) {
    return Pressable(
      onPressed: onPressed,
      builder: (context, s) => Container(
        margin: const EdgeInsets.only(right: 6),
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
        decoration: BoxDecoration(
          color: s.highlighted ? active : base,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: s.focused ? Palette.purple : Palette.ink, width: s.focused ? 3 : 2),
        ),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Text(label, style: displayStyle(12, Palette.ink)),
          Text(sub, style: bodyText(8.5, color: Ui.cardMuted)),
        ]),
      ),
    );
  }

  // ---------------- Werte ----------------

  Widget _stats(RunState r) {
    String v(Stat s) => '${fmtNum(r.stat(s))}${s.unit.isEmpty ? '' : ' ${s.unit}'}';
    final rows = <(String, String)>[
      for (final s in Stat.values) (s == Stat.regen ? 'Regen. / 5 s' : s.label, v(s)),
      ('Level', '${r.level}'),
    ];
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      sectionTitle('Werte'),
      Container(
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
        decoration: BoxDecoration(
          color: Ui.slot,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: Ui.panelLine, width: 2),
        ),
        child: LayoutBuilder(builder: (context, box) {
          final colW = (box.maxWidth - 16) / 2;
          return Wrap(spacing: 16, children: [
            for (final (label, value) in rows)
              SizedBox(
                width: colW,
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 2.5),
                  child: Row(children: [
                    Expanded(child: Text(label, maxLines: 1, overflow: TextOverflow.ellipsis, style: bodyText(12.5, color: Ui.muted))),
                    Text(value, style: displayStyle(14)),
                  ]),
                ),
              ),
          ]);
        }),
      ),
    ]);
  }
}
