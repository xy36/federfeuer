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

  static const _prefKey = 'fullscreen', _sizeKey = 'windowSize';
  static const minSize = Size(960, 540);
  static const _defaultSize = Size(1280, 720);

  /// Wählbare Fenstergrößen in Bildschirmpixeln (16:9).
  static const sizePresets = [
    Size(1280, 720),
    Size(1600, 900),
    Size(1920, 1080),
    Size(2560, 1440),
    Size(3200, 1800),
    Size(3840, 2160),
  ];

  /// Aktueller Modus, zum Anzeigen in den Menüs.
  static final fullScreen = ValueNotifier<bool>(true);

  /// Gewählte Fenstergröße in Bildschirmpixeln; null = Standard (1280 × 720 bei 100 % Skalierung).
  static final windowSize = ValueNotifier<Size?>(null);

  static double get _dpr => WidgetsBinding.instance.platformDispatcher.views.first.devicePixelRatio;

  /// Bildschirmpixel → logische Größe für window_manager.
  static Size _logical(Size px) => Size(px.width / _dpr, px.height / _dpr);

  /// Volle Bildschirmauflösung in Pixeln (= Vollbild).
  static Size get nativeSize => WidgetsBinding.instance.platformDispatcher.views.first.display.size;

  /// Größen, die auf den Bildschirm passen und die Mindestgröße einhalten.
  static List<Size> availableSizes() {
    final display = nativeSize;
    final fits = [
      for (final s in sizePresets)
        if (s.width < display.width &&
            s.height < display.height &&
            _logical(s).width >= minSize.width &&
            _logical(s).height >= minSize.height)
          s,
    ];
    return fits.isEmpty ? [currentSize] : fits;
  }

  /// Aktuell eingestellte Fenstergröße in Bildschirmpixeln.
  static Size get currentSize => windowSize.value ?? _defaultSize * _dpr;

  /// Fenstergröße wählen und speichern; im Vollbild wechselt das Spiel dafür ins Fenster.
  static Future<void> setWindowSize(Size size) async {
    windowSize.value = size;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_sizeKey, '${size.width.round()}x${size.height.round()}');
    } catch (e) {
      debugPrint('Fenstergröße nicht speicherbar: $e');
    }
    if (fullScreen.value) {
      await setFullScreen(false);
    } else {
      await _applySize();
    }
  }

  static Future<void> _applySize() async {
    if (windowSize.value == null) return;
    await windowManager.setSize(_logical(windowSize.value!));
    await windowManager.setAlignment(Alignment.center);
  }

  static Future<void> init() async {
    await windowManager.ensureInitialized();
    var wantFull = true;
    try {
      final prefs = await SharedPreferences.getInstance();
      wantFull = prefs.getBool(_prefKey) ?? true;
      final saved = prefs.getString(_sizeKey)?.split('x').map(int.tryParse).toList();
      if (saved != null && saved.length == 2 && saved[0] != null && saved[1] != null) {
        final size = Size(saved[0]!.toDouble(), saved[1]!.toDouble());
        // Nur übernehmen, wenn sie (noch) auf diesen Bildschirm passt.
        if (availableSizes().contains(size)) windowSize.value = size;
      }
    } catch (e) {
      debugPrint('Vollbild-Einstellung nicht lesbar: $e');
    }
    final options = WindowOptions(
      title: 'Federfeuer',
      size: windowSize.value == null ? _defaultSize : _logical(windowSize.value!),
      minimumSize: minSize,
      center: true,
      backgroundColor: Color(0xFF02040E),
    );
    await windowManager.waitUntilReadyToShow(options, () async {
      await windowManager.show();
      await windowManager.focus();
      if (wantFull) {
        // show() blendet unter Windows asynchron ein, setFullScreen übernimmt aber
        // den aktuellen Fensterstil – ohne WS_VISIBLE bliebe das Fenster unsichtbar
        // (leerer Bildschirm, v. a. im Release-Build per Doppelklick).
        for (var i = 0; i < 50 && !await windowManager.isVisible(); i++) {
          await Future<void>.delayed(const Duration(milliseconds: 20));
        }
        await windowManager.setFullScreen(true);
      }
      fullScreen.value = wantFull;
    });
    HardwareKeyboard.instance.addHandler(_onKey);
  }

  static Future<void> setFullScreen(bool value) async {
    await windowManager.setFullScreen(value);
    fullScreen.value = value;
    // Beim Verlassen stellt window_manager die alte Größe her – gewählte Größe gilt aber.
    if (!value) await _applySize();
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
