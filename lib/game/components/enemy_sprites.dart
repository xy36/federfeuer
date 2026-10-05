part of 'enemy.dart';

// ---------------- Gegner-Sprites ----------------
//
// Bis zu 110 Gegner aus jeweils vielen Pfaden, Verläufen und Clips einzeln zu zeichnen,
// kostet pro Bild mehr Zeit als alles andere zusammen. Deshalb wird jeder Gegnertyp
// einmal je Animationsphase in einen Atlas gerendert (in der aktuellen Bildschirmauflösung)
// und im Spiel nur noch gebündelt per drawAtlas gezeichnet – ein Aufruf je Typ und
// Blickrichtung. Die Hauptbewegung (Flügelschlag, Beine …) läuft dabei als Schleife mit
// [EnemySpriteDef.frames] Phasen; der Puls wird in wenigen Stufen vorgerendert, der
// Treffer-Blitz über die Atlas-Farbe erzeugt. Nicht im Sprite: Rauch, Fäden, Zeiger,
// Statusanzeigen und Einzelgegner (Boss, Torwächter, Irrlicht, Riss, Ei).

/// Wie ein Gegnertyp vorgerendert wird.
class EnemySpriteDef {
  const EnemySpriteDef({
    required this.bounds,
    required this.draw,
    this.omega = 0,
    this.frames = 1,
    this.pulseLevels = 1,
    this.variants = 1,
    this.variantOf,
  });

  /// Ausdehnung der Zeichnung in lokalen Einheiten (Blick nach +x, ohne Elite-Skalierung).
  final Rect bounds;

  /// Kreisfrequenz der Hauptbewegung; eine Schleife dauert 2π / [omega] (0 = statisch).
  /// Alle übrigen zeitabhängigen Teile der Zeichnung sind ganzzahlige Vielfache davon.
  final double omega;

  /// Phasen pro Schleife.
  final int frames;

  /// Vorgerenderte Stufen des Pulses (0,5 + 0,5 · sin(3t)).
  final int pulseLevels;

  /// Weitere Varianten (Warnstufe, Zustand, Ausrichtung) und ihre Auswahl.
  final int variants;
  final int Function(Enemy e)? variantOf;

  /// Zeichnet eine Phase: Zeit [t], Puls, Variante, Radius.
  final void Function(Canvas c, double t, double pulse, int variant, double r) draw;

  int get cells => frames * pulseLevels * variants;
}

EnemyLook _look(double t, double pulse, {double warn = 0, int state = 0, double aim = 0}) =>
    EnemyLook(t: t, pulse: pulse, warn: warn, state: state, aim: aim);

/// Warnstufe 0 … levels−1 (für Varianten).
int _warnLevel(Enemy e, int levels) => (e.warn.clamp(0.0, 1.0) * (levels - 1)).round();

/// Vorgerenderte Gegnertypen. Fehlt ein Typ, wird er wie bisher live gezeichnet.
final Map<EnemyType, EnemySpriteDef> enemySpriteDefs = {
  EnemyType.crow: EnemySpriteDef(
    bounds: const Rect.fromLTRB(-30, -32, 28, 16),
    omega: 16,
    frames: 8,
    pulseLevels: 3,
    draw: (c, t, p, v, r) {
      RotArt.crow(c, t, sin(t * 16), p, withSmoke: false);
      Enemy._slitEye(c, 6, -5, 2.6, Enemy._eye);
    },
  ),
  EnemyType.beetle: EnemySpriteDef(
    bounds: const Rect.fromLTRB(-22, -20, 32, 20),
    omega: 7,
    frames: 16,
    pulseLevels: 3,
    draw: (c, t, p, v, r) => EnemyArt.beetle(c, _look(t, p), r),
  ),
  EnemyType.spitter: EnemySpriteDef(
    bounds: const Rect.fromLTRB(-22, -20, 22, 28),
    omega: 6,
    frames: 12,
    pulseLevels: 3,
    variants: 3,
    variantOf: (e) => _warnLevel(e, 3),
    draw: (c, t, p, v, r) => EnemyArt.spitter(c, _look(t, p, warn: v / 2), r),
  ),
  EnemyType.rock: EnemySpriteDef(
    bounds: const Rect.fromLTRB(-32, -32, 32, 32),
    pulseLevels: 3,
    draw: (c, t, p, v, r) => EnemyArt.rock(c, _look(t, p), r),
  ),
  EnemyType.puffball: EnemySpriteDef(
    bounds: const Rect.fromLTRB(-30, -30, 30, 30),
    omega: 3,
    frames: 16,
    pulseLevels: 3,
    variants: 3,
    variantOf: (e) => _warnLevel(e, 3),
    draw: (c, t, p, v, r) => EnemyArt.puffball(c, _look(t, p, warn: v / 2), r),
  ),
  EnemyType.scarecrow: EnemySpriteDef(
    bounds: const Rect.fromLTRB(-26, -36, 26, 28),
    omega: 1.4,
    frames: 12,
    pulseLevels: 3,
    draw: (c, t, p, v, r) => EnemyArt.scarecrow(c, _look(t, p), r),
  ),
  EnemyType.bat: EnemySpriteDef(
    bounds: const Rect.fromLTRB(-24, -22, 24, 12),
    omega: 22,
    frames: 8,
    draw: (c, t, p, v, r) => EnemyArt.bat(c, _look(t, p), r),
  ),
  // Ausrichtung des Hahns: cos(aim) in 9 Stufen; der Zeigerpfeil bleibt live.
  EnemyType.weathercock: EnemySpriteDef(
    bounds: const Rect.fromLTRB(-26, -30, 26, 24),
    variants: 9,
    variantOf: (e) => ((cos(e.aim) + 1) / 2 * 8).round(),
    draw: (c, t, p, v, r) => EnemyArt.weathercock(c, _look(t, p, aim: acos(v / 4 - 1)), r),
  ),
  EnemyType.spider: EnemySpriteDef(
    bounds: const Rect.fromLTRB(-24, -20, 24, 24),
    omega: 6,
    frames: 10,
    pulseLevels: 3,
    draw: (c, t, p, v, r) => EnemyArt.spider(c, _look(t, p), r),
  ),
  // Zustand: 0 kreisen, 1 zielen (helles Auge), 2 Sturzflug.
  EnemyType.eagle: EnemySpriteDef(
    bounds: const Rect.fromLTRB(-40, -44, 34, 26),
    omega: 8,
    frames: 10,
    pulseLevels: 3,
    variants: 3,
    variantOf: (e) => e.state.clamp(0, 2),
    draw: (c, t, p, v, r) => EnemyArt.eagle(c, _look(t, p, state: v), r),
  ),
  // Nur laufend; eingerollt zeichnet ihn die Weltlogik live.
  EnemyType.avalanche: EnemySpriteDef(
    bounds: const Rect.fromLTRB(-26, -22, 30, 26),
    omega: 12,
    frames: 10,
    pulseLevels: 3,
    draw: (c, t, p, v, r) => EnemyArt.avalancheWalk(c, _look(t, p), r),
  ),
  // Das Wackeln vor dem Ausschwärmen wird beim Zeichnen als Versatz ergänzt.
  EnemyType.crowNest: EnemySpriteDef(
    bounds: const Rect.fromLTRB(-30, -16, 30, 28),
    draw: (c, t, p, v, r) => EnemyArt.crowNest(c, _look(t, p), r),
  ),
  EnemyType.waspNest: EnemySpriteDef(
    bounds: const Rect.fromLTRB(-20, -24, 20, 24),
    pulseLevels: 3,
    draw: (c, t, p, v, r) => EnemyArt.waspNest(c, _look(t, p), r),
  ),
  EnemyType.wasp: EnemySpriteDef(
    bounds: const Rect.fromLTRB(-14, -12, 10, 8),
    omega: 30,
    frames: 6,
    draw: (c, t, p, v, r) => EnemyArt.wasp(c, _look(t, p), r),
  ),
  EnemyType.sporeShroom: EnemySpriteDef(
    bounds: const Rect.fromLTRB(-28, -26, 28, 26),
    pulseLevels: 3,
    variants: 3,
    variantOf: (e) => _warnLevel(e, 3),
    draw: (c, t, p, v, r) => EnemyArt.sporeShroom(c, _look(t, p, warn: v / 2), r),
  ),
  EnemyType.spore: EnemySpriteDef(
    bounds: const Rect.fromLTRB(-11, -11, 11, 11),
    omega: 8,
    frames: 6,
    pulseLevels: 3,
    draw: (c, t, p, v, r) => EnemyArt.spore(c, _look(t, p), r),
  ),
  EnemyType.beetleQueen: EnemySpriteDef(
    bounds: const Rect.fromLTRB(-44, -46, 36, 36),
    omega: 4,
    frames: 16,
    variants: 2,
    variantOf: (e) => _warnLevel(e, 2),
    draw: (c, t, p, v, r) => EnemyArt.beetleQueen(c, _look(t, p, warn: v.toDouble()), r),
  ),
};

/// Ein vorgerenderter Gegnertyp: Bild mit allen Zellen, Ursprung in der Zelle (Pixel)
/// und Pixel pro lokaler Einheit.
class EnemySpriteAtlas {
  EnemySpriteAtlas(this.image, this.cells, this.anchor, this.scale);
  final ui.Image image;
  final List<Rect> cells;
  final Offset anchor;
  final double scale;
}

/// Baut und hält die Atlanten; bei geänderter Bildschirmauflösung werden sie neu gerendert.
class EnemySpriteCache {
  /// Größte Atlas-Kante (Pixel) – darüber wird der Typ in geringerer Auflösung gerendert.
  static const maxAtlasSide = 4096.0;

  double _scale = 0;
  final _atlases = <EnemyType, EnemySpriteAtlas>{};

  EnemySpriteAtlas atlasFor(EnemyType type, EnemySpriteDef def, double scale) {
    if (_scale == 0 || (scale - _scale).abs() > _scale * 0.05) clear(scale);
    return _atlases[type] ??= _build(def, enemyDefs[type]!.radius, _scale);
  }

  void clear([double scale = 0]) {
    for (final a in _atlases.values) {
      a.image.dispose();
    }
    _atlases.clear();
    _scale = scale;
  }

  static EnemySpriteAtlas _build(EnemySpriteDef def, double r, double scale) {
    final b = def.bounds;
    final cols = sqrt(def.cells).ceil(), rows = (def.cells / cols).ceil();
    // Zu großer Atlas: Auflösung so weit senken, dass er passt.
    final s = min(scale, min(maxAtlasSide / (cols * (b.width + 1)), maxAtlasSide / (rows * (b.height + 1))));
    final cw = (b.width * s).ceil() + 2.0, ch = (b.height * s).ceil() + 2.0;
    final rec = ui.PictureRecorder();
    final c = Canvas(rec);
    final cells = <Rect>[];
    final period = def.omega > 0 ? 2 * pi / def.omega : 0.0;
    var i = 0;
    for (var v = 0; v < def.variants; v++) {
      for (var pl = 0; pl < def.pulseLevels; pl++) {
        final pulse = def.pulseLevels == 1 ? 0.5 : (pl + 0.5) / def.pulseLevels;
        for (var f = 0; f < def.frames; f++) {
          final cell = Rect.fromLTWH((i % cols) * cw, (i ~/ cols) * ch, cw, ch);
          cells.add(cell);
          c.save();
          c.clipRect(cell);
          c.translate(cell.left + 1 - b.left * s, cell.top + 1 - b.top * s);
          c.scale(s);
          def.draw(c, period * f / def.frames, pulse, v, r);
          c.restore();
          i++;
        }
      }
    }
    final image = rec.endRecording().toImageSync((cols * cw).ceil(), (rows * ch).ceil());
    return EnemySpriteAtlas(image, cells, Offset(1 - b.left * s, 1 - b.top * s), s);
  }
}

/// Zeichnet die Körper aller vorgerenderten Gegner (zuerst die Schatten), gebündelt je
/// Typ, Blickrichtung und Treffer-Blitz. Liegt mit Priorität 5 vor den Gegnern selbst, die darüber
/// Rauch, Fäden und Statusanzeigen zeichnen.
class EnemyBodyPass extends Component with HasGameReference<FederfeuerGame> {
  EnemyBodyPass() : super(priority: 5);

  final cache = EnemySpriteCache();
  static final normalPaint = Paint()..filterQuality = FilterQuality.low;

  /// Treffer-Blitz: Körper zu 85 % weiß. Als Farbfilter statt über die Farben von
  /// drawAtlas – deren Mischrichtung unterscheidet sich zwischen Skia und Impeller,
  /// und falsch herum würde die ganze Zelle (ein Rechteck) eingefärbt.
  static final hitPaint = Paint()
    ..filterQuality = FilterQuality.low
    ..colorFilter = const ColorFilter.mode(Color(0xD9FFFFFF), BlendMode.srcATop);

  // Puffer je Typ, Blickrichtung und Treffer (Index: Typ · 4 + links · 2 + Treffer)
  final _xf = <int, List<RSTransform>>{};
  final _rects = <int, List<Rect>>{};

  @override
  void onRemove() {
    cache.clear();
    super.onRemove();
  }

  /// Pixel pro Welteinheit (Kamera-Zoom × Gerätepixel) – die Auflösung der Atlanten.
  double get _scale =>
      game.camera.viewfinder.zoom * WidgetsBinding.instance.platformDispatcher.views.first.devicePixelRatio;

  /// Atlanten der Gegner einer Welle schon zum Wellenstart rendern, statt beim ersten
  /// Auftauchen mitten im Kampf (kurzer Hänger). Spawner-Kinder kommen dazu.
  void prewarm(Iterable<EnemyType> types) {
    if (!isMounted) return;
    final scale = _scale;
    for (final t in {...types, for (final t in types) ...?_children[t]}) {
      final def = enemySpriteDefs[t];
      if (def != null) cache.atlasFor(t, def, scale);
    }
  }

  static const _children = {
    EnemyType.waspNest: [EnemyType.wasp],
    EnemyType.sporeShroom: [EnemyType.spore],
    EnemyType.beetleQueen: [EnemyType.avalanche],
    EnemyType.spiderMother: [EnemyType.spider],
  };

  @override
  void render(Canvas c) {
    if (perfSkip.contains(RenderPart.enemyBodies)) return;
    final scale = _scale;
    for (final l in _xf.values) {
      l.clear();
    }
    for (final l in _rects.values) {
      l.clear();
    }
    for (final e in game.enemies) {
      final def = e.spriteDef;
      if (def == null) continue;
      c.save();
      c.translate(e.x, e.y);
      drawShadow(c, e.y, e.r);
      c.restore();
      final atlas = cache.atlasFor(e.type, def, scale);
      final face = e.face;
      final key = e.type.index * 4 + (face > 0 ? 0 : 2) + (e.flash > 0 ? 1 : 0);
      // Gespiegelte Gegner landen in einem eigenen Aufruf unter scale(−1, 1).
      final k = e.sizeK / atlas.scale;
      _xf.putIfAbsent(key, () => []).add(RSTransform.fromComponents(
            rotation: 0,
            scale: k,
            anchorX: atlas.anchor.dx,
            anchorY: atlas.anchor.dy,
            translateX: face * e.x + e.spriteShake * e.sizeK,
            translateY: e.y,
          ));
      _rects.putIfAbsent(key, () => []).add(atlas.cells[e.spriteCell(def)]);
    }
    for (final key in _xf.keys) {
      final xf = _xf[key]!;
      if (xf.isEmpty) continue;
      final type = EnemyType.values[key ~/ 4];
      final atlas = cache.atlasFor(type, enemySpriteDefs[type]!, scale);
      final mirrored = key & 2 != 0;
      if (mirrored) {
        c.save();
        c.scale(-1, 1);
      }
      c.drawAtlas(atlas.image, xf, _rects[key]!, null, null, null, key.isOdd ? hitPaint : normalPaint);
      if (mirrored) c.restore();
    }
  }
}
