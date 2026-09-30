import 'dart:math';

import 'package:flame/components.dart';
import 'package:flame/events.dart';
import 'package:flame/game.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

import 'components/effects.dart';
import 'components/enemy.dart';
import 'components/hud.dart';
import 'components/pickups.dart';
import 'components/player.dart';
import 'components/projectiles.dart';
import 'components/scenery.dart';
import 'components/transient.dart';
import 'components/weapon_mount.dart';
import 'config.dart';
import 'run_state.dart';

enum Phase { menu, play, levelUp, shop, paused, over }

class ArenaWorld extends World {}

class FederfeuerGame extends FlameGame<ArenaWorld> with KeyboardEvents {
  FederfeuerGame() : super(world: ArenaWorld());

  static const overlayIds = ['menu', 'levelUp', 'shop', 'pause', 'gameOver', 'controls'];

  final rng = Random();
  final focusNode = FocusNode();
  final enemies = <Enemy>[];
  final _mounts = <WeaponMount>[];
  late final Player player;

  Phase phase = Phase.menu;
  RunState? run;
  int bestWave = 0;
  bool won = false;

  // Eingabe
  bool keyLeft = false, keyRight = false, keyFly = false;
  bool touchLeft = false, touchRight = false, touchFly = false;
  bool get inLeft => keyLeft || touchLeft;
  bool get inRight => keyRight || touchRight;
  bool get inFly => keyFly || touchFly;
  bool get playing => phase == Phase.play;

  // Kamera (Weltkoordinaten)
  double zoom = 1, viewW = 800, viewH = kVH, offY = 0, camX = 0;

  // Wellen
  double waveTime = 0, banner = 0, shake = 0, winT = 0;
  double _spawnT = 0, _regenAcc = 0, _menuT = 0;

  double rnd(double a, double b) => a + rng.nextDouble() * (b - a);

  @override
  Color backgroundColor() => const Color(0xFF1D1540);

  @override
  Future<void> onLoad() async {
    camera.viewfinder.anchor = Anchor.topLeft;
    player = Player();
    world.addAll([Backdrop(), Ground(), player]);
    camera.viewport.add(Hud());
    overlays.add('menu');
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

  void startRun(String weaponId) {
    run = RunState(weaponId);
    won = false;
    startWave();
  }

  void startWave() {
    final r = run!;
    phase = Phase.play;
    _setOverlays(['controls']);
    _clearArena();
    r.hp = r.maxHp;
    player.reset(Vector2(kWorldW / 2, kGround - 140));
    _syncWeapons();
    waveTime = r.wave == kMaxWave ? 0 : min(20.0 + (r.wave - 1) * 4, 56.0);
    _spawnT = 1.2;
    banner = 2;
    winT = 0;
    shake = 0;
    touchLeft = touchRight = touchFly = false;
    if (r.wave == kMaxWave) {
      final side = rng.nextBool() ? -500.0 : 500.0;
      world.add(SpawnMarker(EnemyType.boss, Vector2(clampD(player.x + side, 100, kWorldW - 100), 170), 2));
    }
    camX = _targetCam();
    focusNode.requestFocus();
  }

  void nextWave() {
    run!.wave++;
    startWave();
  }

  void endWave() {
    final r = run!;
    for (final d in world.children.whereType<Drop>()) {
      if (d.material && !d.taken) r.gain(1);
    }
    _clearArena();
    touchLeft = touchRight = touchFly = false;
    _afterWave();
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
    bestWave = max(bestWave, win ? kMaxWave + 1 : r.wave);
    _setOverlays([]);
    Future.delayed(Duration(milliseconds: win ? 0 : 700), () {
      if (phase == Phase.over) overlays.add('gameOver');
    });
  }

  void toMenu() {
    run = null;
    phase = Phase.menu;
    _clearArena();
    for (final m in _mounts) {
      m.removeFromParent();
    }
    _mounts.clear();
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
    dt = min(dt, 0.05);
    final active = playing;
    super.update(active ? dt : 0);

    if (run == null) {
      _menuT += dt;
      camX = (sin(_menuT * 0.08) * 0.5 + 0.5) * max(0.0, kWorldW - viewW);
      _placeCamera(0, 0);
      return;
    }
    if (!active) return;
    final r = run!;

    banner = max(0.0, banner - dt);
    shake = max(0.0, shake - dt * 40);
    enemies.removeWhere((e) => e.dead);
    _separateEnemies();
    _updateCamera(dt);

    if (winT > 0) {
      winT -= dt;
      if (winT <= 0) endRun(true);
      return;
    }
    if (r.wave < kMaxWave) {
      waveTime -= dt;
      if (waveTime <= 0) {
        endWave();
        return;
      }
    }

    _spawnT -= dt;
    if (_spawnT <= 0) {
      _spawnBatch();
      _spawnT = max(0.9, 2.4 - r.wave * 0.15) * rnd(0.7, 1.3) * (r.wave == kMaxWave ? 1.7 : 1);
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

  double _targetCam() => viewW >= kWorldW
      ? (kWorldW - viewW) / 2
      : clampD(player.x - viewW / 2 + player.vel.x * 0.35, 0, kWorldW - viewW);

  void _updateCamera(double dt) {
    camX += (_targetCam() - camX) * min(1.0, dt * 6);
    _placeCamera((rng.nextDouble() - 0.5) * shake, (rng.nextDouble() - 0.5) * shake);
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
    var cx = rnd(60, kWorldW - 60);
    while ((cx - player.x).abs() < 280) {
      cx = rnd(60, kWorldW - 60);
    }
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
      final x = clampD(cx + rnd(-80, 80), 40, kWorldW - 40);
      final y = d.flying ? rnd(kCeil + 50, kGround - 90) : kGround - d.radius;
      world.add(SpawnMarker(type, Vector2(x, y), 0.9));
    }
  }

  void addEnemy(EnemyType type, Vector2 pos) {
    final e = Enemy(type, pos, run!.wave, rng);
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
    if (r == null || !playing || player.iframe > 0 || winT > 0) return;
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
    if (run!.gain(v)) floatText(player.position - Vector2(0, 40), 'LEVEL UP', Palette.sun, 18);
  }

  void hurtEnemy(Enemy e, double dmg, bool crit, double knock) {
    if (e.dead) return;
    e.hp -= dmg;
    e.flash = 0.08;
    if (e.type != EnemyType.boss) e.position.x += knock;
    floatText(Vector2(e.x, e.y - e.r), '${dmg.round()}', crit ? Palette.sun : const Color(0xFFFFFFFF),
        crit ? 18 : 14);
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
        burst(o.position, const Color(0xFFE8D9FF), 6);
      }
      for (final c in world.children.where((c) => c is EnemyBullet || c is SpawnMarker).toList()) {
        c.removeFromParent();
      }
      return;
    }
    burst(e.position, const Color(0xFFE8D9FF), 12, 170);
    for (var i = 0; i < enemyDefs[e.type]!.drop; i++) {
      world.add(Drop(e.position.clone()..x += rnd(-8, 8), material: true, rng: rng));
    }
    if (rng.nextDouble() < 0.04) world.add(Drop(e.position.clone(), material: false, rng: rng));
  }

  void explode(Vector2 at, double radius, double dmg, bool crit) {
    shake = max(shake, 5);
    burst(at, const Color(0xFFFF9F1C), 18, 220);
    world.add(Ring(at.clone(), radius));
    for (final e in enemies) {
      if (!e.dead && e.position.distanceTo(at) < radius + e.r) hurtEnemy(e, dmg, crit, 0);
    }
  }

  void burst(Vector2 at, Color color, int n, [double speed = 160]) =>
      world.add(Burst(at, color, n, speed, rng));

  void floatText(Vector2 at, String text, Color color, double fontSize) =>
      world.add(FloatText(at.clone()..x += rnd(-6, 6), text, color, fontSize));

  // ---------------- Tastatur ----------------

  @override
  KeyEventResult onKeyEvent(KeyEvent event, Set<LogicalKeyboardKey> keysPressed) {
    bool has(LogicalKeyboardKey k) => keysPressed.contains(k);
    keyLeft = has(LogicalKeyboardKey.keyA) || has(LogicalKeyboardKey.arrowLeft);
    keyRight = has(LogicalKeyboardKey.keyD) || has(LogicalKeyboardKey.arrowRight);
    keyFly = has(LogicalKeyboardKey.space) || has(LogicalKeyboardKey.keyW) || has(LogicalKeyboardKey.arrowUp);
    if (event is KeyDownEvent &&
        (event.logicalKey == LogicalKeyboardKey.keyP || event.logicalKey == LogicalKeyboardKey.escape)) {
      togglePause();
    }
    return KeyEventResult.handled;
  }
}
