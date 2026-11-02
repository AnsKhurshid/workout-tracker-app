import 'package:flutter/material.dart';

/// Raw colour values. Screens never use these directly: they read
/// `Theme.of(context).colorScheme` or the [AppTokens] extension, so a palette
/// change happens here only.
abstract final class AppPalette {
  // Accent: a vivid lime that reads well in a dim gym and marks "done" states.
  static const lime = Color(0xFFB6F36A);
  static const limeDeep = Color(0xFF4D7C0F);
  static const limeContainerDark = Color(0xFF2B3A16);
  static const limeContainerLight = Color(0xFFDDF7B8);

  // Dark neutrals (near-black, slightly cool).
  static const darkBackground = Color(0xFF0B0D10);
  static const darkSurfaceLowest = Color(0xFF08090B);
  static const darkSurfaceLow = Color(0xFF111418);
  static const darkSurface = Color(0xFF14181C);
  static const darkSurfaceHigh = Color(0xFF1B2026);
  static const darkSurfaceHighest = Color(0xFF232930);
  static const darkOutline = Color(0xFF3A424C);
  static const darkOutlineVariant = Color(0xFF262C33);
  static const darkOnSurface = Color(0xFFF1F3F5);
  static const darkOnSurfaceVariant = Color(0xFFA0A8B2);

  // Light neutrals.
  static const lightBackground = Color(0xFFF5F6F8);
  static const lightSurfaceLowest = Color(0xFFFFFFFF);
  static const lightSurfaceLow = Color(0xFFF9FAFB);
  static const lightSurface = Color(0xFFFFFFFF);
  static const lightSurfaceHigh = Color(0xFFEEF0F3);
  static const lightSurfaceHighest = Color(0xFFE6E9ED);
  static const lightOutline = Color(0xFFB9C0C8);
  static const lightOutlineVariant = Color(0xFFE1E5EA);
  static const lightOnSurface = Color(0xFF101318);
  static const lightOnSurfaceVariant = Color(0xFF59626D);

  // Semantic.
  static const errorDark = Color(0xFFFF7A7A);
  static const errorLight = Color(0xFFC62828);
  static const warningDark = Color(0xFFF5B94A);
  static const warningLight = Color(0xFFB26A00);
  static const infoDark = Color(0xFF7CC7FF);
  static const infoLight = Color(0xFF0B6BB5);
}
