import 'package:flutter/material.dart';

/// Colours from the approved Soft Bronze Ask preview. This palette stays local
/// to guide selection and conversations; the rest of the app uses Bronze Eclipse.
abstract final class AskPalette {
  static const background = Color(0xFF49372A);
  static const card = Color(0xFF574337);
  static const ink = Color(0xFFFFF3E4);
  static const muted = Color(0xFFDECCBA);
  static const border = Color(0xFF80634B);
  static const action = Color(0xFFEDC58D);
  static const onAction = Color(0xFF3B2717);
  static const conversation = Color(0xFF503F32);
  static const reply = Color(0xFF685240);
  static const user = Color(0xFF8A6C4D);
}

ThemeData askTheme(ThemeData base, {bool conversation = false}) {
  final family = conversation ? 'JyotaraChat' : 'JyotaraSans';
  // Keep the base style's inherit value and complete fields so animated
  // navigation/button labels can interpolate when entering or leaving Ask.
  final textStyle = base.textTheme.labelLarge!.copyWith(
    fontFamily: family,
    fontFamilyFallback: const ['JyotaraTamil'],
  );
  final textTheme = base.textTheme.apply(
    fontFamily: family,
    fontFamilyFallback: const ['JyotaraTamil'],
    bodyColor: AskPalette.ink,
    displayColor: AskPalette.ink,
  );
  return base.copyWith(
    scaffoldBackgroundColor: conversation
        ? AskPalette.conversation
        : AskPalette.background,
    colorScheme: base.colorScheme.copyWith(
      brightness: Brightness.dark,
      primary: AskPalette.action,
      onPrimary: AskPalette.onAction,
      surface: AskPalette.card,
      onSurface: AskPalette.ink,
      onSurfaceVariant: AskPalette.muted,
      outline: AskPalette.border,
    ),
    textTheme: textTheme,
    primaryTextTheme: textTheme,
    iconTheme: const IconThemeData(color: AskPalette.muted),
    appBarTheme: base.appBarTheme.copyWith(
      backgroundColor: conversation ? AskPalette.card : AskPalette.background,
      foregroundColor: AskPalette.ink,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      titleTextStyle: textTheme.titleMedium,
    ),
    navigationBarTheme: base.navigationBarTheme.copyWith(
      backgroundColor: AskPalette.background,
      indicatorColor: AskPalette.reply,
      iconTheme: WidgetStateProperty.resolveWith(
        (states) => IconThemeData(
          color: states.contains(WidgetState.selected)
              ? AskPalette.action
              : AskPalette.muted,
          size: 22,
        ),
      ),
      labelTextStyle: WidgetStateProperty.resolveWith(
        (states) => textStyle.copyWith(
          fontSize: 11,
          color: states.contains(WidgetState.selected)
              ? AskPalette.action
              : AskPalette.muted,
          fontWeight: states.contains(WidgetState.selected)
              ? FontWeight.w500
              : FontWeight.w400,
        ),
      ),
    ),
    cardTheme: base.cardTheme.copyWith(
      color: AskPalette.card,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      margin: EdgeInsets.zero,
    ),
    chipTheme: base.chipTheme.copyWith(
      backgroundColor: AskPalette.card,
      selectedColor: AskPalette.reply,
      side: const BorderSide(color: AskPalette.border),
      labelStyle: textStyle.copyWith(color: AskPalette.ink, fontSize: 12),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: AskPalette.action,
        textStyle: textStyle,
      ),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: AskPalette.action,
        foregroundColor: AskPalette.onAction,
        textStyle: textStyle.copyWith(fontWeight: FontWeight.w500),
      ),
    ),
    popupMenuTheme: base.popupMenuTheme.copyWith(
      color: AskPalette.card,
      textStyle: textTheme.bodyMedium,
    ),
    dialogTheme: base.dialogTheme.copyWith(
      backgroundColor: AskPalette.card,
      titleTextStyle: textTheme.titleLarge,
      contentTextStyle: textTheme.bodyMedium,
    ),
    bottomSheetTheme: base.bottomSheetTheme.copyWith(
      backgroundColor: AskPalette.card,
      surfaceTintColor: Colors.transparent,
    ),
    inputDecorationTheme: base.inputDecorationTheme.copyWith(
      filled: true,
      fillColor: AskPalette.reply,
      hintStyle: textStyle.copyWith(color: AskPalette.muted),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(24),
        borderSide: const BorderSide(color: AskPalette.border),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(24),
        borderSide: const BorderSide(color: AskPalette.border),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(24),
        borderSide: const BorderSide(color: AskPalette.action),
      ),
    ),
  );
}
