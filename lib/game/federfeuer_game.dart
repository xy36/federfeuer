import 'dart:math';

import 'package:flame/components.dart';
import 'package:flame/events.dart';
import 'package:flame/game.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

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
import 'components/weapon_mount.dart';
import 'components/weather_layer.dart';
import 'config.dart';
import 'gamepad_input.dart';
import 'perf.dart';
import 'progress.dart';
import 'settings.dart';
import '../platform/desktop_window.dart';
import 'run_state.dart';
import 'weather.dart';

/// `cleared`: Welle vorbei, kurze Einblendung, bevor Level-up/Shop erscheinen.
enum Phase { menu, play, cleared, levelUp, shop, paused, over }

class ArenaWorld extends World {}

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

  // Eingabe
  bool keyLeft = false, keyRight = false, keyFly = false;
  bool touchLeft = false, touchRight = false, touchFly = false;
  late final pad = GamepadInput(
    onNavigate: _padNavigate,
    onConfirm: _padConfirm,
    onBack: _padBack,
    onStart: _padStart,
  );
  bool get inLeft => keyLeft || touchLeft || pad.left;
  bool get inRight => keyRight || touchRight || pad.right;
  bool get inFly => keyFly || touchFly || pad.fly;
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

  void startRun(String weaponId, {int? difficulty}) {
    run = RunState(weaponId, difficulty: difficulty ?? progress.selected);
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
    _puddles.setArenaWidth(worldW);
    goalX = boss ? null : worldW - kGoalInset;
    if (goalX != null) world.add(Goal(goalX!));
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
    touchLeft = touchRight = touchFly = false;
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
    run!.wave++;
    startWave();
  }

  /// Ziel erreicht: Welle bestanden, Bonus für die Restzeit.
  void reachGoal() {
    final r = run!;
    final bonus = (max(0.0, waveTime) / kGoalBonusSeconds).floor();
    r.goalBonus = bonus;
    r.gain(bonus);
    endWave();
  }

  /// Welle vorbei: Gegner verpuffen, kurze Einblendung, dann Level-up/Shop.
  void endWave() {
    final r = run!;
    // Nur Material, das schon zum Spieler fliegt, zählt noch; der Rest verfällt.
    for (final d in world.children.whereType<Drop>()) {
      if (d.material && !d.taken && d.pulled) r.gain(1);
    }
    for (final e in enemies) {
      if (!e.dead) burst(e.position, const Color(0xFFC77DFF), 8, 140);
    }
    for (final c in world.children
        .where((c) => c is Enemy || c is EnemyBullet || c is Bullet || c is SpawnMarker || c is Drop)
        .toList()) {
      c.removeFromParent();
    }
    enemies.clear();
    touchLeft = touchRight = touchFly = false;
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
      touchLeft = touchRight = touchFly = false;
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
    newlyUnlocked = progress.recordRun(difficulty: r.difficulty, wave: r.wave, won: win, kills: r.kills, level: r.level);
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
      if (g != null && player.x + player.r >= g) {
        reachGoal();
        return;
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
    final pool = <(EnemyType, double)>[(EnemyType.crow, 10)];
    if (w >= 2) pool.add((EnemyType.beetle, 7));
    if (w >= 3) pool.add((EnemyType.spitter, 4 + w * 0.3));
    if (w >= 5) pool.add((EnemyType.rock, 2 + w * 0.3));
    final total = pool.fold(0.0, (a, b) => a + b.$2);

    var n = 1 + (w / 2.5).floor() + (rng.nextDouble() < 0.4 ? 1 : 0);
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
      final y = d.flying ? rnd(kCeil + 50, kGround - 90) : kGround - d.radius;
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
      if (!e.dead && e.x < player.x - kDespawnBehind) {
        e.dead = true;
        e.removeFromParent();
      }
    }
    enemies.removeWhere((e) => e.dead);
  }

  void addEnemy(EnemyType type, Vector2 pos) {
    final e = Enemy(type, pos, run!.wave, run!.difficultyDef, rng);
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
          if (a.type != EnemyType.boss) {
            a.position.x -= dx * push;
            a.position.y -= dy * push;
          }
          if (b.type != EnemyType.boss) {
            b.position.x += dx * push;
            b.position.y += dy * push;
          }
        }
      }
    }
  }

  // ---------------- Kampf ----------------

  void hurtPlayer(double amount) {
    final r = run;
    if (r == null || !playing || player.iframe > 0 || winT > 0 || godMode) return;
    final a = r.stat(Stat.armor);
    final f = a >= 0 ? 15 / (15 + a) : 1 + (-a) / 15;
    final dmg = max(1, (amount * f).round());
    r.hp -= dmg;
    player.iframe = 0.6;
    shake = 8;
    floatText(player.position, '-$dmg', Palette.coral, 17);
    burst(player.position, Palette.coral, 8);
    if (r.hp <= 0) {
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

  void gain(int v) {
    if (run!.gain(v)) {
      floatText(player.position - Vector2(0, 40), 'LEVEL UP', Palette.sun, 18);
    }
  }

  void hurtEnemy(Enemy e, double dmg, bool crit, double knock) {
    if (e.dead) return;
    e.hp -= dmg;
    e.flash = 0.08;
    if (e.type != EnemyType.boss) e.position.x += knock;
    floatText(
      Vector2(e.x, e.y - e.r),
      '${dmg.round()}',
      crit ? Palette.sun : const Color(0xFFFFFFFF),
      crit ? 18 : 14,
    );
    final ls = run!.stat(Stat.lifesteal);
    if (ls > 0 && rng.nextDouble() * 100 < ls) heal(1);
    if (e.hp <= 0) killEnemy(e);
  }

  void killEnemy(Enemy e) {
    e.dead = true;
    e.removeFromParent();
    run!.kills++;
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
      for (final c
          in world.children
              .where((c) => c is EnemyBullet || c is SpawnMarker)
              .toList()) {
        c.removeFromParent();
      }
      return;
    }
    burst(e.position, const Color(0xFFC77DFF), 12, 170);
    for (var i = 0; i < enemyDefs[e.type]!.drop; i++) {
      world.add(
        Drop(e.position.clone()..x += rnd(-8, 8), material: true, rng: rng, fallSpeed: run!.difficultyDef.dropFallSpeed),
      );
    }
    if (rng.nextDouble() < 0.04) {
      world.add(Drop(e.position.clone(), material: false, rng: rng, fallSpeed: run!.difficultyDef.dropFallSpeed));
    }
  }

  void explode(Vector2 at, double radius, double dmg, bool crit) {
    shake = max(shake, 5);
    burst(at, const Color(0xFFFF9F1C), 18, 220);
    world.add(Ring(at.clone(), radius));
    for (final e in enemies) {
      if (!e.dead && e.position.distanceTo(at) < radius + e.r) {
        hurtEnemy(e, dmg, crit, 0);
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
    world.add(FloatText(at.clone()..x += rnd(-6, 6), text, color, fontSize));
  }

  // ---------------- Debug: Performance-Test ----------------

  /// Lastszene: Wald mit Regen (meiste Effekte), dauerhaft [benchmarkEnemies] Gegner,
  /// sechs Stufe-IV-Waffen, Stufe Phönix, Held unverwundbar. Nach einer Aufwärmphase
  /// wird [benchmarkSeconds] lang gemessen.
  void startBenchmark() {
    startRun('smg', difficulty: kDifficultyCount);
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
    bool has(LogicalKeyboardKey k) => keysPressed.contains(k);
    keyLeft = has(LogicalKeyboardKey.keyA) || has(LogicalKeyboardKey.arrowLeft);
    keyRight =
        has(LogicalKeyboardKey.keyD) || has(LogicalKeyboardKey.arrowRight);
    keyFly =
        has(LogicalKeyboardKey.space) ||
        has(LogicalKeyboardKey.keyW) ||
        has(LogicalKeyboardKey.arrowUp);
    // Menüs: Pfeile/Tab holen den Fokus auf den ersten Button,
    // danach übernimmt Flutters Fokus-Navigation (Pfeile, Tab, Enter).
    if (!playing &&
        event is KeyDownEvent &&
        _menuKeys.contains(event.logicalKey)) {
      _focusFirstMenuItem();
      return KeyEventResult.handled;
    }
    if (event is KeyDownEvent &&
        (event.logicalKey == LogicalKeyboardKey.keyP ||
            event.logicalKey == LogicalKeyboardKey.escape)) {
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
