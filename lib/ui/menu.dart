import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../game/config.dart';
import '../game/federfeuer_game.dart';
import '../game/progress.dart';
import '../platform/desktop_window.dart';
import 'overlays.dart' show FullScreenButton;
import 'widgets.dart';

/// Version im Titelbildschirm (bei Releases mit `pubspec.yaml` abgleichen).
const kGameVersion = '1.0.0';

enum MenuPage { title, play, settings, records, credits, debug }

/// Startmenü: Titelbildschirm mit Unterseiten. Esc bzw. Controller-B führt zurück.
class MenuOverlay extends StatefulWidget {
  const MenuOverlay({super.key, required this.game, this.initialPage = MenuPage.title});
  final FederfeuerGame game;
  final MenuPage initialPage;

  @override
  State<MenuOverlay> createState() => _MenuOverlayState();
}

class _MenuOverlayState extends State<MenuOverlay> {
  FederfeuerGame get game => widget.game;
  late MenuPage page = widget.initialPage;

  @override
  void initState() {
    super.initState();
    game.menuBack = _back;
  }

  @override
  void dispose() {
    if (game.menuBack == _back) game.menuBack = null;
    super.dispose();
  }

  void _go(MenuPage p) {
    setState(() => page = p);
    game.focusMenuSoon();
  }

  void _back() {
    if (page != MenuPage.title) _go(MenuPage.title);
  }

  @override
  Widget build(BuildContext context) {
    final child = switch (page) {
      MenuPage.title => _TitlePage(game: game, go: _go),
      MenuPage.play => _PlayPage(game: game, back: _back),
      MenuPage.settings => _SettingsPage(game: game, back: _back),
      MenuPage.records => _RecordsPage(game: game, back: _back),
      MenuPage.credits => _CreditsPage(back: _back),
      MenuPage.debug => _DebugPage(game: game, back: _back),
    };
    // Esc führt zurück, auch wenn gerade ein Menüpunkt den Fokus hat
    return CallbackShortcuts(
      bindings: {const SingleActivator(LogicalKeyboardKey.escape): _back},
      child: KeyedSubtree(key: ValueKey(page), child: child),
    );
  }
}

// ---------------- Titelbildschirm ----------------

class _TitlePage extends StatelessWidget {
  const _TitlePage({required this.game, required this.go});
  final FederfeuerGame game;
  final void Function(MenuPage) go;

  @override
  Widget build(BuildContext context) {
    final compact = MediaQuery.sizeOf(context).height < 520;
    return SizedBox.expand(
      child: DecoratedBox(
        // Leichte Abdunklung zur Mitte hin, damit Logo und Menü auf jeder Welt lesbar sind
        decoration: const BoxDecoration(
          gradient: RadialGradient(
            radius: 0.9,
            colors: [Color(0x99020410), Color(0x33020410), Color(0x00020410)],
            stops: [0, 0.55, 1],
          ),
        ),
        child: Stack(children: [
          Center(
            child: SingleChildScrollView(
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                _Logo(size: compact ? 54 : 84),
                SizedBox(height: compact ? 4 : 10),
                Text('Flieg durch das Licht bis zum Gipfel', style: bodyText(compact ? 13 : 16, color: Ui.muted)),
                SizedBox(height: compact ? 14 : 34),
                _TitleItem(label: 'Spielen', onPressed: () => go(MenuPage.play)),
                _TitleItem(label: 'Einstellungen', onPressed: () => go(MenuPage.settings)),
                _TitleItem(label: 'Rekorde', onPressed: () => go(MenuPage.records)),
                _TitleItem(label: 'Credits', onPressed: () => go(MenuPage.credits)),
                if (kDebugTools) _TitleItem(label: 'Debug', onPressed: () => go(MenuPage.debug)),
                if (isDesktop) _TitleItem(label: 'Beenden', onPressed: DesktopWindow.quit),
              ]),
            ),
          ),
          Positioned(
            left: 18,
            bottom: 12,
            child: Text('v$kGameVersion', style: bodyText(11, color: const Color(0x809FB0D0))),
          ),
          Positioned(
            right: 18,
            bottom: 12,
            child: Text(isTouchPlatform ? 'Tippen zum Wählen' : '↑↓ wählen  ·  Enter / A bestätigen  ·  Esc / B zurück',
                style: bodyText(11, color: const Color(0x809FB0D0))),
          ),
        ]),
      ),
    );
  }
}

/// Großes Logo mit sanft atmendem Schein.
class _Logo extends StatefulWidget {
  const _Logo({required this.size});
  final double size;

  @override
  State<_Logo> createState() => _LogoState();
}

class _LogoState extends State<_Logo> with SingleTickerProviderStateMixin {
  late final _c = AnimationController(vsync: this, duration: const Duration(seconds: 4))..repeat(reverse: true);

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
        animation: _c,
        builder: (context, _) {
          final k = Curves.easeInOut.transform(_c.value);
          return Text(
            'FEDERFEUER',
            textAlign: TextAlign.center,
            style: displayStyle(widget.size, const Color(0xFFFFF0C8)).copyWith(
              letterSpacing: widget.size * 0.12,
              shadows: [
                Shadow(color: Palette.sun.withAlpha((150 + 80 * k).round()), blurRadius: widget.size * (0.4 + 0.25 * k)),
                Shadow(color: const Color(0xFFFFB347).withAlpha(140), blurRadius: widget.size * 0.12),
              ],
            ),
          );
        },
      );
}

/// Menüpunkt als leuchtender Text; der gewählte Punkt bekommt eine Lichtkugel davor.
class _TitleItem extends StatelessWidget {
  const _TitleItem({required this.label, required this.onPressed});
  final String label;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) => Pressable(
        onPressed: onPressed,
        builder: (context, s) {
          final on = s.highlighted || s.pressed;
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 5),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              AnimatedOpacity(
                duration: const Duration(milliseconds: 150),
                opacity: on ? 1 : 0,
                child: Container(
                  width: 10,
                  height: 10,
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                    color: Color(0xFFFFF4D6),
                    boxShadow: [
                      BoxShadow(color: Color(0xCCFFD27A), blurRadius: 14, spreadRadius: 3),
                      BoxShadow(color: Color(0x66FFD27A), blurRadius: 30, spreadRadius: 8),
                    ],
                  ),
                ),
              ),
              AnimatedPadding(
                duration: const Duration(milliseconds: 150),
                padding: EdgeInsets.only(left: on ? 18 : 12, right: on ? 12 : 18),
                child: Text(
                  label.toUpperCase(),
                  style: displayStyle(24, on ? Colors.white : Ui.muted).copyWith(
                    letterSpacing: 4,
                    shadows: on ? glowShadows(Palette.sun, 0.9) : null,
                  ),
                ),
              ),
              // Gleich breiter Platz rechts, damit der Text mittig bleibt
              const SizedBox(width: 10),
            ]),
          );
        },
      );
}

// ---------------- Gemeinsame Teile der Unterseiten ----------------

/// Unterseite im Glas-Panel mit Titel und „Zurück“.
class _SubPage extends StatelessWidget {
  const _SubPage({required this.title, required this.back, required this.child, this.maxWidth = 760});
  final String title;
  final VoidCallback back;
  final Widget child;
  final double maxWidth;

  @override
  Widget build(BuildContext context) => Panel(
        maxWidth: maxWidth,
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
          Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
            Expanded(child: OutlinedLabel(title, size: 28)),
            GameButton(label: 'Zurück', icon: '‹', size: 14, color: Ui.card, onPressed: back),
          ]),
          const SizedBox(height: 4),
          child,
        ]),
      );
}

/// Zeile mit Beschriftung und An/Aus-Knopf.
class _ToggleRow extends StatelessWidget {
  const _ToggleRow({required this.label, required this.hint, required this.value, required this.onChanged});
  final String label, hint;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 2),
        child: Row(children: [
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(label, style: displayStyle(16)),
              Text(hint, style: mutedStyle),
            ]),
          ),
          SizedBox(
            width: 110,
            child: Center(
              child: GameButton(
                label: value ? 'An' : 'Aus',
                size: 15,
                color: value ? Palette.mint : Ui.card,
                onPressed: () => onChanged(!value),
              ),
            ),
          ),
        ]),
      );
}

Widget _keyHint(String key, String what) => Padding(
      padding: const EdgeInsets.only(right: 8, bottom: 6),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
          decoration: BoxDecoration(
            color: Ui.glass,
            borderRadius: BorderRadius.circular(6),
            border: Border.all(color: Ui.edge, width: 1.4),
          ),
          child: Text(key, style: bodyText(11.5, color: Ui.cardText, weight: 900)),
        ),
        const SizedBox(width: 6),
        Text(what, style: bodyText(12.5, color: Ui.muted)),
      ]),
    );

// ---------------- Spielen: Run vorbereiten ----------------

class _PlayPage extends StatefulWidget {
  const _PlayPage({required this.game, required this.back});
  final FederfeuerGame game;
  final VoidCallback back;

  @override
  State<_PlayPage> createState() => _PlayPageState();
}

class _PlayPageState extends State<_PlayPage> {
  FederfeuerGame get game => widget.game;

  static const _weaponAccent = {
    'pistol': Palette.sun,
    'smg': Palette.cyan,
    'shotgun': Palette.coral,
  };

  @override
  Widget build(BuildContext context) {
    return _SubPage(
      title: 'RUN VORBEREITEN',
      back: widget.back,
      maxWidth: 940,
      child: LayoutBuilder(builder: (context, box) {
        final wide = box.maxWidth >= 700;
        final left = _difficulty(), right = _weapons();
        if (!wide) return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [left, right]);
        return Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Expanded(flex: 9, child: left),
          const SizedBox(width: 24),
          Expanded(flex: 13, child: right),
        ]);
      }),
    );
  }

  Widget _difficulty() {
    final p = game.progress;
    final sel = difficultyDef(p.selected);
    final best = p.bestFor(sel.level);
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
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
        Pill(
          switch (sel.dropFallSpeed) {
            0 => 'Material schwebt',
            < 20 => 'Material sinkt langsam',
            < 50 => 'Material sinkt',
            _ => 'Material fällt schnell',
          },
          icon: sel.dropsFall ? '⬇' : '✦',
        ),
        if (best > 0) Pill(best > kMaxWave ? 'Geschafft!' : 'Rekord: Welle $best', icon: '🏆', color: const Color(0x33FFD23F)),
      ]),
      if (p.unlocked < kDifficultyCount && !p.debugUnlockAll)
        Padding(
          padding: const EdgeInsets.only(top: 8),
          child: Text('Gewinne auf ${difficultyDef(p.unlocked).name}, um ${difficultyDef(p.unlocked + 1).name} freizuschalten.',
              style: mutedStyle),
        ),
      const SizedBox(height: 10),
      Text('Flieg durch $kMaxWave Wellen bis zum Gipfel und besiege den Geierkönig. '
          'Deine Waffen zielen selbst – du kümmerst dich ums Ausweichen.',
          style: bodyText(13, color: Ui.muted)),
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
            Text(unlocked ? '${d.level}' : '🔒', style: numberStyle(16, Ui.cardText)),
            FittedBox(fit: BoxFit.scaleDown, child: Text(d.name, maxLines: 1, style: displayStyle(13, Ui.cardText))),
          ]),
        ),
      ),
    );
  }

  Widget _weapons() {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      sectionTitle('Startwaffe wählen'),
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
      Text(value, style: bodyText(12.5, color: Ui.cardText, weight: 900)),
    ]);

// ---------------- Einstellungen ----------------

class _SettingsPage extends StatefulWidget {
  const _SettingsPage({required this.game, required this.back});
  final FederfeuerGame game;
  final VoidCallback back;

  @override
  State<_SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<_SettingsPage> {
  @override
  Widget build(BuildContext context) {
    final game = widget.game, s = game.settings;
    void save() {
      setState(() {});
      s.save();
    }

    return _SubPage(
      title: 'EINSTELLUNGEN',
      back: widget.back,
      maxWidth: 680,
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        sectionTitle('Bild'),
        if (isDesktop)
          Row(children: [
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('Anzeige', style: displayStyle(16)),
                Text('Vollbild oder Fenster – auch mit F11 bzw. Alt+Enter', style: mutedStyle),
              ]),
            ),
            const SizedBox(width: 110, child: Center(child: FullScreenButton())),
          ]),
        _ToggleRow(
          label: 'Bildschirmwackeln',
          hint: 'Kamera wackelt bei Treffern und Explosionen',
          value: s.screenShake,
          onChanged: (v) {
            s.screenShake = v;
            save();
          },
        ),
        _ToggleRow(
          label: 'FPS-Anzeige',
          hint: 'Bildrate oben rechts einblenden',
          value: s.showFps,
          onChanged: (v) {
            s.showFps = v;
            game.showPerf = v;
            save();
          },
        ),
        sectionTitle('Steuerung'),
        Text('Tastatur', style: displayStyle(14)),
        const SizedBox(height: 6),
        Wrap(children: [
          _keyHint('A / D  ·  ← →', 'bewegen'),
          _keyHint('Leertaste  ·  W  ·  ↑', 'halten: fliegen'),
          _keyHint('P  ·  Esc', 'Pause'),
          if (isDesktop) _keyHint('F11  ·  Alt+Enter', 'Vollbild'),
        ]),
        const SizedBox(height: 6),
        Text('Controller', style: displayStyle(14)),
        const SizedBox(height: 6),
        Wrap(children: [
          _keyHint('Linker Stick  ·  Steuerkreuz', 'bewegen'),
          _keyHint('A  ·  RB  ·  RT', 'halten: fliegen'),
          _keyHint('Start', 'Pause'),
          _keyHint('B', 'zurück'),
        ]),
        if (isTouchPlatform) ...[
          const SizedBox(height: 6),
          Text('Touch', style: displayStyle(14)),
          const SizedBox(height: 6),
          Wrap(children: [
            _keyHint('◀ ▶', 'bewegen'),
            _keyHint('Flug', 'halten: fliegen'),
            _keyHint('II', 'Pause'),
          ]),
        ],
      ]),
    );
  }
}

// ---------------- Rekorde ----------------

class _RecordsPage extends StatelessWidget {
  const _RecordsPage({required this.game, required this.back});
  final FederfeuerGame game;
  final VoidCallback back;

  @override
  Widget build(BuildContext context) {
    final p = game.progress;
    return _SubPage(
      title: 'REKORDE',
      back: back,
      maxWidth: 760,
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        sectionTitle('Bestleistung je Schwierigkeit'),
        Wrap(spacing: 10, runSpacing: 10, children: [
          for (final d in difficultyDefs) _difficultyRecord(p, d),
        ]),
        sectionTitle('Statistik'),
        Wrap(spacing: 10, runSpacing: 10, children: [
          StatTile(value: '${p.runs}', label: 'Runs'),
          StatTile(value: '${p.wins}', label: 'Siege', color: Palette.mint),
          StatTile(value: '${p.kills}', label: 'Gegner', color: Palette.coral),
          StatTile(value: '${p.bestLevel}', label: 'Höchstes Level', color: Palette.cyan),
        ]),
      ]),
    );
  }

  Widget _difficultyRecord(Progress p, DifficultyDef d) {
    final best = p.bestFor(d.level);
    final unlocked = p.unlocked >= d.level;
    final text = !unlocked ? 'gesperrt' : (best > kMaxWave ? 'geschafft' : (best > 0 ? 'Welle $best' : '–'));
    final col = best > kMaxWave ? Palette.sun : (unlocked ? Ui.card : const Color(0xFF6C7590));
    return Container(
      width: 128,
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
      decoration: BoxDecoration(
        color: Ui.slot,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: col.withAlpha(120), width: 1.2),
        boxShadow: [if (best > kMaxWave) BoxShadow(color: Palette.sun.withAlpha(50), blurRadius: 16)],
      ),
      child: Column(children: [
        Text(unlocked ? d.name : '🔒 ${d.name}', style: displayStyle(14, Color.lerp(col, Colors.white, 0.4)!)),
        const SizedBox(height: 4),
        Text(text, style: numberStyle(16, unlocked ? Ui.text : Ui.muted)),
      ]),
    );
  }
}

// ---------------- Credits ----------------

class _CreditsPage extends StatelessWidget {
  const _CreditsPage({required this.back});
  final VoidCallback back;

  @override
  Widget build(BuildContext context) {
    Widget entry(String what, String who) => Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(what.toUpperCase(), style: displayStyle(12, Ui.muted).copyWith(letterSpacing: 2)),
            Text(who, style: bodyText(15)),
          ]),
        );
    return _SubPage(
      title: 'CREDITS',
      back: back,
      maxWidth: 620,
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const SizedBox(height: 10),
        Center(child: OutlinedLabel('FEDERFEUER', size: 30, align: TextAlign.center)),
        const SizedBox(height: 16),
        entry('Engine', 'Flutter und Flame'),
        entry('Schriften', 'Cinzel – The Cinzel Project Authors\nNunito – The Nunito Project Authors\nbeide unter der SIL Open Font License 1.1'),
        entry('Bibliotheken', 'gamepads (flame-engine), window_manager, shared_preferences'),
        entry('Version', kGameVersion),
        // Kleine Lichtzeile als Abschluss
        Center(
          child: Transform.rotate(
            angle: pi / 4,
            child: Container(
              width: 8,
              height: 8,
              decoration: const BoxDecoration(
                color: Color(0xFFFFF4D6),
                boxShadow: [BoxShadow(color: Color(0x99FFD27A), blurRadius: 12, spreadRadius: 2)],
              ),
            ),
          ),
        ),
      ]),
    );
  }
}

// ---------------- Debug ----------------

class _DebugPage extends StatefulWidget {
  const _DebugPage({required this.game, required this.back});
  final FederfeuerGame game;
  final VoidCallback back;

  @override
  State<_DebugPage> createState() => _DebugPageState();
}

class _DebugPageState extends State<_DebugPage> {
  @override
  Widget build(BuildContext context) {
    final game = widget.game, p = game.progress;
    return _SubPage(
      title: 'DEBUG',
      back: widget.back,
      maxWidth: 620,
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        _ToggleRow(
          label: 'Alles freischalten',
          hint: 'Alle Schwierigkeitsstufen wählbar (wird nicht gespeichert)',
          value: p.debugUnlockAll,
          onChanged: (v) => setState(() => p.debugUnlockAll = v),
        ),
        sectionTitle('Messen'),
        Text('FPS-Anzeige jederzeit mit F3. Aussagekräftig nur im Profile- oder Release-Build.', style: mutedStyle),
        const SizedBox(height: 8),
        Wrap(spacing: 10, children: [
          GameButton(label: 'Performance-Test', icon: '⏱', size: 14, color: Ui.card, onPressed: game.startBenchmark),
          GameButton(label: 'Render-Analyse', icon: '🔬', size: 14, color: Ui.card, onPressed: game.startRenderAnalysis),
        ]),
      ]),
    );
  }
}
