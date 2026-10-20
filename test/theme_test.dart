import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ripple/core/theme.dart';

void main() {
  group('themes', () {
    test('light variants are light, dark is dark', () {
      expect(buildLightTheme().brightness, Brightness.light);
      expect(buildIceTheme().brightness, Brightness.light);
      expect(buildDarkTheme().brightness, Brightness.dark);
    });

    test('ice differs from sand background', () {
      expect(buildIceTheme().scaffoldBackgroundColor,
          isNot(buildLightTheme().scaffoldBackgroundColor));
    });
  });
}
