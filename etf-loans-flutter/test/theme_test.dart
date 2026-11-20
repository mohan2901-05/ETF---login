import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:etf_loans/theme/theme_config.dart';

void main() {
  group('ThemeConfig', () {
    test('light theme has correct primary brand color', () {
      expect(ThemeConfig.lightTheme.colorScheme.primary, const Color(0xFF0a2e1b));
    });

    test('light theme surface color', () {
      expect(ThemeConfig.lightTheme.colorScheme.surface, const Color(0xFFFFFFFF));
    });

    test('dark theme has correct primary brand color', () {
      expect(ThemeConfig.darkTheme.colorScheme.primary, const Color(0xFF0a2e1b));
    });

    test('dark theme surface color', () {
      expect(ThemeConfig.darkTheme.colorScheme.surface, const Color(0xFF2D4A3A));
    });

    test('light theme text theme bodyLarge', () {
      final bodyLarge = ThemeConfig.lightTheme.textTheme.bodyLarge;
      expect(bodyLarge?.fontFamily, ThemeConfig.bodyFontFamily);
      expect(bodyLarge?.fontSize, 15);
    });
  });
}