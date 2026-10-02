import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'input_bindings.dart';

/// Gespeicherte Spieleinstellungen (Vollbild verwaltet DesktopWindow selbst).
class Settings {
  static const _shakeKey = 'settingScreenShake', _fpsKey = 'settingShowFps';

  /// Bildschirmwackeln bei Treffern und Explosionen.
  bool screenShake = true;

  /// FPS-Anzeige oben rechts.
  bool showFps = false;

  /// Tastatur- und Controller-Belegung.
  final bindings = InputBindings();

  Future<void> load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      screenShake = prefs.getBool(_shakeKey) ?? true;
      showFps = prefs.getBool(_fpsKey) ?? false;
      bindings.loadFrom(prefs);
    } catch (e) {
      debugPrint('Einstellungen nicht lesbar: $e');
    }
  }

  Future<void> save() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_shakeKey, screenShake);
      await prefs.setBool(_fpsKey, showFps);
      await bindings.saveTo(prefs);
    } catch (e) {
      debugPrint('Einstellungen nicht speicherbar: $e');
    }
  }
}
