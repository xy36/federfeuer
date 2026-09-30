import 'package:flutter/material.dart';

import '../game/config.dart';
import '../game/federfeuer_game.dart';
import '../game/progress.dart';
import '../game/run_state.dart';
import 'widgets.dart';

// ---------------- Startmenü ----------------

class MenuOverlay extends StatefulWidget {
  const MenuOverlay({super.key, required this.game});
  final FederfeuerGame game;

  @override
  State<MenuOverlay> createState() => _MenuOverlayState();
}

class _MenuOverlayState extends State<MenuOverlay> {
  FederfeuerGame get game => widget.game;

  static const _weaponAccent = {
    'pistol': Palette.sun,
    'smg': Palette.cyan,
    'shotgun': Palette.coral,
  };

  @override
  Widget build(BuildContext context) {
    return Panel(
      maxWidth: 940,
      child: LayoutBuilder(builder: (context, box) {
        final wide = box.maxWidth >= 700;
        final intro = _intro(wide);
        final weapons = _weapons();
        if (!wide) {
          return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [intro, weapons]);
        }
        return Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Expanded(flex: 9, child: intro),
          const SizedBox(width: 24),
          Expanded(flex: 13, child: weapons),
        ]);
      }),
    );
  }

  Widget _intro(bool wide) {
    // Niedrige Bildschirme (Handy quer): einzeiliges Logo, keine Einleitung.
    final compact = MediaQuery.sizeOf(context).height < 520;
    final p = game.progress;
    final sel = difficultyDef(p.selected);
    final best = p.bestFor(sel.level);
    final controls = isTouchPlatform
        ? [('◀ ▶', 'bewegen'), ('Flug', 'halten: fliegen')]
        : [('A D', 'bewegen'), ('Leertaste', 'fliegen'), ('P', 'Pause')];
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      OutlinedLabel(compact ? 'FEDERFEUER' : 'FEDER\nFEUER', size: compact ? 36 : (wide ? 60 : 44)),
      if (!compact) ...[
        const SizedBox(height: 12),
        Text('Flieg durch $kMaxWave Wellen bis zum Gipfel und besiege den Geierkönig. '
            'Deine Waffen zielen selbst – du kümmerst dich ums Ausweichen.',
            style: bodyText(14, color: Ui.muted)),
      ],
      sectionTitle('Schwierigkeit'),
      Row(children: [
        for (final d in difficultyDefs)
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 3),
              child: _difficultyChip(d, selected: d.level == sel.level, unlocked: p.isUnlocked(d.level)),
            ),
          ),
      ]),
      const SizedBox(height: 4),
      Wrap(spacing: 6, runSpacing: 6, children: [
        Pill('HP ×${fmtFactor(sel.hp)}'),
        Pill('Schaden ×${fmtFactor(sel.dmg)}'),
        Pill('Spawns ×${fmtFactor(sel.spawn)}'),
        if (best > 0) Pill(best > kMaxWave ? 'Geschafft!' : 'Rekord: Welle $best', icon: '🏆', color: const Color(0x33FFD23F)),
      ]),
      if (p.unlocked < kDifficultyCount && !p.debugUnlockAll)
        Padding(
          padding: const EdgeInsets.only(top: 8),
          child: Text('Gewinne auf ${difficultyDef(p.unlocked).name}, um ${difficultyDef(p.unlocked + 1).name} freizuschalten.',
              style: mutedStyle),
        ),
      sectionTitle('Steuerung'),
      Wrap(spacing: 6, runSpacing: 6, children: [
        for (final (key, what) in controls) _keyHint(key, what),
        _keyHint('🎮', 'Stick · A · Start'),
      ]),
      if (kDebugTools)
        Padding(
          padding: const EdgeInsets.only(top: 12),
          child: GameButton(
            label: p.debugUnlockAll ? 'Debug: alles frei' : 'Debug: aus',
            icon: '🛠',
            size: 13,
            color: p.debugUnlockAll ? Palette.purple : Ui.card,
            onPressed: () => setState(() => p.debugUnlockAll = !p.debugUnlockAll),
          ),
        ),
    ]);
  }

  Widget _difficultyChip(DifficultyDef d, {required bool selected, required bool unlocked}) {
    return Pressable(
      onPressed: unlocked ? () => _select(d.level) : null,
      builder: (context, s) => Padding(
        padding: const EdgeInsets.only(top: 4, bottom: 8),
        child: Sticker(
          state: s,
          color: selected ? Palette.sun : Ui.card,
          radius: 12,
          depth: 4,
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 7),
          child: Column(children: [
            Text(unlocked ? '${d.level}' : '🔒', style: displayStyle(16, Palette.ink)),
            FittedBox(fit: BoxFit.scaleDown, child: Text(d.name, maxLines: 1, style: displayStyle(13, Palette.ink))),
          ]),
        ),
      ),
    );
  }

  Widget _keyHint(String key, String what) => Row(mainAxisSize: MainAxisSize.min, children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
          decoration: BoxDecoration(
            color: Ui.card,
            borderRadius: BorderRadius.circular(6),
            border: Border.all(color: Palette.ink, width: 2),
          ),
          child: Text(key, style: displayStyle(12, Palette.ink)),
        ),
        const SizedBox(width: 5),
        Text(what, style: bodyText(12, color: Ui.muted)),
        const SizedBox(width: 6),
      ]);

  Widget _weapons() {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      sectionTitle('Startwaffe wählen', padding: const EdgeInsets.only(top: 4, bottom: 8)),
      LayoutBuilder(builder: (context, box) {
        // Drei Karten nebeneinander, solange sie nicht zu schmal werden.
        final w = ((box.maxWidth - 24) / 3).clamp(128.0, 176.0);
        return Wrap(spacing: 12, runSpacing: 4, children: [
          for (final id in ['pistol', 'smg', 'shotgun']) _weaponCard(id, w),
        ]);
      }),
    ]);
  }

  Widget _weaponCard(String id, double width) {
    final d = weaponDefs[id]!;
    return ChoiceCard(
      accent: _weaponAccent[id]!,
      icon: d.icon,
      title: d.name,
      width: width,
      height: 222,
      body: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(d.desc, maxLines: 2, overflow: TextOverflow.ellipsis, style: bodyText(12, color: Ui.cardMuted)),
        const Spacer(),
        _statLine('Schaden', '${fmtNum(d.dmg)}${d.count > 1 ? ' ×${d.count}' : ''}'),
        _statLine('Tempo', '${d.cooldown.toStringAsFixed(2)} s'),
        _statLine('Reichweite', '${d.range.round()}'),
        const SizedBox(height: 8),
      ]),
      footer: const CardFooter(Text('Starten ▶'), color: Palette.mint),
      onPressed: () => game.startRun(id),
    );
  }

  void _select(int level) {
    setState(() => game.progress.selected = level);
    game.progress.save();
  }
}

Widget _statLine(String label, String value) => Row(children: [
      Expanded(child: Text(label, style: bodyText(12, color: Ui.cardMuted))),
      Text(value, style: bodyText(12.5, color: Palette.ink, weight: 900)),
    ]);

// ---------------- Level-up ----------------

class LevelUpOverlay extends StatefulWidget {
  const LevelUpOverlay({super.key, required this.game});
  final FederfeuerGame game;

  @override
  State<LevelUpOverlay> createState() => _LevelUpOverlayState();
}

class _LevelUpOverlayState extends State<LevelUpOverlay> {
  @override
  Widget build(BuildContext context) {
    final game = widget.game;
    final r = game.run!;
    return Panel(
      maxWidth: 820,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          PanelHeader(
            title: 'LEVEL UP!',
            subtitle: Wrap(spacing: 6, children: [
              Pill('Level ${r.level}', icon: '⭐'),
              if (r.pendingLevels > 1) Pill('noch ${r.pendingLevels} Verbesserungen'),
            ]),
          ),
          const SizedBox(height: 14),
          Wrap(spacing: 12, runSpacing: 4, children: [
            for (var i = 0; i < r.levelChoices.length; i++) _card(r.levelChoices[i], i),
          ]),
        ],
      ),
    );
  }

  Widget _card(LevelChoice c, int i) {
    final stat = c.option.stat, rare = c.rare;
    return ChoiceCard(
      accent: rare ? Palette.purple : const Color(0xFFCFCFD6),
      badge: rare ? 'SELTEN' : null,
      icon: c.option.icon,
      title: stat.label,
      width: 176,
      height: 176,
      body: Center(
        child: Text('+${fmtNum(c.value)}${stat.unit}', style: displayStyle(34, Palette.good)),
      ),
      footer: CardFooter(const Text('Wählen'), color: rare ? const Color(0xFFD9B8FF) : Palette.sun),
      onPressed: () {
        widget.game.chooseLevel(i);
        if (mounted) setState(() {});
      },
    );
  }
}

// ---------------- Pause ----------------

class PauseOverlay extends StatelessWidget {
  const PauseOverlay({super.key, required this.game});
  final FederfeuerGame game;

  @override
  Widget build(BuildContext context) {
    final r = game.run!;
    return Panel(
      maxWidth: 440,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        mainAxisSize: MainAxisSize.min,
        children: [
          const OutlinedLabel('PAUSE', size: 44),
          const SizedBox(height: 12),
          Wrap(alignment: WrapAlignment.center, spacing: 6, runSpacing: 6, children: [
            Pill(isBossWave(r.wave) ? 'Bosswelle' : 'Welle ${r.wave}'),
            Pill(game.biomeDef.name),
            Pill(r.difficultyDef.name),
          ]),
          const SizedBox(height: 18),
          Wrap(alignment: WrapAlignment.center, spacing: 12, children: [
            GameButton(label: 'Weiterspielen', icon: '▶', color: Palette.mint, onPressed: game.togglePause),
            GameButton(label: 'Aufgeben', color: Ui.card, onPressed: game.toMenu),
          ]),
        ],
      ),
    );
  }
}

// ---------------- Game Over ----------------

class GameOverOverlay extends StatelessWidget {
  const GameOverOverlay({super.key, required this.game});
  final FederfeuerGame game;

  @override
  Widget build(BuildContext context) {
    final r = game.run!;
    final unlocked = game.newlyUnlocked;
    return Panel(
      maxWidth: 480,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        mainAxisSize: MainAxisSize.min,
        children: [
          OutlinedLabel(game.won ? 'SIEG!' : 'ABGESTÜRZT', size: 44, color: game.won ? Palette.sun : Palette.coral),
          const SizedBox(height: 8),
          Text(
            game.won ? 'Der Geierkönig ist gefallen.' : 'Der Kampfspatz ist abgestürzt.',
            style: bodyText(14, color: Ui.muted),
          ),
          const SizedBox(height: 16),
          Wrap(alignment: WrapAlignment.center, spacing: 10, runSpacing: 10, children: [
            StatTile(value: game.won ? '$kMaxWave' : '${r.wave}', label: 'Welle'),
            StatTile(value: '${r.kills}', label: 'Gegner', color: Palette.coral),
            StatTile(value: '${r.level}', label: 'Level', color: Palette.cyan),
          ]),
          const SizedBox(height: 12),
          Pill('Schwierigkeit: ${r.difficultyDef.name}'),
          if (unlocked != null)
            Container(
              margin: const EdgeInsets.only(top: 14),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              decoration: BoxDecoration(
                color: Palette.mint,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: Palette.ink, width: 3),
              ),
              child: Text('🔓 Neue Stufe: ${difficultyDef(unlocked).name}', style: displayStyle(18, Palette.ink)),
            ),
          const SizedBox(height: 16),
          GameButton(label: 'Neue Runde', icon: '↻', color: Palette.mint, onPressed: game.toMenu),
        ],
      ),
    );
  }
}
