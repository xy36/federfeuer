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

  @override
  Widget build(BuildContext context) {
    final r = game.run!;
    return Panel(
      maxWidth: 940,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(children: [
            Expanded(child: Text('Welle ${r.wave} geschafft', style: headingStyle)),
            MoneyPill(r.money),
          ]),
          if (biomeForWave(r.wave + 1) != biomeForWave(r.wave))
            Text('Nächste Welt: ${biomeDefs[biomeForWave(r.wave + 1)]!.name}',
                style: const TextStyle(color: Palette.purple, fontWeight: FontWeight.w700)),
          if (r.goalBonus != null)
            Text('Ziel erreicht – +${r.goalBonus} Material Zeitbonus',
                style: const TextStyle(color: Palette.good, fontWeight: FontWeight.w700)),
          sectionTitle('Angebote'),
          Wrap(spacing: 10, runSpacing: 10, children: [
            for (var i = 0; i < r.offers.length; i++) _offer(r, i),
          ]),
          const SizedBox(height: 12),
          GameButton(
            label: 'Neu würfeln (${r.rerollCost})',
            color: Palette.card,
            onPressed: r.money >= r.rerollCost ? () => setState(() => r.reroll(game.rng)) : null,
          ),
          LayoutBuilder(builder: (context, box) {
            final left = _inventory(r), right = _stats(r);
            if (box.maxWidth > 640) {
              return Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Expanded(flex: 13, child: left),
                const SizedBox(width: 20),
                Expanded(flex: 10, child: right),
              ]);
            }
            return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [left, right]);
          }),
          const SizedBox(height: 16),
          Align(
            alignment: Alignment.centerRight,
            child: GameButton(
              label: r.wave + 1 == kMaxWave ? 'Bosswelle starten' : 'Welle ${r.wave + 1} starten',
              color: Palette.mint,
              onPressed: game.nextWave,
            ),
          ),
        ],
      ),
    );
  }

  void _buy(int i) => setState(() => game.run!.buy(i));

  Widget _offer(RunState r, int i) {
    final o = r.offers[i];
    if (o.sold) {
      return const SizedBox(
        width: kCardWidth,
        height: 150,
        child: Center(child: Text('Gekauft', style: mutedStyle)),
      );
    }
    final poor = r.money < o.price;
    if (o.isWeapon) {
      final d = weaponDefs[o.id]!, t = tiers[o.tier], s = r.weaponStats(o.id, o.tier);
      final ok = r.canAddWeapon(o.id, o.tier), merge = r.canMerge(o.id, o.tier);
      return InfoCard(
        accent: t.color,
        icon: d.icon,
        title: d.name,
        subtitle: 'Waffe, Stufe ${t.label}',
        body: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(d.desc),
          Text('${fmtNum(s.dmg)} Schaden${d.count > 1 ? ' ×${d.count}' : ''}, alle ${s.cooldown.toStringAsFixed(2)} s'),
          Text('Reichweite ${s.range.round()}'),
          if (merge)
            Text('Verschmilzt zu Stufe ${tiers[o.tier + 1].label}',
                style: const TextStyle(color: Palette.good, fontWeight: FontWeight.w600)),
        ]),
        action: GameButton(label: ok ? '${o.price}' : 'Slots voll', onPressed: poor || !ok ? null : () => _buy(i)),
      );
    }
    final it = itemById[o.id]!;
    return InfoCard(
      accent: Palette.sun,
      icon: it.icon,
      title: it.name,
      subtitle: 'Item',
      body: ModsText(it.mods),
      action: GameButton(label: '${o.price}', onPressed: poor ? null : () => _buy(i)),
    );
  }

  Widget _inventory(RunState r) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      sectionTitle('Waffen ${r.weapons.length}/6'),
      Wrap(spacing: 6, runSpacing: 6, children: [
        for (var i = 0; i < r.weapons.length; i++) _weaponSlot(r, i),
      ]),
      sectionTitle('Items'),
      if (r.items.isEmpty)
        const Text('Noch keine', style: mutedStyle)
      else
        Wrap(spacing: 10, runSpacing: 6, children: [
          for (final e in r.items.entries)
            Tooltip(
              message: itemById[e.key]!.name,
              child: Text('${itemById[e.key]!.icon}${e.value > 1 ? '×${e.value}' : ''}',
                  style: const TextStyle(fontSize: 20)),
            ),
        ]),
    ]);
  }

  Widget _weaponSlot(RunState r, int i) {
    final w = r.weapons[i], t = tiers[w.tier];
    return Container(
      width: 210,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: Palette.card,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Palette.line, width: 2),
      ),
      child: Row(children: [
        Container(width: 6, height: 48, color: t.color),
        const SizedBox(width: 8),
        Text(w.def.icon, style: const TextStyle(fontSize: 20)),
        const SizedBox(width: 8),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
            Text(w.def.name, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13), overflow: TextOverflow.ellipsis),
            Text('Stufe ${t.label}', style: mutedStyle.copyWith(fontSize: 12)),
          ]),
        ),
        if (r.weapons.length > 1)
          Padding(
            padding: const EdgeInsets.only(right: 6),
            child: Pressable(
              onPressed: () => setState(() => r.sell(i)),
              radius: 8,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                decoration: BoxDecoration(
                  border: Border.all(color: Palette.line, width: 2),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text('+${r.sellPrice(w)}',
                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Palette.muted)),
              ),
            ),
          ),
      ]),
    );
  }

  Widget _stats(RunState r) {
    String v(Stat s) => '${fmtNum(r.stat(s))}${s.unit.isEmpty ? '' : ' ${s.unit}'}';
    final rows = <(String, String)>[
      for (final s in Stat.values) (s == Stat.regen ? 'Regeneration (pro 5 s)' : s.label, v(s)),
      ('Level', '${r.level}'),
    ];
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      sectionTitle('Werte'),
      for (final (label, value) in rows)
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 2),
          child: Row(children: [
            Expanded(child: Text(label, style: const TextStyle(fontSize: 14))),
            Text(value, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800)),
          ]),
        ),
    ]);
  }
}
