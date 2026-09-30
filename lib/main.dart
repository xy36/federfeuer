import 'package:flame/flame.dart';
import 'package:flame/game.dart';
import 'package:flutter/material.dart';

import 'game/federfeuer_game.dart';
import 'ui/controls_overlay.dart';
import 'ui/overlays.dart';
import 'ui/shop_overlay.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Flame.device.fullScreen();
  await Flame.device.setLandscape();
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
        backgroundColor: const Color(0xFF1D1540),
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
      'menu': (context, game) => MenuOverlay(game: game),
      'levelUp': (context, game) => LevelUpOverlay(game: game),
      'shop': (context, game) => ShopOverlay(game: game),
      'pause': (context, game) => PauseOverlay(game: game),
      'gameOver': (context, game) => GameOverOverlay(game: game),
      'controls': (context, game) => ControlsOverlay(game: game),
    };
