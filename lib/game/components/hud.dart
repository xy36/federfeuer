import 'dart:math';

import 'package:flame/components.dart';
import 'package:flutter/material.dart';

import '../config.dart';
import '../federfeuer_game.dart';
import '../perf.dart';
import 'draw.dart';
import 'enemy.dart';
import 'light.dart';

/// HUD im Viewport (Bildschirmkoordinaten): leuchtende Glaskapseln und feine Lichtlinien.
class Hud extends Component with HasGameReference<FederfeuerGame> {
  Hud() : super(priority: 100);

  static const _glass = Color(0xB30A0F24), _edge = Color(0x59CFE3FF), _muted = Color(0xFF9FB0D0);
  static const _hp = Color(0xFFFF7A8A), _xp = Color(0xFF7FE8FF), _boss = Color(0xFFFF5AE0);

  final _arrow = Path();
  final _edgePaint = Paint()
    ..style = PaintingStyle.stroke
    ..strokeWidth = 1;
  final _fill = Paint();
  final _line = Paint()..strokeCap = StrokeCap.round;

  @override
  void render(Canvas c) {
    if (perfSkip.contains(RenderPart.hud)) return;
    if (game.run == null) return;
    // Auf großen Bildschirmen wächst das HUD mit (wie die Menüs).
    final k = uiScaleFor(game.size.x, game.size.y);
    c.save();
    c.scale(k);
    _render(c, game.size / k, k);
    c.restore();
  }

  void _render(Canvas c, Vector2 s, double k) {
    final g = game, r = g.run!;
    const pad = 14.0;
    final w = min(200.0, s.x * 0.32);

    // Level-Orb links, daneben HP-Kapsel und Material; XP als Bogen um den Orb
    const orbR = 19.0;
    const ox = pad + orbR, oy = pad + orbR;
    Glow.draw(c, ox, oy, orbR * 2.4, _xp.withAlpha(70));
    c.drawCircle(const Offset(ox, oy), orbR, fillOf(_glass));
    _edgePaint.color = _xp.withAlpha(150);
    c.drawCircle(const Offset(ox, oy), orbR, _edgePaint);
    _line
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.5
      ..color = _xp;
    c.drawArc(Rect.fromCircle(center: const Offset(ox, oy), radius: orbR - 3), -pi / 2,
        2 * pi * clampD(r.xp / r.xpNeeded, 0, 1), false, _line);
    OutlineText.draw(c, '${r.level}', const Offset(ox, oy + 1), size: 15, color: _xp, display: false);

    const bx = ox + orbR + 10;
    _capsule(c, Rect.fromLTWH(bx, pad + 3, w, 14), r.hp / r.maxHp, _hp);
    OutlineText.draw(c, '${r.hp.ceil()} / ${r.maxHp.round()}', const Offset(bx + 8, pad + 27),
        size: 12, color: _hp, center: false, display: false);

    // Material
    final gx = bx + w - 38, gy = pad + 27;
    Glow.draw(c, gx, gy, 14, Palette.mint.withAlpha(150));
    c.save();
    c.translate(gx, gy);
    c.rotate(pi / 4);
    drawRect(c, -4, -4, 8, 8, Palette.mint);
    drawRect(c, -1.8, -1.8, 3.6, 3.6, Colors.white);
    c.restore();
    OutlineText.draw(c, '${r.money}', Offset(gx + 10, gy), size: 14, color: Palette.mint, center: false, display: false);

    // Welle / Timer / Boss
    final cx = s.x / 2;
    if (isBossWave(r.wave)) {
      OutlineText.draw(c, 'DER GEIERKÖNIG', Offset(cx, 22), size: 15, color: _boss);
      Enemy? boss;
      for (final e in g.enemies) {
        if (e.type == EnemyType.boss && !e.dead) boss = e;
      }
      if (boss != null) {
        final bw = min(320.0, s.x * 0.5);
        _capsule(c, Rect.fromLTWH(cx - bw / 2, 38, bw, 10), boss.hp / boss.maxHp, _boss);
      }
    } else {
      OutlineText.draw(c, 'WELLE ${r.wave}', Offset(cx, 18), size: 12, color: _muted);
      final low = g.waveTime < 5;
      OutlineText.draw(c, '${max(0, g.waveTime.ceil())}', Offset(cx, 46),
          size: 30, color: low ? _hp : const Color(0xFFFFE6A0), display: false);
      final goal = g.goalX;
      if (goal != null) _drawProgress(c, cx, 72, min(220.0, s.x * 0.34), g.player.x / goal);
    }

    // Wetteranzeige unter Timer bzw. Boss-Leiste
    final wt = g.weather;
    if (!wt.isClear) {
      final text = wt.isWindy ? (wt.windBase >= 0 ? 'Wind ›' : '‹ Wind') : wt.label;
      OutlineText.draw(c, text, Offset(cx, isBossWave(r.wave) ? 64.0 : 90.0), size: 12, color: _xp, display: false);
    }

    final big = min(40.0, s.x / 13), small = min(20.0, s.x / 26);
    if (g.phase == Phase.cleared) {
      OutlineText.draw(c, 'WELLE ${r.wave} GESCHAFFT', Offset(cx, s.y * 0.42), size: big, color: Palette.sun);
      final bonus = r.goalBonus;
      OutlineText.draw(c, bonus != null ? 'Ziel erreicht · +$bonus Zeitbonus' : 'Zeit abgelaufen',
          Offset(cx, s.y * 0.42 + big * 0.95), size: small, color: bonus != null ? Palette.mint : _xp, display: false);
    }

    if (g.banner > 0 && g.playing) {
      // Neue Welt: Name über dem Wellenbanner, in der Kantenfarbe der Welt
      if (r.wave == 1 || biomeForWave(r.wave - 1) != g.biome) {
        OutlineText.draw(c, g.biomeDef.name.toUpperCase(), Offset(cx, s.y * 0.42 - big * 0.95),
            size: small, color: g.biomeDef.rim);
      }
      OutlineText.draw(c, isBossWave(r.wave) ? 'DER GEIERKÖNIG KOMMT' : 'WELLE ${r.wave}', Offset(cx, s.y * 0.42),
          size: big, color: Palette.sun);
      if (!g.weather.isClear) {
        OutlineText.draw(c, g.weather.label, Offset(cx, s.y * 0.42 + big * 0.95), size: small, color: _xp, display: false);
      }
    }

    // Leuchtende Pfeile für Gegner außerhalb des Bildes
    for (final e in g.enemies) {
      if (e.dead) continue;
      final sx = (e.x - g.camX) * g.zoom / k;
      final sy = clampD((e.y + g.offY) * g.zoom / k, 90, s.y - 20);
      if (sx < -e.r * g.zoom / k) {
        _drawArrow(c, 8, sy, 1);
      } else if (sx > s.x + e.r * g.zoom / k) {
        _drawArrow(c, s.x - 8, sy, -1);
      }
    }
  }

  /// Glaskapsel mit leuchtender Füllung [k] (0–1) in [col].
  void _capsule(Canvas c, Rect rect, double k, Color col) {
    final rr = RRect.fromRectAndRadius(rect, Radius.circular(rect.height / 2));
    c.drawRRect(rr, fillOf(_glass));
    final fw = rect.width * clampD(k, 0, 1);
    if (fw > 4) {
      final inner = RRect.fromRectAndRadius(
          Rect.fromLTWH(rect.left, rect.top, fw, rect.height).deflate(2), Radius.circular(rect.height / 2));
      _fill.shader = LinearGradient(colors: [col.withAlpha(170), Color.lerp(col, Colors.white, 0.35)!]).createShader(rect);
      c.drawRRect(inner, _fill);
      Glow.draw(c, rect.left + fw - 3, rect.center.dy, rect.height * 1.8, col.withAlpha(150));
    }
    _edgePaint.color = _edge;
    c.drawRRect(rr, _edgePaint);
  }

  /// Strecke bis zum Ziel: feine Lichtlinie, leuchtender Punkt für den Spieler, Lichtsäule am Ende.
  void _drawProgress(Canvas c, double cx, double y, double w, double k) {
    final x0 = cx - w / 2, px = x0 + w * clampD(k, 0, 1);
    _line
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2
      ..color = const Color(0x40CFE3FF);
    c.drawLine(Offset(x0, y), Offset(x0 + w, y), _line);
    _line.color = const Color(0xCCFFE6A0);
    c.drawLine(Offset(x0, y), Offset(px, y), _line);
    Glow.draw(c, x0 + w + 8, y, 16, const Color(0x99FFE6A0));
    drawRect(c, x0 + w + 7, y - 9, 2, 16, const Color(0xFFFFF4D6));
    Glow.draw(c, px, y, 16, const Color(0xCCFFD27A));
    drawCircle(c, px, y, 3.5, Colors.white);
  }

  void _drawArrow(Canvas c, double x, double y, double dir) {
    Glow.draw(c, x + dir * 6, y, 18, const Color(0x99FF4D8D));
    _arrow
      ..reset()
      ..moveTo(x, y)
      ..lineTo(x + dir * 11, y - 7)
      ..lineTo(x + dir * 8, y)
      ..lineTo(x + dir * 11, y + 7)
      ..close();
    c.drawPath(_arrow, fillOf(const Color(0xFFFF8AB0)));
  }
}
