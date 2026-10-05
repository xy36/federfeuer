import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'config.dart' show kUiScaleOptions, uiScaleSetting;
import 'input_bindings.dart';

/// Gespeicherte Spieleinstellungen (Vollbild verwaltet DesktopWindow selbst).
class Settings {
  static const _shakeKey = 'settingScreenShake', _fpsKey = 'settingShowFps', _uiScaleKey = 'settingUiScale';

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
      final scale = prefs.getDouble(_uiScaleKey);
      if (scale != null && kUiScaleOptions.contains(scale)) uiScaleSetting.value = scale;
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
      await prefs.setDouble(_uiScaleKey, uiScaleSetting.value);
      await bindings.saveTo(prefs);
    } catch (e) {
      debugPrint('Einstellungen nicht speicherbar: $e');
    }
  }
}
