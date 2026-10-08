import 'dart:math';

import 'package:flame/components.dart';
import 'package:flutter/material.dart';

import '../config.dart';
import '../federfeuer_game.dart';
import '../input_bindings.dart';
import '../perf.dart';
import 'draw.dart';
import 'glyph_art.dart';
import 'enemy.dart';
import 'light.dart';
import '../../ui/widgets.dart' show isTouchPlatform;

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

  static const _warn = Color(0xFFFFA040);

  /// Großer Countdown der letzten Sekunden in der Bildmitte: jede Zahl ploppt kurz auf
  /// und verblasst; ab 3 rot. Deckkraft in wenigen Stufen (Text-Cache bleibt klein).
  void _countdown(Canvas c, Vector2 s, double left) {
    final n = left.ceil(), frac = left - (n - 1); // 1 → 0 innerhalb jeder Sekunde
    final pop = 1 + 0.35 * clampD((frac - 0.75) / 0.25, 0, 1);
    final alpha = ((0.18 + 0.42 * frac) * 8).round() / 8;
    final col = n <= 3 ? _hp : _warn;
    c.save();
    c.translate(s.x / 2, s.y * 0.4);
    c.scale(pop);
    OutlineText.draw(c, '$n', Offset.zero, size: 96, color: col.withValues(alpha: alpha));
    c.restore();
    OutlineText.draw(c, 'WELLE ENDET', Offset(s.x / 2, s.y * 0.4 + 62), size: 13, color: _muted);
  }

  static final _windRing = Paint()
    ..style = PaintingStyle.stroke
    ..strokeCap = StrokeCap.round
    ..strokeWidth = 4;

  /// Ankündigung einer Aktion oben in der Mitte: beim Aufladen Symbol mit sich füllendem
  /// Ring und Name, beim Auslösen ploppt der Name groß auf und verblasst (wie der Countdown).
  void _actionBanner(Canvas c, Vector2 s) {
    final g = game, cx = s.x / 2, cy = s.y * 0.2;
    final windup = g.announcing;
    if (windup != null) {
      final col = GlyphArt.colorOf(ActionGlyph(windup));
      final f = 1 - clampD(g.announceT / g.announceTotal, 0, 1); // 0 → 1
      Glow.draw(c, cx, cy, 46, col.withValues(alpha: 0.35));
      c.save();
      c.translate(cx, cy);
      GlyphArt.draw(c, ActionGlyph(windup), 44, t: g.clock);
      c.restore();
      _windRing.color = col.withValues(alpha: 0.35);
      c.drawCircle(Offset(cx, cy), 30, _windRing);
      _windRing.color = Color.lerp(col, Colors.white, 0.35)!;
      c.drawArc(Rect.fromCircle(center: Offset(cx, cy), radius: 30), -pi / 2, 2 * pi * f, false, _windRing);
      OutlineText.draw(c, windup.label.toUpperCase(), Offset(cx, cy + 46), size: 16, color: col);
      return;
    }
    final shout = g.shoutAction;
    if (shout == null || g.shoutT <= 0) return;
    final col = GlyphArt.colorOf(ActionGlyph(shout));
    final frac = clampD(g.shoutT / kActionShoutTime, 0, 1); // 1 → 0
    final pop = 1 + 0.4 * clampD((frac - 0.75) / 0.25, 0, 1);
    final alpha = ((0.25 + 0.75 * frac) * 8).round() / 8;
    c.save();
    c.translate(cx, cy + 10);
    c.scale(pop);
    OutlineText.draw(c, '${shout.label.toUpperCase()}!', Offset.zero, size: 34, color: col.withValues(alpha: alpha));
    c.restore();
  }

  static final _chaosEdge = Paint()..style = PaintingStyle.stroke;

  /// Aktive Chaos-Zustände: farbiger Bildschirmrand und Name mit Restzeit unten in der Mitte.
  void _chaos(Canvas c, Vector2 s) {
    var row = 0;
    for (final e in ChaosEffect.values) {
      final left = game.chaosT[e] ?? 0;
      if (left <= 0) continue;
      final pulse = 0.5 + 0.5 * sin(game.clock * 6);
      _chaosEdge
        ..strokeWidth = 22
        ..color = e.color.withValues(alpha: 0.16 + 0.1 * pulse);
      c.drawRect(Rect.fromLTWH(11, 11, s.x - 22, s.y - 22), _chaosEdge);
      final y = s.y - 92 - row * 30;
      OutlineText.draw(c, '${e.label.toUpperCase()} · ${e.desc}', Offset(s.x / 2, y), size: 14, color: e.color, display: false);
      final bw = 140.0, f = clampD(left / e.duration, 0, 1);
      drawRect(c, s.x / 2 - bw / 2, y + 12, bw, 4, const Color(0x66120A1E));
      drawRect(c, s.x / 2 - bw / 2, y + 12, bw * f, 4, e.color);
      row++;
    }
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
        // Phasengrenzen bei 66 % und 33 %
        for (final f in [0.33, 0.66]) {
          drawRect(c, cx - bw / 2 + bw * f - 1, 36, 2, 14, const Color(0xCCFFFFFF));
        }
        OutlineText.draw(c, 'PHASE ${boss.bossPhase}', Offset(cx + bw / 2 + 34, 43), size: 11, color: _boss, display: false);
      }
    } else {
      OutlineText.draw(c, 'WELLE ${r.wave}', Offset(cx, 18), size: 12, color: _muted);
      // Schlussphase: Timer orange ab 10 s, rot ab 5 s, pulsiert immer stärker
      final left = g.waveTime, warn = left < kWaveWarnTime, low = left < kWaveCountdown;
      final pulse = warn ? 0.5 + 0.5 * sin(g.clock * (low ? 10 : 6)) : 0.0;
      c.save();
      c.translate(cx, 46);
      c.scale(1 + (low ? 0.16 : 0.08) * pulse);
      OutlineText.draw(c, '${max(0, left.ceil())}', Offset.zero,
          size: 30, color: low ? _hp : (warn ? _warn : const Color(0xFFFFE6A0)), display: false);
      c.restore();
      if (g.playing && left > 0 && left <= kWaveCountdown) _countdown(c, s, left);
      final goal = g.goalX;
      if (goal != null) _drawProgress(c, cx, 72, min(220.0, s.x * 0.34), g.player.x / goal);
      // Torwächter: Name und HP-Kapsel unter der Strecke
      final gate = g.gate;
      if (gate != null && !gate.dead) {
        final bw = min(260.0, s.x * 0.4);
        OutlineText.draw(c, gate.type.label.toUpperCase(), Offset(cx, 112), size: 12, color: _boss);
        _capsule(c, Rect.fromLTWH(cx - bw / 2, 122, bw, 9), gate.hp / gate.maxHp, _boss);
      }
    }
    if (g.playing) {
      _chaos(c, s);
      _actionBanner(c, s);
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

    // Torwächter erscheint: großer Name in der Bildmitte
    final gate = g.gate;
    if (g.gateBanner > 0 && g.banner <= 0 && gate != null && g.playing) {
      final a = clampD(g.gateBanner, 0, 1);
      OutlineText.draw(c, 'TORWÄCHTER', Offset(cx, s.y * 0.36), size: small, color: _boss.withValues(alpha: (a * 10).round() / 10));
      OutlineText.draw(c, gate.type.label.toUpperCase(), Offset(cx, s.y * 0.36 + big * 0.95),
          size: big, color: _boss.withValues(alpha: (a * 10).round() / 10));
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
      // Erste Welle mit Controller: Belegung kurz einblenden
      if (r.wave == 1 && g.pad.used) {
        final b = g.settings.bindings;
        String p(InputAction a) => b.firstPad(a).let(padLabel) ?? '–';
        OutlineText.draw(
          c,
          '${p(InputAction.fly)} halten: fliegen  ·  Aktionen automatisch (${p(InputAction.action1)} / ${p(InputAction.action2)}: sofort)  ·  ${p(InputAction.pause)}: Pause',
          Offset(cx, s.y * 0.42 + big * 0.95 + small * 1.4),
          size: small * 0.8,
          color: Palette.sun,
          display: false,
        );
      }
    }

    // Aktionstasten unten links: Symbol mit Abklingbogen, Stufe II mit Punkt
    if (g.playing) {
      const ar = 20.0;
      final ay = s.y - pad - ar - (isTouchPlatform && !g.pad.used ? 100 : 0);
      for (var i = 0; i < r.actions.length; i++) {
        final act = r.actions[i];
        final ax = pad + ar + i * 150;
        final ready = g.actionReady(i);
        final col = act.id.evolved ? const Color(0xFFFFC94A) : Palette.sun;
        // „Bereit!“: kurzer Sprung und nach außen laufender Lichtring, danach sanftes Pulsieren
        final f = g.actionReadyFlash[i] / FederfeuerGame.actionReadyFlashTime; // 1 → 0
        final pop = f > 0 ? 1 + 0.35 * sin(f * pi) : 1.0;
        final pulse = ready ? 0.5 + 0.5 * sin(g.clock * 4) : 0.0;
        final rr = ar * pop;
        Glow.draw(c, ax, ay, ar * (ready ? 2.6 + 0.6 * pulse + 2 * f : 2),
            (ready ? col : _muted).withAlpha(ready ? (90 + 60 * pulse + 100 * f).round().clamp(0, 255) : 50));
        if (f > 0) {
          _line
            ..style = PaintingStyle.stroke
            ..strokeWidth = 3 * f
            ..color = col.withValues(alpha: f);
          c.drawCircle(Offset(ax, ay), ar * (1 + 1.6 * (1 - f)), _line);
        }
        c.drawCircle(Offset(ax, ay), rr, fillOf(ready ? Color.lerp(_glass, col, 0.15 + 0.1 * pulse)! : _glass));
        _edgePaint
          ..color = ready ? col : _edge
          ..strokeWidth = ready ? 2 : 1;
        c.drawCircle(Offset(ax, ay), rr, _edgePaint);
        _edgePaint.strokeWidth = 1;
        if (!ready) {
          _line
            ..style = PaintingStyle.stroke
            ..strokeWidth = 3
            ..color = _xp;
          c.drawArc(Rect.fromCircle(center: Offset(ax, ay), radius: ar - 3), -pi / 2,
              2 * pi * (1 - g.actionCds[i] / r.actionCooldown(act)), false, _line);
        }
        c.save();
        c.translate(ax, ay);
        GlyphArt.draw(c, ActionGlyph(act.id), ar * 1.5 * pop, t: g.clock);
        c.restore();
        if (f > 0) {
          OutlineText.draw(c, 'BEREIT!', Offset(ax, ay - ar - 12 - 6 * (1 - f)),
              // Deckkraft in Zehnteln, damit der Text-Cache nicht für jeden Frame neu rendert
              size: 12, color: col.withValues(alpha: (min(1.0, f * 2) * 10).round() / 10), display: false);
        }
        if (act.level > 0) drawCircle(c, ax + ar * 0.72, ay - ar * 0.72, 4, col);
        OutlineText.draw(c, ready ? act.label : '${g.actionCds[i].ceil()}', Offset(ax + ar + 8, ay - 7),
            size: 12, color: ready ? col : _muted, center: false, display: false);
        final slot = i == 0 ? InputAction.action1 : InputAction.action2, bind = g.settings.bindings;
        final key = g.pad.used
            ? bind.firstPad(slot).let(padLabel)
            : bind.firstKey(slot).let(keyLabel);
        OutlineText.draw(c, key ?? '–', Offset(ax + ar + 8, ay + 9),
            size: 10, color: _muted, center: false, display: false);
      }
    }

    // Lichtblitz: kurzes weißes Aufleuchten
    if (g.flashT > 0) {
      c.drawRect(Rect.fromLTWH(0, 0, s.x, s.y), fillOf(Colors.white.withAlpha((200 * g.flashT / 0.35).round())));
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

extension _Let<T extends Object> on T? {
  R? let<R>(R Function(T) f) {
    final v = this;
    return v == null ? null : f(v);
  }
}
