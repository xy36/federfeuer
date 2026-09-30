import 'package:flutter_test/flutter_test.dart';
import 'package:federfeuer/game/config.dart';

void main() {
  group('Welt', () {
    test('Wellendauer wächst ohne Obergrenze', () {
      expect(waveDuration(1), 20);
      expect(waveDuration(9), 52);
      expect(waveDuration(14), 72);
    });

    test('Welt ist mit Grundtempo in 3/5 der Wellenzeit durchfliegbar', () {
      for (var w = 1; w < kMaxWave; w++) {
        expect(worldWidth(w) / kPlayerSpeed, closeTo(waveDuration(w) * 0.6, 1e-9));
      }
      expect(worldWidth(1), closeTo(2760, 1e-9));
      expect(worldWidth(14), closeTo(9936, 1e-9));
    });

    test('Welten wechseln nach Wellen', () {
      final expected = {
        for (var w = 1; w <= 4; w++) w: Biome.fields,
        for (var w = 5; w <= 8; w++) w: Biome.village,
        for (var w = 9; w <= 12; w++) w: Biome.forest,
        13: Biome.mountains,
        14: Biome.mountains,
        15: Biome.summit,
      };
      expected.forEach((w, b) => expect(biomeForWave(w), b, reason: 'Welle $w'));
    });

    test('Bosswelle nutzt die feste Arena', () {
      expect(isBossWave(kMaxWave), isTrue);
      expect(worldWidth(kMaxWave), kArenaW);
    });
  });
}
