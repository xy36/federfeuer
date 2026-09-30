import 'package:flutter/material.dart';

import '../game/config.dart';
import '../game/federfeuer_game.dart';
import 'widgets.dart';

class MenuOverlay extends StatelessWidget {
  const MenuOverlay({super.key, required this.game});
  final FederfeuerGame game;

  @override
  Widget build(BuildContext context) {
    final controls = [
      ...isTouchPlatform
          ? ['◀ ▶ bewegen', '„Flug“ halten: fliegen']
          : ['A / D bewegen', 'Leertaste halten: fliegen', 'P: Pause'],
      'Controller: Stick bewegen, A halten: fliegen, Start: Pause',
    ];
    return Panel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          const OutlinedLabel('FEDER\nFEUER'),
          const SizedBox(height: 14),
          const Text('Halte dich in der Luft, weiche aus und überlebe $kMaxWave Wellen. '
              'Deine Waffen zielen und schießen von selbst – zwischen den Wellen kaufst du neue.'),
          const SizedBox(height: 8),
          Wrap(spacing: 14, runSpacing: 4, children: [for (final c in controls) Text(c, style: mutedStyle)]),
          sectionTitle('Startwaffe wählen'),
          Wrap(spacing: 10, runSpacing: 10, children: [
            for (final id in ['pistol', 'smg', 'shotgun']) _weaponCard(id),
          ]),
          if (game.bestWave > 0)
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: Text(
                game.bestWave > kMaxWave ? 'Bestleistung: alle Wellen geschafft' : 'Bestleistung: Welle ${game.bestWave}',
                style: mutedStyle,
              ),
            ),
        ],
      ),
    );
  }

  Widget _weaponCard(String id) {
    final d = weaponDefs[id]!;
    return InfoCard(
      accent: tiers[0].color,
      icon: d.icon,
      title: d.name,
      subtitle: '',
      body: Text('${d.desc}\n${fmtNum(d.dmg)} Schaden${d.count > 1 ? ' ×${d.count}' : ''}, '
          'alle ${d.cooldown.toStringAsFixed(2)} s'),
      action: GameButton(label: "Los geht's", color: Palette.mint, onPressed: () => game.startRun(id)),
    );
  }
}

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
      maxWidth: 800,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text('Level up!', style: headingStyle),
          const SizedBox(height: 4),
          Text('Level ${r.level}${r.pendingLevels > 1 ? ' – noch ${r.pendingLevels} Verbesserungen' : ''}',
              style: mutedStyle),
          const SizedBox(height: 12),
          Wrap(spacing: 10, runSpacing: 10, children: [
            for (var i = 0; i < r.levelChoices.length; i++)
              InfoCard(
                accent: r.levelChoices[i].rare ? Palette.purple : tiers[0].color,
                icon: r.levelChoices[i].option.icon,
                title: r.levelChoices[i].option.stat.label,
                subtitle: r.levelChoices[i].rare ? 'Selten' : 'Normal',
                body: ModsText({r.levelChoices[i].option.stat: r.levelChoices[i].value}),
                action: GameButton(
                  label: 'Nehmen',
                  onPressed: () {
                    game.chooseLevel(i);
                    if (mounted) setState(() {});
                  },
                ),
              ),
          ]),
        ],
      ),
    );
  }
}

class PauseOverlay extends StatelessWidget {
  const PauseOverlay({super.key, required this.game});
  final FederfeuerGame game;

  @override
  Widget build(BuildContext context) {
    return Panel(
      maxWidth: 420,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text('Pause', style: headingStyle),
          const SizedBox(height: 16),
          Wrap(spacing: 10, runSpacing: 10, children: [
            GameButton(label: 'Weiterspielen', color: Palette.mint, onPressed: game.togglePause),
            GameButton(label: 'Aufgeben', color: Palette.card, onPressed: game.toMenu),
          ]),
        ],
      ),
    );
  }
}

class GameOverOverlay extends StatelessWidget {
  const GameOverOverlay({super.key, required this.game});
  final FederfeuerGame game;

  @override
  Widget build(BuildContext context) {
    final r = game.run!;
    final text = game.won
        ? 'Alle $kMaxWave Wellen überstanden – ${r.kills} Gegner besiegt, Level ${r.level}.'
        : 'Du hast bis Welle ${r.wave} durchgehalten – ${r.kills} Gegner besiegt, Level ${r.level}.';
    return Panel(
      maxWidth: 460,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(game.won ? 'Der Geierkönig ist gefallen!' : 'Abgestürzt', style: headingStyle),
          const SizedBox(height: 8),
          Text(text),
          const SizedBox(height: 16),
          GameButton(label: 'Neue Runde', color: Palette.mint, onPressed: game.toMenu),
        ],
      ),
    );
  }
}
