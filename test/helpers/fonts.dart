import 'dart:io';

import 'package:flutter/services.dart';

/// Lädt die Spielschriften, damit Layout-Tests mit echten Glyphenmaßen laufen
/// (die Test-Ersatzschrift ist breiter und höher).
Future<void> loadGameFonts() async {
  for (final (family, file) in [
    ('Cinzel', 'assets/fonts/Cinzel.ttf'),
    ('Nunito', 'assets/fonts/Nunito.ttf'),
  ]) {
    final loader = FontLoader(family)..addFont(Future.value(ByteData.sublistView(File(file).readAsBytesSync())));
    await loader.load();
  }
}
