import 'package:flutter/material.dart';

import '../game/config.dart';
import '../game/progress.dart';
import '../game/run_state.dart';
import 'inspect_info.dart';
import 'widgets.dart';

/// Werkbank im Kompendium: Waffe mit Stufe, Gaben und Eigenschaften zusammenstellen und
/// live sehen, was dabei herauskommt (Werte, Klassen, Reaktionen). Umgekehrt: zu einer
/// Reaktion alle Kombinationen finden, mit denen eine Waffe sie allein auslöst.
/// Wählbar ist nur, was schon entdeckt wurde.
class Workbench extends StatefulWidget {
  const Workbench({super.key, required this.progress, required this.reference});
  final Progress progress;

  /// Neutraler Run für die Werte (ohne Inventar und Boni).
  final RunState reference;

  @override
  State<Workbench> createState() => _WorkbenchState();
}

class _WorkbenchState extends State<Workbench> {
  String? _base;
  int _tier = 0;
  final _gifts = <String>[];
  final _traits = <WeaponTrait>[];
  Reaction? _search;

  Progress get p => widget.progress;
  bool _seen(String id) => p.hasSeen('w:$id');
  List<String> get _known => [for (final id in weaponDefs.keys) if (_seen(id)) id];

  void _pickBase(String id) => setState(() {
        _base = id;
        _gifts.removeWhere((g) => g == id);
        _traits.removeWhere((t) => !t.appliesTo(weaponDefs[id]!));
        _fit();
      });

  /// Gaben und Eigenschaften an die Stufe anpassen (Stufe + 1 Gaben, je Stufe eine Eigenschaft).
  void _fit() {
    while (_gifts.length > maxGifts(_tier)) {
      _gifts.removeLast();
    }
    while (_traits.length > _tier) {
      _traits.removeLast();
    }
  }

  void _load(String base, String gift) => setState(() {
        _base = base;
        _tier = 0;
        _gifts
          ..clear()
          ..add(gift);
        _traits.clear();
      });

  @override
  Widget build(BuildContext context) {
    final known = _known;
    if (known.isEmpty) {
      return Text('Noch keine Waffe entdeckt – kauf oder sieh dir im Shop eine an.', style: mutedStyle);
    }
    final left = Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
      sectionTitle('Grundwaffe'),
      Wrap(spacing: 6, runSpacing: 6, children: [
        for (final id in weaponDefs.keys)
          _seen(id)
              ? _chip(weaponDefs[id]!.name,
                  glyph: WeaponGlyph(id, tier: _base == id ? _tier : 0),
                  color: weaponDefs[id]!.cls.color,
                  selected: _base == id,
                  onTap: () => _pickBase(id))
              : _chip('?', color: Ui.muted),
      ]),
      if (_base != null) ..._builder(known),
      sectionTitle('Reaktion suchen'),
      Wrap(spacing: 6, runSpacing: 6, children: [
        for (final re in Reaction.values)
          _chip(re.label,
              badge: re,
              color: re.color,
              selected: _search == re,
              onTap: () => setState(() => _search = _search == re ? null : re)),
      ]),
      if (_search != null) ..._searchResults(_search!, known),
    ]);
    final base = _base;
    final right = base == null
        ? Padding(
            padding: const EdgeInsets.only(top: 14),
            child: Text('Wähle eine Grundwaffe – hier erscheint, was deine Kombination kann.', style: mutedStyle),
          )
        : Container(
            margin: const EdgeInsets.only(top: 14),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Ui.glass,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: tiers[_tier].color.withAlpha(140), width: 1.4),
            ),
            child: weaponInfo(
              widget.reference,
              base,
              _tier,
              owned: OwnedWeapon(base, _tier)
                ..gifts.addAll(_gifts)
                ..traits.addAll(_traits),
              showSell: false,
            ),
          );
    return LayoutBuilder(builder: (context, box) {
      if (box.maxWidth < 640) return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [left, right]);
      return Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Expanded(flex: 11, child: left),
        const SizedBox(width: 16),
        Expanded(flex: 9, child: right),
      ]);
    });
  }

  /// Stufe, Gaben und Eigenschaften der gewählten Grundwaffe.
  List<Widget> _builder(List<String> known) {
    final d = weaponDefs[_base]!;
    return [
      sectionTitle('Stufe'),
      Wrap(spacing: 6, children: [
        for (var t = 0; t < tiers.length; t++)
          _chip('Stufe ${tiers[t].label}',
              color: tiers[t].color,
              selected: _tier == t,
              onTap: () => setState(() {
                    _tier = t;
                    _fit();
                  })),
      ]),
      sectionTitle('Gaben ${_gifts.length} / ${maxGifts(_tier)}'),
      Wrap(spacing: 6, runSpacing: 6, children: [
        for (final id in known)
          if (id != _base)
            _chip(weaponGifts[id]!.name,
                glyph: WeaponGlyph(id),
                color: weaponDefs[id]!.cls.color,
                selected: _gifts.contains(id),
                onTap: _gifts.contains(id) || _gifts.length < maxGifts(_tier)
                    ? () => setState(() => _gifts.contains(id) ? _gifts.remove(id) : _gifts.add(id))
                    : null),
      ]),
      sectionTitle('Eigenschaften ${_traits.length} / $_tier'),
      if (_tier == 0)
        Text('Eigenschaften gibt es ab Stufe II (eine je Verschmelzen).', style: mutedStyle)
      else
        Wrap(spacing: 6, runSpacing: 6, children: [
          for (final t in WeaponTrait.values)
            if (t.appliesTo(d))
              _chip(
                '${t.label}${_count(t) > 0 ? ' ×${_count(t)}' : ''}',
                color: Palette.mint,
                selected: _count(t) > 0,
                onTap: _traits.length < _tier ? () => setState(() => _traits.add(t)) : null,
              ),
          if (_traits.isNotEmpty)
            _chip('↺ leeren', color: Palette.coral, onTap: () => setState(_traits.clear)),
        ]),
    ];
  }

  int _count(WeaponTrait t) => _traits.where((x) => x == t).length;

  /// Kombinationen (Grundwaffe + eine Gabe), mit denen eine Waffe die Reaktion allein auslöst.
  List<Widget> _searchResults(Reaction re, List<String> known) {
    final combos = <(String, String)>[];
    for (final b in known) {
      final bc = weaponDefs[b]!.cls;
      if (bc != re.a && bc != re.b) continue;
      final need = bc == re.a ? re.b : re.a;
      for (final g in known) {
        if (g != b && weaponDefs[g]!.cls == need) combos.add((b, g));
      }
    }
    if (combos.isEmpty) {
      return [
        Padding(
          padding: const EdgeInsets.only(top: 6),
          child: classText(
              'Noch keine Kombination entdeckt: Du brauchst eine ${re.a.label}- und eine ${re.b.label}-Waffe.', mutedStyle),
        ),
      ];
    }
    return [
      Padding(
        padding: const EdgeInsets.only(top: 6, bottom: 2),
        child: classText('${re.label}: ${re.short}. Eine Waffe löst sie allein aus mit …',
            bodyText(12.5, color: Color.lerp(re.color, Colors.white, 0.3)!)),
      ),
      Wrap(spacing: 6, runSpacing: 6, children: [
        for (final (b, g) in combos.take(24))
          _chip('${weaponDefs[b]!.name} + ${weaponGifts[g]!.name}',
              glyph: WeaponGlyph(b), color: weaponDefs[g]!.cls.color, onTap: () => _load(b, g)),
      ]),
      if (combos.length > 24) Text('… und ${combos.length - 24} weitere', style: mutedStyle),
    ];
  }

  /// Kleiner Auswahl-Chip im Glas-Stil.
  Widget _chip(String label, {GlyphRef? glyph, Reaction? badge, required Color color, bool selected = false, VoidCallback? onTap}) =>
      Pressable(
        onPressed: onTap,
        focusableWhenDisabled: true,
        builder: (context, s) => Sticker(
          state: s,
          color: selected ? color : Color.lerp(color, Ui.card, 0.55)!,
          radius: 10,
          depth: 2,
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            if (glyph != null) Padding(padding: const EdgeInsets.only(right: 4), child: Glyph(glyph, size: 20)),
            if (badge != null) Padding(padding: const EdgeInsets.only(right: 4), child: ReactionBadge(badge, size: 18)),
            Text(label,
                style: bodyText(12, color: selected ? Color.lerp(color, Colors.white, 0.5)! : Ui.text, weight: selected ? 900 : 700)),
          ]),
        ),
      );
}
