import 'dart:math';

import 'package:flame/components.dart';
import 'package:flame/events.dart';
import 'package:flame/game.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:gamepads/gamepads.dart' show GamepadButton;

import 'components/atmosphere.dart';
import 'components/decor.dart';
import 'components/effects.dart';
import 'components/enemy.dart';
import 'components/goal.dart';
import 'components/hud.dart';
import 'components/pickups.dart';
import 'components/player.dart';
import 'components/projectiles.dart';
import 'components/scenery.dart';
import 'components/transient.dart';
import 'components/weapon_fx.dart';
import 'components/weapon_mount.dart';
import 'components/weather_layer.dart';
import 'config.dart';
import 'gamepad_input.dart';
import 'input_bindings.dart';
import 'perf.dart';
import 'progress.dart';
import 'settings.dart';
import '../platform/desktop_window.dart';
import 'run_state.dart';
import 'weather.dart';

/// `cleared`: Welle vorbei, kurze Einblendung, bevor Level-up/Shop erscheinen.
enum Phase { menu, play, cleared, levelUp, shop, paused, over }

class ArenaWorld extends World {}

/// Kurztasten im Shop.
enum ShopHotkey { reroll, start, lock, nextSection, prevSection }

class FederfeuerGame extends FlameGame<ArenaWorld> with KeyboardEvents {
  FederfeuerGame() : super(world: ArenaWorld());

  static const overlayIds = [
    'menu',
    'levelUp',
    'shop',
    'pause',
    'gameOver',
    'controls',
  ];

  final rng = Random();
  /// Fokus des Spiels selbst. Nicht per Pfeil/Tab/Controller erreichbar, sonst
  /// zieht die Richtungsnavigation in Menüs auf diesen bildschirmgroßen Knoten.
  final focusNode = FocusNode(debugLabel: 'Spiel', skipTraversal: true);
  final enemies = <Enemy>[];
  final _mounts = <WeaponMount>[];
  late final Player player;
  late final Weather weather = Weather(random: rng);
  late final WeatherLayer _weatherLayer = WeatherLayer(weather, priority: 50);
  late final RainPuddles _puddles = RainPuddles(
    weather,
    arenaWidth: kArenaW,
    groundY: kGround,
    priority: -40,
  );

  Phase phase = Phase.menu;

  /// Breite der aktuellen Welt; wächst pro Welle (siehe [worldWidth]).
  double worldW = kArenaW;

  /// X-Position des Ziels, null in der Bosswelle.
  double? goalX;

  /// Torwächter der aktuellen Welle (sobald erschienen) und Einblendung seines Namens.
  Enemy? gate;
  double gateBanner = 0, _gateHintT = 0;

  /// Das Ziel ist versperrt, solange der Torwächter dieser Welle lebt (oder noch nicht da war).
  bool get goalLocked {
    final r = run;
    if (r == null || gatekeeperForWave(r.wave) == null) return false;
    return !(gate?.dead ?? false);
  }

  /// Welt (Kulisse) der aktuellen Welle; im Menü die Felder.
  Biome biome = Biome.fields;
  BiomeDef get biomeDef => biomeDefs[biome]!;

  /// Läuft im Spiel und im Menü, steht in Pause und Zwischenmenüs (für Animationen der Kulisse).
  double clock = 0;
  RunState? run;
  final progress = Progress();
  final settings = Settings();

  /// Vom Startmenü gesetzt: eine Seite zurück (Esc, Controller-B).
  VoidCallback? menuBack;

  // ---------------- Debug: Performance ----------------

  final perf = PerfMonitor();

  /// Debug: Held nimmt keinen Schaden (bleibt über Runs an, wird nicht gespeichert).
  bool debugInvincible = false;

  /// Debug: Run direkt in Welle [wave] starten. [shopFirst]: vorher Shop mit Startkapital
  /// (30 Material je übersprungener Welle), damit man sich passend ausrüsten kann.
  void debugStartAtWave(int wave, {bool shopFirst = false, bool equip = true}) {
    startRun();
    final r = run!;
    if (wave <= 1) return;
    if (equip) {
      r.debugEquip(wave, rng);
      _syncWeapons();
    }
    if (shopFirst) {
      r.wave = wave - 1;
      r.money += 30 * (wave - 1);
      phase = Phase.shop;
      _clearArena();
      r.rerolls = 0;
      r.rollOffers(rng);
      _setOverlays(['shop']);
    } else {
      r.wave = wave;
      startWave();
    }
  }

  /// FPS-Anzeige (F3), unverwundbarer Held, laufender Performance-Test.
  bool showPerf = false, godMode = false, benchmarkRunning = false;
  double benchmarkLeft = 0;
  PerfResult? perfResult;
  static const benchmarkSeconds = 30.0, benchmarkWarmup = 3.0, benchmarkEnemies = 110;

  /// Render-Analyse: misst die Lastszene abschnittsweise, jeweils ohne einen Bildteil.
  bool analysisRunning = false;
  final analysis = <(RenderPart?, PerfResult)>[];
  static const analysisSettle = 1.0, analysisMeasure = 4.0;
  final _segments = <RenderPart?>[null, ...RenderPart.values];
  int analysisIndex = 0;
  double _analysisT = 0;
  RenderPart? get analysisPart => analysisRunning ? _segments[analysisIndex] : null;
  int get analysisSegments => _segments.length;

  /// Beim letzten Sieg neu freigeschaltete Stufe (für Game Over), sonst null.
  int? newlyUnlocked;
  bool won = false;

  /// Beim letzten Run neu freigeschaltete Vögel (für Game Over).
  List<CharacterDef> newCharacters = const [];

  // Eingabe
  bool keyLeft = false, keyRight = false, keyFly = false, keyDown = false;
  bool touchLeft = false, touchRight = false, touchFly = false, touchDown = false;
  late final pad = GamepadInput(
    onNavigate: _padNavigate,
    onConfirm: _padConfirm,
    onBack: _padBack,
    onStart: _padStart,
    onAction: useAction,
    onMenuButton: _padMenuButton,
    bindings: settings.bindings,
  );

  /// Vom Shop gesetzt: Kurztasten (Neu würfeln, Welle starten, Zurückhalten, Bereich wechseln).
  void Function(ShopHotkey key)? onShopHotkey;

  /// Kurztaste an den Shop geben – nicht direkt nach dem Öffnen (Taste war fürs Spiel gemeint).
  void _shopHotkey(ShopHotkey key) {
    if (phase != Phase.shop) return;
    if (DateTime.now().difference(_menuShownAt).inMilliseconds < kMenuConfirmGraceMs) return;
    onShopHotkey?.call(key);
  }

  /// Controller im Shop: true = Knopf verbraucht (geht nicht weiter ans Spiel, z. B. Start ≠ Pause).
  bool _padMenuButton(GamepadButton b) {
    if (phase != Phase.shop) return false;
    final key = switch (b) {
      GamepadButton.x => ShopHotkey.reroll,
      GamepadButton.y => ShopHotkey.lock,
      GamepadButton.start => ShopHotkey.start,
      GamepadButton.rightBumper => ShopHotkey.nextSection,
      GamepadButton.leftBumper => ShopHotkey.prevSection,
      _ => null,
    };
    if (key == null) return false;
    _shopHotkey(key);
    return true;
  }

  /// Tastatur im Shop – global abgehört, weil ein fokussierter Shop-Knopf die Tasten sonst
  /// nicht ans Spiel weitergibt. Fest belegt, nicht W/Leertaste/S (im Spiel zum Fliegen).
  bool _onShopKey(KeyEvent e) {
    if (phase != Phase.shop || inputCapture || e is! KeyDownEvent) return false;
    final key = switch (e.logicalKey) {
      LogicalKeyboardKey.keyR => ShopHotkey.reroll,
      LogicalKeyboardKey.keyN => ShopHotkey.start,
      LogicalKeyboardKey.keyL => ShopHotkey.lock,
      LogicalKeyboardKey.pageDown => ShopHotkey.nextSection,
      LogicalKeyboardKey.pageUp => ShopHotkey.prevSection,
      _ => null,
    };
    if (key == null) return false;
    if (pad.used) pad.used = false;
    _shopHotkey(key);
    return true;
  }

  /// Neubelegung in den Einstellungen läuft: Tastatur-Eingaben gehen nicht ans Spiel oder Menü.
  bool inputCapture = false;
  bool get inLeft => keyLeft || touchLeft || pad.left;
  bool get inRight => keyRight || touchRight || pad.right;
  bool get inFly => keyFly || touchFly || pad.fly;
  bool get inDown => keyDown || touchDown || pad.down;

  /// Freier Flug (Kolibri): Richtung −1 … 1 aus Tasten, Touch und Stick (analog). Senkrecht: oben = negativ.
  double get inHorizontal =>
      clampD((keyRight || touchRight ? 1 : 0) - (keyLeft || touchLeft ? 1 : 0) + pad.horizontal, -1, 1);
  double get inVertical => clampD((keyDown || touchDown ? 1 : 0) - (keyFly || touchFly ? 1 : 0) + pad.vertical, -1, 1);
  bool get playing => phase == Phase.play;

  // Kamera (Weltkoordinaten)
  double zoom = 1, viewW = 800, viewH = kVH, offY = 0, camX = 0;

  // Wellen
  double waveTime = 0, banner = 0, shake = 0, winT = 0, clearT = 0;

  /// Wann zuletzt ein Menü geöffnet wurde (für die Controller-Sperre).
  DateTime _menuShownAt = DateTime.fromMillisecondsSinceEpoch(0);
  double _spawnT = 0, _regenAcc = 0, _menuT = 0;

  double rnd(double a, double b) => a + rng.nextDouble() * (b - a);

  @override
  Color backgroundColor() => const Color(0xFF1D1540);

  @override
  Future<void> onLoad() async {
    camera.viewfinder.anchor = Anchor.topLeft;
    player = Player();
    world.addAll([
      Backdrop(),
      Decor(),
      Ground(),
      _puddles,
      EnemyGlowPass(front: false),
      EnemyGlowPass(front: true),
      player,
      Foreground(),
    ]);
    camera.viewport.addAll([Atmosphere(), _weatherLayer, Hud()]);
    // FPS-Anzeige gibt es für alle (Einstellungen); F3 und Tests nur mit Debug-Werkzeugen.
    camera.viewport.add(PerfOverlay());
    perf.start();
    if (kDebugTools) HardwareKeyboard.instance.addHandler(_onDebugKey);
    HardwareKeyboard.instance.addHandler(_onShopKey);
    await progress.load();
    await settings.load();
    showPerf = settings.showFps;
    pad.start();
    overlays.add('menu');
  }

  @override
  void onRemove() {
    pad.stop();
    perf.stop();
    HardwareKeyboard.instance.removeHandler(_onDebugKey);
    HardwareKeyboard.instance.removeHandler(_onShopKey);
    super.onRemove();
  }

  @override
  void onGameResize(Vector2 size) {
    super.onGameResize(size);
    if (size.x <= 0 || size.y <= 0) return;
    zoom = min(size.y / kVH, size.x / 560);
    viewW = size.x / zoom;
    viewH = size.y / zoom;
    offY = max(0.0, (viewH - kVH) * 0.55);
    camera.viewfinder.anchor = Anchor.topLeft;
    camera.viewfinder.zoom = zoom;
    _placeCamera(0, 0);
  }

  // ---------------- Ablauf ----------------

  /// Startet einen Run. [weaponOverride] ersetzt die Startwaffe des Charakters (Tests, Benchmark).
  void startRun([String? weaponOverride, int? difficulty, String? character]) {
    final charId = character ?? progress.selectedCharacter;
    run = RunState(
      // Ohne Vorgabe: die für diesen Vogel gewählte Startwaffe
      weaponOverride ?? progress.startWeaponFor(characterById[charId] ?? characterDefs.first),
      difficulty: difficulty ?? progress.selected,
      characterId: charId,
      rng: rng,
    );
    player.character = run!.character;
    progress.noteRun(run!);
    actionCds.fillRange(0, actionCds.length, 0);
    actionReadyFlash.fillRange(0, actionReadyFlash.length, 0);
    newlyUnlocked = null;
    perfResult = null;
    godMode = benchmarkRunning = analysisRunning = false;
    perfSkip.clear();
    analysis.clear();
    won = false;
    startWave();
  }

  void startWave() {
    final r = run!;
    phase = Phase.play;
    _setOverlays(['controls']);
    _clearArena();
    r.hp = r.maxHp;
    r.goalBonus = null;
    final boss = isBossWave(r.wave);
    worldW = worldWidth(r.wave);
    biome = biomeForWave(r.wave);
    r.biome = biome;
    timeSlowT = shieldT = stormT = slideT = flashT = freezeT = 0;
    timeBubbleT = vacuumT = goldenT = hoardT = _boomT = _rocketT = 0;
    _cometT = _bounceT = _magnetT = _strobeT = 0;
    _drums = _strobes = 0;
    lightShieldCd = 0;
    _puddles.setArenaWidth(worldW);
    goalX = boss ? null : worldW - kGoalInset;
    gate = null;
    gateBanner = 0;
    if (goalX != null) world.add(Goal(goalX!, locked: () => goalLocked));
    // Timer-Wellen starten links, die Bosswelle in der Arenamitte.
    player.reset(Vector2(boss ? worldW / 2 : kStartX, kGround - 140));
    _syncWeapons();
    // Wetter-Pool und Zuschlag kommen aus der Welt, die Grundchance aus der Stufe.
    weather.startWave(
      difficulty: r.difficulty,
      pool: biomeDef.weatherPool,
      bonus: biomeDef.badWeatherBonus,
    );
    waveTime = boss ? 0 : waveDuration(r.wave);
    _spawnT = 1.2;
    banner = 2;
    winT = 0;
    shake = 0;
    touchLeft = touchRight = touchFly = touchDown = false;
    if (r.wave == kMaxWave) {
      final side = rng.nextBool() ? -500.0 : 500.0;
      world.add(
        SpawnMarker(
          EnemyType.boss,
          Vector2(clampD(player.x + side, 100, worldW - 100), 170),
          2,
        ),
      );
    }
    camX = _targetCam();
    focusNode.requestFocus();
  }

  void nextWave() {
    progress.noteRun(run!);
    if (progress.seenDirty) progress.save();
    run!.wave++;
    startWave();
  }

  /// Ziel erreicht: Welle bestanden, Bonus für die Restzeit.
  void reachGoal() {
    final r = run!;
    final bonus = (max(0.0, waveTime) / kGoalBonusSeconds).floor() * (r.has(ItemEffect.compass) ? 2 : 1);
    r.goalBonus = bonus;
    r.gain(bonus);
    endWave();
  }

  /// Welle vorbei: Gegner verpuffen, kurze Einblendung, dann Level-up/Shop.
  void endWave() {
    final r = run!;
    // Nur Material, das schon zum Spieler fliegt, zählt noch; der Rest verfällt.
    for (final d in world.children.whereType<Drop>()) {
      if (d.material && !d.taken && d.pulled) r.gain(d.value);
    }
    // Sparschwein: Zinsen
    final interest = r.interest();
    if (interest > 0) {
      r.money += interest;
      r.materialCollected += interest;
    }
    for (final e in enemies) {
      if (!e.dead) burst(e.position, const Color(0xFFC77DFF), 8, 140);
    }
    for (final c in world.children
        .where((c) => c is Enemy || c is EnemyBullet || c is Bullet || c is SpawnMarker || c is Drop || c is CombatEffect)
        .toList()) {
      c.removeFromParent();
    }
    enemies.clear();
    touchLeft = touchRight = touchFly = touchDown = false;
    phase = Phase.cleared;
    clearT = kWaveClearDelay;
    _setOverlays([]);
  }

  void _afterWave() {
    final r = run!;
    if (r.pendingLevels > 0) {
      phase = Phase.levelUp;
      r.rollLevelChoices(rng);
      _setOverlays(['levelUp']);
    } else {
      phase = Phase.shop;
      r.rerolls = 0;
      r.rollOffers(rng);
      _setOverlays(['shop']);
    }
  }

  void chooseLevel(int i) {
    run!.chooseLevel(i);
    _afterWave();
  }

  void togglePause() {
    if (phase == Phase.play) {
      phase = Phase.paused;
      touchLeft = touchRight = touchFly = touchDown = false;
      _setOverlays(['pause']);
    } else if (phase == Phase.paused) {
      phase = Phase.play;
      _setOverlays(['controls']);
      focusNode.requestFocus();
    }
  }

  void endRun(bool win) {
    if (phase == Phase.over) return;
    final r = run!;
    phase = Phase.over;
    won = win;
    newlyUnlocked = progress.recordRun(
      difficulty: r.difficulty,
      wave: r.wave,
      won: win,
      kills: r.kills,
      level: r.level,
      character: r.character.id,
      burnKills: r.burnKills,
      material: r.materialCollected,
    );
    newCharacters = progress.checkUnlocks(r, won: win);
    progress.noteRun(r);
    progress.save();
    _setOverlays([]);
    Future.delayed(Duration(milliseconds: win ? 0 : 700), () {
      if (phase != Phase.over) return;
      overlays.add('gameOver');
      _menuShownAt = DateTime.now();
      focusMenuSoon();
    });
  }

  /// Öffnet das Startmenü direkt auf „Run vorbereiten“ statt auf dem Titel.
  bool menuOpensPlay = false;

  /// Zählt jedes Öffnen des Startmenüs – das Menü startet damit immer frisch.
  int menuGeneration = 0;

  void toMenu({bool play = false}) {
    menuOpensPlay = play;
    menuGeneration++;
    godMode = benchmarkRunning = analysisRunning = false;
    perfSkip.clear();
    perf.recording = false;
    run = null;
    phase = Phase.menu;
    worldW = kArenaW;
    goalX = null;
    biome = Biome.fields;
    _puddles.setArenaWidth(worldW);
    weather.reset();
    _weatherLayer.clearInstant();
    _puddles.clearInstant();
    _clearArena();
    for (final m in _mounts) {
      m.removeFromParent();
    }
    _mounts.clear();
    // Schon offenes Menü neu aufbauen lassen (neuer Key → frischer Zustand)
    overlays.remove('menu');
    _setOverlays(['menu']);
  }

  void _setOverlays(List<String> active) {
    for (final id in overlayIds) {
      if (active.contains(id)) {
        overlays.add(id);
      } else {
        overlays.remove(id);
      }
    }
    // Fokus von entfernten Menü-Buttons zurückholen.
    focusNode.requestFocus();
    if (!playing && active.isNotEmpty) {
      _menuShownAt = DateTime.now();
      focusMenuSoon();
    }
  }

  // ---------------- Menü-Navigation (Tastatur & Controller) ----------------

  /// Mit Controller wird im neuen Menü direkt der erste Button fokussiert.
  void focusMenuSoon() {
    if (!pad.used) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!playing) _focusFirstMenuItem();
    });
  }

  /// Fokus liegt auf keinem Menü-Button, sondern beim Spiel selbst.
  bool get _menuUnfocused {
    final f = FocusManager.instance.primaryFocus;
    return f == null || f == focusNode || f is FocusScopeNode;
  }

  void _focusFirstMenuItem() {
    for (final n in focusNode.traversalDescendants) {
      if (n.canRequestFocus && n.context != null) {
        n.requestFocus();
        return;
      }
    }
  }

  void _padNavigate(TraversalDirection dir) {
    if (playing) return;
    if (_menuUnfocused) {
      _focusFirstMenuItem();
    } else {
      FocusManager.instance.primaryFocus!.focusInDirection(dir);
    }
  }

  void _padConfirm() {
    if (playing) return;
    // Frisch geöffnetes Menü: A war vermutlich noch zum Fliegen gemeint.
    if (DateTime.now().difference(_menuShownAt).inMilliseconds < kMenuConfirmGraceMs) return;
    final ctx = FocusManager.instance.primaryFocus?.context;
    if (_menuUnfocused || ctx == null) {
      _focusFirstMenuItem();
    } else {
      Actions.maybeInvoke(ctx, const ActivateIntent());
    }
  }

  void _padBack() {
    if (phase == Phase.paused) togglePause();
    if (phase == Phase.menu) menuBack?.call();
  }

  void _padStart() {
    if (phase == Phase.play || phase == Phase.paused) togglePause();
  }

  void _clearArena() {
    _pendingSpawns.clear();
    for (final c in world.children.whereType<Transient>().toList()) {
      c.removeFromParent();
    }
    enemies.clear();
  }

  void _syncWeapons() {
    for (final m in _mounts) {
      m.removeFromParent();
    }
    _mounts.clear();
    final ws = run!.weapons;
    for (var i = 0; i < ws.length; i++) {
      final m = WeaponMount(ws[i], i);
      _mounts.add(m);
      world.add(m);
    }
  }

  // ---------------- Game Loop ----------------

  @override
  void update(double dt) {
    perf.frame(dt);
    dt = min(dt, 0.05);
    final active = playing;
    // Am PC stört der Mauszeiger beim Spielen; in Menüs wird er gebraucht.
    final cursor = isDesktop && active ? SystemMouseCursors.none : SystemMouseCursors.basic;
    if (mouseCursor != cursor) mouseCursor = cursor;
    // Während der Einblendung laufen Effekte weiter, Figuren stehen still.
    final animate = active || phase == Phase.cleared || run == null;
    if (active || run == null) clock += dt;
    weather.update(active ? dt : 0);
    super.update(animate ? dt : 0);
    if (_pendingSpawns.isNotEmpty && run != null) {
      for (final s in [..._pendingSpawns]) {
        addEnemy(s.type, s.pos, mini: s.mini, child: s.child, spawnedBy: s.spawnedBy);
      }
      _pendingSpawns.clear();
    }

    if (run == null) {
      _menuT += dt;
      camX = (sin(_menuT * 0.08) * 0.5 + 0.5) * max(0.0, worldW - viewW);
      _placeCamera(0, 0);
      return;
    }
    if (phase == Phase.cleared) {
      clearT -= dt;
      if (clearT <= 0) {
        _clearArena();
        _afterWave();
      }
      return;
    }
    if (!active) {
      perf.recording = false;
      return;
    }
    final r = run!;
    if (benchmarkRunning) _benchmarkTick(dt);
    _tickActions(dt);

    banner = max(0.0, banner - dt);
    shake = max(0.0, shake - dt * 40);
    enemies.removeWhere((e) => e.dead);
    if (!isBossWave(r.wave)) _despawnStragglers();
    _separateEnemies();
    _updateCamera(dt);

    if (winT > 0) {
      winT -= dt;
      if (winT <= 0) endRun(true);
      return;
    }
    if (!isBossWave(r.wave)) {
      waveTime -= dt;
      final g = goalX;
      // Torwächter erscheint vor dem Ziel, sobald der Spieler sich nähert
      final gk = gatekeeperForWave(r.wave);
      if (gk != null && gate == null && g != null && player.x > g - kGateTriggerDist) _spawnGate(gk, g);
      // Name des Torwächters erst nach dem Wellenbanner zeigen
      if (banner <= 0) gateBanner = max(0.0, gateBanner - dt);
      _gateHintT = max(0.0, _gateHintT - dt);
      if (g != null && player.x + player.r >= g) {
        if (goalLocked) {
          // Versperrt: zurückschieben und kurz erklären
          player.position.x = g - player.r - 1;
          player.vel.x = min(0.0, player.vel.x);
          if (_gateHintT <= 0) {
            _gateHintT = 1.5;
            floatText(player.position - Vector2(0, 34), 'Besiege zuerst ${gk!.label}!', Palette.coral, 15);
          }
        } else {
          reachGoal();
          return;
        }
      }
      if (waveTime <= 0) {
        endWave();
        return;
      }
    }

    _spawnT -= dt;
    if (_spawnT <= 0) {
      _spawnBatch();
      _spawnT =
          max(0.9, 2.4 - r.wave * 0.15) /
          r.difficultyDef.spawn *
          rnd(0.7, 1.3) *
          (r.wave == kMaxWave ? 1.7 : 1);
    }

    final regen = r.stat(Stat.regen);
    if (regen > 0) {
      _regenAcc += dt * regen / 5;
      while (_regenAcc >= 1) {
        _regenAcc -= 1;
        heal(1);
      }
    }
  }

  double _targetCam() => viewW >= worldW
      ? (worldW - viewW) / 2
      : clampD(player.x - viewW / 2 + player.vel.x * 0.35, 0, worldW - viewW);

  void _updateCamera(double dt) {
    camX += (_targetCam() - camX) * min(1.0, dt * 6);
    final k = settings.screenShake ? shake : 0.0;
    _placeCamera((rng.nextDouble() - 0.5) * k, (rng.nextDouble() - 0.5) * k);
  }

  void _placeCamera(double sx, double sy) {
    camera.viewfinder.position = Vector2(camX + sx, -offY + sy);
  }

  void _spawnBatch() {
    final r = run!;
    if (enemies.length > 110) return;
    final w = r.wave;
    final pool = spawnPool(w);
    final total = pool.fold(0.0, (a, b) => a + b.$2);

    var n = 1 + (w / 2.5).floor() + (rng.nextDouble() < 0.4 ? 1 : 0) + (w <= kEarlySpawnWaves ? kEarlySpawnBonus : 0);
    final cx = isBossWave(w) ? _bossWaveSpawnX() : _spawnXNearPlayer();
    while (n-- > 0) {
      var roll = rng.nextDouble() * total;
      var type = EnemyType.crow;
      for (final (t, wt) in pool) {
        roll -= wt;
        if (roll <= 0) {
          type = t;
          break;
        }
      }
      final d = enemyDefs[type]!;
      final x = clampD(cx + rnd(-80, 80), 40, worldW - 40);
      // Spinne, Felsadler und Wespennest kommen von oben, Bodengegner auf dem Boden
      final y = type == EnemyType.spider || type == EnemyType.eagle || type == EnemyType.waspNest
          ? kCeil + d.radius + 8
          : (d.flying ? rnd(kCeil + 50, kGround - 90) : kGround - d.radius);
      world.add(SpawnMarker(type, Vector2(x, y), 0.9));
    }
  }

  /// Bosswelle: irgendwo in der Arena, mindestens [kSpawnMinDist] entfernt.
  double _bossWaveSpawnX() {
    var cx = rnd(60, worldW - 60);
    while ((cx - player.x).abs() < kSpawnMinDist) {
      cx = rnd(60, worldW - 60);
    }
    return cx;
  }

  /// Timer-Wellen: sichtbar im Bild, meist in Flugrichtung zum Ziel.
  /// Mindestens [kSpawnMinDist] entfernt, höchstens bis [kSpawnScreenMargin] vor
  /// den Bildrand (und nie weiter als [kSpawnMaxDist]). Ist die Seite zu schmal,
  /// erscheint die Gruppe im Mindestabstand knapp außerhalb.
  /// Ist auf einer Seite kein Platz (Weltrand), kommt die Gruppe von der anderen.
  double _spawnXNearPlayer() {
    double pick(double side) {
      final edge = side > 0 ? camX + viewW - kSpawnScreenMargin : camX + kSpawnScreenMargin;
      final room = (edge - player.x) * side;
      final maxD = max(kSpawnMinDist, min(kSpawnMaxDist, room));
      return player.x + side * rnd(kSpawnMinDist, maxD);
    }

    final side = rng.nextDouble() < kSpawnAheadChance ? 1.0 : -1.0;
    var cx = pick(side);
    if (cx < 60 || cx > worldW - 60) cx = pick(-side);
    return clampD(cx, 60, worldW - 60);
  }

  /// Gegner, die weit hinter dem Spieler zurückbleiben, verschwinden ohne Drop,
  /// damit sie nicht die Obergrenze für lebende Gegner blockieren.
  void _despawnStragglers() {
    for (final e in enemies) {
      if (!e.dead && !e.boss && e.x < player.x - kDespawnBehind) {
        e.dead = true;
        e.removeFromParent();
      }
    }
    enemies.removeWhere((e) => e.dead);
  }

  void _spawnGate(EnemyType type, double goal) {
    final d = enemyDefs[type]!;
    final y = switch (type) {
      EnemyType.spiderMother => kCeil + d.radius + 30,
      EnemyType.bell => 190.0,
      _ => kGround - d.radius,
    };
    addEnemy(type, Vector2(goal - kGateOffset, y));
    gate = enemies.last;
    gateBanner = 2.5;
    shake = max(shake, 10);
    burst(gate!.position, const Color(0xFFFF5AE0), 30, 260);
  }

  /// Lässt [total] Material als möglichst wenige Kristalle fallen (1 / 3 / 5 / 10).
  void dropMaterial(Vector2 at, int total, {double spread = 8}) {
    final fall = run!.difficultyDef.dropFallSpeed;
    for (final v in splitMaterial(total)) {
      world.add(Drop(at.clone()..x += rnd(-spread, spread), material: true, rng: rng, fallSpeed: fall, value: v));
    }
  }

  /// Gegner, die erst nach dem aktuellen Frame erscheinen (Kopien teilender Elitegegner,
  /// Eier und Schlüpflinge) – killEnemy & Co. laufen oft mitten in einer Schleife über [enemies].
  final _pendingSpawns = <({EnemyType type, Vector2 pos, bool mini, bool child, Enemy? spawnedBy})>[];

  void queueSpawn(EnemyType type, Vector2 pos, {bool mini = false, bool child = false, Enemy? spawnedBy}) =>
      _pendingSpawns.add((type: type, pos: pos, mini: mini, child: child, spawnedBy: spawnedBy));

  /// Regulärer Spawn (aus der Warnmarkierung): würfelt ab Welle 5 einen Elitegegner.
  void spawnEnemy(EnemyType type, Vector2 pos) {
    final w = run!.wave;
    // Höchstens [kMaxSpawners] Spawner gleichzeitig, sonst eine Krähe
    if (enemyDefs[type]!.spawner && enemies.where((e) => !e.dead && enemyDefs[e.type]!.spawner).length >= kMaxSpawners) {
      type = EnemyType.crow;
    }
    final elite = type != EnemyType.boss && rng.nextDouble() < eliteChance(w)
        ? EliteMod.values[rng.nextInt(EliteMod.values.length)]
        : null;
    // Stationäre Gegner können sich nicht teilen
    addEnemy(type, pos, elite: elite == EliteMod.splitting && enemyDefs[type]!.stationary ? EliteMod.armored : elite);
  }

  void addEnemy(EnemyType type, Vector2 pos, {EliteMod? elite, bool mini = false, bool child = false, Enemy? spawnedBy}) {
    progress.seeEnemy(type);
    if (elite != null) progress.see('x:${elite.name}');
    final e = Enemy(type, pos, run!.wave, run!.difficultyDef, rng,
        elite: elite, mini: mini, child: child, spawnedBy: spawnedBy);
    enemies.add(e);
    world.add(e);
  }

  void _separateEnemies() {
    final e = enemies;
    for (var i = 0; i < e.length; i++) {
      final a = e[i];
      for (var j = i + 1; j < e.length; j++) {
        final b = e[j];
        final dx = b.x - a.x, dy = b.y - a.y, rr = a.r + b.r;
        if (dx.abs() > rr || dy.abs() > rr) continue;
        final d = max(0.001, sqrt(dx * dx + dy * dy));
        if (d < rr) {
          final push = (rr - d) / 2 / d;
          if (!a.immovable) {
            a.position.x -= dx * push;
            a.position.y -= dy * push;
          }
          if (!b.immovable) {
            b.position.x += dx * push;
            b.position.y += dy * push;
          }
        }
      }
    }
  }

  // ---------------- Kampf ----------------

  void hurtPlayer(double amount, {Enemy? source}) {
    final r = run;
    if (r == null || !playing || player.iframe > 0 || winT > 0 || godMode || debugInvincible) return;
    // Seifenblasenschild schluckt alles
    if (shieldT > 0) return;
    // Lichtschild: blockt alle 8 s einen Treffer
    if (r.has(ItemEffect.lightShield) && lightShieldCd <= 0) {
      lightShieldCd = 8;
      player.iframe = 0.4;
      floatText(player.position - Vector2(0, 20), 'Geblockt', Palette.sun, 14);
      burst(player.position, Palette.sun, 10, 180);
      return;
    }
    // Gummiente: 10 % der Treffer ignorieren
    if (r.has(ItemEffect.duck) && rng.nextDouble() < 0.1) {
      player.iframe = 0.3;
      floatText(player.position - Vector2(0, 20), 'Quietsch!', const Color(0xFFFFE066), 14);
      return;
    }
    final a = r.stat(Stat.armor);
    final f = a >= 0 ? 15 / (15 + a) : 1 + (-a) / 15;
    final dmg = max(1, (amount * f).round());
    r.hp -= dmg;
    player.iframe = 0.6;
    shake = 8;
    floatText(player.position, '-$dmg', Palette.coral, 17);
    burst(player.position, Palette.coral, 8);
    // Dornenkleid: Berührungsschaden ×3 zurück
    if (source != null && !source.dead && r.has(ItemEffect.thorns)) {
      hurtEnemy(source, amount * 3, false, 0);
    }
    if (r.hp <= 0) {
      if (r.has(ItemEffect.phoenix) && !r.phoenixUsed) {
        r.phoenixUsed = true;
        r.hp = max(1, (r.maxHp * 0.3).roundToDouble());
        player.iframe = 2;
        shake = 14;
        burst(player.position, const Color(0xFFFF9F1C), 40, 300);
        floatText(player.position - Vector2(0, 30), 'PHÖNIX!', const Color(0xFFFFB347), 22);
        return;
      }
      r.hp = 0;
      endRun(false);
    }
  }

  void heal(int n) {
    final r = run!;
    if (r.hp >= r.maxHp) return;
    r.hp = min(r.maxHp, r.hp + n);
    floatText(player.position - Vector2(0, 24), '+$n', Palette.mint, 15);
  }

  /// Herz eingesammelt (Rabe Ruß heilt nur halb).
  void healHeart() => heal(max(1, (3 * run!.character.heartMul).round()));

  void gain(int v) {
    if (goldenT > 0) v *= 2;
    if (hoardT > 0 && rng.nextDouble() < 0.2) v *= 2;
    if (run!.gain(v)) {
      floatText(player.position - Vector2(0, 40), 'LEVEL UP', Palette.sun, 18);
    }
  }

  /// Geschenk der Elster: ein zufälliges gewöhnliches oder seltenes Werte-Item.
  void giveGift() {
    final r = run!;
    final pool = itemDefs
        .where((it) => it.effect == ItemEffect.none && it.rarity.index <= Rarity.rare.index && it.mods.isNotEmpty)
        .toList();
    final it = pool[rng.nextInt(pool.length)];
    r.applyMods(it.mods);
    r.items[it.id] = (r.items[it.id] ?? 0) + 1;
    floatText(player.position - Vector2(0, 44), '${it.icon} ${it.name}', const Color(0xFF9FD4FF), 15);
  }

  /// Schaden an einem Gegner. [fx]: Treffereffekte der Waffe, [cls]: Klasse (Brennglas),
  /// [dot]: Schaden über Zeit (ohne Rückstoß, Lebensraub und Effekte).
  void hurtEnemy(Enemy e, double dmg, bool crit, double knock, {bool dot = false, WeaponStats? fx, WeaponClass? cls}) {
    if (e.dead) return;
    final r = run!;
    if (e.cursed) dmg *= 1 + r.curseBonus;
    if (!dot) e.onHit();
    // Gepanzerte Elite: halber Schaden, kein Rückstoß
    if (e.elite == EliteMod.armored) {
      dmg *= 0.5;
      knock = 0;
    }
    e.hp -= dmg;
    if (!dot) {
      e.flash = 0.08;
      if (!e.boss) e.position.x += knock;
    }
    floatText(
      Vector2(e.x, e.y - e.r),
      '${dmg.round()}',
      dot ? const Color(0xFFFFB37A) : (crit ? Palette.sun : const Color(0xFFFFFFFF)),
      dot ? 11 : (crit ? 18 : 14),
    );
    if (!dot) {
      final ls = r.stat(Stat.lifesteal) + (fx?.lifesteal ?? 0);
      if (ls > 0 && lifestealCd <= 0 && rng.nextDouble() * 100 < ls) {
        lifestealCd = kLifestealInterval;
        heal(1);
      }
      if (fx != null) e.applyEffects(fx);
      if (crit && cls == WeaponClass.light && r.has(ItemEffect.burningGlass)) e.ignite(2, dmg * 0.3);
      if (crit && r.has(ItemEffect.stardust)) explode(e.position.clone(), 36, dmg * 0.4, false);
    }
    if (e.hp <= 0) killEnemy(e);
  }

  void killEnemy(Enemy e) {
    e.dead = true;
    e.removeFromParent();
    final r = run!;
    r.kills++;
    if (e.burnT > 0) r.burnKills++;
    if (e.type == EnemyType.boss) {
      burst(e.position, Palette.sun, 60, 320);
      shake = 20;
      winT = 1.6;
      for (final o in enemies) {
        if (o.dead) continue;
        o.dead = true;
        o.removeFromParent();
        burst(o.position, const Color(0xFFC77DFF), 6);
      }
      for (final c in world.children.where((c) => c is EnemyBullet || c is SpawnMarker || c is CombatEffect).toList()) {
        c.removeFromParent();
      }
      return;
    }
    burst(e.position, const Color(0xFFC77DFF), 12, 170);
    // Torwächter: Tor offen, viel Material und ein Geschenk
    if (e.gatekeeper) {
      shake = max(shake, 14);
      burst(e.position, const Color(0xFFFFC94A), 40, 300);
      floatText(e.position - Vector2(0, e.r + 20), 'DAS TOR IST OFFEN', Palette.sun, 20);
      final fall = r.difficultyDef.dropFallSpeed;
      dropMaterial(e.position, kGateDrops, spread: 30);
      world.add(Drop(e.position.clone(), material: false, gift: true, rng: rng, fallSpeed: fall));
      return;
    }
    // Pusteling platzt auch beim Abschuss in eine Giftwolke
    if (e.type == EnemyType.puffball) world.add(PoisonCloud(e.position.clone(), e.dmg));
    // Kinder von Spawnern lassen nichts fallen
    if (e.child) return;
    final fall = r.difficultyDef.dropFallSpeed;
    // Elite: Modifikator beim Tod, mehr Material, manchmal ein Geschenk
    switch (e.elite) {
      case EliteMod.volatile:
        world.add(VolatileRemnant(e.position.clone(), e.dmg * 1.5));
      case EliteMod.splitting:
        // Erst nach dem Frame hinzufügen: killEnemy läuft oft mitten in einer Schleife über [enemies]
        for (final side in [-1.0, 1.0]) {
          queueSpawn(e.type, e.position.clone()..x += side * e.r, mini: true);
        }
      default:
    }
    if (e.elite != null) {
      burst(e.position, const Color(0xFFFFC94A), 18, 220);
      if (rng.nextDouble() < kEliteGiftChance) {
        world.add(Drop(e.position.clone(), material: false, gift: true, rng: rng, fallSpeed: fall));
      }
    }
    // Goldgier: 15 % doppelte Drops
    final times = (r.has(ItemEffect.greed) && rng.nextDouble() < 0.15 ? 2 : 1) * (e.elite != null ? kEliteDrops : 1);
    dropMaterial(e.position, enemyDefs[e.type]!.drop * times);
    if (rng.nextDouble() < 0.04) {
      world.add(Drop(e.position.clone(), material: false, rng: rng, fallSpeed: fall));
    }
    // Elster: manchmal ein Geschenk
    if (r.character.giftChance > 0 && rng.nextDouble() < r.character.giftChance) {
      world.add(Drop(e.position.clone(), material: false, gift: true, rng: rng, fallSpeed: fall));
    }
  }

  void explode(Vector2 at, double radius, double dmg, bool crit, {WeaponStats? fx, Color color = const Color(0xFFFF9F1C)}) {
    shake = max(shake, 5);
    burst(at, color, 18, 220);
    world.add(Ring(at.clone(), radius, color: color));
    for (final e in [...enemies]) {
      if (!e.dead && e.position.distanceTo(at) < radius + e.r) {
        hurtEnemy(e, dmg, crit, 0, fx: fx);
      }
    }
  }

  // ---------------- Aktionstasten ----------------

  /// Abklingzeit je Aktionsplatz.
  final actionCds = List<double>.filled(kActionSlots, 0);

  /// Restzeit der „Bereit!“-Einblendung je Aktionsplatz (HUD-Puls, Ring am Vogel).
  final actionReadyFlash = List<double>.filled(kActionSlots, 0);
  static const actionReadyFlashTime = 0.8;

  /// Zeitlupe, Seifenblasenschild, Gewitter, Bauchrutscher, Lichtblitz-Einblendung, Schnappschuss,
  /// Zeitblase, Staubsauger, Goldene Stunde, Elsterschatz.
  double timeSlowT = 0, shieldT = 0, stormT = 0, slideT = 0, flashT = 0, freezeT = 0;
  double timeBubbleT = 0, vacuumT = 0, goldenT = 0, hoardT = 0;
  double lifestealCd = 0, lightShieldCd = 0, _stormTick = 0, _boomT = 0, _rocketT = 0, _drumT = 0, _actionPower = 1;
  int _drums = 0;

  /// Gewitter-Parameter (Gewitterwolke, Gewitterblase, Ewiges Gewitter).
  double _stormEvery = 0.25, _stormRadius = 460;

  /// Kometenschweif, Prallblase, Elektromagnet, Stroboskop.
  double _cometT = 0, _bounceT = 0, _magnetT = 0, _magnetTick = 0, _strobeT = 0;
  int _strobes = 0;
  bool _slideTrap = false;
  final _bounceCd = <Enemy, double>{};
  final _slideHit = <Enemy>{};

  bool actionReady(int slot) {
    final r = run;
    return r != null && slot < r.actions.length && actionCds[slot] <= 0;
  }

  /// Schadensbasis für Aktionen (wächst mit Welle und Schaden %).
  double get actionDamage {
    final r = run!;
    return (8 + 2.5 * r.wave) * (1 + r.stat(Stat.dmg) / 100) * r.worldDamageMul(raining: weather.isRaining);
  }

  bool _inView(double x) => x > camX - 40 && x < camX + viewW + 40;

  void _pullDrops({bool all = false, bool onlyMaterial = false}) {
    for (final d in world.children.whereType<Drop>()) {
      if ((all || _inView(d.x)) && (!onlyMaterial || d.material)) d.pull();
    }
  }

  /// Stößt Gegner im Umkreis weg; sie fliehen [fear] Sekunden.
  void _pushAway(Vector2 from, double radius, double fear, {double dmg = 0, Color color = const Color(0xFFFFE6A0)}) {
    world.add(Ring(from.clone(), radius, color: color));
    for (final e in [...enemies]) {
      if (e.dead) continue;
      final d = e.position - from;
      if (d.length > radius + e.r) continue;
      e.fearT = max(e.fearT, fear);
      if (!e.boss) e.vel.setFrom((d.length < 1 ? Vector2(1, 0) : d.normalized())..scale(520));
      if (dmg > 0) hurtEnemy(e, dmg, false, 0);
    }
  }

  /// Betäubt Gegner im Umkreis und schadet ihnen (Trommelwirbel).
  void _shockwave(Vector2 at, double radius, double stun, double dmg) {
    world.add(Ring(at.clone(), radius, color: const Color(0xFFFFB37A)));
    shake = max(shake, 6);
    for (final e in [...enemies]) {
      if (!e.dead && e.position.distanceTo(at) < radius + e.r) {
        e.stun(stun);
        hurtEnemy(e, dmg, false, 0);
      }
    }
  }

  /// Blitze in bis zu [n] zufällige Gegner im Umkreis.
  void lightningAround(Vector2 at, double radius, int n, double dmg) {
    final near = enemies.where((e) => !e.dead && e.position.distanceTo(at) < radius).toList()..shuffle(rng);
    for (final e in near.take(n)) {
      world.add(Lightning(e.position.clone()));
      hurtEnemy(e, dmg, false, 0);
      e.stun(0.3);
    }
  }

  /// Kettenblitz: springt von Gegner zu Gegner (höchstens [jumps], je Sprung bis 170 weit).
  void _chainLightning(Vector2 from, int jumps, double dmg) {
    var at = from;
    final hit = <Enemy>{};
    for (var i = 0; i < jumps; i++) {
      Enemy? next;
      var best = 170.0 * 170;
      for (final e in enemies) {
        if (e.dead || hit.contains(e)) continue;
        final d2 = e.position.distanceToSquared(at);
        if (d2 < best) {
          best = d2;
          next = e;
        }
      }
      if (next == null) break;
      hit.add(next);
      world.add(Lightning(next.position.clone()));
      hurtEnemy(next, dmg, false, 0);
      next.stun(0.4);
      at = next.position.clone();
    }
  }

  void useAction([int slot = 0]) {
    final r = run;
    if (r == null || !playing || !actionReady(slot)) return;
    final act = r.actions[slot];
    actionCds[slot] = act.cooldown;
    final pw = act.power;
    _actionPower = pw;
    final p = player.position;
    final base = actionDamage * pw;
    switch (act.id) {
      case ActionId.dash:
        player.dash(0.22 * pw);
      case ActionId.horn:
        _pushAway(p, 240 * (pw > 1 ? 1.3 : 1), 2 * pw);
      case ActionId.bubbleShield:
        shieldT = 1.2 * pw;
      case ActionId.flash:
        flashT = 0.35;
        for (final e in enemies) {
          if (_inView(e.x)) e.stun(1.5 * pw);
        }
      case ActionId.storm:
        _startStorm(3 * pw);
      case ActionId.magnet:
        _pullDrops(all: pw > 1, onlyMaterial: true);
      case ActionId.clock:
        timeSlowT = 3 * pw;
      case ActionId.bellySlide:
        slideT = 0.7;
        _slideTrap = false;
        _slideHit.clear();
        player.slide();
      case ActionId.drumroll:
        _shockwave(p, 200 * (pw > 1 ? 1.3 : 1), 1.6, base * 0.5);
      case ActionId.steal:
        _pullDrops(all: pw > 1);
        burst(p, const Color(0xFF9FD4FF), 14, 220);
      case ActionId.egg:
        world.add(Egg(p.clone(), player.face, base * 1.6));
      // ---- Evolutionen
      case ActionId.sonicBoom:
        player.dash(0.26);
        _boomT = 0.26;
      case ActionId.bubbleRocket:
        player.dash(0.35, 820);
        shieldT = max(shieldT, 0.6);
        _rocketT = 0.35;
      case ActionId.sunStorm:
        flashT = 0.35;
        for (final e in [...enemies]) {
          if (e.dead || !_inView(e.x)) continue;
          e.stun(1.5);
          world.add(Lightning(e.position.clone()));
          hurtEnemy(e, base * 1.5, false, 0);
        }
      case ActionId.snapshot:
        flashT = 0.25;
        freezeT = 2;
        for (final e in enemies) {
          if (_inView(e.x)) e.stun(2);
        }
      case ActionId.timeBubble:
        timeBubbleT = 2.5;
        shieldT = max(shieldT, 2.5);
      case ActionId.vacuum:
        vacuumT = 0.7;
        _pullDrops();
      case ActionId.goldenHour:
        goldenT = 5;
        _pullDrops(onlyMaterial: true);
        floatText(p - Vector2(0, 30), 'GOLDENE STUNDE', Palette.sun, 16);
      case ActionId.thunderHorn:
        _pushAway(p, 240, 2, color: const Color(0xFFBFE0FF));
        _chainLightning(p, 7, base);
      case ActionId.stormEgg:
        world.add(Egg(p.clone(), player.face, base * 1.6, storm: true));
      case ActionId.torpedo:
        player.dash(0.8, 700);
        slideT = 0.8;
        _slideTrap = false;
        _slideHit.clear();
      case ActionId.drumSolo:
        _drums = 3;
        _drumT = 0;
      case ActionId.magpieHoard:
        _pullDrops();
        hoardT = 5;
        burst(p, const Color(0xFF9FD4FF), 20, 260);
      case ActionId.comet:
        player.dash(0.3, 820);
        _cometT = 0.3;
        _slideHit.clear();
      case ActionId.timeJump:
        player.dash(0.3, 820);
        timeSlowT = max(timeSlowT, 2.5);
      case ActionId.bounceBubble:
        shieldT = max(shieldT, 2);
        _bounceT = 2;
        _bounceCd.clear();
      case ActionId.fanfare:
        flashT = 0.35;
        world.add(Ring(p.clone(), 260, color: const Color(0xFFFFE6A0)));
        for (final e in enemies) {
          if (!_inView(e.x)) continue;
          e.stun(2);
          e.fearT = max(e.fearT, 5);
        }
      case ActionId.stormBubble:
        shieldT = max(shieldT, 2);
        _startStorm(2, every: 0.4, radius: 260);
      case ActionId.bubbleTrap:
        world.add(Ring(p.clone(), 260, color: const Color(0xFFBFF0FF)));
        for (final e in enemies) {
          if (!e.dead && e.position.distanceTo(p) < 260 + e.r) {
            e.applyEffects(const WeaponStats(dmg: 0, cooldown: 1, range: 0, trap: 2.5));
          }
        }
        _pullDrops(onlyMaterial: true);
      case ActionId.electroMagnet:
        _magnetT = 1.2;
        _magnetTick = 0;
      case ActionId.endlessStorm:
        _startStorm(6);
        timeSlowT = max(timeSlowT, 3);
      case ActionId.goldenEgg:
        world.add(Egg(p.clone(), player.face, base * 1.6, gold: true));
      case ActionId.sledRide:
        player.slide(1.2);
        slideT = 1.2;
        shieldT = max(shieldT, 1.2);
        _slideTrap = true;
        _slideHit.clear();
      case ActionId.strobe:
        _strobes = 3;
        _strobeT = 0;
      case ActionId.pickpocket:
        _pullDrops();
        timeSlowT = max(timeSlowT, 4);
        burst(p, const Color(0xFF9FD4FF), 16, 240);
    }
  }

  void _startStorm(double time, {double every = 0.25, double radius = 460}) {
    stormT = time;
    _stormTick = 0;
    _stormEvery = every;
    _stormRadius = radius;
  }

  /// Laufende Aktionen und Item-Timer pro Frame.
  void _tickActions(double dt) {
    for (var i = 0; i < actionCds.length; i++) {
      final was = actionCds[i];
      actionCds[i] = max(0.0, was - dt);
      actionReadyFlash[i] = max(0.0, actionReadyFlash[i] - dt);
      // Gerade wieder bereit: kurz und deutlich zeigen
      if (was > 0 && actionCds[i] == 0 && i < (run?.actions.length ?? 0)) {
        actionReadyFlash[i] = actionReadyFlashTime;
        final col = run!.actions[i].id.evolved ? const Color(0xFFFFC94A) : Palette.sun;
        world.add(Ring(player.position.clone(), player.r + 26, color: col));
        burst(player.position, col, 10, 120);
      }
    }
    timeSlowT = max(0.0, timeSlowT - dt);
    shieldT = max(0.0, shieldT - dt);
    flashT = max(0.0, flashT - dt);
    freezeT = max(0.0, freezeT - dt);
    goldenT = max(0.0, goldenT - dt);
    hoardT = max(0.0, hoardT - dt);
    lightShieldCd = max(0.0, lightShieldCd - dt);
    lifestealCd = max(0.0, lifestealCd - dt);
    final p = player.position;
    if (stormT > 0) {
      stormT -= dt;
      _stormTick -= dt;
      if (_stormTick <= 0) {
        _stormTick = _stormEvery;
        lightningAround(p, _stormRadius, 1, actionDamage * _actionPower);
      }
    }
    if (slideT > 0) {
      slideT -= dt;
      for (final e in [...enemies]) {
        if (e.dead || _slideHit.contains(e)) continue;
        if (e.position.distanceTo(p) < e.r + player.r + 10) {
          _slideHit.add(e);
          hurtEnemy(e, actionDamage * 0.8 * _actionPower, false, player.face * 30);
          if (_slideTrap) {
            e.applyEffects(const WeaponStats(dmg: 0, cooldown: 1, range: 0, trap: 2));
          } else {
            e.stun(0.8);
          }
        }
      }
    }
    if (_boomT > 0) {
      _boomT -= dt;
      if (_boomT <= 0) {
        shake = max(shake, 8);
        _pushAway(p, 170, 1.5, dmg: actionDamage * 1.2, color: const Color(0xFFFFF0B8));
      }
    }
    if (_rocketT > 0) {
      _rocketT -= dt;
      for (final e in enemies) {
        if (!e.dead && e.position.distanceTo(p) < e.r + player.r + 24) {
          e.applyEffects(const WeaponStats(dmg: 0, cooldown: 1, range: 0, trap: 2.5));
        }
      }
    }
    if (timeBubbleT > 0) {
      timeBubbleT -= dt;
      for (final e in enemies) {
        if (!e.dead && e.position.distanceTo(p) < 150 + e.r) e.stun(0.2);
      }
    }
    if (vacuumT > 0) {
      vacuumT -= dt;
      for (final e in enemies) {
        if (e.dead || e.boss) continue;
        final d = p - e.position;
        final len = d.length;
        if (len < 340 && len > player.r + e.r + 6) e.position.addScaled(d / len, 420 * dt);
      }
      if (vacuumT <= 0) {
        shake = max(shake, 9);
        _pushAway(p, 190, 1.5, dmg: actionDamage * 1.5, color: const Color(0xFFCFFFF0));
      }
    }
    if (_cometT > 0) {
      _cometT -= dt;
      for (final e in [...enemies]) {
        if (e.dead || _slideHit.contains(e) || e.position.distanceTo(p) > e.r + player.r + 26) continue;
        _slideHit.add(e);
        burst(e.position, const Color(0xFFFFF0B8), 8, 160);
        hurtEnemy(e, actionDamage, false, player.face * 20);
        e.stun(1.2);
      }
    }
    if (_bounceT > 0) {
      _bounceT -= dt;
      _bounceCd.updateAll((_, v) => v - dt);
      _bounceCd.removeWhere((e, v) => v <= 0 || e.dead);
      for (final e in [...enemies]) {
        if (e.dead || _bounceCd.containsKey(e)) continue;
        final d = e.position - p;
        if (d.length > e.r + player.r + 30) continue;
        _bounceCd[e] = 0.6;
        if (!e.boss) e.vel.setFrom((d.length < 1 ? Vector2(1, 0) : d.normalized())..scale(600));
        e.fearT = max(e.fearT, 0.6);
        hurtEnemy(e, actionDamage * 0.5, false, 0);
      }
    }
    if (_magnetT > 0) {
      _magnetT -= dt;
      _magnetTick -= dt;
      for (final e in enemies) {
        if (e.dead || e.boss) continue;
        final d = p - e.position;
        final len = d.length;
        if (len < 340 && len > player.r + e.r + 20) e.position.addScaled(d / len, 380 * dt);
      }
      if (_magnetTick <= 0) {
        _magnetTick = 0.25;
        lightningAround(p, 220, 1, actionDamage * 0.8);
      }
    }
    if (_strobes > 0) {
      _strobeT -= dt;
      if (_strobeT <= 0) {
        _strobes--;
        _strobeT = 0.45;
        flashT = 0.2;
        for (final e in [...enemies]) {
          if (e.dead || !_inView(e.x)) continue;
          e.stun(0.8);
          hurtEnemy(e, actionDamage * 0.4, false, 0);
        }
      }
    }
    if (_drums > 0) {
      _drumT -= dt;
      if (_drumT <= 0) {
        _drums--;
        _drumT = 0.4;
        _shockwave(p, 210, 1.2, actionDamage * 0.5);
      }
    }
  }

  void burst(Vector2 at, Color color, int n, [double speed = 160]) =>
      world.add(Burst(at, color, n, speed, rng));

  /// Höchstzahl gleichzeitiger schwebender Zahlen – darüber werden neue ausgelassen.
  static const maxFloatTexts = 40;
  int floatTextCount = 0;

  void floatText(Vector2 at, String text, Color color, double fontSize) {
    if (floatTextCount >= maxFloatTexts) return;
    floatTextCount++; // sofort zählen, damit mehrere Zahlen im selben Frame die Grenze nicht überspringen
    world.add(FloatText(at.clone()..x += rnd(-6, 6), text, color, fontSize));
  }

  // ---------------- Debug: Performance-Test ----------------

  /// Lastszene: Wald mit Regen (meiste Effekte), dauerhaft [benchmarkEnemies] Gegner,
  /// sechs Stufe-IV-Waffen, Stufe Phönix, Held unverwundbar. Nach einer Aufwärmphase
  /// wird [benchmarkSeconds] lang gemessen.
  void startBenchmark() {
    startRun('smg', kDifficultyCount);
    final r = run!;
    r.wave = 12;
    r.weapons.first.tier = 3;
    for (final id in ['pistol', 'shotgun', 'rail', 'rocket', 'smg']) {
      r.addWeapon(id, 3);
    }
    startWave();
    weather.set(WeatherType.rain);
    godMode = benchmarkRunning = true;
    benchmarkLeft = benchmarkSeconds + benchmarkWarmup;
    perf.reset();
    showPerf = true;
  }

  void _benchmarkTick(double dt) {
    waveTime = 999; // Welle endet nicht von selbst
    player.iframe = 0;
    // Gegnerzahl konstant halten, direkt rund um den Spieler
    var guard = 0;
    while (enemies.length < benchmarkEnemies && guard++ < 20) {
      final type = benchmarkTypes[rng.nextInt(benchmarkTypes.length)];
      final d = enemyDefs[type]!;
      final x = clampD(player.x + (rng.nextBool() ? 1 : -1) * rnd(160, 650), 40, worldW - 40);
      final y = d.flying ? rnd(kCeil + 50, kGround - 90) : kGround - d.radius;
      addEnemy(type, Vector2(x, y));
    }
    if (analysisRunning) {
      _analysisTick(dt);
      return;
    }
    benchmarkLeft -= dt;
    perf.recording = benchmarkLeft <= benchmarkSeconds;
    if (benchmarkLeft <= 0) {
      final result = perf.endRecording();
      perfResult = result;
      debugPrint(result.toString());
      godMode = benchmarkRunning = false;
      togglePause();
    }
  }

  void startRenderAnalysis() {
    startBenchmark();
    analysisRunning = true;
    analysis.clear();
    analysisIndex = 0;
    perfSkip.clear();
    _analysisT = benchmarkWarmup + analysisMeasure;
  }

  void _analysisTick(double dt) {
    _analysisT -= dt;
    perf.recording = _analysisT <= analysisMeasure;
    if (_analysisT > 0) return;
    analysis.add((_segments[analysisIndex], perf.endRecording()));
    perf.reset();
    analysisIndex++;
    if (analysisIndex >= _segments.length) {
      perfSkip.clear();
      analysisRunning = godMode = benchmarkRunning = false;
      for (final line in analysisLines()) {
        debugPrint(line);
      }
      togglePause();
      return;
    }
    perfSkip
      ..clear()
      ..add(_segments[analysisIndex]!);
    _analysisT = analysisSettle + analysisMeasure;
  }

  /// Ergebnis der Render-Analyse: Rasterzeit mit allem und Ersparnis je Bildteil (größte zuerst).
  List<String> analysisLines() {
    if (analysis.isEmpty) return const [];
    final base = analysis.first.$2;
    final rows = [
      for (final (part, r) in analysis.skip(1)) (part!, r, base.avgRasterMs - r.avgRasterMs),
    ]..sort((a, b) => b.$3.compareTo(a.$3));
    return [
      'Render-Analyse – alles an: Raster Ø ${base.avgRasterMs.toStringAsFixed(1)} ms, ${base.avgFps.toStringAsFixed(0)} FPS',
      for (final (part, r, save) in rows)
        'ohne ${part.label}: Raster ${r.avgRasterMs.toStringAsFixed(1)} ms  '
            '(${save >= 0 ? '−' : '+'}${save.abs().toStringAsFixed(1)} ms${save.abs() < 1 ? ', im Rauschen' : ''})',
    ];
  }

  /// F3 blendet die FPS-Anzeige ein/aus – global, auch in Menüs.
  bool _onDebugKey(KeyEvent e) {
    if (e is KeyDownEvent && e.logicalKey == LogicalKeyboardKey.f3) {
      showPerf = !showPerf;
      return true;
    }
    return false;
  }

  // ---------------- Tastatur ----------------

  static final _menuKeys = {
    LogicalKeyboardKey.arrowUp,
    LogicalKeyboardKey.arrowDown,
    LogicalKeyboardKey.arrowLeft,
    LogicalKeyboardKey.arrowRight,
    LogicalKeyboardKey.tab,
  };

  @override
  KeyEventResult onKeyEvent(
    KeyEvent event,
    Set<LogicalKeyboardKey> keysPressed,
  ) {
    if (inputCapture) return KeyEventResult.handled;
    // Tastatur benutzt: Controller-Hinweise wieder ausblenden
    if (event is KeyDownEvent && pad.used) pad.used = false;
    final b = settings.bindings;
    keyLeft = b.keyHeld(InputAction.left, keysPressed);
    keyRight = b.keyHeld(InputAction.right, keysPressed);
    keyFly = b.keyHeld(InputAction.fly, keysPressed);
    keyDown = b.keyHeld(InputAction.down, keysPressed);
    if (playing && event is KeyDownEvent) {
      if (b.keyMatches(InputAction.action1, event.logicalKey)) useAction(0);
      if (b.keyMatches(InputAction.action2, event.logicalKey)) useAction(1);
    }
    // Menüs: Pfeile/Tab holen den Fokus auf den ersten Button,
    // danach übernimmt Flutters Fokus-Navigation (Pfeile, Tab, Enter).
    if (!playing &&
        event is KeyDownEvent &&
        _menuKeys.contains(event.logicalKey)) {
      _focusFirstMenuItem();
      return KeyEventResult.handled;
    }
    // Pause: belegte Taste; Esc immer (Pause bzw. zurück im Menü)
    if (event is KeyDownEvent &&
        (b.keyMatches(InputAction.pause, event.logicalKey) || event.logicalKey == LogicalKeyboardKey.escape)) {
      if (phase == Phase.menu) {
        menuBack?.call();
      } else {
        togglePause();
      }
    }
    if (kDebugTools && event is KeyDownEvent && playing) {
      // Debug: Wetter direkt umschalten
      if (event.logicalKey == LogicalKeyboardKey.digit1) {
        weather.set(WeatherType.clear);
      }
      if (event.logicalKey == LogicalKeyboardKey.digit2) {
        weather.set(WeatherType.wind);
      }
      if (event.logicalKey == LogicalKeyboardKey.digit3) {
        weather.set(WeatherType.rain);
      }
    }
    return KeyEventResult.handled;
  }
}
