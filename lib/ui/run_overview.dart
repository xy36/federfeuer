import 'package:flutter/material.dart';

import '../game/config.dart';
import '../game/run_state.dart';
import 'bird_preview.dart';
import 'inspect.dart';
import 'inspect_info.dart';
import 'widgets.dart';

/// Übersicht über den laufenden Run (Pause): Vogel, Waffen, Items, Aktionen, Set-Boni, Werte.
/// Nur zum Ansehen – jedes Element ist ansteuerbar und zeigt sein Info-Panel.
class RunOverview extends StatelessWidget {
  const RunOverview({super.key, required this.run, required this.worldName});
  final RunState run;
  final String worldName;

  RunState get r => run;

  @override
  Widget build(BuildContext context) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
      _header(),
      LayoutBuilder(builder: (context, box) {
        final left = Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          sectionTitle('Waffen ${r.weapons.length}/${r.maxWeapons}'),
          if (r.weapons.isEmpty) Text('Keine', style: mutedStyle),
          Wrap(spacing: 8, runSpacing: 6, children: [for (final w in r.weapons) _weapon(w)]),
          if (r.reserve.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text('Reserve', style: bodyText(11.5, color: Ui.muted)),
            const SizedBox(height: 4),
            Wrap(spacing: 8, runSpacing: 6, children: [for (final w in r.reserve) _weapon(w)]),
          ],
          sectionTitle('Items'),
          if (r.items.isEmpty) Text('Noch keine', style: mutedStyle),
          Wrap(spacing: 6, runSpacing: 6, children: [
            for (final e in r.items.entries)
              Inspectable(
                focusable: true,
                radius: 999,
                info: (_) => itemInfo(r, e.key),
                child: Pill(e.value > 1 ? '${itemById[e.key]!.name} ×${e.value}' : itemById[e.key]!.name,
                    glyph: ItemGlyph(e.key), color: itemById[e.key]!.rarity.color.withAlpha(40)),
              ),
          ]),
          sectionTitle('Aktionen ${r.actions.length}/$kActionSlots'),
          if (r.actions.isEmpty) Text('Keine', style: mutedStyle),
          Wrap(spacing: 6, runSpacing: 6, children: [
            for (var k = 0; k < r.actions.length; k++)
              Inspectable(
                focusable: true,
                radius: 999,
                info: (_) => actionInfo(r, r.actions[k], k),
                child: Pill('${r.actions[k].label} · ${fmtNum(r.actionCooldown(r.actions[k]))} s',
                    glyph: ActionGlyph(r.actions[k].id),
                    color: r.actions[k].id.evolved ? const Color(0x55FFC94A) : const Color(0x33FFD23F)),
              ),
          ]),
        ]);
        final right = Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          ..._sets(),
          sectionTitle('Werte'),
          _stats(),
        ]);
        if (box.maxWidth < 640) return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [left, right]);
        return Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Expanded(flex: 13, child: left),
          const SizedBox(width: 24),
          Expanded(flex: 10, child: right),
        ]);
      }),
    ]);
  }

  Widget _header() {
    final c = r.character;
    return Row(children: [
      BirdPreview(character: c, size: 64, animate: true),
      const SizedBox(width: 10),
      Expanded(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(c.name, style: displayStyle(20, Color.lerp(c.glow, Colors.white, 0.4)!)),
          const SizedBox(height: 4),
          Wrap(spacing: 6, runSpacing: 6, children: [
            Pill('Level ${r.level}', icon: '⭐'),
            Pill('${r.hp.ceil()} / ${r.maxHp.round()} HP', icon: '❤', color: const Color(0x33FF7A8A)),
            Pill('${r.money}', icon: '◆', color: const Color(0x337CF29C)),
            Pill(isBossWave(r.wave) ? 'Bosswelle' : 'Welle ${r.wave}'),
            Pill(worldName),
            Pill(r.difficultyDef.name),
          ]),
        ]),
      ),
    ]);
  }

  Widget _weapon(OwnedWeapon w) {
    final t = tiers[w.tier];
    return Inspectable(
      focusable: true,
      info: (_) => weaponInfo(r, w.id, w.tier, owned: w, showSell: false, loadout: true),
      child: Container(
        width: 200,
        height: 42,
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          color: Ui.glass,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: t.color.withAlpha(120), width: 1.2),
        ),
        child: Row(children: [
          Container(width: 7, color: t.color),
          const SizedBox(width: 7),
          Glyph(WeaponGlyph(w.id, tier: w.tier), size: 26),
          const SizedBox(width: 6),
          Expanded(
            child: Column(mainAxisAlignment: MainAxisAlignment.center, crossAxisAlignment: CrossAxisAlignment.start, children: [
              FittedBox(fit: BoxFit.scaleDown, child: Text(w.def.name, maxLines: 1, style: displayStyle(12.5, Ui.cardText))),
              classText('Stufe ${t.label} · ${w.classes.map((c) => c.label).join(' + ')}', bodyText(10.5, color: Ui.cardMuted),
                  maxLines: 1),
            ]),
          ),
        ]),
      ),
    );
  }

  List<Widget> _sets() {
    final rows = <Widget>[
      for (final cls in WeaponClass.values)
        if (r.classCount(cls) > 0)
          Inspectable(
            focusable: true,
            radius: 999,
            info: (_) => setInfo(r, cls),
            child: Pill(
              setLevel(r.classCount(cls)) > 0
                  ? '${cls.label} ${r.classCount(cls)}: ${cls.bonusTexts[setLevel(r.classCount(cls)) - 1]}'
                  : '${cls.label} ${r.classCount(cls)}/${nextSetAt(r.classCount(cls))}',
              color: cls.color.withAlpha(setLevel(r.classCount(cls)) > 0 ? 80 : 30),
            ),
          ),
    ];
    if (rows.isEmpty) return const [];
    return [sectionTitle('Set-Boni'), Wrap(spacing: 6, runSpacing: 6, children: rows)];
  }

  Widget _stats() => Container(
        padding: const EdgeInsets.fromLTRB(8, 6, 8, 6),
        decoration: BoxDecoration(
          color: Ui.slot,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: Ui.panelLine, width: 2),
        ),
        child: LayoutBuilder(builder: (context, box) {
          final colW = (box.maxWidth - 12) / 2;
          return Wrap(spacing: 12, children: [
            for (final s in Stat.values)
              SizedBox(
                width: colW,
                child: Inspectable(
                  focusable: true,
                  radius: 8,
                  info: (_) => statInfo(r, s),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 2.5, horizontal: 4),
                    child: Row(children: [
                      Expanded(
                          child: Text(s == Stat.regen ? 'Regen. / 5 s' : s.label,
                              maxLines: 1, overflow: TextOverflow.ellipsis, style: bodyText(12.5, color: Ui.muted))),
                      Text('${fmtNum(r.stat(s))}${s.unit.isEmpty ? '' : ' ${s.unit}'}', style: numberStyle(14)),
                    ]),
                  ),
                ),
              ),
          ]);
        }),
      );
}
