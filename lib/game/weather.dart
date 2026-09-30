import 'dart:math';

/// Wetterarten. Umgesetzt sind bisher Klar, Wind und Regen;
/// Nebel, Gewitter, Hitze und Schnee folgen laut GDD.
enum WeatherType {
  clear('Klar'),
  wind('Wind'),
  rain('Regen');

  const WeatherType(this.label);
  final String label;
}

/// Alle Wetterwerte an einer Stelle (kann später nach config.dart wandern).
class WeatherConfig {
  WeatherConfig._();

  // Wind
  /// Seitlicher Drift in Welteinheiten pro Sekunde.
  static const double windStrength = 80;
  static const double windSwitchMin = 8;
  static const double windSwitchMax = 12;

  /// Dauer eines kompletten Richtungswechsels (+80 → −80) in Sekunden.
  static const double windTurnTime = 1.5;

  /// Böen: ±15 % Schwankung um den Grundwind.
  static const double windGust = 0.15;
  static const double windGustSpeed = 1.7;

  /// Windanfälligkeit nach Gegnerklasse (1 = voller Drift).
  static const double windFactorLight = 1.0; // Krähe
  static const double windFactorMedium = 0.8; // Spucker
  static const double windFactorGround = 0.5; // Käfer
  static const double windFactorHeavy = 0.35; // Brocken
  static const double windFactorBoss = 0.2; // Geierkönig

  // Regen
  static const double rainThrustFactor = 0.9; // Schub −10 %
  static const double rainGlideFallFactor = 1.3; // Gleiten +30 % Fall
  static const double rainDropFallFactor = 1.5; // Material sinkt schneller

  // Häufigkeit
  static const double badWeatherBase = 0.20; // Stufe 1 (Küken)
  static const double badWeatherPerLevel = 0.15; // +15 % pro Stufe
  static const List<WeatherType> defaultPool = [
    WeatherType.wind,
    WeatherType.rain,
  ];
}

/// Zustand und Modifikatoren des aktuellen Wetters.
///
/// Wird einmal im Spiel gehalten, zu Wellenbeginn mit [startWave] gewürfelt
/// und in `play` mit [update] fortgeschrieben. Bei dt = 0 (Menüs) passiert nichts.
class Weather {
  Weather({Random? random}) : _rng = random ?? Random();

  final Random _rng;

  WeatherType _type = WeatherType.clear;
  double _windTarget = 0;
  double _wind = 0;
  double _switchIn = 0;
  double _time = 0;

  WeatherType get type => _type;
  String get label => _type.label;
  bool get isClear => _type == WeatherType.clear;
  bool get isWindy => _type == WeatherType.wind;
  bool get isRaining => _type == WeatherType.rain;

  /// Geglätteter Grundwind ohne Böen (−windStrength … +windStrength).
  double get windBase => _wind;

  /// Seitlicher Drift in Welteinheiten/s inkl. Böen. Positiv = nach rechts.
  double get windX =>
      _wind *
      (1 + WeatherConfig.windGust * sin(_time * WeatherConfig.windGustSpeed));

  /// Wind normiert auf −1 … 1, für die Darstellung.
  double get windNorm => _wind / WeatherConfig.windStrength;

  /// Sekunden bis zum nächsten Richtungswechsel (nur bei Wind relevant).
  double get windSwitchIn => _switchIn;

  double get thrustFactor => isRaining ? WeatherConfig.rainThrustFactor : 1.0;
  double get glideFallFactor =>
      isRaining ? WeatherConfig.rainGlideFallFactor : 1.0;
  double get dropFallFactor =>
      isRaining ? WeatherConfig.rainDropFallFactor : 1.0;

  /// Chance auf nicht-klares Wetter je Schwierigkeitsstufe (1–5).
  static double badWeatherChance(int difficulty) {
    final c = WeatherConfig.badWeatherBase +
        WeatherConfig.badWeatherPerLevel * (difficulty - 1);
    return c.clamp(0.0, 1.0).toDouble();
  }

  /// Würfelt ein Wetter aus [pool] (später: Pool der aktuellen Welt).
  WeatherType roll({
    int difficulty = 1,
    List<WeatherType> pool = WeatherConfig.defaultPool,
  }) {
    final candidates = pool.where((t) => t != WeatherType.clear).toList();
    if (candidates.isEmpty) return WeatherType.clear;
    if (_rng.nextDouble() >= badWeatherChance(difficulty)) {
      return WeatherType.clear;
    }
    return candidates[_rng.nextInt(candidates.length)];
  }

  /// Zu Beginn jeder Welle aufrufen. Gibt das gewürfelte Wetter zurück.
  WeatherType startWave({
    int difficulty = 1,
    List<WeatherType> pool = WeatherConfig.defaultPool,
  }) {
    set(roll(difficulty: difficulty, pool: pool));
    return _type;
  }

  /// Setzt ein Wetter direkt (auch für Debug-Tasten und Tests).
  void set(WeatherType type) {
    _type = type;
    _time = 0;
    _wind = 0;
    if (type == WeatherType.wind) {
      _windTarget =
          (_rng.nextBool() ? 1.0 : -1.0) * WeatherConfig.windStrength;
      _switchIn = _nextSwitch();
    } else {
      _windTarget = 0;
      _switchIn = 0;
    }
  }

  void reset() => set(WeatherType.clear);

  void update(double dt) {
    if (dt <= 0) return;
    _time += dt;

    if (isWindy) {
      _switchIn -= dt;
      if (_switchIn <= 0) {
        _windTarget = -_windTarget;
        _switchIn += _nextSwitch();
      }
    }

    // Weich auf den Zielwind zulaufen (Aufbau und Richtungswechsel).
    final maxStep =
        2 * WeatherConfig.windStrength / WeatherConfig.windTurnTime * dt;
    _wind += (_windTarget - _wind).clamp(-maxStep, maxStep);
  }

  double _nextSwitch() =>
      WeatherConfig.windSwitchMin +
      _rng.nextDouble() *
          (WeatherConfig.windSwitchMax - WeatherConfig.windSwitchMin);
}
