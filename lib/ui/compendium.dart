import 'package:flutter/material.dart';

import '../game/config.dart';
import '../game/federfeuer_game.dart';
import '../game/progress.dart';
import '../game/run_state.dart';
import '../game/components/draw.dart' show drawEliteMark;
import 'bird_preview.dart';
import 'constellation.dart';
import 'inspect.dart';
import 'inspect_info.dart';
import 'widgets.dart';
import 'workbench.dart';

enum CompendiumTab {
  birds('Vögel'),
  weapons('Waffen'),
  items('Items'),
  actions('Aktionen'),
  recipes('Kombinationen'),
  reactions('Reaktionen'),
  workbench('Werkbank'),
  enemies('Gegner');

  const CompendiumTab(this.label);
  final String label;
}

/// Kompendium: alles, was es gibt – aber nur, was schon einmal gesehen wurde.
/// Unbekanntes erscheint als „?“. Fokus bzw. Maus zeigt Details im Info-Panel.
class CompendiumView extends StatefulWidget {
  const CompendiumView({super.key, required this.game});
  final FederfeuerGame game;

  @override
  State<CompendiumView> createState() => _CompendiumViewState();
}

class _CompendiumViewState extends State<CompendiumView> {
  Progress get p => widget.game.progress;
  CompendiumTab _tab = CompendiumTab.birds;

  /// Neutraler Run für Werte in den Info-Panels (Stufe I, ohne Inventar).
  late final RunState _ref = RunState(null)..actions.clear();

  static String _key(String prefix, String id) => '$prefix:$id';

  (int, int) _count(CompendiumTab t) => switch (t) {
        CompendiumTab.birds => (characterDefs.where((c) => p.hasCharacter(c.id)).length, characterDefs.length),
        CompendiumTab.weapons => (weaponDefs.keys.where((id) => p.hasSeen(_key('w', id))).length, weaponDefs.length),
        CompendiumTab.items => (_items.where((it) => p.hasSeen(_key('i', it.id))).length, _items.length),
        CompendiumTab.actions => (ActionId.values.where((a) => p.hasSeen(_key('a', a.name))).length, ActionId.values.length),
        CompendiumTab.recipes => (actionRecipes.where((r) => p.hasSeen(_key('r', r.result.name))).length, actionRecipes.length),
        CompendiumTab.reactions => (Reaction.values.where((re) => p.hasSeen(_key('k', re.name))).length, Reaction.values.length),
        // Werkbank: kein eigener Inhalt zum Entdecken
        CompendiumTab.workbench => (0, 0),
        CompendiumTab.enemies => (
            EnemyType.values.where((e) => p.hasSeen(_key('e', e.name))).length +
                EliteMod.values.where((m) => p.hasSeen(_key('x', m.name))).length,
            EnemyType.values.length + EliteMod.values.length
          ),
      };

  /// Items ohne Aktions-Items (die stehen unter „Aktionen“).
  static final _items = itemDefs.where((it) => it.action == null).toList();

  @override
  Widget build(BuildContext context) {
    var seen = 0, total = 0;
    for (final t in CompendiumTab.values) {
      final (a, b) = _count(t);
      seen += a;
      total += b;
    }
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text('Entdeckt: $seen / $total', style: bodyText(13, color: Ui.muted, weight: 900)),
      const SizedBox(height: 4),
      Wrap(spacing: 6, children: [
        for (final t in CompendiumTab.values)
          GameButton(
            label: t == CompendiumTab.workbench ? t.label : '${t.label} ${_count(t).$1}/${_count(t).$2}',
            size: 12,
            color: t == _tab ? Palette.sun : Ui.card,
            onPressed: () => setState(() => _tab = t),
          ),
      ]),
      const SizedBox(height: 6),
      switch (_tab) {
        CompendiumTab.birds => _grid([for (final c in characterDefs) _bird(c)]),
        CompendiumTab.weapons => _grid([for (final id in weaponDefs.keys) _weapon(id)]),
        CompendiumTab.items => _grid([for (final it in _items) _item(it)]),
        CompendiumTab.actions => _grid([for (final a in ActionId.values) _action(a)]),
        CompendiumTab.recipes => ActionConstellation(progress: p, reference: _ref),
        CompendiumTab.reactions => _grid([for (final re in Reaction.values) _reaction(re)]),
        CompendiumTab.workbench => Workbench(progress: p, reference: _ref),
        CompendiumTab.enemies => _grid([
            for (final e in EnemyType.values) _enemy(e),
            for (final m in EliteMod.values) _elite(m),
          ]),
      },
    ]);
  }

  Widget _grid(List<Widget> tiles) => Wrap(spacing: 8, runSpacing: 8, children: tiles);

  Widget _tile({required Widget icon, required String name, required Color color, required WidgetBuilder info, bool known = true}) =>
      Inspectable(
        focusable: true,
        radius: 12,
        info: info,
        child: Container(
          width: 98,
          height: 92,
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: known ? Color.alphaBlend(color.withAlpha(30), Ui.glass) : Ui.slot,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: known ? color.withAlpha(150) : Ui.panelLine, width: 1.4),
          ),
          child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
            SizedBox(height: 44, child: Center(child: icon)),
            const SizedBox(height: 4),
            Text(known ? name : '???',
                maxLines: 2,
                textAlign: TextAlign.center,
                overflow: TextOverflow.ellipsis,
                style: bodyText(11, color: known ? Ui.text : Ui.muted, weight: 900)),
          ]),
        ),
      );

  Widget get _unknown => Text('?', style: displayStyle(28, Ui.muted));

  Widget _bird(CharacterDef c) {
    final has = p.hasCharacter(c.id);
    return _tile(
      icon: BirdPreview(character: c, size: 44, locked: !has),
      name: c.name,
      color: c.glow,
      // Vögel sind immer zu sehen (als Silhouette), damit die Aufgaben lesbar sind
      info: (_) => characterInfo(p, c),
    );
  }

  Widget _weapon(String id) {
    final d = weaponDefs[id]!, known = p.hasSeen(_key('w', id));
    return _tile(
      icon: known ? Glyph(WeaponGlyph(id), size: 46) : _unknown,
      name: d.name,
      color: d.cls.color,
      known: known,
      info: (_) => known ? weaponInfo(_ref, id, 0) : unknownInfo('Taucht irgendwann im Shop auf.'),
    );
  }

  Widget _item(ItemDef it) {
    final known = p.hasSeen(_key('i', it.id));
    return _tile(
      icon: known ? Glyph(ItemGlyph(it.id), size: 40) : _unknown,
      name: it.name,
      color: it.rarity.color,
      known: known,
      info: (_) => known ? itemInfo(_ref, it.id) : unknownInfo('${it.rarity.label} – taucht irgendwann im Shop auf.'),
    );
  }

  Widget _action(ActionId a) {
    final known = p.hasSeen(_key('a', a.name));
    final hint = a.evolved
        ? 'Evolution – entsteht durch Verschmelzen zweier Aktionen.'
        : (itemDefs.any((it) => it.action == a) ? 'Taucht im Aktions-Feld des Shops auf.' : 'Startfähigkeit eines Vogels.');
    return _tile(
      icon: known ? Glyph(ActionGlyph(a), size: 40) : _unknown,
      name: a.label,
      color: a.evolved ? const Color(0xFFFFC94A) : Palette.sun,
      known: known,
      info: (_) => known ? actionInfo(_ref, OwnedAction(a), 0) : unknownInfo(hint),
    );
  }

  Widget _reaction(Reaction re) {
    final known = p.hasSeen(_key('k', re.name));
    return _tile(
      icon: known ? ReactionBadge(re, size: 44) : _unknown,
      name: re.label,
      color: re.color,
      known: known,
      info: (_) => known
          ? reactionInfo(re)
          : unknownInfo('Entsteht, wenn Waffen der Klassen ${re.a.label} und ${re.b.label} denselben Gegner treffen.'),
    );
  }

  Widget _elite(EliteMod m) {
    final known = p.hasSeen(_key('x', m.name));
    return _tile(
      icon: known ? CustomPaint(size: const Size(32, 32), painter: _MarkPainter(m)) : _unknown,
      name: 'Elite: ${m.label}',
      color: const Color(0xFFFFC94A),
      known: known,
      info: (_) => known ? eliteInfo(m) : unknownInfo('Elitegegner tauchen ab Welle $kEliteStartWave auf.'),
    );
  }

  Widget _enemy(EnemyType t) {
    final known = p.hasSeen(_key('e', t.name));
    return _tile(
      icon: known ? Glyph(EnemyGlyph(t), size: 46) : _unknown,
      name: t.label,
      color: const Color(0xFFC77DFF),
      known: known,
      info: (_) => known ? enemyInfo(t) : unknownInfo('Noch nie begegnet.'),
    );
  }
}

class _MarkPainter extends CustomPainter {
  _MarkPainter(this.mod);
  final EliteMod mod;

  @override
  void paint(Canvas c, Size size) => drawEliteMark(c, mod, size.center(Offset.zero), size.shortestSide * 0.8, mod.color);

  @override
  bool shouldRepaint(_MarkPainter old) => old.mod != mod;
}
