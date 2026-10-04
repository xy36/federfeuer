import 'dart:math';

import 'package:flutter/material.dart';

import '../config.dart';
import 'bird_art.dart';
import 'enemy_art.dart';
import 'light.dart';
import 'weapon_art.dart';

/// Was ein Symbol zeigt.
sealed class GlyphRef {
  const GlyphRef();
}

class WeaponGlyph extends GlyphRef {
  const WeaponGlyph(this.id, {this.tier = 0});
  final String id;
  final int tier;
}

class ItemGlyph extends GlyphRef {
  const ItemGlyph(this.id);
  final String id;
}

class ActionGlyph extends GlyphRef {
  const ActionGlyph(this.action);
  final ActionId action;
}

class StatGlyph extends GlyphRef {
  const StatGlyph(this.stat);
  final Stat stat;
}

class EnemyGlyph extends GlyphRef {
  const EnemyGlyph(this.type);
  final EnemyType type;
}

class BirdGlyph extends GlyphRef {
  const BirdGlyph(this.character);
  final CharacterDef character;
}

/// Lichtsymbole statt Emojis: Waffen als ihre Modelle, Gegner und Vögel als ihre Zeichnungen,
/// Items, Aktionen und Werte als feine Lichtlinien. Gezeichnet in einem Feld der Größe [size],
/// Mittelpunkt im Ursprung.
class GlyphArt {
  GlyphArt._();

  static final _wide = Paint()
    ..style = PaintingStyle.stroke
    ..strokeCap = StrokeCap.round
    ..strokeJoin = StrokeJoin.round
    ..blendMode = BlendMode.plus;
  static final _core = Paint()
    ..style = PaintingStyle.stroke
    ..strokeCap = StrokeCap.round
    ..strokeJoin = StrokeJoin.round;

  /// Farbe eines Symbols (Seltenheit, Aktion, Wert).
  static Color colorOf(GlyphRef g) => switch (g) {
        WeaponGlyph(:final id) => weaponDefs[id]!.cls.color,
        ItemGlyph(:final id) => itemById[id]!.action != null ? const Color(0xFFFFD27A) : _rarityGlow(itemById[id]!.rarity),
        ActionGlyph(:final action) => action.evolved ? const Color(0xFFFFC94A) : const Color(0xFFFFE6A0),
        StatGlyph() => const Color(0xFF9FE4FF),
        EnemyGlyph() => const Color(0xFFC77DFF),
        BirdGlyph(:final character) => character.glow,
      };

  static Color _rarityGlow(Rarity r) => switch (r) {
        Rarity.common => const Color(0xFFE6EEFF),
        Rarity.rare => const Color(0xFF7FC8FF),
        Rarity.epic => const Color(0xFFD08CFF),
        Rarity.legendary => const Color(0xFFFF8A9A),
      };

  static void draw(Canvas c, GlyphRef g, double size, {double t = 0}) {
    switch (g) {
      case WeaponGlyph(:final id, :final tier):
        c.save();
        c.scale(size / 26);
        c.translate(-6, 0);
        WeaponArt.draw(c, id, kick: 0, t: t, tier: tiers[tier].color, glow: weaponDefs[id]!.cls.color);
        c.restore();
      case EnemyGlyph(:final type):
        final r = enemyDefs[type]!.radius;
        // Sichtbare Ausdehnung der Zeichnung (Bosse ragen weit über ihren Radius hinaus)
        final extent = switch (type) {
          EnemyType.boss => 120.0,
          EnemyType.strawKing || EnemyType.spiderMother => r * 2.5,
          EnemyType.bell => r * 2.7,
          EnemyType.eagle || EnemyType.bat => r * 3.4,
          _ => r * 2.4,
        };
        c.save();
        c.scale(size / extent);
        if (type == EnemyType.boss) c.translate(-8, 4);
        if (type == EnemyType.strawKing) c.translate(0, 10);
        EnemyArt.drawType(c, type, EnemyLook(t: t, pulse: 0.6), r);
        c.restore();
      case BirdGlyph(:final character):
        c.save();
        c.scale(size / 34 * character.scale);
        BirdArt.draw(c, character, BirdArt.bodyPaint(character),
            BirdPose(flap: 0.3, upright: character.look == BirdLook.penguin, t: t));
        c.restore();
      case ActionGlyph(:final action) when action.evolved:
        _evolution(c, action, size, t);
      default:
        final col = colorOf(g);
        c.save();
        c.scale(size / 24);
        Glow.draw(c, 0, 0, 16, col.withValues(alpha: 0.35));
        final shape = _shape(g);
        if (shape.fill != null) c.drawPath(shape.fill!, Paint()..color = col.withValues(alpha: 0.28));
        _wide
          ..strokeWidth = 3.4
          ..color = col.withValues(alpha: 0.35);
        c.drawPath(shape.stroke, _wide);
        _core
          ..strokeWidth = 1.5
          ..color = Color.lerp(col, Colors.white, 0.55)!;
        c.drawPath(shape.stroke, _core);
        c.restore();
    }
  }

  /// Evolution: die beiden Zutaten klein übereinander in einem goldenen Ring.
  static void _evolution(Canvas c, ActionId a, double size, double t) {
    final rec = actionRecipes.where((r) => r.result == a).firstOrNull;
    c.save();
    c.scale(size / 24);
    Glow.draw(c, 0, 0, 18, const Color(0x66FFC94A));
    _wide
      ..strokeWidth = 3
      ..color = const Color(0x66FFC94A);
    c.drawCircle(Offset.zero, 10.5, _wide);
    _core
      ..strokeWidth = 1.2
      ..color = const Color(0xFFFFE6A0);
    c.drawCircle(Offset.zero, 10.5, _core);
    if (rec != null) {
      for (final (dx, dy, id) in [(-3.2, -2.6, rec.a), (3.2, 2.6, rec.b)]) {
        c.save();
        c.translate(dx, dy);
        draw(c, ActionGlyph(id), 13, t: t);
        c.restore();
      }
    }
    c.restore();
  }

  // ---------------- Formen (Feld −12…12) ----------------

  static ({Path stroke, Path? fill}) _shape(GlyphRef g) => switch (g) {
        ItemGlyph(:final id) => itemById[id]!.action != null ? _action(itemById[id]!.action!) : _item(id),
        ActionGlyph(:final action) => _action(action),
        StatGlyph(:final stat) => _stat(stat),
        _ => (stroke: Path()..addOval(Rect.fromCircle(center: Offset.zero, radius: 8)), fill: null),
      };

  static Path _circle(double x, double y, double r) => Path()..addOval(Rect.fromCircle(center: Offset(x, y), radius: r));
  static Path _poly(List<(double, double)> pts, {bool close = false}) {
    final p = Path()..moveTo(pts.first.$1, pts.first.$2);
    for (final q in pts.skip(1)) {
      p.lineTo(q.$1, q.$2);
    }
    if (close) p.close();
    return p;
  }

  static Path _star(double r, double inner, int n, {double rot = -pi / 2}) {
    final p = Path();
    for (var i = 0; i < n * 2; i++) {
      final a = rot + i * pi / n, rr = i.isEven ? r : inner;
      final pt = Offset(cos(a) * rr, sin(a) * rr);
      i == 0 ? p.moveTo(pt.dx, pt.dy) : p.lineTo(pt.dx, pt.dy);
    }
    return p..close();
  }

  static Path _feather() => Path()
    ..moveTo(-8, 8)
    ..quadraticBezierTo(-4, -6, 8, -9)
    ..quadraticBezierTo(4, 4, -8, 8)
    ..moveTo(-8, 8)
    ..lineTo(6, -7);

  static Path _heart(double s) => Path()
    ..moveTo(0, 7 * s)
    ..cubicTo(-10 * s, 0, -6 * s, -9 * s, 0, -4 * s)
    ..cubicTo(6 * s, -9 * s, 10 * s, 0, 0, 7 * s)
    ..close();

  static ({Path stroke, Path? fill}) _item(String id) {
    switch (id) {
      case 'helm':
        final p = Path()
          ..moveTo(-9, 4)
          ..quadraticBezierTo(-9, -9, 0, -9)
          ..quadraticBezierTo(9, -9, 9, 4)
          ..lineTo(-9, 4)
          ..moveTo(-11, 6)
          ..lineTo(11, 6)
          ..moveTo(0, -9)
          ..lineTo(0, 4);
        return (stroke: p, fill: p);
      case 'apfel':
        final p = Path()
          ..moveTo(0, -5)
          ..cubicTo(-10, -9, -11, 8, -3, 9)
          ..quadraticBezierTo(0, 8, 3, 9)
          ..cubicTo(11, 8, 10, -9, 0, -5)
          ..moveTo(0, -5)
          ..lineTo(1, -10)
          ..moveTo(1, -8)
          ..quadraticBezierTo(5, -11, 7, -8);
        return (stroke: p, fill: p);
      case 'pflaster':
        final p = Path()..addRRect(RRect.fromRectAndRadius(const Rect.fromLTRB(-10, -4, 10, 4), const Radius.circular(4)));
        p.addRect(const Rect.fromLTRB(-3, -4, 3, 4));
        return (stroke: p, fill: null);
      case 'fernglas':
        return (stroke: _circle(-5, 3, 4.5)..addPath(_circle(5, 3, 4.5), Offset.zero)..addPath(_poly([(-5, -2), (-3, -8), (3, -8), (5, -2)]), Offset.zero), fill: null);
      case 'feder':
        return (stroke: _feather(), fill: null);
      case 'magnet':
        final p = Path()
          ..moveTo(-7, -9)
          ..lineTo(-7, 2)
          ..arcToPoint(const Offset(7, 2), radius: const Radius.circular(7), clockwise: false)
          ..lineTo(7, -9)
          ..moveTo(-10, -6)
          ..lineTo(-4, -6)
          ..moveTo(4, -6)
          ..lineTo(10, -6);
        return (stroke: p, fill: null);
      case 'hantel':
        final p = Path()
          ..moveTo(-6, 0)
          ..lineTo(6, 0)
          ..addRect(const Rect.fromLTRB(-11, -5, -6, 5))
          ..addRect(const Rect.fromLTRB(6, -5, 11, 5));
        return (stroke: p, fill: null);
      case 'kaffee':
        final p = Path()
          ..moveTo(-8, -3)
          ..lineTo(-6, 8)
          ..lineTo(5, 8)
          ..lineTo(7, -3)
          ..close()
          ..moveTo(7, 0)
          ..quadraticBezierTo(12, 1, 6, 5)
          ..moveTo(-3, -6)
          ..quadraticBezierTo(-1, -9, -3, -11)
          ..moveTo(2, -6)
          ..quadraticBezierTo(4, -9, 2, -11);
        return (stroke: p, fill: null);
      case 'zahn':
        final p = Path()
          ..moveTo(-6, -8)
          ..quadraticBezierTo(0, -11, 6, -8)
          ..quadraticBezierTo(7, 0, 3, 9)
          ..lineTo(0, 3)
          ..lineTo(-3, 9)
          ..quadraticBezierTo(-7, 0, -6, -8)
          ..close();
        return (stroke: p, fill: p);
      case 'klee':
        final p = Path();
        for (var i = 0; i < 4; i++) {
          final a = i * pi / 2 - pi / 4;
          p.addOval(Rect.fromCircle(center: Offset(cos(a) * 4.5, sin(a) * 4.5 - 2), radius: 4));
        }
        p
          ..moveTo(0, 2)
          ..quadraticBezierTo(1, 7, 4, 10);
        return (stroke: p, fill: null);
      case 'glas':
        final p = Path()
          ..addOval(Rect.fromCircle(center: const Offset(0, -2), radius: 7))
          ..moveTo(-5, 6)
          ..lineTo(5, 6)
          ..lineTo(3, 10)
          ..lineTo(-3, 10)
          ..close()
          ..moveTo(-3, -4)
          ..lineTo(0, -6);
        return (stroke: p, fill: _circle(0, -2, 7));
      case 'panzer':
        final p = Path()
          ..moveTo(-10, 4)
          ..quadraticBezierTo(-9, -8, 0, -8)
          ..quadraticBezierTo(9, -8, 10, 4)
          ..close()
          ..addPath(_poly([(-4, -4), (4, -4), (6, 1), (-6, 1)], close: true), Offset.zero);
        return (stroke: p, fill: null);
      case 'dose':
        final p = Path()
          ..addRRect(RRect.fromRectAndRadius(const Rect.fromLTRB(-6, -9, 6, 9), const Radius.circular(2)))
          ..addPath(_poly([(1, -5), (-3, 1), (1, 1), (-1, 6)]), Offset.zero);
        return (stroke: p, fill: null);
      case 'wurm':
        final p = Path()..moveTo(-10, 4);
        for (var i = 1; i <= 8; i++) {
          p.lineTo(-10 + i * 2.5, 4 + sin(i * 1.2) * 4 - i * 0.6);
        }
        return (stroke: p, fill: null);
      case 'knochen':
        final p = Path()
          ..moveTo(-6, 6)
          ..lineTo(6, -6)
          ..addOval(Rect.fromCircle(center: const Offset(-8, 5), radius: 2.5))
          ..addOval(Rect.fromCircle(center: const Offset(-5, 8), radius: 2.5))
          ..addOval(Rect.fromCircle(center: const Offset(8, -5), radius: 2.5))
          ..addOval(Rect.fromCircle(center: const Offset(5, -8), radius: 2.5));
        return (stroke: p, fill: null);
      case 'segelfeder':
        final p = _feather()
          ..moveTo(-10, -4)
          ..quadraticBezierTo(-6, -6, -2, -4)
          ..moveTo(-10, -9)
          ..quadraticBezierTo(-6, -11, -2, -9);
        return (stroke: p, fill: null);
      case 'windfahne':
        final p = Path()
          ..moveTo(-6, 10)
          ..lineTo(-6, -10)
          ..lineTo(8, -6)
          ..lineTo(-6, -1)
          ..moveTo(0, 4)
          ..quadraticBezierTo(5, 2, 10, 4);
        return (stroke: p, fill: _poly([(-6, -10), (8, -6), (-6, -1)], close: true));
      case 'regenmantel':
        final p = Path()
          ..moveTo(-3, -9)
          ..lineTo(3, -9)
          ..lineTo(9, 9)
          ..lineTo(-9, 9)
          ..close()
          ..moveTo(0, -9)
          ..lineTo(0, 9);
        return (stroke: p, fill: p);
      case 'gummiente':
        final p = Path()
          ..moveTo(-10, 2)
          ..quadraticBezierTo(-9, 9, 0, 9)
          ..quadraticBezierTo(9, 9, 9, 3)
          ..lineTo(3, 1)
          ..addOval(Rect.fromCircle(center: const Offset(3, -4), radius: 4.5))
          ..moveTo(7, -4)
          ..lineTo(11, -3)
          ..lineTo(7, -2);
        return (stroke: p, fill: _circle(3, -4, 4.5));
      case 'socke':
        final p = Path()
          ..moveTo(-3, -10)
          ..lineTo(3, -10)
          ..lineTo(3, 2)
          ..quadraticBezierTo(10, 3, 9, 8)
          ..lineTo(-2, 8)
          ..quadraticBezierTo(-4, 7, -3, 2)
          ..close()
          ..addOval(Rect.fromCircle(center: const Offset(5, 6), radius: 1.6));
        return (stroke: p, fill: null);
      case 'sparschwein':
        final p = Path()
          ..addOval(const Rect.fromLTRB(-10, -6, 7, 7))
          ..moveTo(7, -1)
          ..lineTo(10, -1)
          ..lineTo(10, 3)
          ..lineTo(7, 3)
          ..moveTo(-6, 7)
          ..lineTo(-6, 10)
          ..moveTo(3, 7)
          ..lineTo(3, 10)
          ..moveTo(-3, -6)
          ..lineTo(1, -6);
        return (stroke: p, fill: null);
      case 'glueckskeks':
        final p = Path()
          ..moveTo(-10, 2)
          ..quadraticBezierTo(0, -12, 10, 2)
          ..quadraticBezierTo(0, -3, -10, 2)
          ..moveTo(0, -3)
          ..lineTo(4, 8)
          ..lineTo(9, 7);
        return (stroke: p, fill: null);
      case 'brennglas':
        final p = Path()
          ..addOval(Rect.fromCircle(center: const Offset(-3, -3), radius: 6))
          ..moveTo(1, 1)
          ..lineTo(9, 9)
          ..moveTo(-3, -11)
          ..lineTo(-3, -9.5)
          ..moveTo(-11, -3)
          ..lineTo(-9.5, -3);
        return (stroke: p, fill: _circle(-3, -3, 6));
      case 'giesskanne':
        final p = Path()
          ..addRect(const Rect.fromLTRB(-7, -3, 4, 8))
          ..moveTo(4, 0)
          ..lineTo(10, -7)
          ..moveTo(-7, 0)
          ..quadraticBezierTo(-12, 3, -7, 6)
          ..moveTo(11, -4)
          ..lineTo(11, -2)
          ..moveTo(9, -2)
          ..lineTo(9, 0);
        return (stroke: p, fill: null);
      case 'kiesel':
        final p = Path()
          ..addOval(const Rect.fromLTRB(-10, 1, -1, 8))
          ..addOval(const Rect.fromLTRB(1, 2, 10, 9))
          ..addOval(const Rect.fromLTRB(-5, -7, 5, 1));
        return (stroke: p, fill: p);
      case 'spiegel':
        final p = _poly([(-6, -10), (7, -8), (4, 10), (-8, 6)], close: true)
          ..moveTo(-2, -6)
          ..lineTo(1, -1)
          ..lineTo(-1, 4);
        return (stroke: p, fill: null);
      case 'dornenkleid':
        final p = Path()
          ..moveTo(-8, -8)
          ..lineTo(8, -8)
          ..lineTo(6, 9)
          ..lineTo(-6, 9)
          ..close();
        for (var i = 0; i < 3; i++) {
          final y = -4.0 + i * 5;
          p
            ..moveTo(-9, y)
            ..lineTo(-12, y - 2)
            ..moveTo(9, y)
            ..lineTo(12, y - 2);
        }
        return (stroke: p, fill: null);
      case 'sternenstaub':
        final p = _star(6, 2.4, 4)
          ..addPath(_star(2.8, 1, 4).shift(const Offset(-7, 6)), Offset.zero)
          ..addPath(_star(2.4, 0.9, 4).shift(const Offset(7, 7)), Offset.zero);
        return (stroke: p, fill: _star(6, 2.4, 4));
      case 'lichtschild':
        final p = Path()
          ..moveTo(0, -10)
          ..lineTo(9, -6)
          ..quadraticBezierTo(8, 6, 0, 10)
          ..quadraticBezierTo(-8, 6, -9, -6)
          ..close()
          ..addPath(_star(4, 1.6, 4), Offset.zero);
        return (stroke: p, fill: null);
      case 'kompass':
        final p = Path()
          ..addOval(Rect.fromCircle(center: Offset.zero, radius: 9))
          ..addPath(_poly([(0, -7), (2.5, 0), (0, 7), (-2.5, 0)], close: true), Offset.zero);
        return (stroke: p, fill: _poly([(0, -7), (2.5, 0), (-2.5, 0)], close: true));
      case 'goldgier':
        final p = Path()
          ..addOval(const Rect.fromLTRB(-9, 0, 3, 6))
          ..addOval(const Rect.fromLTRB(-3, -5, 9, 1))
          ..addOval(const Rect.fromLTRB(-7, -10, 5, -4));
        return (stroke: p, fill: p);
      case 'phoenix':
        final p = Path()
          ..moveTo(0, 10)
          ..cubicTo(-9, 4, -6, -4, -1, -10)
          ..cubicTo(0, -4, 4, -6, 3, -10)
          ..cubicTo(10, -2, 8, 6, 0, 10)
          ..close()
          ..moveTo(0, 6)
          ..quadraticBezierTo(-3, 1, 0, -3)
          ..quadraticBezierTo(3, 1, 0, 6);
        return (stroke: p, fill: p);
      default:
        return (stroke: _circle(0, 0, 8), fill: null);
    }
  }

  static ({Path stroke, Path? fill}) _action(ActionId a) {
    switch (a) {
      case ActionId.dash:
        final p = _feather()
          ..moveTo(-11, -2)
          ..lineTo(-5, -2)
          ..moveTo(-11, 2)
          ..lineTo(-6, 2);
        return (stroke: p, fill: null);
      case ActionId.horn:
        final p = Path()
          ..moveTo(-10, -2)
          ..lineTo(-4, -2)
          ..lineTo(6, -8)
          ..lineTo(6, 8)
          ..lineTo(-4, 2)
          ..lineTo(-10, 2)
          ..close()
          ..moveTo(9, -4)
          ..quadraticBezierTo(11, 0, 9, 4);
        return (stroke: p, fill: null);
      case ActionId.bubbleShield:
        final p = _circle(0, 0, 9)
          ..addOval(Rect.fromCircle(center: const Offset(-3.5, -3.5), radius: 2));
        return (stroke: p, fill: _circle(0, 0, 9));
      case ActionId.flash:
        final p = _poly([(2, -11), (-6, 1), (0, 1), (-2, 11), (7, -2), (1, -2)], close: true);
        return (stroke: p, fill: p);
      case ActionId.storm:
        final p = Path()
          ..moveTo(-8, 0)
          ..quadraticBezierTo(-11, -6, -5, -7)
          ..quadraticBezierTo(-2, -12, 3, -8)
          ..quadraticBezierTo(10, -8, 8, 0)
          ..close()
          ..addPath(_poly([(1, 1), (-3, 6), (1, 6), (-1, 11)]), Offset.zero);
        return (stroke: p, fill: null);
      case ActionId.magnet:
        return _item('magnet');
      case ActionId.clock:
        final p = _circle(0, 1, 9)
          ..moveTo(0, 1)
          ..lineTo(0, -5)
          ..moveTo(0, 1)
          ..lineTo(4, 3)
          ..moveTo(-2, -10)
          ..lineTo(2, -10);
        return (stroke: p, fill: null);
      case ActionId.bellySlide:
        final p = Path()
          ..addOval(const Rect.fromLTRB(-8, -5, 8, 3))
          ..moveTo(-11, 7)
          ..lineTo(11, 7)
          ..moveTo(-11, 3)
          ..lineTo(-9, 3);
        return (stroke: p, fill: null);
      case ActionId.drumroll:
        final p = Path()
          ..addOval(const Rect.fromLTRB(-8, -4, 8, 1))
          ..moveTo(-8, -1)
          ..lineTo(-8, 7)
          ..quadraticBezierTo(0, 11, 8, 7)
          ..lineTo(8, -1)
          ..moveTo(-3, -6)
          ..lineTo(-9, -11)
          ..moveTo(3, -6)
          ..lineTo(9, -11);
        return (stroke: p, fill: null);
      case ActionId.steal:
        final p = Path()
          ..moveTo(-8, 4)
          ..quadraticBezierTo(-9, -6, -3, -6)
          ..lineTo(-3, -1)
          ..moveTo(-3, -6)
          ..lineTo(0, -9)
          ..lineTo(1, -1)
          ..moveTo(0, -9)
          ..lineTo(4, -8)
          ..lineTo(4, -1)
          ..moveTo(4, -6)
          ..lineTo(8, -4)
          ..lineTo(7, 5)
          ..quadraticBezierTo(0, 10, -8, 4);
        return (stroke: p, fill: null);
      case ActionId.egg:
        final p = Path()..addOval(const Rect.fromLTRB(-7, -10, 7, 9));
        return (stroke: p, fill: p);
      case ActionId.kick:
        final p = Path()
          ..moveTo(-4, -10)
          ..lineTo(-2, 2)
          ..lineTo(8, 4)
          ..moveTo(8, 4)
          ..lineTo(11, 1)
          ..moveTo(8, 4)
          ..lineTo(11, 6)
          ..moveTo(-10, 6)
          ..lineTo(-6, 6)
          ..moveTo(-11, 9)
          ..lineTo(-5, 9);
        return (stroke: p, fill: null);
      case ActionId.screech:
        final p = Path()
          ..moveTo(-9, 2)
          ..quadraticBezierTo(-7, -7, 1, -6)
          ..lineTo(6, -3)
          ..lineTo(1, -1)
          ..quadraticBezierTo(-3, 3, -9, 2)
          ..moveTo(5, 3)
          ..quadraticBezierTo(8, 6, 6, 9)
          ..moveTo(8, 0)
          ..quadraticBezierTo(12, 4, 10, 9);
        return (stroke: p, fill: null);
      default:
        return (stroke: _star(9, 4, 5), fill: null);
    }
  }

  static ({Path stroke, Path? fill}) _stat(Stat s) {
    switch (s) {
      case Stat.maxHp:
        return (stroke: _heart(1.2), fill: _heart(1.2));
      case Stat.regen:
        final p = _heart(1.1)
          ..moveTo(0, -3)
          ..lineTo(0, 4)
          ..moveTo(-3.5, 0.5)
          ..lineTo(3.5, 0.5);
        return (stroke: p, fill: null);
      case Stat.dmg:
        final p = _star(10, 4, 8);
        return (stroke: p, fill: p);
      case Stat.atk:
        return _action(ActionId.flash);
      case Stat.range:
        final p = _circle(0, 0, 9)
          ..addOval(Rect.fromCircle(center: Offset.zero, radius: 4.5))
          ..addOval(Rect.fromCircle(center: Offset.zero, radius: 1));
        return (stroke: p, fill: null);
      case Stat.speed:
        return _action(ActionId.dash);
      case Stat.armor:
        final p = Path()
          ..moveTo(0, -10)
          ..lineTo(9, -6)
          ..quadraticBezierTo(8, 6, 0, 10)
          ..quadraticBezierTo(-8, 6, -9, -6)
          ..close();
        return (stroke: p, fill: p);
      case Stat.lifesteal:
        return _item('zahn');
      case Stat.crit:
        return _item('klee');
      case Stat.pickup:
        return _item('magnet');
      case Stat.thrust:
        final p = Path()
          ..moveTo(0, 10)
          ..lineTo(0, -9)
          ..moveTo(-6, -3)
          ..lineTo(0, -9)
          ..lineTo(6, -3)
          ..moveTo(-8, 4)
          ..quadraticBezierTo(-12, -2, -6, -6)
          ..moveTo(8, 4)
          ..quadraticBezierTo(12, -2, 6, -6);
        return (stroke: p, fill: null);
      case Stat.glide:
        final p = Path()
          ..moveTo(-11, -2)
          ..quadraticBezierTo(0, -10, 11, -2)
          ..quadraticBezierTo(0, -5, -11, -2)
          ..moveTo(0, -5)
          ..lineTo(0, 9);
        return (stroke: p, fill: null);
    }
  }
}

/// Symbol als Widget (Shop, Kompendium, Info-Panels, Pillen, Knöpfe).
class Glyph extends StatelessWidget {
  const Glyph(this.ref, {super.key, this.size = 24});
  final GlyphRef ref;
  final double size;

  @override
  Widget build(BuildContext context) => SizedBox.square(
        dimension: size,
        child: CustomPaint(painter: _GlyphPainter(ref)),
      );
}

class _GlyphPainter extends CustomPainter {
  _GlyphPainter(this.ref);
  final GlyphRef ref;

  @override
  void paint(Canvas c, Size size) {
    c.save();
    c.translate(size.width / 2, size.height / 2);
    GlyphArt.draw(c, ref, size.shortestSide, t: 1.2);
    c.restore();
  }

  @override
  bool shouldRepaint(_GlyphPainter old) => !identical(old.ref, ref);
}
