import 'dart:math';

import 'package:flutter/material.dart';

import '../config.dart';
import 'bird_art.dart';
import 'enemy_art.dart';
import 'light.dart';
import 'weapon_art.dart';

part 'glyph_objects.dart';

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
/// Items, Aktionen und Werte als leuchtende Objekte (`glyph_objects.dart`). Gezeichnet in einem Feld der Größe [size],
/// Mittelpunkt im Ursprung.
class GlyphArt {
  GlyphArt._();

  /// Farbe eines Symbols (Seltenheit, Aktion, Wert).
  static Color colorOf(GlyphRef g) => switch (g) {
        WeaponGlyph(:final id) => weaponDefs[id]!.cls.color,
        ItemGlyph(:final id) => itemById[id]!.action != null ? const Color(0xFFFFD27A) : _rarityGlow(itemById[id]!.rarity),
        ActionGlyph(:final action) => _Obj.actionColor(action),
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
      case ItemGlyph(:final id):
        final it = itemById[id]!;
        _scaled(c, size, () => it.action != null ? _Obj.action(c, it.action!, t) : _Obj.item(c, id, t));
      case ActionGlyph(:final action):
        _scaled(c, size, () => _Obj.action(c, action, t));
      case StatGlyph(:final stat):
        _scaled(c, size, () => _Obj.stat(c, stat, t));
    }
  }

  static void _scaled(Canvas c, double size, void Function() f) {
    c.save();
    c.scale(size / 24);
    f();
    c.restore();
  }

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

  static Path _heart(double s) => Path()
    ..moveTo(0, 7 * s)
    ..cubicTo(-10 * s, 0, -6 * s, -9 * s, 0, -4 * s)
    ..cubicTo(6 * s, -9 * s, 10 * s, 0, 0, 7 * s)
    ..close();

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
