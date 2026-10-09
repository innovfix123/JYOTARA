import 'package:flutter/material.dart';

/// All interface fonts are bundled so English and Tamil work offline.
abstract final class JyotaraFonts {
  static const app = 'JyotaraSans';
  // Preserve the existing alias used by headings, now backed by Inter too.
  static const editorial = 'JyotaraEditorial';
  static const chat = 'JyotaraChat';
  static const tamil = 'JyotaraTamil';
  static const fallback = [tamil];
}

TextTheme jyotaraAppTextTheme({bool tamil = false}) =>
    TextTheme(
      displaySmall: TextStyle(
        fontSize: 40,
        height: tamil ? 1.45 : 1.2,
        fontWeight: FontWeight.w500,
        letterSpacing: 0,
      ),
      headlineMedium: TextStyle(
        fontSize: 28,
        height: tamil ? 1.45 : 1.24,
        fontWeight: FontWeight.w500,
        letterSpacing: 0,
      ),
      headlineSmall: TextStyle(
        fontSize: 22,
        height: tamil ? 1.45 : 1.28,
        fontWeight: FontWeight.w500,
        letterSpacing: 0,
      ),
      titleLarge: const TextStyle(
        fontWeight: FontWeight.w500,
        letterSpacing: 0,
      ),
      titleMedium: const TextStyle(
        fontWeight: FontWeight.w500,
        letterSpacing: 0,
      ),
      bodyLarge: TextStyle(
        fontWeight: FontWeight.w400,
        height: tamil ? 1.5 : 1.48,
        letterSpacing: 0,
      ),
      bodyMedium: TextStyle(
        fontWeight: FontWeight.w400,
        height: tamil ? 1.5 : 1.42,
        letterSpacing: 0,
      ),
    ).apply(
      fontFamily: JyotaraFonts.app,
      fontFamilyFallback: JyotaraFonts.fallback,
    );
