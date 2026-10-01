import 'package:flame/flame.dart';
import 'package:flame/game.dart';
import 'package:flutter/material.dart';

import 'game/federfeuer_game.dart';
import 'platform/desktop_window.dart';
import 'ui/controls_overlay.dart';
import 'ui/menu.dart';
import 'ui/overlays.dart';
import 'ui/shop_overlay.dart';
import 'ui/widgets.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  if (isDesktop) {
    await DesktopWindow.init();
  } else {
    await Flame.device.fullScreen();
    await Flame.device.setLandscape();
  }
  runApp(const FederfeuerApp());
}

class FederfeuerApp extends StatefulWidget {
  const FederfeuerApp({super.key});

  @override
  State<FederfeuerApp> createState() => _FederfeuerAppState();
}

class _FederfeuerAppState extends State<FederfeuerApp> {
  final _game = FederfeuerGame();

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Federfeuer',
      debugShowCheckedModeBanner: false,
      // Menüs haben feste Kartengrößen; System-Schriftgröße würde sie sprengen.
      builder: (context, child) => MediaQuery.withNoTextScaling(child: child!),
      home: Scaffold(
        backgroundColor: const Color(0xFF02040E),
        body: SafeArea(
          child: GameWidget<FederfeuerGame>(
            game: _game,
            focusNode: _game.focusNode,
            autofocus: true,
            overlayBuilderMap: buildOverlayMap(),
          ),
        ),
      ),
    );
  }
}

/// Alle Flutter-Overlays des Spiels (Menüs und Touch-Steuerung).
Map<String, Widget Function(BuildContext, FederfeuerGame)> buildOverlayMap() => {
      'menu': (context, game) => UiScale(
            child: MenuOverlay(
              key: ValueKey(game.menuGeneration),
              game: game,
              initialPage: game.menuOpensPlay ? MenuPage.play : MenuPage.title,
            ),
          ),
      'levelUp': (context, game) => UiScale(child: LevelUpOverlay(game: game)),
      'shop': (context, game) => UiScale(child: ShopOverlay(game: game)),
      'pause': (context, game) => UiScale(child: PauseOverlay(game: game)),
      'gameOver': (context, game) => UiScale(child: GameOverOverlay(game: game)),
      'controls': (context, game) => UiScale(child: ControlsOverlay(game: game)),
    };
