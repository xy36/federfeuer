import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:window_manager/window_manager.dart';

/// Läuft das Spiel als Desktop-App (Windows, macOS, Linux)?
bool get isDesktop =>
    !kIsWeb &&
    (defaultTargetPlatform == TargetPlatform.windows ||
        defaultTargetPlatform == TargetPlatform.macOS ||
        defaultTargetPlatform == TargetPlatform.linux);

/// Fenster und Vollbild am PC: Start im gespeicherten Modus (Standard: Vollbild),
/// Umschalten mit F11 oder Alt+Enter bzw. per Knopf in Menü und Pause.
class DesktopWindow {
  DesktopWindow._();

  static const _prefKey = 'fullscreen';
  static const minSize = Size(960, 540);

  /// Aktueller Modus, zum Anzeigen in den Menüs.
  static final fullScreen = ValueNotifier<bool>(true);

  static Future<void> init() async {
    await windowManager.ensureInitialized();
    var wantFull = true;
    try {
      final prefs = await SharedPreferences.getInstance();
      wantFull = prefs.getBool(_prefKey) ?? true;
    } catch (e) {
      debugPrint('Vollbild-Einstellung nicht lesbar: $e');
    }
    const options = WindowOptions(
      title: 'Federfeuer',
      size: Size(1280, 720),
      minimumSize: minSize,
      center: true,
      backgroundColor: Color(0xFF02040E),
    );
    await windowManager.waitUntilReadyToShow(options, () async {
      await windowManager.show();
      await windowManager.focus();
      if (wantFull) await windowManager.setFullScreen(true);
      fullScreen.value = wantFull;
    });
    HardwareKeyboard.instance.addHandler(_onKey);
  }

  static Future<void> setFullScreen(bool value) async {
    await windowManager.setFullScreen(value);
    fullScreen.value = value;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_prefKey, value);
    } catch (e) {
      debugPrint('Vollbild-Einstellung nicht speicherbar: $e');
    }
  }

  /// Spiel beenden (Menüpunkt „Beenden“ am PC).
  static Future<void> quit() => windowManager.close();

  static Future<void> toggle() async => setFullScreen(!await windowManager.isFullScreen());

  /// F11 oder Alt+Enter – global, egal welches Element gerade den Fokus hat.
  static bool _onKey(KeyEvent e) {
    if (e is! KeyDownEvent) return false;
    final alt = HardwareKeyboard.instance.isAltPressed;
    if (e.logicalKey == LogicalKeyboardKey.f11 || (alt && e.logicalKey == LogicalKeyboardKey.enter)) {
      toggle();
      return true;
    }
    return false;
  }
}
