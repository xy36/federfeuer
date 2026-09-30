import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:federfeuer/game/weather.dart';

void _run(Weather w, double seconds) {
  const dt = 1 / 60;
  for (var t = 0.0; t < seconds; t += dt) {
    w.update(dt);
  }
}

void main() {
  group('Weather', () {
    test('Klar hat keine Effekte', () {
      final w = Weather(random: Random(1));
      expect(w.type, WeatherType.clear);
      _run(w, 2);
      expect(w.windX, 0);
      expect(w.thrustFactor, 1);
      expect(w.glideFallFactor, 1);
      expect(w.dropFallFactor, 1);
    });

    test('Regen verändert nur Flug und Drops', () {
      final w = Weather(random: Random(1))..set(WeatherType.rain);
      _run(w, 2);
      expect(w.thrustFactor, closeTo(0.9, 1e-9));
      expect(w.glideFallFactor, closeTo(1.3, 1e-9));
      expect(w.dropFallFactor, closeTo(1.5, 1e-9));
      expect(w.windX, 0);
    });

    test('Chance auf Wetter je Stufe', () {
      expect(Weather.badWeatherChance(1), closeTo(0.20, 1e-9));
      expect(Weather.badWeatherChance(3), closeTo(0.50, 1e-9));
      expect(Weather.badWeatherChance(5), closeTo(0.80, 1e-9));
      expect(Weather.badWeatherChance(10), 1.0);
    });

    test('roll hält die Chance ein', () {
      final w = Weather(random: Random(42));
      const n = 20000;
      var bad = 0;
      for (var i = 0; i < n; i++) {
        if (w.roll(difficulty: 3) != WeatherType.clear) bad++;
      }
      expect(bad / n, closeTo(0.5, 0.02));
    });

    test('leerer Pool ergibt immer Klar', () {
      final w = Weather(random: Random(3));
      expect(w.roll(difficulty: 5, pool: const []), WeatherType.clear);
    });

    test('Wind baut sich weich auf', () {
      final w = Weather(random: Random(7))..set(WeatherType.wind);
      expect(w.windBase, 0);
      _run(w, 0.2);
      expect(w.windBase.abs(), lessThan(WeatherConfig.windStrength));
      _run(w, 1.0);
      expect(w.windBase.abs(), closeTo(WeatherConfig.windStrength, 1e-6));
    });

    test('Wind wechselt nach 8–12 s die Richtung', () {
      final w = Weather(random: Random(7))..set(WeatherType.wind);
      _run(w, 1);
      final dir = w.windBase.sign;
      _run(w, WeatherConfig.windSwitchMax + WeatherConfig.windTurnTime);
      expect(w.windBase, closeTo(-dir * WeatherConfig.windStrength, 1e-6));
    });

    test('dt = 0 friert das Wetter ein', () {
      final w = Weather(random: Random(7))..set(WeatherType.wind);
      _run(w, 0.3);
      final before = w.windBase;
      w.update(0);
      expect(w.windBase, before);
    });
  });
}
