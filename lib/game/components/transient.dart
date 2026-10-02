import 'package:flame/components.dart';

/// Markiert Komponenten, die beim Wellenwechsel entfernt werden.
mixin Transient on Component {}

/// Kampf-Effekte (Begleiter, Wolken, Eier, Blitze), die am Wellenende sofort verschwinden.
mixin CombatEffect on Component {}
