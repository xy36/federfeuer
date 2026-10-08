import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:gamepads/gamepads.dart' show GamepadButton;

import '../game/config.dart';
import '../game/gamepad_input.dart' show ModalMenu, openModalMenu;
import '../game/run_state.dart';
import 'controls_editor.dart' show ShortcutHint;
import 'widgets.dart';

/// Gruppen der Werte-Seite mit Farbe.
const statGroups = <(String, Color, List<Stat>)>[
  ('Angriff', Palette.coral, [Stat.dmg, Stat.atk, Stat.crit, Stat.range, Stat.lifesteal]),
  ('Verteidigung', Palette.mint, [Stat.maxHp, Stat.regen, Stat.armor, Stat.dodge]),
  ('Bewegung', Palette.cyan, [Stat.speed, Stat.thrust, Stat.glide]),
  ('Glück & Mehr', Palette.sun, [Stat.luck, Stat.actionSpeed, Stat.pickup]),
];

/// Wert, bei dem der Balken voll ist.
double _barRef(Stat s) => switch (s) {
      Stat.maxHp => 100,
      Stat.regen => 20,
      Stat.armor => 20,
      Stat.dodge => kDodgeMax,
      Stat.lifesteal => 30,
      Stat.crit => 50,
      Stat.range => 300,
      Stat.pickup => 300,
      _ => 100,
    };

String _fmt(double v) => fmtNum(v);
String _signed(double v) => '${v > 0 ? '+' : ''}${fmtNum(v)}';

/// Was der Wert gerade bewirkt (kurz, mit echten Zahlen).
String statEffect(RunState r, Stat s) {
  final v = r.stat(s);
  double cd(double pct) => 1 / max(0.3, 1 + pct / 100);
  return switch (s) {
    Stat.maxHp => 'aktuell ${r.hp.ceil()} von ${r.maxHp.round()} HP',
    Stat.regen => v > 0 ? 'heilt ${_fmt(v / 5)} HP pro Sekunde' : 'keine Heilung über Zeit',
    Stat.dmg => 'Waffen und Aktionen × ${_fmt(1 + v / 100)}',
    Stat.atk => 'Abklingzeit der Waffen × ${_fmt(cd(v))} (höchstens auf 30 %)',
    Stat.range => '${_signed(v)} auf die Reichweite aller Waffen',
    Stat.speed => 'Bewegungstempo × ${_fmt(1 + v / 100)}',
    Stat.armor => v > -15 ? 'erlittener Schaden × ${_fmt(15 / (15 + v))}' : 'erlittener Schaden stark erhöht',
    Stat.lifesteal => 'je Treffer ${_fmt(max(0, v))} % Chance auf +1 HP (höchstens alle 0,5 s)',
    Stat.crit => 'kritische Treffer: Schaden × ${_fmt(r.critMul)}',
    Stat.luck => '${(100 * (0.2 + kLuckLevelRare * max(0.0, v))).round()} % seltene Level-ups, '
        'Herzen und Geschenke × ${_fmt(r.luckDropMul)}',
    Stat.dodge => v > kDodgeMax ? 'wirksam ${_fmt(kDodgeMax)} % (Obergrenze)' : '${_fmt(max(0, v))} % der Treffer gehen daneben',
    Stat.actionSpeed => 'Abklingzeit der Aktionen × ${_fmt(cd(v))}',
    Stat.pickup => 'Material fliegt ab ${_fmt(70 + v)} zu dir',
    Stat.thrust => 'Schub beim Fliegen × ${_fmt(1 + v / 100)}',
    Stat.glide => 'Sinken beim Gleiten langsamer',
  };
}

/// Eigene Seite mit allen Werten: gruppiert, mit Balken, Herkunft (Vogel, Level, Items,
/// Set-Boni) und Wirkung. Modal: Esc, C, Controller-B oder View schließen sie.
class StatsPage extends StatefulWidget {
  const StatsPage({super.key, required this.run, required this.onClose});
  final RunState run;
  final VoidCallback onClose;

  @override
  State<StatsPage> createState() => _StatsPageState();
}

class _StatsPageState extends State<StatsPage> implements ModalMenu {
  final _scope = FocusScopeNode(debugLabel: 'StatsPage');

  @override
  void initState() {
    super.initState();
    openModalMenu = this;
    // Fokus in die Seite (erster Wert), damit Esc/C und Controller hier ankommen
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _scope.traversalDescendants.where((n) => n.canRequestFocus).firstOrNull?.requestFocus();
    });
  }

  @override
  void dispose() {
    if (identical(openModalMenu, this)) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (identical(openModalMenu, this)) openModalMenu = null;
      });
    }
    _scope.dispose();
    super.dispose();
  }

  @override
  void close() => widget.onClose();

  @override
  bool get hidesInfo => true;

  @override
  void navigate(TraversalDirection dir) => FocusManager.instance.primaryFocus?.focusInDirection(dir);

  @override
  Widget build(BuildContext context) {
    final r = widget.run;
    return FocusScope(
      node: _scope,
      child: CallbackShortcuts(
        bindings: {
          const SingleActivator(LogicalKeyboardKey.escape): close,
          const SingleActivator(LogicalKeyboardKey.keyC): close,
        },
        child: ColoredBox(
          color: const Color(0xEB050814),
          child: SafeArea(
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 940),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                    Row(children: [
                      Expanded(
                        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Text('WERTE', style: displayStyle(26, Palette.sun).copyWith(shadows: glowShadows(Palette.sun))),
                          Text(
                            '${r.character.name} · Level ${r.level} · ${r.hp.ceil()}/${r.maxHp.round()} HP · Welle ${r.wave}',
                            style: bodyText(13, color: Ui.muted),
                          ),
                        ]),
                      ),
                      _legend(),
                    ]),
                    const SizedBox(height: 10),
                    Expanded(
                      child: SingleChildScrollView(
                        child: LayoutBuilder(builder: (context, box) {
                          final two = box.maxWidth > 620;
                          final w = two ? (box.maxWidth - 14) / 2 : box.maxWidth;
                          return Wrap(spacing: 14, runSpacing: 14, children: [
                            for (final (title, color, stats) in statGroups)
                              SizedBox(width: w, child: _group(r, title, color, stats)),
                          ]);
                        }),
                      ),
                    ),
                    const SizedBox(height: 10),
                    Row(mainAxisAlignment: MainAxisAlignment.end, children: [
                      const ShortcutHint(keyLabel: 'Esc', pad: GamepadButton.b),
                      GameButton(label: 'Zurück zum Shop', icon: '◀', size: 15, color: Ui.card, onPressed: close),
                    ]),
                  ]),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  static const _sources = [('Vogel', Ui.muted), ('Level', Palette.cyan), ('Items', Palette.sun), ('Sets', Palette.purple)];

  Widget _legend() => Wrap(spacing: 10, children: [
        for (final (label, c) in _sources)
          Row(mainAxisSize: MainAxisSize.min, children: [
            Container(width: 10, height: 10, decoration: BoxDecoration(color: c, borderRadius: BorderRadius.circular(3))),
            const SizedBox(width: 4),
            Text(label, style: bodyText(11.5, color: Ui.muted)),
          ]),
      ]);

  Widget _group(RunState r, String title, Color color, List<Stat> stats) => Container(
        padding: const EdgeInsets.fromLTRB(14, 10, 14, 8),
        decoration: BoxDecoration(
          color: Ui.glass,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: color.withAlpha(110), width: 1.5),
          boxShadow: [BoxShadow(color: color.withAlpha(30), blurRadius: 18)],
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(title.toUpperCase(), style: displayStyle(14, color).copyWith(letterSpacing: 1.5)),
          const SizedBox(height: 4),
          for (final s in stats) _StatTile(run: r, stat: s, color: color),
        ]),
      );
}

/// Eine Zeile: Name, Wert, Balken nach Herkunft, Wirkung. Ansteuerbar (Scrollen mit Controller).
class _StatTile extends StatefulWidget {
  const _StatTile({required this.run, required this.stat, required this.color});
  final RunState run;
  final Stat stat;
  final Color color;

  @override
  State<_StatTile> createState() => _StatTileState();
}

class _StatTileState extends State<_StatTile> {
  bool _focus = false;

  @override
  Widget build(BuildContext context) {
    final r = widget.run, s = widget.stat;
    final total = r.stat(s);
    final parts = [
      ('Vogel', r.statBase[s]!, Ui.muted),
      ('Level', r.statFromLevels[s]!, Palette.cyan),
      ('Items', r.statFromItems(s), Palette.sun),
      ('Sets', r.statFromSets(s), Palette.purple),
    ];
    final unit = s.unit.isEmpty ? '' : ' ${s.unit}';
    final ref = max(_barRef(s), total.abs());
    return Focus(
      onFocusChange: (v) {
        setState(() => _focus = v);
        if (v) Scrollable.ensureVisible(context, alignment: 0.5, duration: const Duration(milliseconds: 150));
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 100),
        margin: const EdgeInsets.symmetric(vertical: 3),
        padding: const EdgeInsets.fromLTRB(8, 5, 8, 6),
        decoration: BoxDecoration(
          color: _focus ? widget.color.withAlpha(30) : Colors.transparent,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: _focus ? Colors.white : Colors.transparent, width: 1.5),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Expanded(child: Text(s.label, style: bodyText(13.5, color: Ui.text, weight: 900))),
            Text('${_fmt(total)}$unit', style: numberStyle(16, total < 0 ? Palette.coral : Ui.text)),
          ]),
          const SizedBox(height: 4),
          _bar(parts, ref),
          const SizedBox(height: 3),
          Wrap(spacing: 8, children: [
            for (final (label, v, c) in parts)
              if (v.abs() > 1e-9) Text('$label ${_signed(v)}', style: bodyText(11, color: c)),
          ]),
          Text(statEffect(r, s), style: bodyText(11.5, color: Ui.muted)),
        ]),
      ),
    );
  }

  /// Gestapelter Balken: positive Anteile nach Herkunft, negative rot schraffiert darüber.
  Widget _bar(List<(String, double, Color)> parts, double ref) => ClipRRect(
        borderRadius: BorderRadius.circular(4),
        child: SizedBox(
          height: 7,
          child: LayoutBuilder(builder: (context, box) {
            final w = box.maxWidth;
            final neg = parts.fold(0.0, (a, p) => a + min(0.0, p.$2)).abs();
            var x = 0.0;
            final segs = <Widget>[];
            for (final (_, v, c) in parts) {
              if (v <= 0) continue;
              final seg = min(w - x, v / ref * w);
              segs.add(Positioned(left: x, top: 0, bottom: 0, width: max(0.0, seg), child: ColoredBox(color: c)));
              x += seg;
            }
            return Stack(children: [
              Positioned.fill(child: ColoredBox(color: Ui.slot)),
              ...segs,
              if (neg > 0)
                Positioned(
                  right: w - min(w, x),
                  top: 0,
                  bottom: 0,
                  width: min(x, neg / ref * w),
                  child: ColoredBox(color: Palette.coral.withAlpha(200)),
                ),
            ]);
          }),
        ),
      );
}
