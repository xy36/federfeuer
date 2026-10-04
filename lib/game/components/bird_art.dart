import 'package:flutter/material.dart';

import '../config.dart';
import 'spirit_bird_art.dart';

/// Haltung eines Vogels in einem Frame.
class BirdPose {
  const BirdPose({
    this.flap = 0,
    this.upright = false,
    this.blink = 0,
    this.look = Offset.zero,
    this.walk,
    this.holding = false,
    this.sway = 0,
    this.t = 0,
  });

  /// Zeit in Sekunden (für fließende Lichtbänder und aufsteigende Funken).
  final double t;

  /// Flügelschlag −1 (oben) … 1 (unten).
  final double flap;

  /// Aufrechter Körper (Pinguin).
  final bool upright;

  /// Lidschluss 0 (offen) … 1 (zu).
  final double blink;

  /// Blickrichtung der Pupillen (−1 … 1 je Achse).
  final Offset look;

  /// Laufphase am Boden (null = in der Luft, Beine eingezogen).
  final double? walk;

  /// Hält eine Waffe in den Krallen (Beine leicht nach unten gestreckt).
  final bool holding;

  /// Schwanzschwung beim Lenken (−1 … 1).
  final double sway;
}

/// Detaillierte, prozedural gezeichnete Geistvögel. Lokale Koordinaten: Blick nach +x,
/// Körpermitte im Ursprung, Radius etwa 16.
/// Einstieg fürs Zeichnen der Vögel (Spiel und Menü-Vorschauen). Gezeichnet wird im Stil
/// „leuchtender Geist“, siehe [SpiritBirdArt].
class BirdArt {
  BirdArt._();

  /// Körperfarbe als Verlauf (für Aufrufer, die einen Paint mitgeben; der Geist-Stil
  /// berechnet seinen Verlauf selbst aus der Silhouette).
  static Paint bodyPaint(CharacterDef ch) => Paint()..color = ch.body;

  static void draw(Canvas c, CharacterDef ch, Paint body, BirdPose pose) => SpiritBirdArt.draw(c, ch, pose);
}
