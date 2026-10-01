import 'dart:math';
import 'dart:ui';

import 'package:flame/components.dart';
import 'package:flutter/scheduler.dart';

import 'components/draw.dart';
import 'components/projectiles.dart';
import 'config.dart';
import 'federfeuer_game.dart';

/// Bildteile, die die Render-Analyse einzeln abschalten kann.
enum RenderPart {
  backdrop('Hintergrund (Himmel, Licht, Ebenen)'),
  decor('Kulisse'),
  ground('Boden'),
  foreground('Vordergrund'),
  atmosphere('Atmosphäre (Partikel, Vignette)'),
  weather('Wetter'),
  enemyBodies('Gegner-Körper'),
  enemyGlow('Gegner-Leuchten'),
  projectiles('Kugeln'),
  effects('Effekte (Funken, Zahlen)'),
  hud('HUD');

  const RenderPart(this.label);
  final String label;
}

/// Gerade abgeschaltete Bildteile (nur Render-Analyse). Leer im normalen Spiel.
final perfSkip = <RenderPart>{};

/// Ergebnis eines Performance-Tests.
class PerfResult {
  const PerfResult({
    required this.seconds,
    required this.frames,
    required this.avgFps,
    required this.low1Fps,
    required this.worstMs,
    required this.avgRasterMs,
    required this.maxRasterMs,
    required this.avgBuildMs,
  });

  final double seconds, avgFps, low1Fps, worstMs, avgRasterMs, maxRasterMs, avgBuildMs;
  final int frames;

  List<String> get lines => [
        'Ø ${avgFps.toStringAsFixed(1)} FPS   1%-Low ${low1Fps.toStringAsFixed(1)} FPS',
        'Schlechtester Frame ${worstMs.toStringAsFixed(1)} ms   ($frames Frames, ${seconds.toStringAsFixed(0)} s)',
        'Raster Ø ${avgRasterMs.toStringAsFixed(1)} ms / max ${maxRasterMs.toStringAsFixed(1)} ms   Build Ø ${avgBuildMs.toStringAsFixed(1)} ms',
      ];

  @override
  String toString() => 'Performance-Test: ${lines.join(' | ')}';
}

/// Misst Frame-Zeiten: Spiel-Takt (dt) und die Build-/Raster-Zeiten der Engine.
class PerfMonitor {
  final _recent = <double>[]; // letzte Frame-Zeiten in Sekunden (Live-Anzeige)
  final _run = <double>[]; // alle Frame-Zeiten des laufenden Tests
  final _raster = <double>[], _build = <double>[];
  double _rasterLive = 0, _buildLive = 0;
  bool recording = false;
  bool _listening = false;

  void start() {
    if (_listening) return;
    _listening = true;
    SchedulerBinding.instance.addTimingsCallback(_onTimings);
  }

  void stop() {
    if (!_listening) return;
    _listening = false;
    SchedulerBinding.instance.removeTimingsCallback(_onTimings);
  }

  void _onTimings(List<FrameTiming> timings) {
    for (final t in timings) {
      final r = t.rasterDuration.inMicroseconds / 1000, b = t.buildDuration.inMicroseconds / 1000;
      _rasterLive = _rasterLive * 0.9 + r * 0.1;
      _buildLive = _buildLive * 0.9 + b * 0.1;
      if (recording) {
        _raster.add(r);
        _build.add(b);
      }
    }
  }

  /// Rohe Frame-Zeit (vor der Begrenzung auf 0,05 s) eintragen; [recording]
  /// steuert, ob sie in den laufenden Test eingeht.
  void frame(double dt) {
    if (dt <= 0) return;
    _recent.add(dt);
    if (_recent.length > 120) _recent.removeAt(0);
    if (recording) _run.add(dt);
  }

  void reset() {
    _run.clear();
    _raster.clear();
    _build.clear();
    recording = false;
  }

  PerfResult endRecording() {
    recording = false;
    final total = _run.fold(0.0, (a, b) => a + b);
    final sorted = [..._run]..sort((a, b) => b.compareTo(a));
    final n1 = max(1, (sorted.length * 0.01).ceil());
    final worst1 = sorted.take(n1).fold(0.0, (a, b) => a + b) / n1;
    double avg(List<double> l) => l.isEmpty ? 0 : l.reduce((a, b) => a + b) / l.length;
    return PerfResult(
      seconds: total,
      frames: _run.length,
      avgFps: total > 0 ? _run.length / total : 0,
      low1Fps: worst1 > 0 ? 1 / worst1 : 0,
      worstMs: sorted.isEmpty ? 0 : sorted.first * 1000,
      avgRasterMs: avg(_raster),
      maxRasterMs: _raster.isEmpty ? 0 : _raster.reduce(max),
      avgBuildMs: avg(_build),
    );
  }

  double get fps {
    if (_recent.isEmpty) return 0;
    return _recent.length / _recent.fold(0.0, (a, b) => a + b);
  }

  double get worstRecentMs => _recent.isEmpty ? 0 : _recent.reduce(max) * 1000;
  double get rasterMs => _rasterLive;
  double get buildMs => _buildLive;
}

/// Debug-Anzeige oben rechts (F3) und das Ergebnis des Performance-Tests.
class PerfOverlay extends Component with HasGameReference<FederfeuerGame> {
  PerfOverlay() : super(priority: 200);

  final _bg = Paint()..color = const Color(0xD9050814);

  @override
  void render(Canvas c) {
    final g = game;
    final result = g.perfResult;
    final analysis = g.analysisRunning ? const <String>[] : g.analysisLines();
    if (!g.showPerf && result == null && !g.benchmarkRunning && analysis.isEmpty) return;
    final m = g.perf;
    final lines = <(String, Color)>[];
    if (g.showPerf || g.benchmarkRunning) {
      final fps = m.fps;
      final col = fps >= 55 ? const Color(0xFF8CF5B0) : (fps >= 30 ? const Color(0xFFFFE08A) : const Color(0xFFFF8A9A));
      lines
        ..add(('${fps.toStringAsFixed(0)} FPS   max ${m.worstRecentMs.toStringAsFixed(1)} ms', col))
        ..add(('Raster ${m.rasterMs.toStringAsFixed(1)} ms   Build ${m.buildMs.toStringAsFixed(1)} ms', const Color(0xFFE6EEFF)))
        ..add((
          'Gegner ${g.enemies.length}   Kugeln ${g.world.children.whereType<Bullet>().length + g.world.children.whereType<EnemyBullet>().length}   '
              'Komponenten ${g.world.children.length}',
          const Color(0xFFB9C6E6)
        ));
      if (g.analysisRunning) {
        final part = g.analysisPart;
        lines.add((
          'Render-Analyse ${g.analysisIndex + 1}/${g.analysisSegments}: ${part == null ? 'alles an' : 'ohne ${part.label}'}',
          const Color(0xFFFFE08A)
        ));
      } else if (g.benchmarkRunning) {
        lines.add(('Performance-Test läuft … ${g.benchmarkLeft.ceil()} s', const Color(0xFFFFE08A)));
      }
    }
    for (var i = 0; i < analysis.length; i++) {
      lines.add((analysis[i], i == 0 ? const Color(0xFFFFE08A) : const Color(0xFFFFFFFF)));
    }
    if (result != null) {
      lines.add(('Performance-Test beendet', const Color(0xFFFFE08A)));
      for (final l in result.lines) {
        lines.add((l, const Color(0xFFFFFFFF)));
      }
    }
    const lh = 17.0, pad = 8.0, w = 520.0;
    final x = g.size.x - w - 12, y = 60.0;
    c.drawRRect(RRect.fromRectAndRadius(Rect.fromLTWH(x, y, w, lines.length * lh + pad * 2), const Radius.circular(10)), _bg);
    for (var i = 0; i < lines.length; i++) {
      OutlineText.draw(c, lines[i].$1, Offset(x + pad, y + pad + lh * (i + 0.5)),
          size: 12.5, color: lines[i].$2, center: false, display: false);
    }
  }
}

/// Gegnertypen der Last-Szene im Performance-Test.
const benchmarkTypes = [EnemyType.crow, EnemyType.crow, EnemyType.beetle, EnemyType.spitter, EnemyType.rock];
