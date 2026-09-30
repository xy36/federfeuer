import 'dart:math';

import 'package:flame/components.dart';
import 'package:flutter/material.dart';

import '../config.dart';
import '../federfeuer_game.dart';
import 'draw.dart';
import 'enemy.dart';

/// Wird im Viewport (Bildschirmkoordinaten) gezeichnet.
class Hud extends Component with HasGameReference<FederfeuerGame> {
  Hud() : super(priority: 100);

  final _arrow = Path();

  @override
  void render(Canvas c) {
    final g = game, r = g.run;
    if (r == null) return;
    final s = g.size;
    const pad = 12.0;
    final w = min(220.0, s.x * 0.38);

    // HP
    drawRect(c, pad - 3, pad - 3, w + 6, 24, Palette.ink);
    drawRect(c, pad, pad, w, 18, const Color(0xFF5A2438));
    drawRect(c, pad, pad, w * clampD(r.hp / r.maxHp, 0, 1), 18, Palette.coral);
    OutlineText.draw(c, '${r.hp.ceil()} / ${r.maxHp.round()}', Offset(pad + w / 2, pad + 9), size: 13);

    // XP
    drawRect(c, pad - 3, pad + 22, w + 6, 14, Palette.ink);
    drawRect(c, pad, pad + 25, w, 8, const Color(0xFF1F4A47));
    drawRect(c, pad, pad + 25, w * clampD(r.xp / r.xpNeeded, 0, 1), 8, Palette.teal);

    OutlineText.draw(c, 'Lv ${r.level}', const Offset(pad, pad + 54), size: 14, color: Palette.cyan, center: false);
    c.save();
    c.translate(pad + 64, pad + 54);
    c.rotate(pi / 4);
    drawRect(c, -5, -5, 10, 10, Palette.mint);
    c.restore();
    OutlineText.draw(c, '${r.money}', const Offset(pad + 76, pad + 54), size: 15, color: Palette.mint, center: false);

    // Welle / Timer / Boss
    final cx = s.x / 2;
    if (r.wave == kMaxWave) {
      OutlineText.draw(c, 'BOSS', Offset(cx, 24), size: 20, color: Palette.sun);
      Enemy? boss;
      for (final e in g.enemies) {
        if (e.type == EnemyType.boss && !e.dead) boss = e;
      }
      if (boss != null) {
        final bw = min(320.0, s.x * 0.5);
        drawRect(c, cx - bw / 2 - 3, 40, bw + 6, 16, Palette.ink);
        drawRect(c, cx - bw / 2, 43, bw, 10, const Color(0xFF5A2438));
        drawRect(c, cx - bw / 2, 43, bw * clampD(boss.hp / boss.maxHp, 0, 1), 10, Palette.coral);
      }
    } else {
      OutlineText.draw(c, 'Welle ${r.wave}', Offset(cx, 22), size: 16);
      OutlineText.draw(c, '${max(0, g.waveTime.ceil())}', Offset(cx, 54),
          size: 30, color: g.waveTime < 5 ? Palette.coral : Palette.sun);
    }

    // Wetteranzeige unter Timer bzw. Boss-Leiste
    final wt = g.weather;
    if (!wt.isClear) {
      final text = wt.isWindy ? (wt.windBase >= 0 ? 'Wind ▶' : '◀ Wind') : wt.label;
      OutlineText.draw(c, text, Offset(cx, r.wave == kMaxWave ? 72.0 : 84.0), size: 13, color: Palette.cyan);
    }

    if (g.banner > 0 && g.playing) {
      OutlineText.draw(c, r.wave == kMaxWave ? 'Der Geierkönig kommt' : 'Welle ${r.wave}',
          Offset(cx, s.y * 0.42), size: min(46.0, s.x / 12), color: Palette.sun);
      if (!g.weather.isClear) {
        OutlineText.draw(c, g.weather.label, Offset(cx, s.y * 0.42 + min(46.0, s.x / 12)),
            size: min(24.0, s.x / 22), color: Palette.cyan);
      }
    }

    // Pfeile für Gegner außerhalb des Bildes
    for (final e in g.enemies) {
      if (e.dead) continue;
      final sx = (e.x - g.camX) * g.zoom;
      final sy = clampD((e.y + g.offY) * g.zoom, 80, s.y - 20);
      if (sx < -e.r * g.zoom) {
        _drawArrow(c, 6, sy, 1);
      } else if (sx > s.x + e.r * g.zoom) {
        _drawArrow(c, s.x - 6, sy, -1);
      }
    }
  }

  void _drawArrow(Canvas c, double x, double y, double dir) {
    _arrow
      ..reset()
      ..moveTo(x, y)
      ..lineTo(x + dir * 12, y - 8)
      ..lineTo(x + dir * 12, y + 8)
      ..close();
    c.drawPath(_arrow, fillOf(const Color(0xFFFF4D6D)));
  }
}
