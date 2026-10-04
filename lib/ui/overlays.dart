import 'package:flutter/material.dart';
import 'package:gamepads/gamepads.dart';

import '../game/config.dart';
import '../game/federfeuer_game.dart';
import '../game/run_state.dart';
import '../platform/desktop_window.dart';
import 'bird_preview.dart';
import 'run_overview.dart';
import 'widgets.dart';

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
      hints: const [(GamepadButton.a, 'Verbesserung wählen'), (null, 'Navigieren')],
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
      accent: rare ? Palette.purple : Ui.card,
      badge: rare ? 'SELTEN' : null,
      icon: c.option.icon,
      glyph: StatGlyph(c.option.stat),
      title: stat.label,
      width: 176,
      height: 176,
      body: Center(
        child: Text('+${fmtNum(c.value)}${stat.unit}', style: numberStyle(34, const Color(0xFFB5FFD0)).copyWith(shadows: glowShadows(Palette.mint))),
      ),
      footer: CardFooter(const Text('Wählen'), color: rare ? Palette.purple : Palette.sun),
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
      maxWidth: 960,
      hints: const [(GamepadButton.b, 'Weiterspielen'), (null, 'Navigieren – Details beim Auswählen')],
      footer: Wrap(alignment: WrapAlignment.end, spacing: 12, children: [
        if (isDesktop) const FullScreenButton(),
        GameButton(label: 'Aufgeben', size: 15, color: Ui.card, onPressed: game.toMenu),
        GameButton(label: 'Weiterspielen', icon: '▶', size: 17, color: Palette.mint, onPressed: game.togglePause),
      ]),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
        const OutlinedLabel('PAUSE', size: 34),
        const SizedBox(height: 8),
        RunOverview(run: r, worldName: game.biomeDef.name),
      ]),
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
      hints: const [(GamepadButton.a, 'Auswählen'), (null, 'Navigieren')],
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        mainAxisSize: MainAxisSize.min,
        children: [
          OutlinedLabel(game.won ? 'SIEG!' : 'ABGESTÜRZT', size: 44, color: game.won ? Palette.sun : Palette.coral, align: TextAlign.center),
          const SizedBox(height: 8),
          Text(
            game.won ? 'Der Geierkönig ist gefallen.' : '${r.character.name} ist abgestürzt.',
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
                color: Palette.mint.withAlpha(36),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: Palette.mint.withAlpha(180), width: 1.4),
                boxShadow: [BoxShadow(color: Palette.mint.withAlpha(70), blurRadius: 20)],
              ),
              child: GlyphText('🔓 Neue Stufe: ${difficultyDef(unlocked).name}',
                  style: displayStyle(17, const Color(0xFFCFFFE0)).copyWith(shadows: glowShadows(Palette.mint))),
            ),
          for (final c in game.newCharacters)
            Container(
              margin: const EdgeInsets.only(top: 10),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: c.glow.withAlpha(36),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: c.glow.withAlpha(180), width: 1.4),
                boxShadow: [BoxShadow(color: c.glow.withAlpha(70), blurRadius: 20)],
              ),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                BirdPreview(character: c, size: 40),
                const SizedBox(width: 8),
                Text('Neuer Vogel: ${c.name}',
                    style: displayStyle(16, Color.lerp(c.glow, Colors.white, 0.5)!).copyWith(shadows: glowShadows(c.glow))),
              ]),
            ),
          const SizedBox(height: 16),
          Wrap(alignment: WrapAlignment.center, spacing: 12, children: [
            GameButton(label: 'Neue Runde', icon: '↻', color: Palette.mint, onPressed: () => game.toMenu(play: true)),
            GameButton(label: 'Hauptmenü', color: Ui.card, onPressed: game.toMenu),
          ]),
        ],
      ),
    );
  }
}

/// Umschalter Vollbild/Fenster (nur am PC); zeigt den aktuellen Modus.
class FullScreenButton extends StatelessWidget {
  const FullScreenButton({super.key});

  @override
  Widget build(BuildContext context) => ValueListenableBuilder<bool>(
        valueListenable: DesktopWindow.fullScreen,
        builder: (context, full, _) => GameButton(
          label: full ? 'Fenster' : 'Vollbild',
          icon: full ? '🗗' : '⛶',
          size: 13,
          color: Ui.card,
          onPressed: DesktopWindow.toggle,
        ),
      );
}
