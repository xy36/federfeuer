import 'dart:math';
import 'dart:ui';

import 'package:flame/components.dart';

import '../weather.dart';

Color _rgba(int r, int g, int b, double a) =>
    Color.fromARGB((a.clamp(0.0, 1.0) * 255).round(), r, g, b);

double _approach(double v, double target, double step) =>
    v < target ? min(target, v + step) : max(target, v - step);

/// Wetter im Bildschirmraum: Regenschleier, Windlinien, Blätter.
///
/// In `camera.viewport` einhängen, Priorität unter dem HUD.
/// Blendet beim Wetterwechsel weich ein und aus.
class WeatherLayer extends Component {
  WeatherLayer(this.weather, {Random? random, int priority = 5})
      : _rng = random ?? Random(),
        super(priority: priority);

  final Weather weather;
  final Random _rng;

  static const double _fadeTime = 1.2;
  static const double _rainSlant = -0.12;

  final Vector2 _size = Vector2.zero();
  double _rainAlpha = 0;
  double _windAlpha = 0;

  final List<_RainDrop> _drops = [];
  final List<_WindStreak> _streaks = [];
  final List<_Leaf> _leaves = [];

  final Paint _overlayPaint = Paint();
  final Paint _rainPaint = Paint()
    ..strokeWidth = 1.6
    ..strokeCap = StrokeCap.round;
  final Paint _streakPaint = Paint()
    ..strokeWidth = 1.5
    ..strokeCap = StrokeCap.round;
  final Paint _leafPaint = Paint();

  static const List<(int, int, int)> _leafColors = [
    (0xFF, 0x7F, 0x66), // Koralle
    (0xFF, 0xB2, 0x7A), // Aprikose
    (0x7F, 0xE0, 0xC0), // Mint
  ];

  @override
  void onGameResize(Vector2 size) {
    super.onGameResize(size);
    _size.setFrom(size);
    _spawnParticles();
  }

  void _spawnParticles() {
    final w = _size.x, h = _size.y;
    if (w <= 0 || h <= 0) return;

    final dropCount = (w * h / 5000).clamp(60, 240).round();
    _drops
      ..clear()
      ..addAll(List.generate(
        dropCount,
        (_) => _RainDrop(
          x: _rng.nextDouble() * w,
          y: _rng.nextDouble() * h,
          len: 10 + _rng.nextDouble() * 14,
          speed: 850 + _rng.nextDouble() * 350,
        ),
      ));

    _streaks
      ..clear()
      ..addAll(List.generate(18, (_) => _newStreak()));

    _leaves
      ..clear()
      ..addAll(List.generate(10, (_) {
        final c = _leafColors[_rng.nextInt(_leafColors.length)];
        return _Leaf(
          x: _rng.nextDouble() * w,
          y: _rng.nextDouble() * h * 0.85,
          speed: 260 + _rng.nextDouble() * 160,
          phase: _rng.nextDouble() * pi * 2,
          angle: _rng.nextDouble() * pi,
          size: 3 + _rng.nextDouble() * 3,
          color: c,
        );
      }));
  }

  _WindStreak _newStreak() {
    final life = 0.6 + _rng.nextDouble() * 0.8;
    return _WindStreak(
      x: _rng.nextDouble() * _size.x,
      y: _rng.nextDouble() * _size.y * 0.9,
      len: 40 + _rng.nextDouble() * 90,
      speed: 500 + _rng.nextDouble() * 400,
      life: life,
      maxLife: life,
    );
  }

  /// Sofort ausblenden (z. B. beim Zurück ins Menü, wo dt = 0 ist).
  void clearInstant() {
    _rainAlpha = 0;
    _windAlpha = 0;
  }

  @override
  void update(double dt) {
    if (dt <= 0 || _size.x <= 0) return;
    _rainAlpha =
        _approach(_rainAlpha, weather.isRaining ? 1.0 : 0.0, dt / _fadeTime);
    _windAlpha =
        _approach(_windAlpha, weather.isWindy ? 1.0 : 0.0, dt / _fadeTime);
    if (_rainAlpha > 0) _updateRain(dt);
    if (_windAlpha > 0) _updateWind(dt);
  }

  void _updateRain(double dt) {
    final w = _size.x, h = _size.y;
    for (final d in _drops) {
      d.y += d.speed * dt;
      d.x += d.speed * _rainSlant * dt;
      if (d.y - d.len > h) {
        d.y = -_rng.nextDouble() * 40;
        d.x = _rng.nextDouble() * (w + 100) - 50;
      }
      if (d.x < -50) d.x += w + 100;
    }
  }

  void _updateWind(double dt) {
    final w = _size.x, h = _size.y;
    final n = weather.windNorm;

    for (var i = 0; i < _streaks.length; i++) {
      final s = _streaks[i];
      s.x += s.speed * n * dt;
      s.life -= dt;
      if (s.life <= 0 || s.x < -s.len - 20 || s.x > w + s.len + 20) {
        _streaks[i] = _newStreak();
      }
    }

    for (final l in _leaves) {
      l.phase += dt * 3;
      l.x += l.speed * n * dt;
      l.y += sin(l.phase) * 40 * dt + 12 * dt;
      l.angle += dt * 4 * (n >= 0 ? 1 : -1);
      if (l.x > w + 20) l.x = -20;
      if (l.x < -20) l.x = w + 20;
      if (l.y > h * 0.9) l.y = _rng.nextDouble() * h * 0.3;
    }
  }

  @override
  void render(Canvas canvas) {
    if (_rainAlpha > 0) _renderRain(canvas);
    if (_windAlpha > 0) _renderWind(canvas);
  }

  void _renderRain(Canvas canvas) {
    // Abdunkeln Richtung Indigo.
    _overlayPaint.color = _rgba(0x1B, 0x10, 0x36, 0.22 * _rainAlpha);
    canvas.drawRect(Offset.zero & Size(_size.x, _size.y), _overlayPaint);

    _rainPaint.color = _rgba(0xC8, 0xD8, 0xFF, 0.45 * _rainAlpha);
    for (final d in _drops) {
      canvas.drawLine(
        Offset(d.x, d.y),
        Offset(d.x - d.len * _rainSlant, d.y - d.len),
        _rainPaint,
      );
    }
  }

  void _renderWind(Canvas canvas) {
    final dir = weather.windNorm >= 0 ? 1.0 : -1.0;
    final strength = weather.windNorm.abs();

    for (final s in _streaks) {
      final fade = sin(pi * (s.life / s.maxLife).clamp(0.0, 1.0));
      _streakPaint.color =
          _rgba(0xFF, 0xFF, 0xFF, 0.35 * fade * strength * _windAlpha);
      canvas.drawLine(
        Offset(s.x, s.y),
        Offset(s.x - s.len * dir, s.y),
        _streakPaint,
      );
    }

    for (final l in _leaves) {
      final (r, g, b) = l.color;
      _leafPaint.color = _rgba(r, g, b, 0.9 * _windAlpha);
      canvas.save();
      canvas.translate(l.x, l.y);
      canvas.rotate(l.angle);
      canvas.drawOval(
        Rect.fromCenter(center: Offset.zero, width: l.size * 2, height: l.size),
        _leafPaint,
      );
      canvas.restore();
    }
  }
}

/// Pfützen am Boden (Weltraum), füllen sich bei Regen und trocknen danach.
///
/// In die `world` einhängen, Priorität über dem Boden, unter Figuren.
class RainPuddles extends Component {
  RainPuddles(
    this.weather, {
    required double arenaWidth,
    required this.groundY,
    Random? random,
    int priority = 1,
  })  : _rng = random ?? Random(),
        super(priority: priority) {
    final count = (arenaWidth / 140).round();
    for (var i = 0; i < count; i++) {
      _puddles.add(_Puddle(
        x: _rng.nextDouble() * arenaWidth,
        width: 30 + _rng.nextDouble() * 60,
      ));
    }
  }

  final Weather weather;
  final double groundY;
  final Random _rng;

  final List<_Puddle> _puddles = [];
  final List<_Ripple> _ripples = [];
  double _wet = 0;
  double _rippleAcc = 0;

  final Paint _puddlePaint = Paint();
  final Paint _ripplePaint = Paint()
    ..style = PaintingStyle.stroke
    ..strokeWidth = 1.2;

  @override
  void update(double dt) {
    if (dt <= 0) return;
    _wet = weather.isRaining
        ? _approach(_wet, 1, dt / 6) // füllt sich in ~6 s
        : _approach(_wet, 0, dt / 3); // trocknet in ~3 s

    for (final r in _ripples) {
      r.t += dt;
    }
    _ripples.removeWhere((r) => r.t > 0.6);

    if (weather.isRaining && _wet > 0.2 && _puddles.isNotEmpty) {
      _rippleAcc += dt * 14 * _wet;
      while (_rippleAcc >= 1) {
        _rippleAcc -= 1;
        final p = _puddles[_rng.nextInt(_puddles.length)];
        final w = _currentWidth(p);
        _ripples.add(_Ripple(x: p.x + (_rng.nextDouble() - 0.5) * w * 0.7));
      }
    }
  }

  /// Sofort trocken (z. B. beim Zurück ins Menü).
  void clearInstant() {
    _wet = 0;
    _ripples.clear();
  }

  double _currentWidth(_Puddle p) => p.width * (0.4 + 0.6 * _wet);

  @override
  void render(Canvas canvas) {
    if (_wet <= 0.01) return;
    _puddlePaint.color = _rgba(0x9F, 0xB4, 0xE8, 0.45 * _wet);
    for (final p in _puddles) {
      canvas.drawOval(
        Rect.fromCenter(
          center: Offset(p.x, groundY + 3),
          width: _currentWidth(p),
          height: 6,
        ),
        _puddlePaint,
      );
    }
    for (final r in _ripples) {
      final k = r.t / 0.6;
      _ripplePaint.color = _rgba(0xE6, 0xEE, 0xFF, 0.6 * (1 - k) * _wet);
      canvas.drawOval(
        Rect.fromCenter(
          center: Offset(r.x, groundY + 3),
          width: 4 + 18 * k,
          height: 2 + 4 * k,
        ),
        _ripplePaint,
      );
    }
  }
}

class _RainDrop {
  _RainDrop({
    required this.x,
    required this.y,
    required this.len,
    required this.speed,
  });
  double x, y;
  final double len, speed;
}

class _WindStreak {
  _WindStreak({
    required this.x,
    required this.y,
    required this.len,
    required this.speed,
    required this.life,
    required this.maxLife,
  });
  double x, life;
  final double y, len, speed, maxLife;
}

class _Leaf {
  _Leaf({
    required this.x,
    required this.y,
    required this.speed,
    required this.phase,
    required this.angle,
    required this.size,
    required this.color,
  });
  double x, y, phase, angle;
  final double speed, size;
  final (int, int, int) color;
}

class _Puddle {
  _Puddle({required this.x, required this.width});
  final double x, width;
}

class _Ripple {
  _Ripple({required this.x});
  final double x;
  double t = 0;
}
