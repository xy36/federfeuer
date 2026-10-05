import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:gamepads/gamepads.dart';

import '../game/config.dart';
import '../game/federfeuer_game.dart';
import '../game/gamepad_input.dart' show controllerActive;
import '../game/progress.dart';
import '../game/run_state.dart';
import '../platform/desktop_window.dart';
import 'bird_preview.dart';
import 'compendium.dart';
import 'controls_editor.dart';
import 'inspect.dart';
import 'inspect_info.dart';
import 'widgets.dart';

/// Version im Titelbildschirm (bei Releases mit `pubspec.yaml` abgleichen).
const kGameVersion = '1.0.0';

enum MenuPage { title, play, settings, records, compendium, credits, debug }

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
    // Offene Auswahlliste schließt zuerst (Esc bzw. Controller-B).
    if (GameDropdown.closeOpen()) return;
    if (page != MenuPage.title) _go(MenuPage.title);
  }

  @override
  Widget build(BuildContext context) {
    final child = switch (page) {
      MenuPage.title => _TitlePage(game: game, go: _go),
      MenuPage.play => _PlayPage(game: game, back: _back),
      MenuPage.settings => _SettingsPage(game: game, back: _back),
      MenuPage.records => _RecordsPage(game: game, back: _back),
      MenuPage.compendium => _SubPage(title: 'KOMPENDIUM', back: _back, maxWidth: 900, child: CompendiumView(game: game)),
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
                _TitleItem(label: 'Kompendium', onPressed: () => go(MenuPage.compendium)),
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
            child: ValueListenableBuilder<bool>(
              valueListenable: controllerActive,
              builder: (context, pad, _) => pad
                  ? const ControllerHints([(GamepadButton.a, 'Bestätigen'), (null, 'Wählen')], center: false)
                  : GlyphText(isTouchPlatform ? 'Tippen zum Wählen' : '↑↓ wählen  ·  Enter bestätigen  ·  Esc zurück',
                      style: bodyText(11, color: const Color(0x809FB0D0))),
            ),
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
        hints: const [(GamepadButton.a, 'Auswählen'), (GamepadButton.b, 'Zurück'), (null, 'Navigieren')],
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
/// Einstellungszeile: Name und Hinweis links, Bedienelement rechts.
class _SettingRow extends StatelessWidget {
  const _SettingRow({required this.label, required this.hint, required this.child});
  final String label, hint;
  final Widget child;

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
          const SizedBox(width: 12),
          child,
        ]),
      );
}

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
          child: GlyphText(key, style: bodyText(11.5, color: Ui.cardText, weight: 900)),
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

  @override
  Widget build(BuildContext context) {
    return _SubPage(
      title: 'RUN VORBEREITEN',
      back: widget.back,
      maxWidth: 980,
      child: LayoutBuilder(builder: (context, box) {
        final wide = box.maxWidth >= 720;
        final left = _difficulty(), right = _characters();
        if (!wide) return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [right, left]);
        return Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Expanded(flex: 8, child: left),
          const SizedBox(width: 24),
          Expanded(flex: 14, child: right),
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
        // Mit dem gewählten Vogel (Frack lässt Material immer fallen)
        Builder(builder: (context) {
          final fall = max(sel.dropFallSpeed, characterById[p.selectedCharacter]!.minDropFall);
          return Pill(
            switch (fall) {
              0 => 'Material schwebt',
              < 20 => 'Material sinkt langsam',
              < 50 => 'Material sinkt',
              _ => 'Material fällt schnell',
            },
            icon: fall > 0 ? '⬇' : '✦',
          );
        }),
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
            GlyphText(unlocked ? '${d.level}' : '🔒', style: numberStyle(16, Ui.cardText)),
            FittedBox(fit: BoxFit.scaleDown, child: Text(d.name, maxLines: 1, style: displayStyle(13, Ui.cardText))),
          ]),
        ),
      ),
    );
  }

  Widget _characters() {
    final p = game.progress;
    final sel = characterById[p.selectedCharacter]!;
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      sectionTitle('Vogel wählen'),
      Wrap(spacing: 6, runSpacing: 6, children: [
        for (final c in characterDefs) _characterTile(c, selected: c.id == sel.id, unlocked: p.hasCharacter(c.id)),
      ]),
      const SizedBox(height: 10),
      _characterDetail(sel),
    ]);
  }

  Widget _characterTile(CharacterDef c, {required bool selected, required bool unlocked}) {
    return Pressable(
      onPressed: () => setState(() {
        if (unlocked) {
          game.progress.selectedCharacter = c.id;
          game.progress.save();
        } else {
          _locked = c;
        }
      }),
      builder: (context, s) => Sticker(
        state: s,
        color: selected ? c.glow : (unlocked ? Ui.card : const Color(0xFF59607A)),
        radius: 12,
        depth: 3,
        padding: const EdgeInsets.all(2),
        child: Stack(alignment: Alignment.center, children: [
          BirdPreview(character: c, size: 50, locked: !unlocked),
          if (!unlocked) const GlyphText('🔒', style: TextStyle(fontSize: 14)),
        ]),
      ),
    );
  }

  /// Zuletzt angetippter gesperrter Vogel: zeigt dessen Aufgabe.
  CharacterDef? _locked;

  Widget _characterDetail(CharacterDef c) {
    final p = game.progress;
    final lock = _locked;
    final chosen = p.startWeaponFor(c);
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Ui.slot,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: c.glow.withAlpha(140), width: 1.4),
        boxShadow: [BoxShadow(color: c.glow.withAlpha(40), blurRadius: 18)],
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          BirdPreview(character: c, size: 76, animate: true),
          const SizedBox(width: 10),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(c.name, style: displayStyle(20, Color.lerp(c.glow, Colors.white, 0.4)!)),
              Text('${c.species} · ${c.role}', style: mutedStyle),
              const SizedBox(height: 6),
              _trait('Stärke', c.strength, Palette.mint),
              _trait('Nachteil', c.weakness, Palette.coral),
              _trait('Fliegt', c.flight, Palette.cyan),
            ]),
          ),
        ]),
        const SizedBox(height: 8),
        Text('STARTWAFFE', style: displayStyle(11, Ui.muted).copyWith(letterSpacing: 1.5)),
        const SizedBox(height: 4),
        if (c.startWeapons.isEmpty)
          const Pill('keine Startwaffe – Waffen nur aus dem Shop', icon: '✋')
        else
          Wrap(spacing: 6, runSpacing: 6, children: [
            for (final id in c.startWeapons) _weaponChoice(c, id, selected: id == chosen),
          ]),
        const SizedBox(height: 8),
        Wrap(spacing: 6, runSpacing: 6, children: [
          if (c.startAction != null) Pill(c.startAction!.label, glyph: ActionGlyph(c.startAction!), color: const Color(0x33FFD23F)),
          if (c.maxWeapons != 6) Pill('${c.maxWeapons} Waffenslots', icon: '🎒'),
        ]),
        if (lock != null && !p.hasCharacter(lock.id)) ...[
          const SizedBox(height: 8),
          _unlockHint(lock),
        ],
        const SizedBox(height: 10),
        Align(
          alignment: Alignment.centerRight,
          child: GameButton(label: 'Starten', icon: '▶', size: 17, color: Palette.mint, onPressed: () => game.startRun()),
        ),
      ]),
    );
  }

  /// Wählbare Startwaffe mit Info-Panel (Werte inklusive Klassenbonus des Vogels).
  Widget _weaponChoice(CharacterDef c, String id, {required bool selected}) {
    final d = weaponDefs[id]!;
    return Inspectable(
      radius: 12,
      // Ohne Waffen im Inventar, damit kein „Kauf erreicht den nächsten Bonus“ erscheint
      info: (_) => weaponInfo(RunState(id, characterId: c.id)..weapons.clear(), id, 0),
      child: Pressable(
        onPressed: () => setState(() {
          game.progress.setStartWeapon(c, id);
          game.progress.save();
        }),
        builder: (context, st) => Sticker(
          state: st,
          color: selected ? Palette.sun : d.cls.color,
          radius: 12,
          depth: 2,
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            Glyph(WeaponGlyph(id), size: 26),
            const SizedBox(width: 6),
            Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
              Text(d.name, style: bodyText(12.5, color: selected ? Palette.sun : Ui.text, weight: 900)),
              Text(d.cls.label, style: bodyText(10.5, color: Ui.muted)),
            ]),
            if (selected) ...[
              const SizedBox(width: 6),
              GlyphText('✓', style: bodyText(13, color: Palette.sun, weight: 900)),
            ],
          ]),
        ),
      ),
    );
  }

  Widget _unlockHint(CharacterDef c) {
    final prog = game.progress.unlockProgress(c.unlock);
    return GlyphText(
      '🔒 ${c.name}: ${c.unlock.text}${prog == null ? '' : ' (${prog.$1} / ${prog.$2})'}',
      style: bodyText(12.5, color: Ui.muted),
    );
  }

  Widget _trait(String label, String text, Color col) => Padding(
        padding: const EdgeInsets.only(bottom: 2),
        child: Text.rich(TextSpan(children: [
          TextSpan(text: '$label  ', style: bodyText(12, color: col, weight: 900)),
          TextSpan(text: text, style: bodyText(12.5, color: Ui.text)),
        ])),
      );

  void _select(int level) {
    setState(() => game.progress.selected = level);
    game.progress.save();
  }
}

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
          ValueListenableBuilder<bool>(
            valueListenable: DesktopWindow.fullScreen,
            builder: (context, full, _) => _SettingRow(
              label: 'Anzeige',
              hint: 'Vollbild oder Fenster – auch mit F11 bzw. Alt+Enter',
              child: GameDropdown<bool>(
                value: full,
                items: const [true, false],
                labelOf: (v) => v ? 'Vollbild' : 'Fenster',
                onChanged: DesktopWindow.setFullScreen,
              ),
            ),
          ),
        if (isDesktop)
          ListenableBuilder(
            listenable: Listenable.merge([DesktopWindow.fullScreen, DesktopWindow.windowSize]),
            builder: (context, _) => _SettingRow(
              label: 'Auflösung',
              hint: 'Volle Auflösung im Vollbild, kleinere im Fenster',
              child: GameDropdown<Size>(
                value: DesktopWindow.fullScreen.value ? DesktopWindow.nativeSize : DesktopWindow.currentSize,
                items: [...DesktopWindow.availableSizes(), DesktopWindow.nativeSize],
                labelOf: (v) => '${v.width.round()} × ${v.height.round()}'
                    '${v == DesktopWindow.nativeSize ? ' (Vollbild)' : ''}',
                onChanged: (v) =>
                    v == DesktopWindow.nativeSize ? DesktopWindow.setFullScreen(true) : DesktopWindow.setWindowSize(v),
              ),
            ),
          ),
        ValueListenableBuilder<double>(
          valueListenable: uiScaleSetting,
          builder: (context, scale, _) => _SettingRow(
            label: 'Skalierung',
            hint: 'Größe von Menüs und Spielanzeigen',
            child: GameDropdown<double>(
              value: scale,
              items: kUiScaleOptions,
              labelOf: (v) => '${(v * 100).round()} %${v == 1 ? ' (Standard)' : ''}',
              onChanged: (v) {
                uiScaleSetting.value = v;
                s.save();
              },
            ),
          ),
        ),
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
        ControlsEditor(game: game),
        if (isTouchPlatform) ...[
          const SizedBox(height: 6),
          Text('Touch', style: displayStyle(14)),
          const SizedBox(height: 6),
          Wrap(children: [
            _keyHint('◀ ▶', 'bewegen'),
            _keyHint('Flug', 'halten: fliegen'),
            _keyHint('▼', 'Kolibri: runter'),
            _keyHint('Symbole', 'Aktionen'),
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
          StatTile(value: '${p.burnKills}', label: 'Verbrannt', color: const Color(0xFFFF8A3D)),
          StatTile(value: '${p.material}', label: 'Material', color: Palette.mint),
        ]),
        sectionTitle('Vögel'),
        Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          for (final c in characterDefs) _characterRecord(p, c),
        ]),
      ]),
    );
  }

  Widget _characterRecord(Progress p, CharacterDef c) {
    final has = p.characters.contains(c.id) || c.unlock.kind == UnlockKind.start;
    final prog = p.unlockProgress(c.unlock);
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(children: [
        BirdPreview(character: c, size: 34, locked: !has),
        const SizedBox(width: 8),
        SizedBox(width: 150, child: Text(c.name, style: displayStyle(14, has ? Ui.text : Ui.muted))),
        Expanded(
          child: Text(
            has ? 'freigeschaltet' : '${c.unlock.text}${prog == null ? '' : ' (${prog.$1} / ${prog.$2})'}',
            style: bodyText(12.5, color: has ? Palette.mint : Ui.muted),
          ),
        ),
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
        GlyphText(unlocked ? d.name : '🔒 ${d.name}', style: displayStyle(14, Color.lerp(col, Colors.white, 0.4)!)),
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
  /// Gewählte Welle für den Direktstart und ob passende Ausrüstung dazukommt.
  int _wave = 4;
  bool _equip = true;

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
          hint: 'Alle Schwierigkeitsstufen und Vögel wählbar (wird nicht gespeichert)',
          value: p.debugUnlockAll,
          onChanged: (v) => setState(() => p.debugUnlockAll = v),
        ),
        _ToggleRow(
          label: 'Unverwundbar',
          hint: 'Der Vogel nimmt keinen Schaden (wird nicht gespeichert)',
          value: game.debugInvincible,
          onChanged: (v) => setState(() => game.debugInvincible = v),
        ),
        sectionTitle('Welle wählen'),
        Text('Startet einen Run mit dem gewählten Vogel und der gewählten Stufe direkt in dieser Welle. '
            'Torwächter: 4, 8, 12 · Boss: 15.', style: mutedStyle),
        const SizedBox(height: 8),
        Wrap(spacing: 6, runSpacing: 6, children: [
          for (var w = 1; w <= kMaxWave; w++)
            _waveChip(w, gate: gatekeeperForWave(w) != null, boss: isBossWave(w)),
        ]),
        _ToggleRow(
          label: 'Passende Ausrüstung',
          hint: 'Level, Waffen, Items und Aktionen wie ungefähr nach ${max(0, _wave - 1)} Wellen',
          value: _equip,
          onChanged: (v) => setState(() => _equip = v),
        ),
        const SizedBox(height: 4),
        Wrap(spacing: 10, children: [
          GameButton(
            label: 'Welle $_wave starten',
            icon: '▶',
            size: 14,
            color: Palette.mint,
            onPressed: () => game.debugStartAtWave(_wave, equip: _equip),
          ),
          if (_wave > 1)
            GameButton(
              label: 'Erst Shop (+${30 * (_wave - 1)} Material)',
              icon: '🛒',
              size: 14,
              color: Ui.card,
              onPressed: () => game.debugStartAtWave(_wave, shopFirst: true, equip: _equip),
            ),
        ]),
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

  Widget _waveChip(int w, {required bool gate, required bool boss}) {
    final sel = w == _wave;
    return Pressable(
      onPressed: () => setState(() => _wave = w),
      builder: (context, st) => Sticker(
        state: st,
        color: sel ? Palette.sun : (boss ? const Color(0xFFFF5AE0) : (gate ? const Color(0xFFC07BFF) : Ui.card)),
        radius: 10,
        depth: 2,
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        child: Text('$w', style: numberStyle(14, Ui.cardText)),
      ),
    );
  }
}
